import 'dart:math';

import 'package:shift_kobo/models/assignment_strategy.dart';
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

  Future<List<Shift>> autoAssignShifts(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> dailyShiftRequirements, {
    Team? team,
    AssignmentStrategy strategy = AssignmentStrategy.fairness,
    int maxConsecutiveDays = 5,
    int minRestHours = 12,
    MonthlyRequirementsProvider? requirementsProvider,
  }) async {
    List<Shift> assignedShifts = [];
    // 有効なスタッフのみ使用（月間最大シフト数0のスタッフは自動的に除外される）
    List<Staff> availableStaff = staffProvider.activeStaffList;
    int shiftIdCounter = 0;

    // 前月のシフトを取得（連続勤務日数・勤務間インターバルのチェック用）
    // スタッフ個別設定の最大値を考慮して取得範囲を決定
    // （個別設定がチーム設定より大きい場合があるため）
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
    print('前月シフト取得: ${previousMonthStart.toString().split(' ')[0]} 〜 ${previousMonthEnd.toString().split(' ')[0]} (${previousMonthShifts.length}件, 最大連続日数=$effectiveMaxConsecutive)');

    // アクティブなシフトタイプ名のセットを取得
    final activeShiftTypeNames = shiftTimeProvider.settings
        .where((s) => s.isActive)
        .map((s) => s.displayName)
        .toSet();

    // 必要人数をアクティブなシフトタイプのみにフィルタリング
    final filteredRequirements = Map<String, int>.fromEntries(
      dailyShiftRequirements.entries.where((e) => activeShiftTypeNames.contains(e.key)),
    );

    // デバッグ: スタッフ数を確認
    print('利用可能なスタッフ数: ${availableStaff.length}');
    for (var staff in availableStaff) {
      print('スタッフ: ${staff.name}, 最大シフト数: ${staff.maxShiftsPerMonth}, 勤務希望日: ${staff.preferredDates.length}件');
    }

    Map<String, int> staffShiftCounts = {};
    for (Staff staff in availableStaff) {
      staffShiftCounts[staff.id] = 0;
    }

    // ========================================
    // 第1段階: 勤務希望日を優先的に割り当て
    // ========================================
    print('=== 第1段階: 勤務希望日の割り当て開始 ===');
    final preferredDateShifts = await _assignPreferredDates(
      startDate,
      endDate,
      filteredRequirements,
      availableStaff,
      staffShiftCounts,
      team,
      maxConsecutiveDays,
      minRestHours,
      strategy,
      shiftIdCounter,
      requirementsProvider: requirementsProvider,
      activeShiftTypeNames: activeShiftTypeNames,
      previousMonthShifts: previousMonthShifts,
    );
    assignedShifts.addAll(preferredDateShifts);
    shiftIdCounter += preferredDateShifts.length;
    print('第1段階で割り当てられたシフト数: ${preferredDateShifts.length}');

    // ========================================
    // 第2段階: 残りのシフトを既存ロジックで割り当て
    // ========================================
    print('=== 第2段階: 残りシフトの割り当て開始 ===');

    DateTime currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      // チーム休みの日はスキップ
      if (team != null && _isTeamHoliday(team, currentDate)) {
        print('${currentDate.toString().split(' ')[0]}: チーム休みのためスキップ');
        currentDate = currentDate.add(const Duration(days: 1));
        continue;
      }

      // この日の必要人数を取得（曜日別・日付個別設定がある場合は優先）
      final rawDateRequirements = requirementsProvider?.getRequirementsForDate(currentDate)
          ?? filteredRequirements;
      // アクティブなシフトタイプのみにフィルタリング
      final dateRequirements = Map<String, int>.fromEntries(
        rawDateRequirements.entries.where((e) => activeShiftTypeNames.contains(e.key)),
      );

      for (String shiftType in dateRequirements.keys) {
        int requiredStaffCount = dateRequirements[shiftType] ?? 0;

        // この日のこのシフトタイプで既に割り当てられた人数をカウント
        int alreadyAssigned = assignedShifts.where((shift) =>
            shift.date.year == currentDate.year &&
            shift.date.month == currentDate.month &&
            shift.date.day == currentDate.day &&
            shift.shiftType == shiftType).length;

        // 残りの枠数分だけ割り当て
        int remainingSlots = requiredStaffCount - alreadyAssigned;

        for (int i = 0; i < remainingSlots; i++) {
          Staff? assignedStaff = _findBestStaffForShift(
            currentDate,
            shiftType,
            availableStaff,
            staffShiftCounts,
            assignedShifts,
            strategy,
            maxConsecutiveDays,
            minRestHours,
            previousMonthShifts: previousMonthShifts,
          );

          if (assignedStaff != null) {
            final timeRange = _getShiftTimeRange(shiftType, currentDate);
            if (timeRange != null) {
              shiftIdCounter++;
              String uniqueId = 'auto_${DateTime.now().millisecondsSinceEpoch}_$shiftIdCounter';
              Shift newShift = Shift(
                id: uniqueId,
                date: currentDate,
                startTime: timeRange.$1, // startTime
                endTime: timeRange.$2, // endTime
                staffId: assignedStaff.id,
                shiftType: shiftType,
                assignmentStrategy: strategy.name,
              );
              print(
                  'シフト作成: ID=$uniqueId, 日付=${currentDate.toString().split(' ')[0]}, スタッフ=${assignedStaff.name}, 時間=${timeRange.$1.hour.toString().padLeft(2, '0')}:${timeRange.$1.minute.toString().padLeft(2, '0')}-${timeRange.$2.hour.toString().padLeft(2, '0')}:${timeRange.$2.minute.toString().padLeft(2, '0')}');

              assignedShifts.add(newShift);
              staffShiftCounts[assignedStaff.id] = (staffShiftCounts[assignedStaff.id] ?? 0) + 1;
            } else {
              print('${currentDate.toString().split(' ')[0]} $shiftType: 時間設定が見つかりません');
            }
          } else {
            print('${currentDate.toString().split(' ')[0]} $shiftType: 割り当て可能なスタッフがいません');
          }
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    print('作成されたシフト数: ${assignedShifts.length}');
    return assignedShifts;
  }

  /// 第1段階: 勤務希望日を優先的に割り当て
  Future<List<Shift>> _assignPreferredDates(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> dailyShiftRequirements,
    List<Staff> availableStaff,
    Map<String, int> staffShiftCounts,
    Team? team,
    int maxConsecutiveDays,
    int minRestHours,
    AssignmentStrategy strategy,
    int shiftIdCounter, {
    MonthlyRequirementsProvider? requirementsProvider,
    Set<String>? activeShiftTypeNames,
    List<Shift> previousMonthShifts = const [],
  }) async {
    List<Shift> assignedShifts = [];

    // 勤務希望日を持つスタッフを抽出
    List<Staff> staffWithPreferences = availableStaff.where((staff) => staff.preferredDates.isNotEmpty).toList();

    if (staffWithPreferences.isEmpty) {
      print('勤務希望日を設定しているスタッフはいません');
      return assignedShifts;
    }

    // 各スタッフの希望日充足数を追跡（この生成内でのみ使用）
    Map<String, int> preferredDateGrantedCount = {};
    for (var staff in staffWithPreferences) {
      preferredDateGrantedCount[staff.id] = 0;
    }

    // 日付ごとに希望者をグループ化
    Map<DateTime, List<Staff>> preferencesByDate = {};

    for (var staff in staffWithPreferences) {
      for (var dateStr in staff.preferredDates) {
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);

        // 期間内の日付のみ対象
        if (dateOnly.isBefore(startDate) || dateOnly.isAfter(endDate)) {
          continue;
        }

        // チーム休みの日はスキップ
        if (team != null && _isTeamHoliday(team, dateOnly)) {
          continue;
        }

        // 勤務不可制約チェック
        if (!_isStaffAvailableOnDate(staff, dateOnly)) {
          print('${staff.name}の希望日 ${dateOnly.toString().split(' ')[0]} は勤務不可制約により除外');
          continue;
        }

        preferencesByDate[dateOnly] ??= [];
        preferencesByDate[dateOnly]!.add(staff);
      }
    }

    // 各日付について割り当て処理
    for (var entry in preferencesByDate.entries) {
      final date = entry.key;
      final candidates = entry.value;

      // この日の必要人数を取得（曜日別・日付個別設定がある場合は優先）
      final rawDateRequirements = requirementsProvider?.getRequirementsForDate(date)
          ?? dailyShiftRequirements;
      // アクティブなシフトタイプのみにフィルタリング
      final dateRequirements = activeShiftTypeNames != null
          ? Map<String, int>.fromEntries(
              rawDateRequirements.entries.where((e) => activeShiftTypeNames.contains(e.key)),
            )
          : rawDateRequirements;

      // 各シフトタイプについて処理
      for (String shiftType in dateRequirements.keys) {
        int requiredStaffCount = dateRequirements[shiftType] ?? 0;

        // この日のこのシフトタイプで既に割り当てられた人数
        int alreadyAssigned = assignedShifts.where((shift) =>
            shift.date.year == date.year &&
            shift.date.month == date.month &&
            shift.date.day == date.day &&
            shift.shiftType == shiftType).length;

        int remainingSlots = requiredStaffCount - alreadyAssigned;
        if (remainingSlots <= 0) continue;

        // 有効な候補者をフィルタリング
        List<Staff> validCandidates = candidates.where((staff) {
          // 月間最大シフト数チェック
          if (staffShiftCounts[staff.id]! >= staff.maxShiftsPerMonth) {
            return false;
          }

          // シフトタイプ制約をチェック
          final oldShiftTypeName = _mapCustomToOldShiftType(shiftType);
          if (staff.unavailableShiftTypes.contains(shiftType) || staff.unavailableShiftTypes.contains(oldShiftTypeName)) {
            return false;
          }

          // 既にこの日にシフトがある場合は除外
          bool hasShiftOnDate = assignedShifts.any((shift) =>
              shift.staffId == staff.id &&
              shift.date.year == date.year &&
              shift.date.month == date.month &&
              shift.date.day == date.day);
          if (hasShiftOnDate) return false;

          // 連続勤務日数チェック（個別設定を優先、前月も考慮）
          final effectiveMaxConsecutive = _getEffectiveMaxConsecutiveDays(staff, maxConsecutiveDays);
          if (_getConsecutiveWorkDays(staff.id, date, assignedShifts, previousMonthShifts) >= effectiveMaxConsecutive) {
            return false;
          }

          // 勤務間インターバルチェック（個別設定を優先、前月も考慮）
          final effectiveMinRest = _getEffectiveMinRestHours(staff, minRestHours);
          if (!_checkWorkInterval(staff.id, date, shiftType, assignedShifts, effectiveMinRest, previousMonthShifts)) {
            return false;
          }

          return true;
        }).toList();

        if (validCandidates.isEmpty) continue;

        // ハイブリッド方式で候補者をソート
        final random = Random();
        validCandidates.sort((a, b) {
          // 1. 充足率で比較（低い方が優先）
          final aPreferredCount = a.preferredDates.length;
          final bPreferredCount = b.preferredDates.length;
          final aGranted = preferredDateGrantedCount[a.id] ?? 0;
          final bGranted = preferredDateGrantedCount[b.id] ?? 0;

          final aRate = aPreferredCount > 0 ? aGranted / aPreferredCount : 0.0;
          final bRate = bPreferredCount > 0 ? bGranted / bPreferredCount : 0.0;

          if ((aRate - bRate).abs() > 0.001) {
            return aRate.compareTo(bRate);
          }

          // 2. 希望日数で比較（少ない方が優先）
          if (aPreferredCount != bPreferredCount) {
            return aPreferredCount.compareTo(bPreferredCount);
          }

          // 3. ランダム
          return random.nextInt(3) - 1;
        });

        // 枠数分だけ割り当て
        int assignedCount = 0;
        for (var staff in validCandidates) {
          if (assignedCount >= remainingSlots) break;

          final timeRange = _getShiftTimeRange(shiftType, date);
          if (timeRange == null) continue;

          shiftIdCounter++;
          String uniqueId = 'auto_pref_${DateTime.now().millisecondsSinceEpoch}_$shiftIdCounter';
          Shift newShift = Shift(
            id: uniqueId,
            date: date,
            startTime: timeRange.$1,
            endTime: timeRange.$2,
            staffId: staff.id,
            shiftType: shiftType,
            assignmentStrategy: strategy.name,
          );

          print('【勤務希望日】シフト作成: ${staff.name} → ${date.toString().split(' ')[0]} $shiftType');

          assignedShifts.add(newShift);
          staffShiftCounts[staff.id] = (staffShiftCounts[staff.id] ?? 0) + 1;
          preferredDateGrantedCount[staff.id] = (preferredDateGrantedCount[staff.id] ?? 0) + 1;
          assignedCount++;
        }
      }
    }

    // Analyticsイベントを送信（希望日が設定されていた場合のみ）
    if (staffWithPreferences.isNotEmpty) {
      // 期間内の希望日総数を計算
      int totalPreferences = 0;
      for (var staff in staffWithPreferences) {
        for (var dateStr in staff.preferredDates) {
          final date = DateTime.parse(dateStr);
          final dateOnly = DateTime(date.year, date.month, date.day);
          if (!dateOnly.isBefore(startDate) && !dateOnly.isAfter(endDate)) {
            totalPreferences++;
          }
        }
      }

      if (totalPreferences > 0) {
        try {
          await AnalyticsService.logPreferredDatesAssigned(
            totalPreferences: totalPreferences,
            granted: assignedShifts.length,
          );
        } catch (_) {
          // Analyticsエラーは無視
        }
        print('勤務希望日: 総数=$totalPreferences, 割り当て=${assignedShifts.length}');
      }
    }

    return assignedShifts;
  }

  Staff? _findBestStaffForShift(
    DateTime date,
    String shiftType,
    List<Staff> availableStaff,
    Map<String, int> staffShiftCounts,
    List<Shift> assignedShifts,
    AssignmentStrategy strategy,
    int maxConsecutiveDays,
    int minRestHours, {
    List<Shift> previousMonthShifts = const [],
  }) {
    List<Staff> candidates = availableStaff.where((staff) {
      if (!_isStaffAvailableOnDate(staff, date)) {
        return false;
      }

      // 月間最大シフト数チェック（0の場合は自動的に除外される）
      if (staffShiftCounts[staff.id]! >= staff.maxShiftsPerMonth) {
        return false;
      }

      // シフトタイプ制約をチェック
      // カスタム名と従来名の両方でチェック
      final oldShiftTypeName = _mapCustomToOldShiftType(shiftType);
      if (staff.unavailableShiftTypes.contains(shiftType) || staff.unavailableShiftTypes.contains(oldShiftTypeName)) {
        print('${staff.name}は$shiftType不可のため除外');
        return false;
      }

      bool hasShiftOnDate = assignedShifts
          .any((shift) => shift.staffId == staff.id && shift.date.year == date.year && shift.date.month == date.month && shift.date.day == date.day);
      if (hasShiftOnDate) {
        return false;
      }

      // 連続勤務日数をチェック（個別設定を優先、前月も考慮）
      final effectiveMaxConsecutive = _getEffectiveMaxConsecutiveDays(staff, maxConsecutiveDays);
      if (_getConsecutiveWorkDays(staff.id, date, assignedShifts, previousMonthShifts) >= effectiveMaxConsecutive) {
        print('${staff.name}は連続勤務日数制限($effectiveMaxConsecutive日)により除外');
        return false;
      }

      // 勤務間インターバルをチェック（個別設定を優先、前月も考慮）
      final effectiveMinRest = _getEffectiveMinRestHours(staff, minRestHours);
      if (!_checkWorkInterval(staff.id, date, shiftType, assignedShifts, effectiveMinRest, previousMonthShifts)) {
        print('${staff.name}は勤務間インターバル不足($effectiveMinRest時間必要)により除外');
        return false;
      }

      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    // 戦略に応じてソート
    switch (strategy) {
      case AssignmentStrategy.fairness:
        // シフト数重視: 充足率のみで比較（月間最大シフト数の設定に応じた比率）
        candidates.sort((a, b) {
          int aCount = staffShiftCounts[a.id] ?? 0;
          int bCount = staffShiftCounts[b.id] ?? 0;

          double aRate = a.maxShiftsPerMonth > 0 ? aCount / a.maxShiftsPerMonth : 1.0;
          double bRate = b.maxShiftsPerMonth > 0 ? bCount / b.maxShiftsPerMonth : 1.0;

          // まず充足率で比較
          int rateComparison = aRate.compareTo(bRate);
          if (rateComparison != 0) return rateComparison;

          // 充足率が同じ場合は、最後の勤務からの経過日数で比較
          int aDaysSinceLastShift = _getDaysSinceLastShift(a.id, date, assignedShifts);
          int bDaysSinceLastShift = _getDaysSinceLastShift(b.id, date, assignedShifts);

          // 最後の勤務からより日数が経っている人を優先
          return bDaysSinceLastShift.compareTo(aDaysSinceLastShift);
        });
        break;

      case AssignmentStrategy.distributed:
        // 分散重視: 最後の勤務からの経過日数を優先（連続勤務を避ける）
        candidates.sort((a, b) {
          int aDaysSinceLastShift = _getDaysSinceLastShift(a.id, date, assignedShifts);
          int bDaysSinceLastShift = _getDaysSinceLastShift(b.id, date, assignedShifts);

          // 最後の勤務からより日数が経っている人を優先
          int daysComparison = bDaysSinceLastShift.compareTo(aDaysSinceLastShift);
          if (daysComparison != 0) return daysComparison;

          // 同じ日数の場合は充足率で比較
          int aCount = staffShiftCounts[a.id] ?? 0;
          int bCount = staffShiftCounts[b.id] ?? 0;

          double aRate = a.maxShiftsPerMonth > 0 ? aCount / a.maxShiftsPerMonth : 1.0;
          double bRate = b.maxShiftsPerMonth > 0 ? bCount / b.maxShiftsPerMonth : 1.0;

          return aRate.compareTo(bRate);
        });
        break;
    }

    return candidates.first;
  }

  bool _isStaffAvailableOnDate(Staff staff, DateTime date) {
    // 曜日ベースの休み希望をチェック
    if (staff.preferredDaysOff.contains(date.weekday)) {
      print('${staff.name}は${date.weekday}曜日は休み希望');
      return false;
    }

    // 祝日の休み希望をチェック
    if (staff.holidaysOff) {
      final isHoliday = holiday_jp.isHoliday(date);
      if (isHoliday) {
        final holiday = holiday_jp.getHoliday(date);
        final holidayName = holiday?.nameEn ?? '祝日';
        print('${staff.name}は祝日（$holidayName）は休み希望');
        return false;
      }
    }

    // 特定日の休み希望をチェック
    final dateOnly = DateTime(date.year, date.month, date.day);
    for (final dayOffStr in staff.specificDaysOff) {
      final dayOff = DateTime.parse(dayOffStr);
      if (dayOff.year == dateOnly.year && dayOff.month == dateOnly.month && dayOff.day == dateOnly.day) {
        print('${staff.name}は${date.year}/${date.month}/${date.day}は休み希望');
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
  int _getConsecutiveWorkDays(String staffId, DateTime date, List<Shift> assignedShifts, [List<Shift> previousMonthShifts = const []]) {
    int consecutiveDays = 0;
    DateTime checkDate = date.subtract(const Duration(days: 1));

    // 今月のシフトと前月のシフトを結合してチェック
    final allShifts = [...assignedShifts, ...previousMonthShifts];

    while (true) {
      bool hasShift = allShifts.any(
          (shift) => shift.staffId == staffId && shift.date.year == checkDate.year && shift.date.month == checkDate.month && shift.date.day == checkDate.day);

      if (!hasShift) break;

      consecutiveDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return consecutiveDays;
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

  // 特定のシフトパターンの危険度をチェック
  int _getShiftPatternRisk(String previousShiftType, String nextShiftType) {
    // リスクレベル: 0=安全, 1=注意, 2=危険, 3=禁止

    // 夜勤→早番は最も危険
    if (previousShiftType == '夜勤' && nextShiftType == '早番') {
      return 3; // 禁止
    }

    // 遅番→早番も危険
    if (previousShiftType == '遅番' && nextShiftType == '早番') {
      return 2; // 危険
    }

    // 夜勤→日勤も注意が必要
    if (previousShiftType == '夜勤' && nextShiftType == '日勤') {
      return 1; // 注意
    }

    return 0; // 安全
  }
}
