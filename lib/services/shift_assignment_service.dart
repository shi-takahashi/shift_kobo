import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:shift_kobo/models/assignment_strategy.dart';
import 'package:shift_kobo/models/companion_rule.dart';
import 'package:shift_kobo/models/shift.dart';
import 'package:shift_kobo/models/shift_constraint.dart';
import 'package:shift_kobo/models/shift_type.dart' as old_shift_type;
import 'package:shift_kobo/models/staff.dart';
import 'package:shift_kobo/models/team.dart';
import 'package:shift_kobo/providers/monthly_requirements_provider.dart';
import 'package:shift_kobo/providers/shift_provider.dart';
import 'package:shift_kobo/providers/shift_time_provider.dart';
import 'package:shift_kobo/providers/staff_provider.dart';
import 'package:shift_kobo/services/analytics_service.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;

class ShiftAssignmentService {
  final StaffProvider staffProvider;
  final ShiftProvider shiftProvider;
  final ShiftTimeProvider shiftTimeProvider;

  ShiftAssignmentService({
    required this.staffProvider,
    required this.shiftProvider,
    required this.shiftTimeProvider,
  });

  // 連休（日付未指定）の事前確保結果。staffId -> 休みに確保した日（_dateKey形式）の集合。
  // autoAssignShifts の冒頭で計算してセットし、_isStaffAvailableOnDate で休み扱いに使う。
  Map<String, Set<String>> _reservedDaysOff = {};

  // ========================================
  // 自動作成のチューニング定数
  // ========================================
  // 内部で生成する候補の数。best-of-Nで一番公平なものを採用する。
  // 「一発で完璧」を狙わず、「そこそこ公平・大きな不満なし」を出す程度。
  // もっと良いものが欲しければユーザーが再生成（→plan切替で候補が溜まる）。
  static const int _candidateCount = 8;
  // 各枠を埋める時、上位何人からランダムに選ぶか（探索の幅＝毎回違う結果になる源）。
  static const int _explorationTopK = 3;
  // 公平性ガード: 総数が「最も少ない人＋この値」までの人だけを枠の候補にする（総数のバラつき上限）。
  // この窓の中では種別が少ない人を優先するので、総数を抑えつつ種別（日勤/夜勤）も均等化できる。
  // max20なら約1.5日分。小さいほど総数は揃うが種別を散らす余地が減る。
  static const double _fairnessTolerance = 0.075;

  // 公平性スコアの重み（大きいほど重視）。
  static const double _wUnfilled = 1000.0; // 未充足枠（最重視＝できるだけ埋める）
  static const double _wTypeSpread = 8.0; // 種別ごとの偏り（夜勤/日勤を各人均等に）
  static const double _wTotalSpread = 5.0; // 総シフト数の偏り
  static const double _wPair = 1.0; // ペア（同じ2人組）の固定度
  static const double _wPreferred = 2.0; // 勤務希望日の充足（ボーナス）
  static const double _wCompanion = 50.0; // 付き添い必須(ソフト)違反＝相方なしで単独になった回数の罰
  // 生成後の公平化リバランス（局所探索）の最大反復回数。改善が止まれば早期終了する。
  static const int _rebalanceMaxIters = 300;
  // リバランスのコスト重み。総数を支配的にして「総数優先・種別は総数を崩さない範囲」にする。
  static const double _rebalanceTotalWeight = 100.0;
  static const double _rebalanceTypeWeight = 1.0;

  // カスタム名から従来のShiftType名へのマッピング
  static Map<String, String> get _customToOldMapping => {
        '早番': old_shift_type.ShiftType.morning,
        '日勤': old_shift_type.ShiftType.day,
        '遅番': old_shift_type.ShiftType.evening,
        '夜勤': old_shift_type.ShiftType.night,
        '終日': old_shift_type.ShiftType.fullDay,
      };

  String _mapCustomToOldShiftType(String customName) {
    // まず直接マッピング
    final oldName = _customToOldMapping[customName];
    if (oldName != null) return oldName;

    // 見つからない場合はそのまま返す（新しいカスタム名の場合）
    return customName;
  }

  // カスタム名からShiftTimeSettingを取得し、時間範囲を生成
  (DateTime, DateTime)? _getShiftTimeRange(String shiftTypeName, DateTime date) {
    // ShiftTimeSettingから検索
    final setting = shiftTimeProvider.settings.where((s) => s.displayName == shiftTypeName).firstOrNull;

    if (setting != null) {
      // ShiftTimeSettingから時間を取得
      final startParts = setting.startTime.split(':');
      final endParts = setting.endTime.split(':');

      final startTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      var endTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      // 終了時間が開始時間より早い場合は翌日
      if (endTime.isBefore(startTime)) {
        endTime = endTime.add(const Duration(days: 1));
      }

      return (startTime, endTime);
    }

    // 従来のShiftType.defaultTimeRangesからフォールバック
    final oldName = _mapCustomToOldShiftType(shiftTypeName);
    final timeRange = old_shift_type.ShiftType.defaultTimeRanges[oldName];
    if (timeRange != null) {
      return (timeRange.toStartDateTime(date), timeRange.toEndDateTime(date));
    }

    return null;
  }

  /// ペアを表す安定キー（順序に依存しない）
  String _pairKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  /// 日付を年月日だけのキーにする（時刻を無視して比較するため）
  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// デバッグ時のみログ出力（リリースビルドでは出力されない）。
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  // ========================================
  // 自動作成のエントリポイント
  // ========================================
  // 内部で複数の候補シフトを生成し（各回ランダム性あり）、公平性スコアで
  // 一番良いものを採用して返す（best-of-N）。
  // これにより「毎回違う、かつそこそこ公平」を実現する。
  Future<List<Shift>> autoAssignShifts(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> dailyShiftRequirements, {
    Team? team,
    AssignmentStrategy strategy = AssignmentStrategy.fairness,
    int maxConsecutiveDays = 5,
    int minRestHours = 12,
    bool overnightCountsAsTwoDays = true,
    MonthlyRequirementsProvider? requirementsProvider,
  }) async {
    // 前回実行の連休予約が残らないようにクリアしておく
    _reservedDaysOff = {};

    // 有効なスタッフのみ使用（月間最大シフト数0のスタッフは候補生成側で除外される）
    final List<Staff> availableStaff = staffProvider.activeStaffList;
    if (availableStaff.isEmpty) {
      _log('利用可能なスタッフがいません');
      return [];
    }

    // ペア設定（チーム単位）。NGは同居不可のハード制約として使う。
    final Set<String> ngPairKeys = team?.ngPairs.toSet() ?? <String>{};
    // 付き添い必須ルール（スタッフID -> ルール）。ハードは適格判定、ソフトはスコアで扱う。
    final List<CompanionRule> allCompanionRules = team?.companionRules ?? const <CompanionRule>[];

    // ② 別枠+1（研修扱い・戦力カウントしない）の新人は、生成・リバランスから除外して
    // 最後に上乗せする（後処理 _assignTrainingShadows）。こうすることで通常の戦力スケジュール
    // （相方＝指導役を含む）を歪めず・壊さずに、相方が出勤している日へ新人をシャドーで重ねられる。
    final List<CompanionRule> extraTraineeRules =
        allCompanionRules.where((r) => !r.countsAsWorkforce).toList();
    final Set<String> extraTraineeIds = extraTraineeRules.map((r) => r.staffId).toSet();

    // 生成・リバランスで使う付き添いマップは ①（戦力カウントする）ルールのみ。
    final Map<String, CompanionRule> companionByStaff = {
      for (final r in allCompanionRules)
        if (r.countsAsWorkforce) r.staffId: r,
    };

    // 生成・リバランス対象スタッフ（② 研修扱いの新人は除外。後処理で別枠+1する）。
    final List<Staff> genStaff =
        availableStaff.where((s) => !extraTraineeIds.contains(s.id)).toList();

    // 前月のシフトを取得（連続勤務日数・勤務間インターバルのチェック用）
    // スタッフ個別設定の最大値を考慮して取得範囲を決定
    int effectiveMaxConsecutive = maxConsecutiveDays;
    for (final staff in availableStaff) {
      final staffMax = staff.maxConsecutiveDays;
      if (staffMax != null && staffMax > effectiveMaxConsecutive) {
        effectiveMaxConsecutive = staffMax;
      }
    }
    final previousMonthEnd = startDate.subtract(const Duration(days: 1));
    final previousMonthStart = startDate.subtract(Duration(days: effectiveMaxConsecutive + 1));
    final previousMonthShifts = shiftProvider.getShiftsInRange(previousMonthStart, previousMonthEnd);
    _log('前月シフト取得: ${previousMonthStart.toString().split(' ')[0]} 〜 ${previousMonthEnd.toString().split(' ')[0]} (${previousMonthShifts.length}件, 最大連続日数=$effectiveMaxConsecutive)');

    // アクティブなシフトタイプ名のセットを取得
    final activeShiftTypeNames = shiftTimeProvider.settings
        .where((s) => s.isActive)
        .map((s) => s.displayName)
        .toSet();

    // 必要人数をアクティブなシフトタイプのみにフィルタリング
    final filteredRequirements = Map<String, int>.fromEntries(
      dailyShiftRequirements.entries.where((e) => activeShiftTypeNames.contains(e.key)),
    );

    _log('利用可能なスタッフ数: ${availableStaff.length}');

    // ========================================
    // 連休（日付未指定）の事前確保（ソフト）
    // ========================================
    // チーム設定「N連休をM回」を満たすため、人手に余裕のある位置に連続N日の休みを
    // 事前に確保する。確保した日は _isStaffAvailableOnDate で休み扱いになり、
    // 候補生成・リバランスの両方で尊重される。カバレッジが割れる日には置かない（＝ソフト）。
    // 連休ブロックの位置をクリックのたびに変えるため、時刻ベースの乱数を渡す。
    // （best-of-N の前で1回だけ確保するので、ここで毎回シードを変えないと毎回同じ位置になる）
    final reserveRng = Random(DateTime.now().microsecondsSinceEpoch & 0x7fffffff);
    _reservedDaysOff = _computeConsecutiveDaysOffReservations(
      startDate,
      endDate,
      genStaff,
      team,
      filteredRequirements,
      requirementsProvider,
      activeShiftTypeNames,
      reserveRng,
    );
    // ② 別枠+1（研修扱い）の新人は genStaff から外れているため、上の計算に含まれない。
    // 彼らは必要人数を消費しない（休んでも未充足を生まない）ので、戦力のカバレッジ計算と分けて
    // 連休を別計算し、結果をマージする。これで研修新人の連休も確保される（後処理 _assignTrainingShadows が
    // _reservedDaysOff を尊重して上乗せを避ける）。
    if (extraTraineeIds.isNotEmpty) {
      final traineeStaff =
          availableStaff.where((s) => extraTraineeIds.contains(s.id)).toList();
      final traineeReservations = _computeConsecutiveDaysOffReservations(
        startDate,
        endDate,
        traineeStaff,
        team,
        filteredRequirements,
        requirementsProvider,
        activeShiftTypeNames,
        reserveRng,
      );
      traineeReservations.forEach((staffId, days) {
        _reservedDaysOff.putIfAbsent(staffId, () => <String>{}).addAll(days);
      });
    }
    final reservedTotal = _reservedDaysOff.values.fold<int>(0, (a, b) => a + b.length);
    if (reservedTotal > 0) {
      final rulesDesc = (team?.consecutiveDaysOffRules ?? const [])
          .map((r) => '${r.length}連休×${r.count}')
          .join(', ');
      _log('連休事前確保: ${_reservedDaysOff.length}人 / 合計$reservedTotal日 (ルール: $rulesDesc)');
    }

    // ========================================
    // best-of-N: N個の候補を生成して一番公平なものを選ぶ
    // ========================================
    // クリックのたびに違う結果になるよう、時刻ベースのシードを使う。
    final baseSeed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    _Candidate? best;
    double bestScore = double.negativeInfinity;

    for (int i = 0; i < _candidateCount; i++) {
      final rng = Random(baseSeed + i * 7919 + 1);
      final candidate = _generateCandidate(
        startDate,
        endDate,
        filteredRequirements,
        genStaff,
        team,
        maxConsecutiveDays,
        minRestHours,
        overnightCountsAsTwoDays,
        ngPairKeys,
        companionByStaff,
        strategy,
        requirementsProvider,
        activeShiftTypeNames,
        previousMonthShifts,
        rng,
      );
      final score = _scoreCandidate(candidate, genStaff, activeShiftTypeNames, companionByStaff);
      _log('候補#$i: score=${score.toStringAsFixed(1)}, shifts=${candidate.shifts.length}, 未充足=${candidate.unfilled}, 希望充足=${candidate.preferredGranted}');
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    // best候補に対して公平化リバランス（後処理で総数・種別の偏りをならす）。
    // 貪欲生成の経路依存（種別の偏り・4連休など）を、制約を守ったまま付け替えで解消する。
    if (best != null) {
      _logFairnessSummary('リバランス前', best.shifts, genStaff, activeShiftTypeNames);
      // 厳しい連勤上限でも総数を揃えられるよう、先に「間隔ならし」で塊をほぐして隙間を作り、
      // その隙間に総数/種別リバランスで少ない人のシフトを入れ、最後にもう一度ならす。
      // 各パスとも制約安全（連勤上限などの違反は作らない）。
      for (int round = 0; round < 2; round++) {
        // 総数・種別を変えずに、勤務/休みのタイミングだけ平均化する（同種別の日付交換）。
        _rebalanceSpacing(
          best.shifts,
          genStaff,
          maxConsecutiveDays,
          minRestHours,
          overnightCountsAsTwoDays,
          ngPairKeys,
          companionByStaff,
          previousMonthShifts,
        );
        _rebalanceFairness(
          best.shifts,
          genStaff,
          activeShiftTypeNames,
          maxConsecutiveDays,
          minRestHours,
          overnightCountsAsTwoDays,
          ngPairKeys,
          companionByStaff,
          previousMonthShifts,
        );
      }
      _rebalanceSpacing(
        best.shifts,
        genStaff,
        maxConsecutiveDays,
        minRestHours,
        overnightCountsAsTwoDays,
        ngPairKeys,
        companionByStaff,
        previousMonthShifts,
      );
      _logFairnessSummary('リバランス後', best.shifts, genStaff, activeShiftTypeNames);
      // 念のため: 最終結果が連勤上限を満たしているか自動検証してログに出す。
      _logConsecutiveCheck(best.shifts, genStaff, maxConsecutiveDays, overnightCountsAsTwoDays, previousMonthShifts);

      // ② 別枠+1（研修扱い）の新人を、生成・リバランス後のシフトへ上乗せする。
      // 相方（指導役）が既に出勤している日へ、本人の月間上限・公平性に従って分散配置する。
      if (extraTraineeRules.isNotEmpty) {
        _assignTrainingShadows(
          best.shifts,
          extraTraineeRules,
          availableStaff,
          startDate,
          endDate,
          team,
          maxConsecutiveDays,
          minRestHours,
          overnightCountsAsTwoDays,
          ngPairKeys,
          requirementsProvider,
          filteredRequirements,
          activeShiftTypeNames,
          previousMonthShifts,
          strategy,
        );
      }
    }

    final result = best?.shifts ?? [];

    // 採用候補のシフトIDを一意なものに振り直す（FirestoreのドキュメントID衝突を防ぐ）
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < result.length; i++) {
      final prefix = result[i].id.startsWith('pref_') ? 'auto_pref' : 'auto';
      result[i].id = '${prefix}_${stamp}_$i';
    }

    // Analytics（採用された候補で1回だけ送信）
    await _logPreferredAnalytics(startDate, endDate, availableStaff, result);

    _log('best-of-$_candidateCount 採用: score=${bestScore.toStringAsFixed(1)}, 作成シフト数=${result.length}');
    return result;
  }

