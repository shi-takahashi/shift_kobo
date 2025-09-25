import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/shift.dart';
import '../models/shift_constraint.dart';
import '../models/staff.dart';

class ShiftProvider extends ChangeNotifier {
  late Box<Shift> _shiftBox;
  late Box<ShiftConstraint> _constraintBox;
  List<Shift> _shifts = [];
  List<ShiftConstraint> _constraints = [];

  List<Shift> get shifts => _shifts;
  List<ShiftConstraint> get constraints => _constraints;

  ShiftProvider() {
    _init();
  }

  Future<void> _init() async {
    _shiftBox = Hive.box<Shift>('shifts');
    _constraintBox = Hive.box<ShiftConstraint>('constraints');
    _loadData();
  }

  void _loadData() {
    _shifts = _shiftBox.values.toList();
    _constraints = _constraintBox.values.toList();
    notifyListeners();
  }

  Future<void> addShift(Shift shift) async {
    await _shiftBox.put(shift.id, shift);
    _loadData();
  }

  Future<void> updateShift(Shift shift) async {
    // 既存のShiftをボックスから取得
    final existingShift = _shiftBox.get(shift.id);
    if (existingShift != null) {
      // 既存のShiftを更新
      existingShift.staffId = shift.staffId;
      existingShift.date = shift.date;
      existingShift.startTime = shift.startTime;
      existingShift.endTime = shift.endTime;
      existingShift.shiftType = shift.shiftType;
      existingShift.note = shift.note;
      existingShift.updatedAt = DateTime.now();
      await existingShift.save();
    } else {
      // 存在しない場合は新規追加（通常は起こらないが安全のため）
      shift.updatedAt = DateTime.now();
      await _shiftBox.put(shift.id, shift);
    }
    _loadData();
  }

  Future<void> deleteShift(String shiftId) async {
    final shift = _shiftBox.get(shiftId);
    if (shift != null) {
      await shift.delete();
      _loadData();
    }
  }

  Future<void> addConstraint(ShiftConstraint constraint) async {
    await _constraintBox.put(constraint.id, constraint);
    _loadData();
  }

  Future<void> deleteConstraint(String constraintId) async {
    final constraint = _constraintBox.get(constraintId);
    if (constraint != null) {
      await constraint.delete();
      _loadData();
    }
  }

  List<Shift> getShiftsForDate(DateTime date) {
    return _shifts.where((shift) {
      return shift.date.year == date.year &&
             shift.date.month == date.month &&
             shift.date.day == date.day;
    }).toList();
  }

  List<Shift> getShiftsForMonth(int year, int month) {
    return _shifts.where((shift) {
      return shift.date.year == year && shift.date.month == month;
    }).toList();
  }

  List<Shift> getShiftsByStaffId(String staffId) {
    return _shifts.where((shift) => shift.staffId == staffId).toList();
  }

  List<ShiftConstraint> getConstraintsByStaffId(String staffId) {
    return _constraints.where((c) => c.staffId == staffId).toList();
  }

  List<ShiftConstraint> getConstraintsForDate(DateTime date) {
    return _constraints.where((c) {
      return c.date.year == date.year &&
             c.date.month == date.month &&
             c.date.day == date.day;
    }).toList();
  }

  Map<DateTime, List<Shift>> getMonthlyShiftMap(int year, int month) {
    final monthShifts = getShiftsForMonth(year, month);
    final Map<DateTime, List<Shift>> shiftMap = {};
    
    for (final shift in monthShifts) {
      final dateKey = DateTime(shift.date.year, shift.date.month, shift.date.day);
      if (shiftMap.containsKey(dateKey)) {
        shiftMap[dateKey]!.add(shift);
      } else {
        shiftMap[dateKey] = [shift];
      }
    }
    
    return shiftMap;
  }

  Future<void> autoGenerateShifts({
    required DateTime startDate,
    required DateTime endDate,
    required List<Staff> staffList,
    required Map<String, int> dailyRequirements,
  }) async {
    
    for (DateTime date = startDate;
         date.isBefore(endDate.add(const Duration(days: 1)));
         date = date.add(const Duration(days: 1))) {
      
      final availableStaff = _getAvailableStaff(date, staffList);
      
      for (final shiftType in dailyRequirements.keys) {
        final required = dailyRequirements[shiftType] ?? 0;
        
        for (int i = 0; i < required && i < availableStaff.length; i++) {
          final shift = Shift(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
            date: date,
            staffId: availableStaff[i].id,
            shiftType: shiftType,
            startTime: DateTime(date.year, date.month, date.day, 9, 0),
            endTime: DateTime(date.year, date.month, date.day, 17, 0),
          );
          
          await addShift(shift);
        }
      }
    }
  }

  List<Staff> _getAvailableStaff(DateTime date, List<Staff> allStaff) {
    final constraints = getConstraintsForDate(date);
    final unavailableStaffIds = constraints
        .where((c) => !c.isAvailable)
        .map((c) => c.staffId)
        .toSet();
    
    final existingShifts = getShiftsForDate(date);
    final assignedStaffIds = existingShifts.map((s) => s.staffId).toSet();
    
    return allStaff.where((staff) {
      return staff.isActive &&
             !unavailableStaffIds.contains(staff.id) &&
             !assignedStaffIds.contains(staff.id) &&
             !staff.preferredDaysOff.contains(date.weekday);
    }).toList();
  }
}