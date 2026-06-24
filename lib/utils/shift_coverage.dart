import '../models/shift.dart';

/// シフトの充足判定ユーティリティ。
///
/// 「その日の設定人数（required）」と「実際に割り当てられたシフト（assigned）」を
/// 突き合わせ、不足している枠を算出する。自動作成・手動編集・プラン切替のいずれでも、
/// 常に「現在のシフト vs 設定」を見るので、埋めれば自動で不足が解消する。

/// その日の不足枠を「シフト種別名 -> 不足人数」で返す。
///
/// - [required]: その日の設定人数（種別名 -> 必要人数）。`getRequirementsForDate` の戻り値。
/// - [assigned]: その日に割り当て済みのシフト一覧。
/// - [activeTypeNames]: 現在有効なシフト種別名の集合（無効な種別は判定対象外）。
///
/// required>0 かつ activeTypeNames に含まれる種別だけを対象にする。不足が無ければ空マップ。
Map<String, int> computeDateShortfall({
  required Map<String, int> required,
  required List<Shift> assigned,
  required Set<String> activeTypeNames,
}) {
  final have = <String, int>{};
  for (final s in assigned) {
    have[s.shiftType] = (have[s.shiftType] ?? 0) + 1;
  }
  final shortfall = <String, int>{};
  required.forEach((type, need) {
    if (need <= 0 || !activeTypeNames.contains(type)) return;
    final miss = need - (have[type] ?? 0);
    if (miss > 0) shortfall[type] = miss;
  });
  return shortfall;
}

/// その日が未充足か（不足枠が1つでもあるか）。
bool isDateUnderfilled({
  required Map<String, int> required,
  required List<Shift> assigned,
  required Set<String> activeTypeNames,
}) =>
    computeDateShortfall(
      required: required,
      assigned: assigned,
      activeTypeNames: activeTypeNames,
    ).isNotEmpty;