  // ========================================
  // ② 別枠+1（研修扱い）の付き添い新人を、生成・リバランス後のシフトへ上乗せする
  // ========================================
  // 新人は「戦力としてカウントしない」ため必要人数を消費しない。相方（指導役）が既に出勤している日へ、
  // 本人の月間上限・公平性に従って分散配置する（相方在席は _isEligible のハード判定で担保）。
  // リバランス後に動くので、戦力スケジュールを一切歪めず・壊さない。
  void _assignTrainingShadows(
    List<Shift> shifts,
    List<CompanionRule> traineeRules,
    List<Staff> allStaff,
    DateTime startDate,
    DateTime endDate,
    Team? team,
    int maxConsecutiveDays,
    int minRestHours,
    bool overnightCountsAsTwoDays,
    Set<String> ngPairKeys,
    MonthlyRequirementsProvider? requirementsProvider,
    Map<String, int> filteredRequirements,
    Set<String> activeShiftTypeNames,
    List<Shift> previousMonthShifts,
    AssignmentStrategy strategy,
  ) {
    final staffById = {for (final s in allStaff) s.id: s};

    // 通常スタッフ（戦力）の実出勤水準を「充足率＝担当数 / 月間上限 の平均」で求める。
    // 研修新人は頭数に入らず必要枠で律速されないため、上限まで埋めると働きすぎる
    // （他が15日／上限20なのに新人だけ20日になる）。そこで目標を「上限」ではなく
    // 「通常スタッフと同じ充足率」にし、max が同じなら同じ出勤日数に揃うようにする。
    final traineeIds = traineeRules.map((r) => r.staffId).toSet();
    final workforce = allStaff
        .where((s) => s.maxShiftsPerMonth > 0 && !traineeIds.contains(s.id))
        .toList();
    double workforceFillRate = 1.0;
    if (workforce.isNotEmpty) {
      double sum = 0;
      for (final s in workforce) {
        final c = shifts.where((sh) => sh.staffId == s.id).length;
        sum += c / s.maxShiftsPerMonth;
      }
      workforceFillRate = sum / workforce.length;
    }

    for (final rule in traineeRules) {
      final trainee = staffById[rule.staffId];
      if (trainee == null) continue;
      if (trainee.maxShiftsPerMonth <= 0) continue;

      // この新人を1人だけ含む付き添いマップ（_isEligible の相方在席チェックを効かせるため）。
      final soloCompanionMap = {rule.staffId: rule};
      // _isEligible が読むのは本人の月間カウントのみ。本人分だけ持てば十分。
      final counts = <String, int>{
        rule.staffId: shifts.where((s) => s.staffId == rule.staffId).length,
      };

      // その日に本人が入れる（相方在席・休み希望・連勤・インターバル・NG など全制約クリアの）
      // シフト種別を1つ返す。無ければ null。判定はその時点の shifts/counts に対して都度行う。
      String? eligibleTypeFor(DateTime date) {
        if (team != null && _isTeamHoliday(team, date)) return null;
        final rawReq = requirementsProvider?.getRequirementsForDate(date) ?? filteredRequirements;
        for (final shiftType in rawReq.keys) {
          if (!activeShiftTypeNames.contains(shiftType)) continue;
          if (_getShiftTimeRange(shiftType, date) == null) continue;
          if (_isEligible(
            trainee,
            date,
            shiftType,
            shifts,
            counts,
            maxConsecutiveDays,
            minRestHours,
            previousMonthShifts,
            overnightCountsAsTwoDays: overnightCountsAsTwoDays,
            ngPairKeys: ngPairKeys,
            companionByStaff: soloCompanionMap,
          )) {
            return shiftType;
          }
        }
        return null;
      }

      final placedDates = <String>{};
      int placed = 0;
      void place(DateTime date, String shiftType) {
        final range = _getShiftTimeRange(shiftType, date)!;
        shifts.add(Shift(
          id: 'tmp_shadow_${rule.staffId}_$placed',
          date: date,
          startTime: range.$1,
          endTime: range.$2,
          staffId: rule.staffId,
          shiftType: shiftType,
          assignmentStrategy: strategy.name,
        ));
        counts[rule.staffId] = (counts[rule.staffId] ?? 0) + 1;
        placedDates.add(_dateKey(date));
        placed++;
      }

      final startOnly = DateTime(startDate.year, startDate.month, startDate.day);

      // 1) 勤務希望日（制約）を最優先で確保する。全制約をクリアできる希望日は必ず置く。
      //    （戦力側の _assignPreferredDates と同じ「希望日を先に置く」流儀。）
      int preferredPlaced = 0;
      final preferredInRange = trainee.preferredDates
          .map((iso) => DateTime.parse(iso))
          .map((dt) => DateTime(dt.year, dt.month, dt.day))
          .where((dt) => !dt.isBefore(startOnly) && !dt.isAfter(endDate))
          .toList()
        ..sort((a, b) => a.compareTo(b));
      for (final date in preferredInRange) {
        final type = eligibleTypeFor(date);
        if (type != null) {
          place(date, type);
          preferredPlaced++;
        }
      }

      // 2) 残りを「通常スタッフと同じ充足率」の日数まで、相方のいる日へできるだけ公平に
      //    （月内で等間隔に）分散する。目標は上限ではなく水準（max が同じなら他と同じ出勤日数）。
      final fairTarget = (workforceFillRate * trainee.maxShiftsPerMonth)
          .round()
          .clamp(0, trainee.maxShiftsPerMonth)
          .toInt();
      final remainingBudget = fairTarget - placed;
      if (remainingBudget > 0) {
        final feasible = <({DateTime date, String shiftType})>[];
        DateTime d = startOnly;
        while (!d.isAfter(endDate)) {
          if (!placedDates.contains(_dateKey(d))) {
            final type = eligibleTypeFor(d);
            if (type != null) feasible.add((date: d, shiftType: type));
          }
          d = d.add(const Duration(days: 1));
        }
        final target = remainingBudget < feasible.length ? remainingBudget : feasible.length;
        for (final slot in _evenlySample(feasible, target)) {
          // 直前の上乗せで連勤/インターバル等が崩れていないか都度再判定する。
          final type = eligibleTypeFor(slot.date);
          if (type != null) place(slot.date, type);
        }
      }

      if (placed == 0) {
        _log('付き添い(別枠+1): ${trainee.name} は相方の出勤日が無く配置できませんでした');
      } else {
        _log('付き添い(別枠+1): ${trainee.name} を $placed 日上乗せ'
            '（勤務希望 $preferredPlaced 日 / 目標 ${(workforceFillRate * trainee.maxShiftsPerMonth).round()} 日'
            '＝通常充足率${(workforceFillRate * 100).round()}% / 月間上限 ${trainee.maxShiftsPerMonth}）');
      }
    }
  }

  /// リストから target 個を等間隔で選ぶ（月内に均等分散させるため）。
  List<T> _evenlySample<T>(List<T> items, int target) {
    if (target <= 0) return [];
    if (target >= items.length) return List<T>.from(items);
    final result = <T>[];
    for (int i = 0; i < target; i++) {
      result.add(items[(i * items.length) ~/ target]);
    }
    return result;
  }

