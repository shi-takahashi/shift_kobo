import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;

import 'companion_rule.dart';
import 'consecutive_days_off_rule.dart';

/// チーム（組織単位）
class Team {
  final String id;              // チームID
  final String name;            // チーム名
  final String ownerId;         // 作成者のUID
  final List<String> adminIds;  // 管理者のUIDリスト
  final List<String> memberIds; // スタッフのUIDリスト（管理者も含む）
  final String inviteCode;      // 招待コード（8文字ランダム）
  final DateTime? shiftDeadline; // 休み希望締め日
  final int maxConsecutiveDays;  // 連続勤務日数上限（デフォルト5日）
  final int minRestHours;        // 勤務間インターバル（デフォルト12時間）
  final bool countOvernightAsTwoDays; // 夜勤(日またぎ)を連勤2日分として数えるか（デフォルトtrue）
  final List<String> ngPairs;    // 組ませないペア（"idA|idB" 形式・idは昇順）
  final List<CompanionRule> companionRules; // 付き添い必須（新人＝相方の誰か1人と同席）
  final List<int> teamDaysOff;   // チーム全体の曜日休み（1=月曜〜7=日曜）
  final List<String> teamSpecificDaysOff; // チーム全体の特定日休み（ISO8601形式）
  final bool teamHolidaysOff;    // チーム全体の祝日休み
  // 連休（日付未指定）の確保ルール。空なら機能オフ。
  // 例: [2連休×2回, 3連休×1回] のように複数の組み合わせを指定できる。
  final List<ConsecutiveDaysOffRule> consecutiveDaysOffRules;
  final DateTime createdAt;     // 作成日時
  final DateTime updatedAt;     // 更新日時

  Team({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.adminIds,
    required this.memberIds,
    required this.inviteCode,
    this.shiftDeadline,
    this.maxConsecutiveDays = 5,  // デフォルト5日
    this.minRestHours = 12,        // デフォルト12時間
    this.countOvernightAsTwoDays = true, // デフォルト: 夜勤は連勤2日分
    List<String>? ngPairs,
    List<CompanionRule>? companionRules,
    List<int>? teamDaysOff,
    List<String>? teamSpecificDaysOff,
    this.teamHolidaysOff = false,
    List<ConsecutiveDaysOffRule>? consecutiveDaysOffRules,
    required this.createdAt,
    required this.updatedAt,
  })  : ngPairs = ngPairs ?? [],
        companionRules = companionRules ?? [],
        teamDaysOff = teamDaysOff ?? [],
        teamSpecificDaysOff = teamSpecificDaysOff ?? [],
        consecutiveDaysOffRules = consecutiveDaysOffRules ?? [];

  /// ペアの安定キー（順序に依存しない）。スタッフID2つから一意なキーを作る。
  static String pairKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  bool isNgPair(String a, String b) => ngPairs.contains(pairKey(a, b));

  /// その日がチーム全体の休み（曜日定休・特定日・祝日休み）か。
  /// チーム休みの日は誰も勤務しない＝自動割り当ての対象外であり、
  /// 必要人数の未充足判定からも除外する（必要人数が残っていても不足扱いにしない）。
  /// 付き添い・連休・未充足バッジなど休み判定が必要な全箇所はこれを正典として使う。
  bool isDayOff(DateTime date) {
    // 1. 曜日定休（1=月曜〜7=日曜）
    if (teamDaysOff.contains(date.weekday)) return true;

    // 2. 祝日休み
    if (teamHolidaysOff && holiday_jp.isHoliday(date)) return true;

    // 3. 特定日休み（年月日で比較。保存形式の差異に強い）
    final d = DateTime(date.year, date.month, date.day);
    for (final iso in teamSpecificDaysOff) {
      final off = DateTime.tryParse(iso);
      if (off != null && off.year == d.year && off.month == d.month && off.day == d.day) {
        return true;
      }
    }
    return false;
  }

  /// 指定スタッフの付き添い必須ルール（無ければnull）
  CompanionRule? companionRuleFor(String staffId) {
    for (final rule in companionRules) {
      if (rule.staffId == staffId) return rule;
    }
    return null;
  }

