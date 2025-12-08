import 'package:shift_kobo/models/assignment_strategy.dart';
import 'package:shift_kobo/models/shift.dart';
import 'package:shift_kobo/models/shift_constraint.dart';
import 'package:shift_kobo/models/shift_type.dart' as old_shift_type;
import 'package:shift_kobo/models/staff.dart';
import 'package:shift_kobo/providers/shift_provider.dart';
import 'package:shift_kobo/providers/shift_time_provider.dart';
import 'package:shift_kobo/providers/staff_provider.dart';

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
    AssignmentStrategy strategy = AssignmentStrategy.fairness,
  }) async {
    List<Shift> assignedShifts = [];
    // 有効なスタッフのみ使用（月間最大シフト数0のスタッフは自動的に除外される）
    List<Staff> availableStaff = staffProvider.activeStaffList;
    int shiftIdCounter = 0;

    // デバッグ: スタッフ数を確認
    print('利用可能なスタッフ数: ${availableStaff.length}');
    for (var staff in availableStaff) {
      print('スタッフ: ${staff.name}, 最大シフト数: ${staff.maxShiftsPerMonth}');
    }

    Map<String, int> staffShiftCounts = {};
    for (Staff staff in availableStaff) {
      staffShiftCounts[staff.id] = 0;
    }

    DateTime currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      for (String shiftType in dailyShiftRequirements.keys) {
        int requiredStaffCount = dailyShiftRequirements[shiftType] ?? 0;

        for (int i = 0; i < requiredStaffCount; i++) {
          Staff? assignedStaff = _findBestStaffForShift(
            currentDate,
            shiftType,
            availableStaff,
            staffShiftCounts,
            assignedShifts,
            strategy,
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

  Staff? _findBestStaffForShift(
    DateTime date,
    String shiftType,
    List<Staff> availableStaff,
    Map<String, int> staffShiftCounts,
    List<Shift> assignedShifts,
    AssignmentStrategy strategy,
  ) {
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

      // 連続勤務日数をチェック（最大5日連続まで）
      if (_getConsecutiveWorkDays(staff.id, date, assignedShifts) >= 5) {
        print('${staff.name}は連続勤務日数制限により除外');
        return false;
      }

      // 勤務間インターバルをチェック
      if (!_checkWorkInterval(staff.id, date, shiftType, assignedShifts)) {
        print('${staff.name}は勤務間インターバル不足により除外');
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

  // 連続勤務日数を計算
  int _getConsecutiveWorkDays(String staffId, DateTime date, List<Shift> assignedShifts) {
    int consecutiveDays = 0;
    DateTime checkDate = date.subtract(const Duration(days: 1));

    while (true) {
      bool hasShift = assignedShifts.any(
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

  // 勤務間インターバルをチェック
  bool _checkWorkInterval(String staffId, DateTime date, String shiftType, List<Shift> assignedShifts) {
    // 前日と翌日のシフトをチェック
    DateTime previousDay = date.subtract(const Duration(days: 1));
    DateTime nextDay = date.add(const Duration(days: 1));

    // 前日のシフトを取得
    Shift? previousShift = assignedShifts
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
      if (!_hasValidInterval(previousShift.endTime, currentStart)) {
        return false;
      }
    }

    // 翌日シフトとのインターバルチェック
    if (nextShift != null) {
      if (!_hasValidInterval(currentEnd, nextShift.startTime)) {
        return false;
      }
    }

    return true;
  }

  // 2つの時間の間に十分なインターバルがあるかチェック
  bool _hasValidInterval(DateTime endTime, DateTime startTime) {
    const int minIntervalHours = 12; // 最低12時間のインターバル
    const int preferredIntervalHours = 24; // 理想的には24時間

    Duration interval = startTime.difference(endTime);

    // 最低12時間のインターバルが必要
    if (interval.inHours < minIntervalHours) {
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
