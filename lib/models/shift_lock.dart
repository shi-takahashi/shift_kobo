/// シフトの締め（ロック）状態を表すモデル
class ShiftLock {
  final String id; // "2026-01" のような形式
  final bool isLocked;
  final DateTime? lockedAt;
  final String? lockedBy; // userId

  ShiftLock({
    required this.id,
    required this.isLocked,
    this.lockedAt,
    this.lockedBy,
  });

  /// 年月からIDを生成
  static String generateId(int year, int month) {
    return '$year-$month';
  }

  /// IDから年を取得
  int get year => int.parse(id.split('-')[0]);

  /// IDから月を取得
  int get month => int.parse(id.split('-')[1]);

  /// Firestoreからデータを読み込む
  factory ShiftLock.fromMap(Map<String, dynamic> map, String id) {
    return ShiftLock(
      id: id,
      isLocked: map['isLocked'] as bool? ?? false,
      lockedAt: map['lockedAt'] != null
          ? (map['lockedAt'] as dynamic).toDate()
          : null,
      lockedBy: map['lockedBy'] as String?,
    );
  }

  /// Firestoreに保存するためのMapに変換
  Map<String, dynamic> toMap() {
    return {
      'isLocked': isLocked,
      'lockedAt': lockedAt,
      'lockedBy': lockedBy,
    };
  }

  /// コピーを作成
  ShiftLock copyWith({
    String? id,
    bool? isLocked,
    DateTime? lockedAt,
    String? lockedBy,
  }) {
    return ShiftLock(
      id: id ?? this.id,
      isLocked: isLocked ?? this.isLocked,
      lockedAt: lockedAt ?? this.lockedAt,
      lockedBy: lockedBy ?? this.lockedBy,
    );
  }
}