  // ========================================
  // 1つの候補シフトを生成する（ランダム性あり）
  // ========================================
  _Candidate _generateCandidate(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> filteredRequirements,
    List<Staff> availableStaff,
    Team? team,
    int maxConsecutiveDays,
    int minRestHours,
    bool overnightCountsAsTwoDays,
    Set<String> ngPairKeys,
    Map<String, CompanionRule> companionByStaff,
    AssignmentStrategy strategy,
    MonthlyRequirementsProvider? requirementsProvider,
    Set<String> activeShiftTypeNames,
    List<Shift> previousMonthShifts,
    Random rng,
  ) {
    final List<Shift> assignedShifts = [];
    int idCounter = 0;
    int unfilled = 0;

    // この候補内の集計（公平性のために逐次更新する）
    final Map<String, int> staffShiftCounts = {}; // staffId -> 総シフト数
    final Map<String, Map<String, int>> staffTypeCounts = {}; // staffId -> (種別 -> 数)
    final Map<String, int> pairCounts = {}; // ペアキー -> 同じシフトに入った回数
    for (final staff in availableStaff) {
      staffShiftCounts[staff.id] = 0;
      staffTypeCounts[staff.id] = {};
    }

    // --- 第1段階: 勤務希望日を優先的に割り当て ---
    final preferredGranted = _assignPreferredDates(
      startDate,
      endDate,
      filteredRequirements,
      availableStaff,
      staffShiftCounts,
      staffTypeCounts,
      pairCounts,
      team,
      maxConsecutiveDays,
      minRestHours,
      strategy,
      assignedShifts,
      rng,
      requirementsProvider: requirementsProvider,
      activeShiftTypeNames: activeShiftTypeNames,
      previousMonthShifts: previousMonthShifts,
      overnightCountsAsTwoDays: overnightCountsAsTwoDays,
      ngPairKeys: ngPairKeys,
      companionByStaff: companionByStaff,
    );

    // --- 第2段階: 残りのシフトを割り当て ---
    DateTime currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      // チーム休みの日はスキップ
      if (team != null && _isTeamHoliday(team, currentDate)) {
        currentDate = currentDate.add(const Duration(days: 1));
        continue;
      }

      // この日の必要人数（曜日別・日付個別設定があれば優先）
      final rawDateRequirements = requirementsProvider?.getRequirementsForDate(currentDate) ?? filteredRequirements;
      final dateRequirements = Map<String, int>.fromEntries(
        rawDateRequirements.entries.where((e) => activeShiftTypeNames.contains(e.key)),
      );

      for (final shiftType in dateRequirements.keys) {
        final requiredStaffCount = dateRequirements[shiftType] ?? 0;

        // この日のこのシフトタイプで既に割り当て済みの人数
        final alreadyAssigned = assignedShifts.where((shift) =>
            _isSameDay(shift.date, currentDate) && shift.shiftType == shiftType).length;

        final remainingSlots = requiredStaffCount - alreadyAssigned;
        if (remainingSlots <= 0) continue;

        final timeRange = _getShiftTimeRange(shiftType, currentDate);
        if (timeRange == null) {
          unfilled += remainingSlots;
          continue;
        }

        // この枠に1人割り当てる
        void place(Staff staff) {
          idCounter++;
          final shift = Shift(
            id: 'tmp_$idCounter',
            date: currentDate,
            startTime: timeRange.$1,
            endTime: timeRange.$2,
            staffId: staff.id,
            shiftType: shiftType,
            assignmentStrategy: strategy.name,
          );
          assignedShifts.add(shift);
          _recordAssignment(staff.id, currentDate, shiftType, assignedShifts, staffShiftCounts, staffTypeCounts, pairCounts);
        }

        // この枠に付き添い必須スタッフの相方候補が既に在席しているか
        bool companionPresent(CompanionRule rule) => assignedShifts.any((s) =>
            _isSameDay(s.date, currentDate) && s.shiftType == shiftType && rule.companionIds.contains(s.staffId));

        bool eligibleHere(Staff staff, {bool withCompanionReq = true}) => _isEligible(
              staff,
              currentDate,
              shiftType,
              assignedShifts,
              staffShiftCounts,
              maxConsecutiveDays,
              minRestHours,
              previousMonthShifts,
              overnightCountsAsTwoDays: overnightCountsAsTwoDays,
              ngPairKeys: ngPairKeys,
              companionByStaff: withCompanionReq ? companionByStaff : const {},
            );

        int filled = 0;

        // --- 底上げシード: 出勤が遅れている付き添い必須スタッフを、相方とセットで先に確保する ---
        // 「ベテラン2人で埋まる枠」を「遅れている新人＋ベテラン」に振り向け、新人の出勤を公平水準まで引き上げる。
        // 平均充足率（担当数/最大日数の平均）を超えたら対象外になるので入れ過ぎない。
        if (companionByStaff.isNotEmpty) {
          double fillRate(Staff s) =>
              s.maxShiftsPerMonth > 0 ? (staffShiftCounts[s.id] ?? 0) / s.maxShiftsPerMonth : 1.0;
          final workableForAvg = availableStaff.where((s) => s.maxShiftsPerMonth > 0).toList();
          final avgFill = workableForAvg.isEmpty
              ? 0.0
              : workableForAvg.map(fillRate).reduce((a, b) => a + b) / workableForAvg.length;

          // 遅れている順に処理
          final laggers = availableStaff
              .where((s) => (companionByStaff[s.id]?.hard ?? false) && fillRate(s) < avgFill)
              .toList()
            ..sort((a, b) => fillRate(a).compareTo(fillRate(b)));

          for (final c in laggers) {
            if (remainingSlots - filled < 2) break; // 本人＋相方で2席必要
            final rule = companionByStaff[c.id]!;
            if (companionPresent(rule)) continue; // 既に相方在席なら通常フローで入れる
            if (!eligibleHere(c, withCompanionReq: false)) continue; // 本人が相方要件以外で適格か
            final companions = availableStaff
                .where((x) => x.id != c.id && rule.companionIds.contains(x.id) && eligibleHere(x))
                .toList();
            if (companions.isEmpty) continue;
            final companion = _selectStaffForSlot(
                companions, currentDate, shiftType, staffShiftCounts, staffTypeCounts, pairCounts, assignedShifts, strategy, rng);
            place(companion);
            place(c);
            filled += 2;
          }
        }

        while (filled < remainingSlots) {
          final seatsLeft = remainingSlots - filled;

          // 通常の適格者（付き添い必須スタッフは相方が在席する枠でだけ含まれる）
          final eligible = availableStaff.where((s) => eligibleHere(s)).toList();

          // ブートストラップ候補: 相方未在席でも、適格な相方を1人連れて来れば入れる付き添い必須スタッフ。
          // 本人＋相方で2席必要なので seatsLeft>=2 のときだけ。これで本人も「1人目の席」を取りに行ける。
          final bootstrap = <Staff>[];
          if (seatsLeft >= 2) {
            for (final staff in availableStaff) {
              final rule = companionByStaff[staff.id];
              if (rule == null || !rule.hard) continue;
              if (companionPresent(rule)) continue; // 在席なら通常eligible側で扱う
              if (!eligibleHere(staff, withCompanionReq: false)) continue; // 相方要件以外で適格か
              final hasBringable =
                  availableStaff.any((c) => c.id != staff.id && rule.companionIds.contains(c.id) && eligibleHere(c));
              if (hasBringable) bootstrap.add(staff);
            }
          }

          final eligibleIds = eligible.map((s) => s.id).toSet();
          final pool = [...eligible, ...bootstrap.where((s) => !eligibleIds.contains(s.id))];
          if (pool.isEmpty) {
            unfilled += seatsLeft;
            break;
          }

          final chosen = _selectStaffForSlot(
            pool, currentDate, shiftType, staffShiftCounts, staffTypeCounts, pairCounts, assignedShifts, strategy, rng);

          final chosenRule = companionByStaff[chosen.id];
          if (chosenRule != null && chosenRule.hard && !companionPresent(chosenRule)) {
            // ブートストラップ: 相方を1人先に確保してから本人を入れる（本人を単独にしない）
            final companions = availableStaff
                .where((c) => c.id != chosen.id && chosenRule.companionIds.contains(c.id) && eligibleHere(c))
                .toList();
            if (companions.isEmpty || seatsLeft < 2) {
              // 想定外（poolに入る条件で担保済み）。安全側で残り席を諦める。
              unfilled += seatsLeft;
              break;
            }
            final companion = _selectStaffForSlot(
                companions, currentDate, shiftType, staffShiftCounts, staffTypeCounts, pairCounts, assignedShifts, strategy, rng);
            place(companion);
            place(chosen);
            filled += 2;
          } else {
            place(chosen);
            filled++;
          }
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return _Candidate(assignedShifts, unfilled, preferredGranted);
  }

  /// 第1段階: 勤務希望日を優先的に割り当て。割り当てた希望日シフト数を返す。
  int _assignPreferredDates(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> dailyShiftRequirements,
    List<Staff> availableStaff,
    Map<String, int> staffShiftCounts,
    Map<String, Map<String, int>> staffTypeCounts,
    Map<String, int> pairCounts,
    Team? team,
    int maxConsecutiveDays,
    int minRestHours,
    AssignmentStrategy strategy,
    List<Shift> assignedShifts,
    Random rng, {
    MonthlyRequirementsProvider? requirementsProvider,
    Set<String>? activeShiftTypeNames,
    List<Shift> previousMonthShifts = const [],
    bool overnightCountsAsTwoDays = true,
    Set<String> ngPairKeys = const {},
    Map<String, CompanionRule> companionByStaff = const {},
  }) {
    int granted = 0;

    // 勤務希望日を持つスタッフを抽出
    final staffWithPreferences = availableStaff.where((staff) => staff.preferredDates.isNotEmpty).toList();
    if (staffWithPreferences.isEmpty) return 0;

    // 各スタッフの希望日充足数（この生成内でのみ使用）
    final Map<String, int> preferredDateGrantedCount = {};
    for (final staff in staffWithPreferences) {
      preferredDateGrantedCount[staff.id] = 0;
    }

    // 日付ごとに希望者をグループ化
    final Map<DateTime, List<Staff>> preferencesByDate = {};
    for (final staff in staffWithPreferences) {
      for (final dateStr in staff.preferredDates) {
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);

        if (dateOnly.isBefore(startDate) || dateOnly.isAfter(endDate)) continue;
        if (team != null && _isTeamHoliday(team, dateOnly)) continue;
        if (!_isStaffAvailableOnDate(staff, dateOnly)) continue;

        preferencesByDate[dateOnly] ??= [];
        preferencesByDate[dateOnly]!.add(staff);
      }
    }

    for (final entry in preferencesByDate.entries) {
      final date = entry.key;
      final candidates = entry.value;

      final rawDateRequirements = requirementsProvider?.getRequirementsForDate(date) ?? dailyShiftRequirements;
      final dateRequirements = activeShiftTypeNames != null
          ? Map<String, int>.fromEntries(
              rawDateRequirements.entries.where((e) => activeShiftTypeNames.contains(e.key)),
            )
          : rawDateRequirements;

      for (final shiftType in dateRequirements.keys) {
        final requiredStaffCount = dateRequirements[shiftType] ?? 0;

        final alreadyAssigned = assignedShifts.where((shift) =>
            _isSameDay(shift.date, date) && shift.shiftType == shiftType).length;

        final remainingSlots = requiredStaffCount - alreadyAssigned;
        if (remainingSlots <= 0) continue;

        // 有効な候補者をフィルタリング（共通の適格判定を使用）
        final validCandidates = candidates
            .where((staff) => _isEligible(
                  staff,
                  date,
                  shiftType,
                  assignedShifts,
                  staffShiftCounts,
                  maxConsecutiveDays,
                  minRestHours,
                  previousMonthShifts,
                  overnightCountsAsTwoDays: overnightCountsAsTwoDays,
                  ngPairKeys: ngPairKeys,
                  companionByStaff: companionByStaff,
                ))
            .toList();
        if (validCandidates.isEmpty) continue;

        // 希望充足率が低い人を優先（同率はランダム）
        validCandidates.shuffle(rng);
        validCandidates.sort((a, b) {
          final aPreferredCount = a.preferredDates.length;
          final bPreferredCount = b.preferredDates.length;
          final aGranted = preferredDateGrantedCount[a.id] ?? 0;
          final bGranted = preferredDateGrantedCount[b.id] ?? 0;

          final aRate = aPreferredCount > 0 ? aGranted / aPreferredCount : 0.0;
          final bRate = bPreferredCount > 0 ? bGranted / bPreferredCount : 0.0;
          if ((aRate - bRate).abs() > 0.001) return aRate.compareTo(bRate);

          // 希望日数が少ない人を優先
          return aPreferredCount.compareTo(bPreferredCount);
        });

        int assignedCount = 0;
        for (final staff in validCandidates) {
          if (assignedCount >= remainingSlots) break;

          final timeRange = _getShiftTimeRange(shiftType, date);
          if (timeRange == null) continue;

          final shift = Shift(
            id: 'pref_${granted}_${date.millisecondsSinceEpoch}',
            date: date,
            startTime: timeRange.$1,
            endTime: timeRange.$2,
            staffId: staff.id,
            shiftType: shiftType,
            assignmentStrategy: strategy.name,
          );
          assignedShifts.add(shift);
          _recordAssignment(staff.id, date, shiftType, assignedShifts, staffShiftCounts, staffTypeCounts, pairCounts);
          preferredDateGrantedCount[staff.id] = (preferredDateGrantedCount[staff.id] ?? 0) + 1;
          assignedCount++;
          granted++;
        }
      }
    }

    return granted;
  }

  /// あるスタッフを指定の日・シフトタイプに割り当て可能か（ハード制約のチェック）
  bool _isEligible(
    Staff staff,
    DateTime date,
    String shiftType,
    List<Shift> assignedShifts,
    Map<String, int> staffShiftCounts,
    int maxConsecutiveDays,
    int minRestHours,
    List<Shift> previousMonthShifts, {
    bool overnightCountsAsTwoDays = true,
    Set<String> ngPairKeys = const {},
    Map<String, CompanionRule> companionByStaff = const {},
  }) {
    // 休み希望・勤務不可日
    if (!_isStaffAvailableOnDate(staff, date)) return false;

    // 月間最大シフト数（0の場合はここで必ず除外される）
    if ((staffShiftCounts[staff.id] ?? 0) >= staff.maxShiftsPerMonth) return false;

    // シフトタイプ制約（カスタム名・従来名の両方でチェック）
    final oldShiftTypeName = _mapCustomToOldShiftType(shiftType);
    if (staff.unavailableShiftTypes.contains(shiftType) || staff.unavailableShiftTypes.contains(oldShiftTypeName)) {
      return false;
    }

    // 同じ日に既にシフトがある場合は除外
    final hasShiftOnDate = assignedShifts.any((shift) => shift.staffId == staff.id && _isSameDay(shift.date, date));
    if (hasShiftOnDate) return false;

    // NGペア: 同じ日・同じシフト枠にNG相手が既に入っているなら不可
    if (ngPairKeys.isNotEmpty) {
      final hasNgCoworker = assignedShifts.any((shift) =>
          shift.staffId != staff.id &&
          _isSameDay(shift.date, date) &&
          shift.shiftType == shiftType &&
          ngPairKeys.contains(Team.pairKey(staff.id, shift.staffId)));
      if (hasNgCoworker) return false;
    }

    // 付き添い必須（ハード）: この枠に相方候補が誰も入っていないなら不可（＝単独勤務させない）。
    // 相方が既にいる枠にのみ後乗りできる＝本人が枠の先頭になれないので一人になることがない。
    final companionRule = companionByStaff[staff.id];
    if (companionRule != null && companionRule.hard) {
      final hasCompanion = assignedShifts.any((shift) =>
          _isSameDay(shift.date, date) &&
          shift.shiftType == shiftType &&
          companionRule.companionIds.contains(shift.staffId));
      if (!hasCompanion) return false;
    }

    // 連続勤務日数（個別設定を優先、前月も考慮）
    // これから入れるシフトが夜勤なら2日分消費する扱い。
    // 「前の連勤 ＋ 今回 ＋ 後ろの連勤」が上限を超えたら不可。
    // 前方向だけでなく後方向も見るのは、リバランス等でスケジュールの途中に差し込む場合に
    // 差し込み日の未来側に既にある連勤を見落とさないため（生成は追加のみなので後ろ=0）。
    final effectiveMaxConsecutive = _getEffectiveMaxConsecutiveDays(staff, maxConsecutiveDays);
    final priorConsecutive = _getConsecutiveWorkDays(
        staff.id, date, assignedShifts, previousMonthShifts, overnightCountsAsTwoDays);
    final forwardConsecutive = _getConsecutiveWorkDaysForward(
        staff.id, date, assignedShifts, overnightCountsAsTwoDays);
    final newShiftCost = (overnightCountsAsTwoDays && _isOvernightShiftType(shiftType, date)) ? 2 : 1;
    if (priorConsecutive + newShiftCost + forwardConsecutive > effectiveMaxConsecutive) {
      return false;
    }

    // 勤務間インターバル（個別設定を優先、前月も考慮）
    final effectiveMinRest = _getEffectiveMinRestHours(staff, minRestHours);
    if (!_checkWorkInterval(staff.id, date, shiftType, assignedShifts, effectiveMinRest, previousMonthShifts)) {
      return false;
    }

    return true;
  }

  /// 適格なスタッフの中から、公平性を考慮しつつランダム性を持たせて1人選ぶ。
  /// 「上位K人から重み付きランダム」で選ぶことで、毎回違う＆そこそこ公平にする。
  Staff _selectStaffForSlot(
    List<Staff> eligible,
    DateTime date,
    String shiftType,
    Map<String, int> staffShiftCounts,
    Map<String, Map<String, int>> staffTypeCounts,
    Map<String, int> pairCounts,
    List<Shift> assignedShifts,
    AssignmentStrategy strategy,
    Random rng,
  ) {
    if (eligible.length == 1) return eligible.first;

    // この日のこのシフトタイプに既に入っている人（＝一緒に組む人）
    final coWorkers = assignedShifts
        .where((s) => _isSameDay(s.date, date) && s.shiftType == shiftType)
        .map((s) => s.staffId)
        .toList();

    double pairCostOf(Staff staff) {
      double cost = 0;
      for (final cw in coWorkers) {
        cost += (pairCounts[_pairKey(staff.id, cw)] ?? 0).toDouble();
      }
      return cost;
    }

    // 種別の偏りも最大出勤日数に対する比率で見る（全員同じ上限なら生枚数と同値）
    double typeCountOf(Staff staff) {
      final c = (staffTypeCounts[staff.id]?[shiftType] ?? 0).toDouble();
      return staff.maxShiftsPerMonth > 0 ? c / staff.maxShiftsPerMonth : c;
    }

    double fillRateOf(Staff staff) {
      final count = staffShiftCounts[staff.id] ?? 0;
      return staff.maxShiftsPerMonth > 0 ? count / staff.maxShiftsPerMonth : 1.0;
    }

    int daysSinceOf(Staff staff) => _getDaysSinceLastShift(staff.id, date, assignedShifts);

    // 同率はランダムに崩したいので、先にシャッフルしてから安定ソート
    eligible.shuffle(rng);
    eligible.sort((a, b) {
      int cmp;
      if (strategy == AssignmentStrategy.distributed) {
        // 分散優先: まず間隔（最後の勤務からの経過日数が大きい人）
        cmp = daysSinceOf(b).compareTo(daysSinceOf(a));
        if (cmp != 0) return cmp;
        cmp = typeCountOf(a).compareTo(typeCountOf(b));
        if (cmp != 0) return cmp;
        cmp = fillRateOf(a).compareTo(fillRateOf(b));
        if (cmp != 0) return cmp;
        return pairCostOf(a).compareTo(pairCostOf(b));
      } else {
        // 公平性優先: まず種別ごとの偏り → 総数（充足率）→ ペア → 間隔。
        // 総数は別途「公平性ガードの窓」で範囲を抑えるので、ここでは種別を優先し、
        // 窓内（総数がほぼ同じ人たち）で「その種別が少ない人」を選んで種別を均等化する。
        cmp = typeCountOf(a).compareTo(typeCountOf(b));
        if (cmp != 0) return cmp;
        cmp = fillRateOf(a).compareTo(fillRateOf(b));
        if (cmp != 0) return cmp;
        cmp = pairCostOf(a).compareTo(pairCostOf(b));
        if (cmp != 0) return cmp;
        return daysSinceOf(b).compareTo(daysSinceOf(a));
      }
    });

    // 公平性ガード: 最も空いている人より充足率が _fairnessTolerance 以上多い人は探索対象から外す。
    // これで「まだ空いている人がいるのに、もう入っている人を先に選ぶ」のを防ぎ、総数のバラつきを抑える。
    // （whereは順序を保つので、種別バランス優先のソート順は維持される）
    final minFill = eligible.map(fillRateOf).reduce(min);
    final candidates = eligible.where((s) => fillRateOf(s) <= minFill + _fairnessTolerance).toList();
    final pool = candidates.isNotEmpty ? candidates : eligible;

    // 上位K人から重み付きランダム（上位ほど選ばれやすい）
    final k = min(_explorationTopK, pool.length);
    // 重み: [k, k-1, ..., 1]
    final totalWeight = k * (k + 1) / 2;
    double r = rng.nextDouble() * totalWeight;
    for (int i = 0; i < k; i++) {
      final w = (k - i).toDouble();
      if (r < w) return pool[i];
      r -= w;
    }
    return pool.first;
  }

  /// 割り当てを記録して各集計を更新する
  void _recordAssignment(
    String staffId,
    DateTime date,
    String shiftType,
    List<Shift> assignedShifts,
    Map<String, int> staffShiftCounts,
    Map<String, Map<String, int>> staffTypeCounts,
    Map<String, int> pairCounts,
  ) {
    staffShiftCounts[staffId] = (staffShiftCounts[staffId] ?? 0) + 1;
    final typeMap = staffTypeCounts[staffId] ??= {};
    typeMap[shiftType] = (typeMap[shiftType] ?? 0) + 1;

    // 同じ日・同じシフトタイプの既存メンバーとのペアを記録（自分自身は除く）
    for (final s in assignedShifts) {
      if (s.staffId == staffId) continue;
      if (_isSameDay(s.date, date) && s.shiftType == shiftType) {
        final key = _pairKey(staffId, s.staffId);
        pairCounts[key] = (pairCounts[key] ?? 0) + 1;
      }
    }
  }

  // ========================================
  // 公平性スコア（高いほど良い候補）
  // ========================================
  double _scoreCandidate(_Candidate candidate, List<Staff> availableStaff, Set<String> activeShiftTypeNames,
      [Map<String, CompanionRule> companionByStaff = const {}]) {
    final shifts = candidate.shifts;

    // 実際に働ける（月間最大>0）スタッフのみを公平性の対象にする
    final workable = availableStaff.where((s) => s.maxShiftsPerMonth > 0).toList();
    if (workable.isEmpty) return -double.maxFinite;

    // 総シフト数の集計
    final Map<String, int> totalCounts = {for (final s in workable) s.id: 0};
    // 種別ごとの集計
    final Map<String, Map<String, int>> typeCounts = {for (final s in workable) s.id: {}};
    // ペアの集計（同じ日・同じシフトタイプ）
    final Map<String, int> pairCounts = {};
    // (日付,種別) -> メンバー
    final Map<String, List<String>> groups = {};

    for (final shift in shifts) {
      if (totalCounts.containsKey(shift.staffId)) {
        totalCounts[shift.staffId] = totalCounts[shift.staffId]! + 1;
        final tm = typeCounts[shift.staffId]!;
        tm[shift.shiftType] = (tm[shift.shiftType] ?? 0) + 1;
      }
      final gkey = '${shift.date.year}-${shift.date.month}-${shift.date.day}|${shift.shiftType}';
      (groups[gkey] ??= []).add(shift.staffId);
    }

    for (final members in groups.values) {
      for (int i = 0; i < members.length; i++) {
        for (int j = i + 1; j < members.length; j++) {
          final key = _pairKey(members[i], members[j]);
          pairCounts[key] = (pairCounts[key] ?? 0) + 1;
        }
      }
    }

    // 公平性は「最大出勤日数に対する比率」で見る（多く働ける人は多く・少ない人は少なく）。
    // 担当数を「平均最大日数を持っていたら何枚相当か」に正規化してから散らばりを測る。
    // 全員の最大日数が同じなら正規化後＝生枚数になり、既存のチューニング（重み）を壊さない。
    final avgMax = workable.map((s) => s.maxShiftsPerMonth).reduce((a, b) => a + b) / workable.length;
    double normalized(int count, int max) => max > 0 ? count / max * avgMax : count.toDouble();

    // 総数の偏り（比率ベースの標準偏差）
    final totalSpread = _stddev(workable.map((s) => normalized(totalCounts[s.id]!, s.maxShiftsPerMonth)).toList());

    // 種別ごとの偏り（各種別について、担当できるスタッフ間の比率の標準偏差を合計）
    double typeSpread = 0;
    for (final type in activeShiftTypeNames) {
      final oldName = _mapCustomToOldShiftType(type);
      final capable = workable.where((s) =>
          !s.unavailableShiftTypes.contains(type) && !s.unavailableShiftTypes.contains(oldName)).toList();
      if (capable.length < 2) continue;
      final counts = capable.map((s) => normalized(typeCounts[s.id]?[type] ?? 0, s.maxShiftsPerMonth)).toList();
      typeSpread += _stddev(counts);
    }

    // ペアの固定度（同じペアが繰り返すほど大きくなる）。回数の二乗和で超過分を罰する。
    double pairPenalty = 0;
    for (final v in pairCounts.values) {
      if (v > 1) pairPenalty += (v - 1) * (v - 1).toDouble();
    }

    // 付き添い必須（ソフト）: 相方なしで単独になっている回数を罰する。
    // ハードは適格判定で担保済みなので、ここではソフトのルールだけ見る。
    double companionPenalty = 0;
    if (companionByStaff.isNotEmpty) {
      for (final shift in shifts) {
        final rule = companionByStaff[shift.staffId];
        if (rule == null || rule.hard) continue;
        final hasCompanion = shifts.any((s) =>
            !identical(s, shift) &&
            _isSameDay(s.date, shift.date) &&
            s.shiftType == shift.shiftType &&
            rule.companionIds.contains(s.staffId));
        if (!hasCompanion) companionPenalty += 1;
      }
    }

    final score = -_wUnfilled * candidate.unfilled -
        _wTypeSpread * typeSpread -
        _wTotalSpread * totalSpread -
        _wPair * pairPenalty -
        _wCompanion * companionPenalty +
        _wPreferred * candidate.preferredGranted;

    return score;
  }

  // ========================================
  // 生成後の公平化リバランス（局所探索 / 山登り）
  // ========================================
  // 2種類の操作で偏りをならす（制約は _isEligible を再利用して完全維持）：
  //   ・付け替え: 1枚のシフトを別の適格スタッフに渡す → 主に「総数」を調整する。
  //   ・交換    : 2人の異種別シフトの担当を入れ替える → 各自の総数を変えずに「種別」だけ調整する。
  // コストは「総数」を支配的に重み付けし、総数を悪化させてまで種別を直すことはしない
  // （夜勤ができない人が日勤を多めにやって総数を合わせる、等の正しい配分を壊さないため）。
  void _rebalanceFairness(
    List<Shift> shifts,
    List<Staff> availableStaff,
    Set<String> activeShiftTypeNames,
    int maxConsecutiveDays,
    int minRestHours,
    bool overnightCountsAsTwoDays,
    Set<String> ngPairKeys,
    Map<String, CompanionRule> companionByStaff,
    List<Shift> previousMonthShifts,
  ) {
    final workable = availableStaff.where((s) => s.maxShiftsPerMonth > 0).toList();
    if (workable.length < 2 || shifts.isEmpty) return;

    final staffById = {for (final s in workable) s.id: s};
    final totalCounts = {for (final s in workable) s.id: 0};
    final typeCounts = {for (final s in workable) s.id: <String, int>{}};
    for (final sh in shifts) {
      if (!totalCounts.containsKey(sh.staffId)) continue;
      totalCounts[sh.staffId] = totalCounts[sh.staffId]! + 1;
      final tm = typeCounts[sh.staffId]!;
      tm[sh.shiftType] = (tm[sh.shiftType] ?? 0) + 1;
    }

    final avgMax = workable.map((s) => s.maxShiftsPerMonth).reduce((a, b) => a + b) / workable.length;
    double norm(int c, int max) => max > 0 ? c / max * avgMax : c.toDouble();

    // コスト = 総数の標準偏差（支配的）＋ 種別ごとの標準偏差の合計。
    // 総数の重みを大きくして「総数優先・種別は総数を崩さない範囲で」を実現する。
    double cost() {
      final total = _stddev(workable.map((s) => norm(totalCounts[s.id]!, s.maxShiftsPerMonth)).toList());
      double type = 0;
      for (final t in activeShiftTypeNames) {
        final oldName = _mapCustomToOldShiftType(t);
        final capable = workable
            .where((s) => !s.unavailableShiftTypes.contains(t) && !s.unavailableShiftTypes.contains(oldName))
            .toList();
        if (capable.length < 2) continue;
        type += _stddev(capable.map((s) => norm(typeCounts[s.id]?[t] ?? 0, s.maxShiftsPerMonth)).toList());
      }
      return _rebalanceTotalWeight * total + _rebalanceTypeWeight * type;
    }

    // 付け替え（from→to に1枚）。total/type を更新。
    void applyMove(String from, String to, String type, int sign) {
      totalCounts[from] = totalCounts[from]! - sign;
      totalCounts[to] = totalCounts[to]! + sign;
      typeCounts[from]![type] = (typeCounts[from]![type] ?? 0) - sign;
      typeCounts[to]![type] = (typeCounts[to]![type] ?? 0) + sign;
    }

    // 交換（a の type1 と b の type2 を入れ替え）。総数は不変、種別のみ変化。
    void applySwap(String a, String b, String type1, String type2, int sign) {
      typeCounts[a]![type1] = (typeCounts[a]![type1] ?? 0) - sign;
      typeCounts[a]![type2] = (typeCounts[a]![type2] ?? 0) + sign;
      typeCounts[b]![type2] = (typeCounts[b]![type2] ?? 0) - sign;
      typeCounts[b]![type1] = (typeCounts[b]![type1] ?? 0) + sign;
    }

    for (int iter = 0; iter < _rebalanceMaxIters; iter++) {
      double bestCost = cost();
      int bestKind = 0; // 0=なし, 1=付け替え, 2=交換
      Shift? m1;
      Shift? m2;
      String? toId;

      // --- 付け替え候補（総数調整）---
      for (final sh in shifts) {
        final from = sh.staffId;
        if (!totalCounts.containsKey(from)) continue;
        for (final z in workable) {
          if (z.id == from) continue;
          if (!_canReassign(sh, z, shifts, totalCounts, maxConsecutiveDays, minRestHours,
              overnightCountsAsTwoDays, ngPairKeys, companionByStaff, previousMonthShifts)) {
            continue;
          }
          applyMove(from, z.id, sh.shiftType, 1);
          final c = cost();
          applyMove(from, z.id, sh.shiftType, -1);
          if (c < bestCost - 1e-9) {
            bestCost = c;
            bestKind = 1;
            m1 = sh;
            toId = z.id;
          }
        }
      }

      // --- 交換候補（種別調整・総数不変）---
      for (int i = 0; i < shifts.length; i++) {
        final s1 = shifts[i];
        if (!totalCounts.containsKey(s1.staffId)) continue;
        for (int j = i + 1; j < shifts.length; j++) {
          final s2 = shifts[j];
          if (s1.staffId == s2.staffId || s1.shiftType == s2.shiftType) continue;
          if (!totalCounts.containsKey(s2.staffId)) continue;
          if (!_canSwap(s1, s2, shifts, totalCounts, staffById, maxConsecutiveDays, minRestHours,
              overnightCountsAsTwoDays, ngPairKeys, companionByStaff, previousMonthShifts)) {
            continue;
          }
          applySwap(s1.staffId, s2.staffId, s1.shiftType, s2.shiftType, 1);
          final c = cost();
          applySwap(s1.staffId, s2.staffId, s1.shiftType, s2.shiftType, -1);
          if (c < bestCost - 1e-9) {
            bestCost = c;
            bestKind = 2;
            m1 = s1;
            m2 = s2;
          }
        }
      }

      if (bestKind == 1 && m1 != null && toId != null) {
        applyMove(m1.staffId, toId, m1.shiftType, 1);
        m1.staffId = toId;
      } else if (bestKind == 2 && m1 != null && m2 != null) {
        applySwap(m1.staffId, m2.staffId, m1.shiftType, m2.shiftType, 1);
        final tmp = m1.staffId;
        m1.staffId = m2.staffId;
        m2.staffId = tmp;
      } else {
        break; // これ以上改善できない
      }
    }
  }

  /// シフト s1 と s2 の担当を入れ替えられるか（総数不変・種別交換）。制約は _isEligible を再利用。
  bool _canSwap(
    Shift s1,
    Shift s2,
    List<Shift> shifts,
    Map<String, int> totalCounts,
    Map<String, Staff> staffById,
    int maxConsecutiveDays,
    int minRestHours,
    bool overnightCountsAsTwoDays,
    Set<String> ngPairKeys,
    Map<String, CompanionRule> companionByStaff,
    List<Shift> previousMonthShifts,
  ) {
    final a = s1.staffId;
    final b = s2.staffId;
    final sa = staffById[a];
    final sb = staffById[b];
    if (sa == null || sb == null) return false;

    // 両方を一旦外す。交換では総数不変なので、最大シフト数判定用に各自-1して評価する。
    shifts.remove(s1);
    shifts.remove(s2);
    totalCounts[a] = totalCounts[a]! - 1;
    totalCounts[b] = totalCounts[b]! - 1;

    bool ok = _isEligible(sa, s2.date, s2.shiftType, shifts, totalCounts, maxConsecutiveDays, minRestHours,
            previousMonthShifts,
            overnightCountsAsTwoDays: overnightCountsAsTwoDays, ngPairKeys: ngPairKeys, companionByStaff: companionByStaff) &&
        _isEligible(sb, s1.date, s1.shiftType, shifts, totalCounts, maxConsecutiveDays, minRestHours, previousMonthShifts,
            overnightCountsAsTwoDays: overnightCountsAsTwoDays, ngPairKeys: ngPairKeys, companionByStaff: companionByStaff);
    if (ok) {
      ok = _slotCompanionsSatisfiedAfterSwap(s2.date, s2.shiftType, shifts, a, companionByStaff) &&
          _slotCompanionsSatisfiedAfterSwap(s1.date, s1.shiftType, shifts, b, companionByStaff);
    }

    // 復元
    totalCounts[a] = totalCounts[a]! + 1;
    totalCounts[b] = totalCounts[b]! + 1;
    shifts.add(s1);
    shifts.add(s2);
    return ok;
  }

  /// シフト sh の担当を z に付け替えられるか（制約は _isEligible を再利用）。
  bool _canReassign(
    Shift sh,
    Staff z,
    List<Shift> shifts,
    Map<String, int> totalCounts,
    int maxConsecutiveDays,
    int minRestHours,
    bool overnightCountsAsTwoDays,
    Set<String> ngPairKeys,
    Map<String, CompanionRule> companionByStaff,
    List<Shift> previousMonthShifts,
  ) {
    // shを一旦外して、その枠をzに渡せるか判定する（元の担当はこの枠から抜ける前提）
    shifts.remove(sh);
    bool ok = _isEligible(
      z,
      sh.date,
      sh.shiftType,
      shifts,
      totalCounts,
      maxConsecutiveDays,
      minRestHours,
      previousMonthShifts,
      overnightCountsAsTwoDays: overnightCountsAsTwoDays,
      ngPairKeys: ngPairKeys,
      companionByStaff: companionByStaff,
    );
    // 元の担当が抜けることで、同じ枠の付き添い必須スタッフを孤立させないか確認
    if (ok) {
      ok = _slotCompanionsSatisfiedAfterSwap(sh.date, sh.shiftType, shifts, z.id, companionByStaff);
    }
    shifts.add(sh); // 復元
    return ok;
  }

  /// 付け替え後の枠（元担当を除き z を加えた状態）で、付き添い必須スタッフ全員に相方がいるか。
  bool _slotCompanionsSatisfiedAfterSwap(
    DateTime date,
    String shiftType,
    List<Shift> shiftsWithoutTarget,
    String addedStaffId,
    Map<String, CompanionRule> companionByStaff,
  ) {
    if (companionByStaff.isEmpty) return true;
    final members = shiftsWithoutTarget
        .where((s) => _isSameDay(s.date, date) && s.shiftType == shiftType)
        .map((s) => s.staffId)
        .toSet()
      ..add(addedStaffId);
    for (final m in members) {
      final rule = companionByStaff[m];
      if (rule == null || !rule.hard) continue;
      final hasCompanion = members.any((o) => o != m && rule.companionIds.contains(o));
      if (!hasCompanion) return false;
    }
    return true;
  }

  // ========================================
  // 間隔ならし（タイミングの平均化）
  // ========================================
  // 「同じ種別のシフトを2人で日付交換する」操作だけで、勤務/休みの塊（5連勤→5連休など）をならす。
  // 同種別交換なので各人の総数・種別の枚数は不変＝公平性を一切崩さない。タイミングだけ変える。
  void _rebalanceSpacing(
    List<Shift> shifts,
    List<Staff> availableStaff,
    int maxConsecutiveDays,
    int minRestHours,
    bool overnightCountsAsTwoDays,
    Set<String> ngPairKeys,
    Map<String, CompanionRule> companionByStaff,
    List<Shift> previousMonthShifts,
  ) {
    final workable = availableStaff.where((s) => s.maxShiftsPerMonth > 0).toList();
    if (workable.length < 2 || shifts.isEmpty) return;
    final staffById = {for (final s in workable) s.id: s};
    final workableIds = workable.map((s) => s.id).toSet();
    final totalCounts = {for (final s in workable) s.id: 0};
    for (final sh in shifts) {
      if (totalCounts.containsKey(sh.staffId)) totalCounts[sh.staffId] = totalCounts[sh.staffId]! + 1;
    }

    // 勤務/休みの塊を罰するコスト（各人の連勤・連休の長さの二乗和）。小さいほど均等。
    double spacingCost() {
      final byStaff = <String, List<DateTime>>{};
      for (final sh in shifts) {
        if (!workableIds.contains(sh.staffId)) continue;
        (byStaff[sh.staffId] ??= []).add(sh.date);
      }
      double sum = 0;
      for (final days in byStaff.values) {
        sum += _spacingPenaltyFor(days);
      }
      return sum;
    }

    for (int iter = 0; iter < _rebalanceMaxIters; iter++) {
      double bestCost = spacingCost();
      Shift? b1;
      Shift? b2;

      for (int i = 0; i < shifts.length; i++) {
        final s1 = shifts[i];
        if (!totalCounts.containsKey(s1.staffId)) continue;
        for (int j = i + 1; j < shifts.length; j++) {
          final s2 = shifts[j];
          if (s1.staffId == s2.staffId) continue;
          if (s1.shiftType != s2.shiftType) continue; // 同種別のみ＝総数・種別を変えない
          if (_isSameDay(s1.date, s2.date)) continue; // 同日交換は意味なし
          if (!totalCounts.containsKey(s2.staffId)) continue;
          if (!_canSwap(s1, s2, shifts, totalCounts, staffById, maxConsecutiveDays, minRestHours,
              overnightCountsAsTwoDays, ngPairKeys, companionByStaff, previousMonthShifts)) {
            continue;
          }
          final a = s1.staffId;
          final b = s2.staffId;
          s1.staffId = b;
          s2.staffId = a;
          final c = spacingCost();
          s1.staffId = a;
          s2.staffId = b;
          if (c < bestCost - 1e-9) {
            bestCost = c;
            b1 = s1;
            b2 = s2;
          }
        }
      }

      if (b1 == null || b2 == null) break;
      final tmp = b1.staffId;
      b1.staffId = b2.staffId;
      b2.staffId = tmp;
    }
  }

  /// 1人の勤務日リストから、連勤・連休の塊の度合い（長さの二乗和）を計算する。小さいほど均等。
  double _spacingPenaltyFor(List<DateTime> days) {
    if (days.length < 2) return 0;
    final sorted = days.map((d) => DateTime(d.year, d.month, d.day)).toList()..sort();
    double pen = 0;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap <= 1) {
        run++;
      } else {
        pen += (run * run).toDouble();
        final rest = gap - 1; // 間の休み日数
        pen += (rest * rest).toDouble();
        run = 1;
      }
    }
    pen += (run * run).toDouble();
    return pen;
  }

  /// 公平性の内訳をログ出力（各スタッフの総数＋種別ごとの枚数、総数の最大-最小差）。
  void _logFairnessSummary(
    String label,
    List<Shift> shifts,
    List<Staff> availableStaff,
    Set<String> activeShiftTypeNames,
  ) {
    final workable = availableStaff.where((s) => s.maxShiftsPerMonth > 0).toList();
    if (workable.isEmpty) return;
    final totalCounts = {for (final s in workable) s.id: 0};
    final typeCounts = {for (final s in workable) s.id: <String, int>{}};
    final daysByStaff = <String, List<DateTime>>{};
    for (final sh in shifts) {
      if (!totalCounts.containsKey(sh.staffId)) continue;
      totalCounts[sh.staffId] = totalCounts[sh.staffId]! + 1;
      final tm = typeCounts[sh.staffId]!;
      tm[sh.shiftType] = (tm[sh.shiftType] ?? 0) + 1;
      (daysByStaff[sh.staffId] ??= []).add(sh.date);
    }
    final totals = workable.map((s) => totalCounts[s.id]!).toList();
    final maxT = totals.reduce(max);
    final minT = totals.reduce(min);
    _log('=== 公平性[$label] 総数差=${maxT - minT}（最大$maxT / 最小$minT）===');
    for (final s in workable) {
      final tm = typeCounts[s.id]!;
      final typeStr = activeShiftTypeNames.map((t) => '$t:${tm[t] ?? 0}').join(' ');
      final runs = _maxRunAndRest(daysByStaff[s.id] ?? const []);
      _log('  ${s.name}: 計${totalCounts[s.id]}（$typeStr）最長連勤${runs.$1} 最長連休${runs.$2}');
    }
  }

  /// 最終結果が連勤上限を満たしているか検証してログ出力（デグレ検知用）。
  /// 各スタッフの実際の最大連勤（夜勤2日カウント・前月跨ぎ込み）を上限と比較する。
  void _logConsecutiveCheck(
    List<Shift> shifts,
    List<Staff> availableStaff,
    int teamMaxConsecutive,
    bool overnightCountsAsTwoDays,
    List<Shift> previousMonthShifts,
  ) {
    final daysByStaff = <String, List<DateTime>>{};
    for (final sh in shifts) {
      (daysByStaff[sh.staffId] ??= []).add(sh.date);
    }
    int violations = 0;
    for (final staff in availableStaff) {
      final dates = daysByStaff[staff.id];
      if (dates == null || dates.isEmpty) continue;
      final effMax = _getEffectiveMaxConsecutiveDays(staff, teamMaxConsecutive);
      int maxRun = 0;
      for (final d in dates) {
        // d+1日の「直前連勤」= dで終わる連勤の長さ（夜勤2日カウント・前月跨ぎ込み）
        final run = _getConsecutiveWorkDays(
            staff.id, d.add(const Duration(days: 1)), shifts, previousMonthShifts, overnightCountsAsTwoDays);
        if (run > maxRun) maxRun = run;
      }
      if (maxRun > effMax) {
        violations++;
        _log('⚠️ 連勤違反: ${staff.name} 最大連勤$maxRun > 上限$effMax');
      }
    }
    _log('連勤チェック: 違反$violations件（0なら全員上限以内）');
  }

  /// 勤務日リストから (最長連勤, 最長連休) を返す。
  (int, int) _maxRunAndRest(List<DateTime> days) {
    if (days.isEmpty) return (0, 0);
    final sorted = days.map((d) => DateTime(d.year, d.month, d.day)).toList()..sort();
    int maxRun = 1, run = 1, maxRest = 0;
    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap <= 1) {
        run++;
        if (run > maxRun) maxRun = run;
      } else {
        final rest = gap - 1;
        if (rest > maxRest) maxRest = rest;
        run = 1;
      }
    }
    return (maxRun, maxRest);
  }

  double _stddev(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// 採用された候補について勤務希望日のAnalyticsを1回だけ送信
  Future<void> _logPreferredAnalytics(
    DateTime startDate,
    DateTime endDate,
    List<Staff> availableStaff,
    List<Shift> result,
  ) async {
    final staffWithPreferences = availableStaff.where((staff) => staff.preferredDates.isNotEmpty).toList();
    if (staffWithPreferences.isEmpty) return;

    int totalPreferences = 0;
    for (final staff in staffWithPreferences) {
      for (final dateStr in staff.preferredDates) {
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (!dateOnly.isBefore(startDate) && !dateOnly.isAfter(endDate)) {
          totalPreferences++;
        }
      }
    }
    if (totalPreferences <= 0) return;

    final granted = result.where((s) => s.id.startsWith('auto_pref_')).length;
    try {
      await AnalyticsService.logPreferredDatesAssigned(
        totalPreferences: totalPreferences,
        granted: granted,
      );
    } catch (_) {
      // Analyticsエラーは無視
    }
    _log('勤務希望日: 総数=$totalPreferences, 割り当て=$granted');
  }

  bool _isStaffAvailableOnDate(Staff staff, DateTime date) {
    // 連休（日付未指定）で事前確保した休みをチェック
    final reserved = _reservedDaysOff[staff.id];
    if (reserved != null && reserved.contains(_dateKey(date))) {
      return false;
    }

    // 曜日ベースの休み希望をチェック
    if (staff.preferredDaysOff.contains(date.weekday)) {
      return false;
    }

    // 祝日の休み希望をチェック
    if (staff.holidaysOff) {
      final isHoliday = holiday_jp.isHoliday(date);
      if (isHoliday) {
        return false;
      }
    }

    // 特定日の休み希望をチェック
    final dateOnly = DateTime(date.year, date.month, date.day);
    for (final dayOffStr in staff.specificDaysOff) {
      final dayOff = DateTime.parse(dayOffStr);
      if (dayOff.year == dateOnly.year && dayOff.month == dateOnly.month && dayOff.day == dateOnly.day) {
        return false;
      }
    }

    // 日付ベースの制約をチェック
    for (ShiftConstraint constraint in staff.constraints) {
      if (constraint.date.year == date.year && constraint.date.month == date.month && constraint.date.day == date.day) {
        return constraint.isAvailable;
      }
    }
    return true;
  }

  /// そのスタッフがその日に「確実に休み」か（チーム休み＋本人の休み希望）。
  /// 連休の事前確保で「既に休みの日」を判定するために使う（予約分は含めない）。
  bool _isStaffDefinitelyOff(Staff staff, DateTime date, Team team) {
    if (_isTeamHoliday(team, date)) return true;
    // _reservedDaysOff はこの計算時点では空なので、本人の休み希望のみ判定される。
    if (!_isStaffAvailableOnDate(staff, date)) return true;
    return false;
  }

  /// 連休（日付未指定）の事前確保。
  /// チーム設定の連休ルール群（例「2連休を2回 ＋ 3連休を1回」）を満たすため、
  /// 連続休みブロックを確保する。これは**ハード制約**（埋まりより優先）として扱う。
  /// 他の制約（休み希望・連勤上限）と同様、対象スタッフ全員に確保し、
  /// 一部だけ連休なしという不公平を作らない。
  /// 返り値: staffId -> 確保した休み日（_dateKey形式）の集合。
  ///
  /// 方針:
  /// - ルール群を「必要な連休（長さ）の集合」に展開する（2連休×2＋3連休×1 → [3,2,2]）。
  /// - 既に休みが連続している箇所（チーム休み・祝日・休み希望）を「既存の連休」とみなし、
  ///   長い要求から順に割り当てる（1つの連休は1回分としてのみカウント）。足りない分だけ新規確保。
  /// - 各ブロックは前後を勤務日で挟む（既存/予約済みの休みと隣接させない）＝「2連休×2回」が
  ///   「4連休×1回」に化けないように分離する。
  /// - 置き場はカバレッジ（必要人数）に余裕のある位置を優先するが、余裕が無くても
  ///   未充足を許容して確保する（_findBestOffWindow の多段フォールバック）。
  Map<String, Set<String>> _computeConsecutiveDaysOffReservations(
    DateTime startDate,
    DateTime endDate,
    List<Staff> availableStaff,
    Team? team,
    Map<String, int> filteredRequirements,
    MonthlyRequirementsProvider? requirementsProvider,
    Set<String> activeShiftTypeNames,
    Random rng,
  ) {
    final reservations = <String, Set<String>>{};
    if (team == null) return reservations;

    // 対象は自動割り当て対象のスタッフ（月間上限0は対象外）
    final assignable = availableStaff.where((s) => s.maxShiftsPerMonth > 0).toList();
    if (assignable.isEmpty) return reservations;

    // スタッフごとの「実効連休ルール」を「必要な連休の長さ」の集合（長い順）に展開する。
    // 個別上書き（overrideConsecutiveDaysOff）が優先：
    //   override OFF              → チーム設定に従う
    //   override ON ＋ ルール非空 → 個別の連休ルールを使う
    //   override ON ＋ ルール空   → この人は連休なし（チーム設定も適用しない）
    List<int> requiredLengthsFor(Staff s) {
      final rules = s.overrideConsecutiveDaysOff
          ? s.consecutiveDaysOffRules
          : team.consecutiveDaysOffRules;
      final out = <int>[];
      for (final rule in rules) {
        if (rule.length < 2 || rule.count < 1) continue;
        for (int k = 0; k < rule.count; k++) {
          out.add(rule.length);
        }
      }
      out.sort((a, b) => b.compareTo(a)); // 長い連休から確保する
      return out;
    }

    // 誰一人として連休が必要でなければ何もしない（チーム未設定＋個別上書きも無し＝機能オフ）。
    if (assignable.every((s) => requiredLengthsFor(s).isEmpty)) {
      return reservations;
    }

    // 対象期間の日付リスト
    final days = <DateTime>[];
    for (var d = DateTime(startDate.year, startDate.month, startDate.day);
        !d.isAfter(endDate);
        d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    final dayCount = days.length;

    // 各日の必要総人数（曜日別・日付個別設定を反映）
    final requiredPerDay = List<int>.filled(dayCount, 0);
    for (int i = 0; i < dayCount; i++) {
      final raw = requirementsProvider?.getRequirementsForDate(days[i]) ?? filteredRequirements;
      int sum = 0;
      raw.forEach((k, v) {
        if (activeShiftTypeNames.contains(k)) sum += v;
      });
      requiredPerDay[i] = sum;
    }

    // 各日の「勤務可能なスタッフ数」（確実に休みでない人数）。予約するたびに減らしていく。
    final availablePerDay = List<int>.filled(dayCount, 0);
    // スタッフごとの「確実に休み」フラグ（予約で埋めた日も後でtrueにして分離に使う）
    final offByStaff = <String, List<bool>>{};
    for (final s in assignable) {
      final off = List<bool>.filled(dayCount, false);
      for (int i = 0; i < dayCount; i++) {
        final isOff = _isStaffDefinitelyOff(s, days[i], team);
        off[i] = isOff;
        if (!isOff) availablePerDay[i]++;
      }
      offByStaff[s.id] = off;
    }

    // 既存の連休が少ない人を優先（同じ日に集中させないため公平側に倒す）。
    int existingRunCount(List<bool> off) {
      int c = 0, run = 0;
      for (final v in off) {
        if (v) {
          run++;
        } else {
          if (run >= 2) c++;
          run = 0;
        }
      }
      if (run >= 2) c++;
      return c;
    }

    assignable.sort((a, b) => existingRunCount(offByStaff[a.id]!)
        .compareTo(existingRunCount(offByStaff[b.id]!)));

    for (final s in assignable) {
      // このスタッフの実効連休ルール（個別上書き優先）。
      final requiredLengths = requiredLengthsFor(s);
      if (requiredLengths.isEmpty) continue; // この人は連休なし
      // 一番短い連休すら入らない月は確保不能（スキップ）。
      if (dayCount < requiredLengths.last) continue;

      final off = offByStaff[s.id]!;

      // 既存の連続休み（長さ>=2）の本数を集める
      final existingRuns = <int>[];
      int run = 0;
      for (int i = 0; i < dayCount; i++) {
        if (off[i]) {
          run++;
        } else {
          if (run >= 2) existingRuns.add(run);
          run = 0;
        }
      }
      if (run >= 2) existingRuns.add(run);
      existingRuns.sort((a, b) => b.compareTo(a)); // 長い順

      // 必要な連休を長い順に既存連休へ割り当て、足りない長さを新規確保リストにする。
      final usedRun = List<bool>.filled(existingRuns.length, false);
      final toReserve = <int>[];
      for (final reqLen in requiredLengths) {
        int matched = -1;
        for (int j = 0; j < existingRuns.length; j++) {
          if (!usedRun[j] && existingRuns[j] >= reqLen) {
            matched = j;
            break;
          }
        }
        if (matched >= 0) {
          usedRun[matched] = true; // 1つの連休は1回分としてのみ消費
        } else {
          toReserve.add(reqLen);
        }
      }
      if (toReserve.isEmpty) continue;

      final preferredKeys =
          s.preferredDates.map((iso) => _dateKey(DateTime.parse(iso))).toSet();
      final reservedForStaff = reservations.putIfAbsent(s.id, () => <String>{});

      // 長い連休から確保する（空きが多いうちに大きいブロックを置く）。
      // 連休はハード制約（埋まりより優先）。まずカバレッジに余裕のある位置を狙い、
      // 無ければカバレッジを割ってでも確保し（＝未充足を許容）、それでも無理なら
      // 最後に境界（分離・勤務希望日）を緩めて確保する。
      for (final blockLen in toReserve) {
        int start = _findBestOffWindow(off, availablePerDay, requiredPerDay, days,
            preferredKeys, blockLen, rng,
            respectCoverage: true, respectBoundaries: true);
        if (start < 0) {
          start = _findBestOffWindow(off, availablePerDay, requiredPerDay, days,
              preferredKeys, blockLen, rng,
              respectCoverage: false, respectBoundaries: true);
        }
        if (start < 0) {
          start = _findBestOffWindow(off, availablePerDay, requiredPerDay, days,
              preferredKeys, blockLen, rng,
              respectCoverage: false, respectBoundaries: false);
        }
        if (start < 0) {
          // 構造的に窓が取れない（極めて稀）。確保できなかったことを記録する。
          _log('連休を確保できませんでした: ${s.name} ($blockLen連休)');
          continue;
        }

        for (int i = start; i < start + blockLen; i++) {
          off[i] = true; // 同じ人の次のブロックと分離させる
          availablePerDay[i]--; // カバレッジを消費（他スタッフの確保にも反映）
          reservedForStaff.add(_dateKey(days[i]));
        }
      }

      if (reservedForStaff.isEmpty) reservations.remove(s.id);
    }

    return reservations;
  }

  /// 連休ブロック（長さ [blockLength]）を置く最適な開始位置を探す。見つからなければ -1。
  /// 窓内が既に休みの日（off==true）は常に除外する。
  ///
  /// 選び方:
  /// - 既存/予約済みの休みから**最も離れた（孤立した）位置**を優先する。これにより
  ///   複数ブロックが月内で離れて配置され、間の1日が自動割り当てで偶然空いても
  ///   連結して長大な連休になりにくい（例: 2連休と3連休が繋がって6連休、を抑止）。
  /// - カバレッジを尊重する場合は、まず孤立度、次に余裕（スラック）で選ぶ。
  ///   尊重しない場合は、まず割れ幅（スラック）が小さい位置、次に孤立度で選ぶ。
  ///
  /// - [respectCoverage] true: その日を休みにすると必要人数を割る窓は除外する。
  ///   false: 割っても許容し、割れ幅が最小の位置を選ぶ（＝ハード確保のフォールバック）。
  /// - [respectBoundaries] true: 勤務希望日を含まない／前後を勤務日で挟む（分離）窓に限る。
  ///   false: それらを無視してでも確保する（最終手段）。
  int _findBestOffWindow(
    List<bool> off,
    List<int> availablePerDay,
    List<int> requiredPerDay,
    List<DateTime> days,
    Set<String> preferredKeys,
    int blockLength,
    Random rng, {
    required bool respectCoverage,
    required bool respectBoundaries,
  }) {
    final dayCount = off.length;
    // 主目的（primary）が最良の窓を集め、その中からランダムに1つ選ぶ。
    // これにより「毎回同じ位置（月初）」を避けつつ、孤立度/未充足の最小化という
    // 本質的な目的は保たれる。primary は respectCoverage 時=孤立度、
    // フォールバック時=スラック（割れの小ささ）。同点（タイ）の集合からランダムに選ぶ。
    int bestPrimary = -1 << 30;
    final bestStarts = <int>[];
    for (int start = 0; start + blockLength <= dayCount; start++) {
      bool ok = true;
      int minSlack = 1 << 30;
      for (int i = start; i < start + blockLength; i++) {
        if (off[i]) {
          ok = false;
          break;
        }
        if (respectBoundaries && preferredKeys.contains(_dateKey(days[i]))) {
          ok = false;
          break;
        }
        if (respectCoverage && availablePerDay[i] - 1 < requiredPerDay[i]) {
          ok = false;
          break;
        }
        final slack = availablePerDay[i] - requiredPerDay[i];
        if (slack < minSlack) minSlack = slack;
      }
      if (!ok) continue;
      if (respectBoundaries) {
        // 既存/予約済みの休みと隣接させない（前後を勤務日で挟む＝分離）
        if (start - 1 >= 0 && off[start - 1]) continue;
        if (start + blockLength < dayCount && off[start + blockLength]) continue;
      }

      // 孤立度: 窓の前後それぞれ、最も近い既存/予約済みの休みまでの勤務日数の小さい方。
      // 大きいほど他の休みから離れている＝連結しにくい。月端は連結相手がいないので大きく扱う。
      int leftClear = dayCount;
      for (int i = start - 1; i >= 0; i--) {
        if (off[i]) {
          leftClear = start - 1 - i;
          break;
        }
      }
      int rightClear = dayCount;
      for (int i = start + blockLength; i < dayCount; i++) {
        if (off[i]) {
          rightClear = i - (start + blockLength);
          break;
        }
      }
      final isolation = leftClear < rightClear ? leftClear : rightClear;

      // 主目的（大きいほど良い）。respectCoverage 時は孤立度（連結防止）を最優先、
      // 割っても確保するフォールバック時はスラック（割れの小ささ）を最優先にする。
      // 従来あった副次タイブレークは、位置の多様性を出すためランダム選択に置き換える。
      final int primary = respectCoverage ? isolation : minSlack;
      if (primary > bestPrimary) {
        bestPrimary = primary;
        bestStarts
          ..clear()
          ..add(start);
      } else if (primary == bestPrimary) {
        bestStarts.add(start);
      }
    }
    if (bestStarts.isEmpty) return -1;
    // 最良タイの集合からランダムに選ぶ（毎回違う位置になる）。
    return bestStarts[rng.nextInt(bestStarts.length)];
  }

  /// チーム全体の休みかどうかをチェック
  bool _isTeamHoliday(Team team, DateTime date) {
    // 曜日ベースのチーム休みをチェック
    if (team.teamDaysOff.contains(date.weekday)) {
      return true;
    }

    // 祝日のチーム休みをチェック
    if (team.teamHolidaysOff) {
      final isHoliday = holiday_jp.isHoliday(date);
      if (isHoliday) {
        return true;
      }
    }

    // 特定日のチーム休みをチェック
    final dateOnly = DateTime(date.year, date.month, date.day);
    for (final dayOffStr in team.teamSpecificDaysOff) {
      final dayOff = DateTime.parse(dayOffStr);
      if (dayOff.year == dateOnly.year && dayOff.month == dateOnly.month && dayOff.day == dateOnly.day) {
        return true;
      }
    }

    return false;
  }

  Map<String, int> analyzeCurrentShifts(DateTime month) {
    List<Shift> monthShifts = shiftProvider.getShiftsForMonth(month.year, month.month);
    Map<String, int> staffShiftCounts = {};

    for (Shift shift in monthShifts) {
      staffShiftCounts[shift.staffId] = (staffShiftCounts[shift.staffId] ?? 0) + 1;
    }

    return staffShiftCounts;
  }

  bool validateShiftAssignment(Shift shift) {
    Staff? staff = staffProvider.staff.firstWhere(
      (s) => s.id == shift.staffId,
      orElse: () => throw Exception('スタッフが見つかりません'),
    );

    if (!_isStaffAvailableOnDate(staff, shift.date)) {
      return false;
    }

    List<Shift> existingShifts = shiftProvider.getShiftsForDate(shift.date);
    bool hasConflict = existingShifts.any((existingShift) => existingShift.staffId == shift.staffId && existingShift.id != shift.id);

    return !hasConflict;
  }

  Map<DateTime, List<String>> getUnavailableStaffByDate(
    DateTime startDate,
    DateTime endDate,
  ) {
    Map<DateTime, List<String>> unavailableMap = {};

    DateTime currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      List<String> unavailableStaffIds = [];

      for (Staff staff in staffProvider.staff) {
        if (!_isStaffAvailableOnDate(staff, currentDate)) {
          unavailableStaffIds.add(staff.id);
        }
      }

      if (unavailableStaffIds.isNotEmpty) {
        unavailableMap[currentDate] = unavailableStaffIds;
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return unavailableMap;
  }

  int calculateOptimalStaffCount(String shiftType, DateTime date) {
    final oldShiftType = _mapCustomToOldShiftType(shiftType);

    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      switch (oldShiftType) {
        case old_shift_type.ShiftType.morning:
          return 3;
        case old_shift_type.ShiftType.day:
          return 4;
        case old_shift_type.ShiftType.evening:
          return 3;
        case old_shift_type.ShiftType.night:
          return 2;
        default:
          return 2;
      }
    } else {
      switch (oldShiftType) {
        case old_shift_type.ShiftType.morning:
          return 2;
        case old_shift_type.ShiftType.day:
          return 3;
        case old_shift_type.ShiftType.evening:
          return 2;
        case old_shift_type.ShiftType.night:
          return 2;
        default:
          return 2;
      }
    }
  }

  /// スタッフの有効な連続勤務日数上限を取得（個別設定 > チーム設定）
  int _getEffectiveMaxConsecutiveDays(Staff staff, int teamMaxConsecutiveDays) {
    return staff.maxConsecutiveDays ?? teamMaxConsecutiveDays;
  }

  /// スタッフの有効な勤務間インターバルを取得（個別設定 > チーム設定）
  int _getEffectiveMinRestHours(Staff staff, int teamMinRestHours) {
    return staff.minRestHours ?? teamMinRestHours;
  }

  // 連続勤務日数を計算（前月のシフトも考慮）
  // overnightCountsAsTwoDays=true の場合、夜勤（日をまたぐシフト）は連勤2日分として数える。
  // 夜勤は開始日だけでなく明けの翌日も実際に勤務しているため、暦日2日分を消費する扱い。
  int _getConsecutiveWorkDays(String staffId, DateTime date, List<Shift> assignedShifts,
      [List<Shift> previousMonthShifts = const [], bool overnightCountsAsTwoDays = true]) {
    int consecutiveDays = 0;
    DateTime checkDate = date.subtract(const Duration(days: 1));

    // 今月のシフトと前月のシフトを結合してチェック
    final allShifts = [...assignedShifts, ...previousMonthShifts];

    while (true) {
      final shift = allShifts.where((shift) =>
          shift.staffId == staffId &&
          shift.date.year == checkDate.year &&
          shift.date.month == checkDate.month &&
          shift.date.day == checkDate.day).firstOrNull;

      if (shift == null) break;

      consecutiveDays += (overnightCountsAsTwoDays && _isOvernightShift(shift)) ? 2 : 1;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return consecutiveDays;
  }

  // 指定日より「後ろ（未来側）」の連続勤務日数を計算する。
  // スケジュールの途中にシフトを差し込む（リバランス）際、差し込み日の未来側にある連勤を
  // 見落とさないために使う。前月は未来側に関係しないので考慮しない。
  int _getConsecutiveWorkDaysForward(String staffId, DateTime date, List<Shift> assignedShifts,
      [bool overnightCountsAsTwoDays = true]) {
    int consecutiveDays = 0;
    DateTime checkDate = date.add(const Duration(days: 1));

    while (true) {
      final shift = assignedShifts.where((shift) =>
          shift.staffId == staffId &&
          shift.date.year == checkDate.year &&
          shift.date.month == checkDate.month &&
          shift.date.day == checkDate.day).firstOrNull;

      if (shift == null) break;

      consecutiveDays += (overnightCountsAsTwoDays && _isOvernightShift(shift)) ? 2 : 1;
      checkDate = checkDate.add(const Duration(days: 1));
    }

    return consecutiveDays;
  }

  /// シフト（割り当て済み）が日をまたぐ夜勤かどうかを判定する。
  /// 終了日が開始日より後、または時刻が開始＞終了（翌日まで）なら日またぎ。
  bool _isOvernightShift(Shift shift) {
    final startDay = DateTime(shift.startTime.year, shift.startTime.month, shift.startTime.day);
    final endDay = DateTime(shift.endTime.year, shift.endTime.month, shift.endTime.day);
    if (endDay.isAfter(startDay)) return true;

    final startMinutes = shift.startTime.hour * 60 + shift.startTime.minute;
    final endMinutes = shift.endTime.hour * 60 + shift.endTime.minute;
    return endMinutes < startMinutes;
  }

  /// これから割り当てるシフトタイプが、その日付で日をまたぐ夜勤になるかを判定する。
  bool _isOvernightShiftType(String shiftType, DateTime date) {
    final range = _getShiftTimeRange(shiftType, date);
    if (range == null) return false;
    final startDay = DateTime(range.$1.year, range.$1.month, range.$1.day);
    final endDay = DateTime(range.$2.year, range.$2.month, range.$2.day);
    return endDay.isAfter(startDay);
  }

  // 最後の勤務からの経過日数を計算
  int _getDaysSinceLastShift(String staffId, DateTime date, List<Shift> assignedShifts) {
    List<Shift> staffShifts = assignedShifts.where((shift) => shift.staffId == staffId && shift.date.isBefore(date)).toList();

    if (staffShifts.isEmpty) {
      // まだシフトがない場合は大きな値を返す（優先度を上げる）
      return 999;
    }

    staffShifts.sort((a, b) => b.date.compareTo(a.date));
    DateTime lastShiftDate = staffShifts.first.date;

    return date.difference(lastShiftDate).inDays;
  }

  // 勤務間インターバルをチェック（前月のシフトも考慮）
  bool _checkWorkInterval(String staffId, DateTime date, String shiftType, List<Shift> assignedShifts, int minRestHours, [List<Shift> previousMonthShifts = const []]) {
    // 前日と翌日のシフトをチェック
    DateTime previousDay = date.subtract(const Duration(days: 1));
    DateTime nextDay = date.add(const Duration(days: 1));

    // 今月のシフトと前月のシフトを結合
    final allShifts = [...assignedShifts, ...previousMonthShifts];

    // 前日のシフトを取得（前月のシフトも含めてチェック）
    Shift? previousShift = allShifts
        .where((shift) =>
            shift.staffId == staffId && shift.date.year == previousDay.year && shift.date.month == previousDay.month && shift.date.day == previousDay.day)
        .firstOrNull;

    // 翌日のシフトを取得
    Shift? nextShift = assignedShifts
        .where((shift) => shift.staffId == staffId && shift.date.year == nextDay.year && shift.date.month == nextDay.month && shift.date.day == nextDay.day)
        .firstOrNull;

    // 現在割り当てようとしているシフトの時間を取得
    final currentTimeRange = _getShiftTimeRange(shiftType, date);
    if (currentTimeRange == null) return true;

    DateTime currentStart = currentTimeRange.$1;
    DateTime currentEnd = currentTimeRange.$2;

    // 前日シフトとのインターバルチェック
    if (previousShift != null) {
      // 日をまたぐシフト（夜勤など）のendTimeを正しく調整
      final adjustedEndTime = _adjustOvernightEndTime(previousShift);
      if (!_hasValidInterval(adjustedEndTime, currentStart, minRestHours)) {
        return false;
      }
    }

    // 翌日シフトとのインターバルチェック
    if (nextShift != null) {
      if (!_hasValidInterval(currentEnd, nextShift.startTime, minRestHours)) {
        return false;
      }
    }

    return true;
  }

  /// 日をまたぐシフトのendTimeを正しく調整する
  /// endTimeがstartTimeより前の時間で、かつdateと同じ日付の場合、翌日として扱う
  DateTime _adjustOvernightEndTime(Shift shift) {
    final endTimeOfDay = shift.endTime.hour * 60 + shift.endTime.minute;
    final startTimeOfDay = shift.startTime.hour * 60 + shift.startTime.minute;

    // 終了時間が開始時間より前（日をまたぐシフト）
    if (endTimeOfDay < startTimeOfDay) {
      // endTimeの日付がshift.dateと同じ場合、翌日に調整
      if (shift.endTime.year == shift.date.year &&
          shift.endTime.month == shift.date.month &&
          shift.endTime.day == shift.date.day) {
        return shift.endTime.add(const Duration(days: 1));
      }
    }

    return shift.endTime;
  }

  // 2つの時間の間に十分なインターバルがあるかチェック
  bool _hasValidInterval(DateTime endTime, DateTime startTime, int minRestHours) {
    Duration interval = startTime.difference(endTime);

    // 指定された時間のインターバルが必要
    if (interval.inHours < minRestHours) {
      return false;
    }

    return true;
  }
}

/// 1回の生成で得られた候補シフトと、その評価に使う付随情報
class _Candidate {
  final List<Shift> shifts;
  final int unfilled; // 埋められなかった枠の数
  final int preferredGranted; // 割り当てた勤務希望日シフトの数

  _Candidate(this.shifts, this.unfilled, this.preferredGranted);
}
