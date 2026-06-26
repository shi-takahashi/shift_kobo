/// 付き添い必須ルール（方向性あり・グループ）
///
/// 「新人 [staffId] は、相方候補 [companionIds] の"誰か1人"と
/// 同じ日・同じシフトに必ず（または なるべく）同席する」という制約。
///
/// - [hard] true（既定）: 相方が同席できないなら本人も入れない（＝単独勤務NG）。
/// - [hard] false: なるべく相方と組ませるが、無理なら本人だけでも入れる。
///
/// [countsAsWorkforce] は「この人を必要人数（戦力）として数えるか」を切り替える：
/// - true（既定 ＝ パターン①）: 必要人数の枠内で確保する。新人が枠の1つを埋め、相方がもう1枠。
///   この運用では必要人数を2名以上に設定しておく必要がある（従来の動作）。
/// - false（パターン② ＝ 研修扱い）: 必要人数とは別枠で +1 する。相方が必要枠を埋めて戦力として
///   数えられ、新人はその上に上乗せ（シャドー）される。必要人数1名のままでも「新人が入る日だけ実質2名」
///   になる。新人の出勤日は本人の月間上限・公平性に従って自動配分する（生成・リバランス後に上乗せ）。
///
/// 注意: これは方向性のある制約（staffId 側にのみ条件がかかる）。
/// 相方候補側は単独でも他の人と組んでも自由。
class CompanionRule {
  final String staffId;             // 付き添いが必要なスタッフ（例: 新人）
  final List<String> companionIds;  // 許容する相方の候補（誰か1人いればOK）
  final bool hard;                  // true=絶対（単独なら入れない）, false=なるべく
  final bool countsAsWorkforce;     // true=必要人数内(①戦力), false=別枠+1(②研修扱い)

  CompanionRule({
    required this.staffId,
    required this.companionIds,
    this.hard = true,
    this.countsAsWorkforce = true,
  });

  factory CompanionRule.fromMap(Map<String, dynamic> map) {
    return CompanionRule(
      staffId: map['staffId'] ?? '',
      companionIds: List<String>.from(map['companionIds'] ?? []),
      hard: map['hard'] ?? true,
      countsAsWorkforce: map['countsAsWorkforce'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'companionIds': companionIds,
      'hard': hard,
      'countsAsWorkforce': countsAsWorkforce,
    };
  }

  CompanionRule copyWith({
    String? staffId,
    List<String>? companionIds,
    bool? hard,
    bool? countsAsWorkforce,
  }) {
    return CompanionRule(
      staffId: staffId ?? this.staffId,
      companionIds: companionIds ?? this.companionIds,
      hard: hard ?? this.hard,
      countsAsWorkforce: countsAsWorkforce ?? this.countsAsWorkforce,
    );
  }
}
