import 'package:shift_kobo/models/shift.dart';
import 'package:shift_kobo/models/staff.dart';
import 'package:shift_kobo/models/shift_constraint.dart';
import 'package:shift_kobo/models/shift_type.dart';
import 'package:shift_kobo/providers/staff_provider.dart';
import 'package:shift_kobo/providers/shift_provider.dart';

class ShiftAssignmentService {
  final StaffProvider staffProvider;
  final ShiftProvider shiftProvider;

  ShiftAssignmentService({
    required this.staffProvider,
    required this.shiftProvider,
  });

  Future<List<Shift>> autoAssignShifts(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> dailyShiftRequirements,
  ) async {
    List<Shift> assignedShifts = [];
    List<Staff> availableStaff = staffProvider.staff;
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
          );

          if (assignedStaff != null) {
            int currentCount = staffShiftCounts[assignedStaff.id] ?? 0;
            double fillRate = assignedStaff.maxShiftsPerMonth > 0 
                ? (currentCount + 1) / assignedStaff.maxShiftsPerMonth * 100 
                : 100;
            print('${currentDate.toString().split(' ')[0]} $shiftType: ${assignedStaff.name}を割り当て (${currentCount + 1}/${assignedStaff.maxShiftsPerMonth}回, ${fillRate.toStringAsFixed(1)}%)');
            ShiftTimeRange? timeRange = ShiftType.defaultTimeRanges[shiftType];
            if (timeRange != null) {
              shiftIdCounter++;
              String uniqueId = 'auto_${DateTime.now().millisecondsSinceEpoch}_$shiftIdCounter';
              Shift newShift = Shift(
                id: uniqueId,
                date: currentDate,
                startTime: timeRange.toStartDateTime(currentDate),
                endTime: timeRange.toEndDateTime(currentDate),
                staffId: assignedStaff.id,
                shiftType: shiftType,
              );
              print('シフト作成: ID=$uniqueId, 日付=${currentDate.toString().split(' ')[0]}, スタッフ=${assignedStaff.name}');
              
              assignedShifts.add(newShift);
              staffShiftCounts[assignedStaff.id] = 
                  (staffShiftCounts[assignedStaff.id] ?? 0) + 1;
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
  ) {
    List<Staff> candidates = availableStaff.where((staff) {
      if (!_isStaffAvailableOnDate(staff, date)) {
        return false;
      }

      if (staffShiftCounts[staff.id]! >= staff.maxShiftsPerMonth) {
        return false;
      }

      // シフトタイプ制約をチェック
      if (staff.unavailableShiftTypes.contains(shiftType)) {
        print('${staff.name}は$shiftType不可のため除外');
        return false;
      }

      bool hasShiftOnDate = assignedShifts.any((shift) =>
          shift.staffId == staff.id &&
          shift.date.year == date.year &&
          shift.date.month == date.month &&
          shift.date.day == date.day);
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

    // 公平性とシフト分散を考慮してソート
    candidates.sort((a, b) {
      int aCount = staffShiftCounts[a.id] ?? 0;
      int bCount = staffShiftCounts[b.id] ?? 0;
      
      // それぞれの充足率を計算（現在のシフト数 / 最大シフト数）
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

    return candidates.first;
  }

  bool _isStaffAvailableOnDate(Staff staff, DateTime date) {
    // 曜日ベースの休み希望をチェック
    if (staff.preferredDaysOff.contains(date.weekday)) {
      print('${staff.name}は${date.weekday}曜日は休み希望');
      return false;
    }
    
    // 日付ベースの制約をチェック
    for (ShiftConstraint constraint in staff.constraints) {
      if (constraint.date.year == date.year &&
          constraint.date.month == date.month &&
          constraint.date.day == date.day) {
        return constraint.isAvailable;
      }
    }
    return true;
  }

  Map<String, int> analyzeCurrentShifts(DateTime month) {
    List<Shift> monthShifts = shiftProvider.getShiftsForMonth(month.year, month.month);
    Map<String, int> staffShiftCounts = {};
    
    for (Shift shift in monthShifts) {
      staffShiftCounts[shift.staffId] = 
          (staffShiftCounts[shift.staffId] ?? 0) + 1;
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
    bool hasConflict = existingShifts.any((existingShift) =>
        existingShift.staffId == shift.staffId &&
        existingShift.id != shift.id);
    
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
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      switch (shiftType) {
        case ShiftType.morning:
          return 3;
        case ShiftType.day:
          return 4;
        case ShiftType.evening:
          return 3;
        case ShiftType.night:
          return 2;
        default:
          return 2;
      }
    } else {
      switch (shiftType) {
        case ShiftType.morning:
          return 2;
        case ShiftType.day:
          return 3;
        case ShiftType.evening:
          return 2;
        case ShiftType.night:
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
      bool hasShift = assignedShifts.any((shift) =>
          shift.staffId == staffId &&
          shift.date.year == checkDate.year &&
          shift.date.month == checkDate.month &&
          shift.date.day == checkDate.day);
      
      if (!hasShift) break;
      
      consecutiveDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return consecutiveDays;
  }

  // 最後の勤務からの経過日数を計算
  int _getDaysSinceLastShift(String staffId, DateTime date, List<Shift> assignedShifts) {
    List<Shift> staffShifts = assignedShifts
        .where((shift) => shift.staffId == staffId && shift.date.isBefore(date))
        .toList();
    
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
    Shift? previousShift = assignedShifts.where((shift) =>
        shift.staffId == staffId &&
        shift.date.year == previousDay.year &&
        shift.date.month == previousDay.month &&
        shift.date.day == previousDay.day).firstOrNull;
    
    // 翌日のシフトを取得
    Shift? nextShift = assignedShifts.where((shift) =>
        shift.staffId == staffId &&
        shift.date.year == nextDay.year &&
        shift.date.month == nextDay.month &&
        shift.date.day == nextDay.day).firstOrNull;
    
    // 現在割り当てようとしているシフトの時間を取得
    ShiftTimeRange? currentTimeRange = ShiftType.defaultTimeRanges[shiftType];
    if (currentTimeRange == null) return true;
    
    DateTime currentStart = currentTimeRange.toStartDateTime(date);
    DateTime currentEnd = currentTimeRange.toEndDateTime(date);
    
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