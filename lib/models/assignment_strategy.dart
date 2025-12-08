/// シフト割り当て戦略
enum AssignmentStrategy {
  fairness, // シフト数優先（デフォルト）
  distributed; // 分散優先

  String get displayName {
    switch (this) {
      case AssignmentStrategy.fairness:
        return 'シフト数優先';
      case AssignmentStrategy.distributed:
        return '分散優先';
    }
  }

  String get description {
    switch (this) {
      case AssignmentStrategy.fairness:
        return '月間最大シフト数の設定に応じた比率で割り当て';
      case AssignmentStrategy.distributed:
        return '連続勤務を避け、休みを挟んで割り当て';
    }
  }

  /// 文字列から表示名を取得
  static String getDisplayNameFromString(String strategyName) {
    try {
      final strategy = AssignmentStrategy.values.firstWhere(
        (s) => s.name == strategyName,
      );
      return strategy.displayName;
    } catch (e) {
      // enumに存在しない場合（"nothing"など）
      switch (strategyName) {
        case 'nothing':
          return '優先なし';
        default:
          return strategyName;
      }
    }
  }
}
