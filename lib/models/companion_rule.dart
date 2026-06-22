/// 付き添い必須ルール（方向性あり・グループ）
///
/// 「新人 [staffId] は、相方候補 [companionIds] の"誰か1人"と
/// 同じ日・同じシフトに必ず（または なるべく）同席する」という制約。
///
/// - [hard] true（既定）: 相方が同席できないなら本人も入れない（＝単独勤務NG）。
/// - [hard] false: なるべく相方と組ませるが、無理なら本人だけでも入れる。
///
/// 注意: これは方向性のある制約（staffId 側にのみ条件がかかる）。
/// 相方候補側は単独でも他の人と組んでも自由。
class CompanionRule {
  final String staffId;             // 付き添いが必要なスタッフ（例: 新人）
  final List<String> companionIds;  // 許容する相方の候補（誰か1人いればOK）
  final bool hard;                  // true=絶対（単独なら入れない）, false=なるべく

  CompanionRule({
    required this.staffId,
    required this.companionIds,
    this.hard = true,
  });

  factory CompanionRule.fromMap(Map<String, dynamic> map) {
    return CompanionRule(
      staffId: map['staffId'] ?? '',
      companionIds: List<String>.from(map['companionIds'] ?? []),
      hard: map['hard'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'companionIds': companionIds,
      'hard': hard,
    };
  }

  CompanionRule copyWith({
    String? staffId,
    List<String>? companionIds,
    bool? hard,
  }) {
    return CompanionRule(
      staffId: staffId ?? this.staffId,
      companionIds: companionIds ?? this.companionIds,
      hard: hard ?? this.hard,
    );
  }
}
