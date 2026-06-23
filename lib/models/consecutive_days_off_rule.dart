/// 連休（日付未指定）の確保ルール
///
/// 「月のどこかで、連続 [length] 日の休みを [count] 回 確保する」という指定。
/// 複数のルールを並べることで「2連休を2回 ＋ 3連休を1回」のような組み合わせも表現できる。
///
/// - [length]: 連続して休む日数（連休なので2以上）
/// - [count]:  月に何回その連休を確保するか（1以上）
///
/// チーム設定（全員一律）と、将来のスタッフ個別上書きの両方で同じ型を使い回す。
class ConsecutiveDaysOffRule {
  final int length; // N: 連続日数
  final int count;  // M: 月の回数

  const ConsecutiveDaysOffRule({
    required this.length,
    required this.count,
  });

  factory ConsecutiveDaysOffRule.fromMap(Map<String, dynamic> map) {
    return ConsecutiveDaysOffRule(
      length: (map['length'] as num?)?.toInt() ?? 2,
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'count': count,
    };
  }

  ConsecutiveDaysOffRule copyWith({
    int? length,
    int? count,
  }) {
    return ConsecutiveDaysOffRule(
      length: length ?? this.length,
      count: count ?? this.count,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConsecutiveDaysOffRule &&
      other.length == length &&
      other.count == count;

  @override
  int get hashCode => Object.hash(length, count);
}
