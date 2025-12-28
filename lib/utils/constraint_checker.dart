import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;
import '../models/staff.dart';
import '../providers/shift_provider.dart';

/// 制約チェック用のユーティリティクラス
class ConstraintChecker {
  /// スタッフがある日付・シフトタイプで働く場合の制約違反をチェック
  ///
  /// [staff] チェック対象のスタッフ
  /// [date] シフトの日付
  /// [shiftType] シフトタイプ名
  /// [shiftProvider] 月間シフト数チェック用（オプション）
  /// [existingShiftId] 既存シフトの編集時は除外するシフトID（オプション）
  ///
  /// 戻り値: 制約違反のメッセージリスト（違反がなければ空）
  static List<String> checkViolations({
    required Staff staff,
    required DateTime date,
    required String shiftType,
    ShiftProvider? shiftProvider,
    String? existingShiftId,
  }) {
    final violations = <String>[];

    // 1. 曜日の休み希望チェック
    final weekday = date.weekday; // 1-7 (月-日)
    if (staff.preferredDaysOff.contains(weekday)) {
      final dayNames = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
      violations.add('${dayNames[weekday - 1]}は休み希望');
    }

    // 2. 祝日の休み希望チェック
    if (staff.holidaysOff) {
      final isHoliday = holiday_jp.isHoliday(date);
      if (isHoliday) {
        violations.add('祝日は休み希望');
      }
    }

    // 3. 特定日の休み希望チェック
    final dateString = DateTime(date.year, date.month, date.day).toIso8601String();
    if (staff.specificDaysOff.contains(dateString)) {
      violations.add('${date.month}/${date.day}は休み希望日');
    }

    // 4. 勤務不可シフトタイプチェック
    if (staff.unavailableShiftTypes.contains(shiftType)) {
      violations.add('$shiftTypeは勤務不可');
    }

    // 5. 月間最大シフト数チェック（shiftProviderが提供された場合のみ）
    if (shiftProvider != null && staff.maxShiftsPerMonth > 0) {
      final targetMonth = DateTime(date.year, date.month);
      final monthlyShifts = shiftProvider.getShiftsForMonth(targetMonth.year, targetMonth.month)
          .where((shift) => shift.staffId == staff.id);

      // 既存シフトは除外してカウント
      int currentMonthlyCount = monthlyShifts.where((shift) {
        if (existingShiftId != null) {
          return shift.id != existingShiftId;
        }
        return true;
      }).length;

      // 新規追加の場合は+1
      int futureCount = existingShiftId == null ? currentMonthlyCount + 1 : currentMonthlyCount;

      if (futureCount > staff.maxShiftsPerMonth) {
        violations.add('月間最大シフト数（${staff.maxShiftsPerMonth}回）を超えます（現在: ${currentMonthlyCount}回）');
      }
    }

    return violations;
  }

  /// 制約違反があるかどうかを簡易チェック
  static bool hasViolations({
    required Staff staff,
    required DateTime date,
    required String shiftType,
  }) {
    return checkViolations(
      staff: staff,
      date: date,
      shiftType: shiftType,
    ).isNotEmpty;
  }
}