  /// Firestoreから取得
  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      adminIds: List<String>.from(data['adminIds'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      shiftDeadline: (data['shiftDeadline'] as Timestamp?)?.toDate(),
      maxConsecutiveDays: data['maxConsecutiveDays'] ?? 5,
      minRestHours: data['minRestHours'] ?? 12,
      countOvernightAsTwoDays: data['countOvernightAsTwoDays'] ?? true,
      ngPairs: List<String>.from(data['ngPairs'] ?? []),
      companionRules: ((data['companionRules'] as List<dynamic>?) ?? [])
          .map((e) => CompanionRule.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      teamDaysOff: List<int>.from(data['teamDaysOff'] ?? []),
      teamSpecificDaysOff: List<String>.from(data['teamSpecificDaysOff'] ?? []),
      teamHolidaysOff: data['teamHolidaysOff'] ?? false,
      consecutiveDaysOffRules: _parseConsecutiveDaysOffRules(data),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// 連休ルールをFirestoreデータから復元する。
  /// 旧フィールド（consecutiveDaysOffLength / consecutiveDaysOffCount）が残っている
  /// チームは、1ルールへ移行して読み込む（後方互換）。
  static List<ConsecutiveDaysOffRule> _parseConsecutiveDaysOffRules(Map<String, dynamic> data) {
    final raw = data['consecutiveDaysOffRules'] as List<dynamic>?;
    if (raw != null) {
      return raw
          .map((e) => ConsecutiveDaysOffRule.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.length >= 2 && r.count >= 1)
          .toList();
    }
    // 旧スカラー形式からの移行
    final oldCount = (data['consecutiveDaysOffCount'] as num?)?.toInt() ?? 0;
    if (oldCount >= 1) {
      final oldLength = (data['consecutiveDaysOffLength'] as num?)?.toInt() ?? 2;
      return [ConsecutiveDaysOffRule(length: oldLength, count: oldCount)];
    }
    return [];
  }

  /// Firestoreへ保存
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'inviteCode': inviteCode,
      'shiftDeadline': shiftDeadline != null
          ? Timestamp.fromDate(shiftDeadline!)
          : null,
      'maxConsecutiveDays': maxConsecutiveDays,
      'minRestHours': minRestHours,
      'countOvernightAsTwoDays': countOvernightAsTwoDays,
      'ngPairs': ngPairs,
      'companionRules': companionRules.map((e) => e.toMap()).toList(),
      'teamDaysOff': teamDaysOff,
      'teamSpecificDaysOff': teamSpecificDaysOff,
      'teamHolidaysOff': teamHolidaysOff,
      'consecutiveDaysOffRules': consecutiveDaysOffRules.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// コピー作成
  Team copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? adminIds,
    List<String>? memberIds,
    String? inviteCode,
    DateTime? shiftDeadline,
    int? maxConsecutiveDays,
    int? minRestHours,
    bool? countOvernightAsTwoDays,
    List<String>? ngPairs,
    List<CompanionRule>? companionRules,
    List<int>? teamDaysOff,
    List<String>? teamSpecificDaysOff,
    bool? teamHolidaysOff,
    List<ConsecutiveDaysOffRule>? consecutiveDaysOffRules,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      shiftDeadline: shiftDeadline ?? this.shiftDeadline,
      maxConsecutiveDays: maxConsecutiveDays ?? this.maxConsecutiveDays,
      minRestHours: minRestHours ?? this.minRestHours,
      countOvernightAsTwoDays: countOvernightAsTwoDays ?? this.countOvernightAsTwoDays,
      ngPairs: ngPairs ?? this.ngPairs,
      companionRules: companionRules ?? this.companionRules,
      teamDaysOff: teamDaysOff ?? this.teamDaysOff,
      teamSpecificDaysOff: teamSpecificDaysOff ?? this.teamSpecificDaysOff,
      teamHolidaysOff: teamHolidaysOff ?? this.teamHolidaysOff,
      consecutiveDaysOffRules: consecutiveDaysOffRules ?? this.consecutiveDaysOffRules,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 指定したユーザーが管理者かどうか
  bool isAdmin(String uid) => adminIds.contains(uid);

  /// 指定したユーザーがスタッフかどうか
  bool isMember(String uid) => memberIds.contains(uid);
}
