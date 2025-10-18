import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/shift_constraint.dart';
import '../models/staff.dart';

class ShiftProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Shift> _shifts = [];
  List<ShiftConstraint> _constraints = [];
  StreamSubscription? _shiftsSubscription;
  StreamSubscription? _constraintsSubscription;
  bool _isShiftsLoading = true;
  bool _isConstraintsLoading = true;

  List<Shift> get shifts => _shifts;
  List<ShiftConstraint> get constraints => _constraints;
  bool get isLoading => _isShiftsLoading || _isConstraintsLoading;

  ShiftProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    _subscribeToShifts();
    _subscribeToConstraints();
  }

  /// Firestoreからシフトをリアルタイムで購読
  void _subscribeToShifts() {
    if (teamId == null) return;

    _shiftsSubscription?.cancel();
    _shiftsSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .snapshots()
        .listen((snapshot) {
      _shifts = snapshot.docs.map((doc) {
        final data = doc.data();
        return Shift(
          id: doc.id,
          date: (data['date'] as Timestamp).toDate(),
          staffId: data['staffId'] ?? '',
          shiftType: data['shiftType'] ?? '',
          startTime: (data['startTime'] as Timestamp).toDate(),
          endTime: (data['endTime'] as Timestamp).toDate(),
          note: data['note'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      // 初回ロード完了
      if (_isShiftsLoading) {
        _isShiftsLoading = false;
      }

      notifyListeners();
    });
  }

  /// Firestoreから制約をリアルタイムで購読
  void _subscribeToConstraints() {
    if (teamId == null) return;

    _constraintsSubscription?.cancel();
    _constraintsSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraints')
        .snapshots()
        .listen((snapshot) {
      _constraints = snapshot.docs.map((doc) {
        final data = doc.data();
        return ShiftConstraint(
          id: doc.id,
          staffId: data['staffId'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          isAvailable: data['isAvailable'] ?? true,
          reason: data['reason'],
        );
      }).toList();

      // 初回ロード完了
      if (_isConstraintsLoading) {
        _isConstraintsLoading = false;
      }

      notifyListeners();
    });
  }

  Future<void> addShift(Shift shift) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .doc(shift.id)
        .set({
      'date': Timestamp.fromDate(shift.date),
      'staffId': shift.staffId,
      'shiftType': shift.shiftType,
      'startTime': Timestamp.fromDate(shift.startTime),
      'endTime': Timestamp.fromDate(shift.endTime),
      'note': shift.note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// バッチでシフトを追加（自動シフト作成用）
  Future<void> batchAddShifts(List<Shift> shifts) async {
    if (teamId == null || shifts.isEmpty) return;

    // Firestoreのバッチは最大500件まで
    const batchSize = 500;

    for (var i = 0; i < shifts.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < shifts.length) ? i + batchSize : shifts.length;
      final batchShifts = shifts.sublist(i, end);

      for (var shift in batchShifts) {
        final docRef = _firestore
            .collection('teams')
            .doc(teamId)
            .collection('shifts')
            .doc(shift.id);

        batch.set(docRef, {
          'date': Timestamp.fromDate(shift.date),
          'staffId': shift.staffId,
          'shiftType': shift.shiftType,
          'startTime': Timestamp.fromDate(shift.startTime),
          'endTime': Timestamp.fromDate(shift.endTime),
          'note': shift.note,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  /// バッチでシフトを削除（月間削除用）
  Future<void> batchDeleteShifts(List<Shift> shifts) async {
    if (teamId == null || shifts.isEmpty) return;

    const batchSize = 500;

    for (var i = 0; i < shifts.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < shifts.length) ? i + batchSize : shifts.length;
      final batchShifts = shifts.sublist(i, end);

      for (var shift in batchShifts) {
        final docRef = _firestore
            .collection('teams')
            .doc(teamId)
            .collection('shifts')
            .doc(shift.id);

        batch.delete(docRef);
      }

      await batch.commit();
    }
  }

  Future<void> updateShift(Shift shift) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .doc(shift.id)
        .update({
      'date': Timestamp.fromDate(shift.date),
      'staffId': shift.staffId,
      'shiftType': shift.shiftType,
      'startTime': Timestamp.fromDate(shift.startTime),
      'endTime': Timestamp.fromDate(shift.endTime),
      'note': shift.note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteShift(String shiftId) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .doc(shiftId)
        .delete();
  }

  Future<void> addConstraint(ShiftConstraint constraint) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraints')
        .doc(constraint.id)
        .set({
      'staffId': constraint.staffId,
      'date': Timestamp.fromDate(constraint.date),
      'isAvailable': constraint.isAvailable,
      'reason': constraint.reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteConstraint(String constraintId) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraints')
        .doc(constraintId)
        .delete();
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

  /// 指定したスタッフの指定日のシフト一覧を取得
  List<Shift> getShiftsForStaffAndDate(String staffId, DateTime date) {
    return _shifts.where((shift) {
      return shift.staffId == staffId &&
             shift.date.year == date.year &&
             shift.date.month == date.month &&
             shift.date.day == date.day;
    }).toList();
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

  /// データの再読み込み（バックアップ復元後などに使用）
  void reload() {
    _subscribeToShifts();
    _subscribeToConstraints();
  }

  @override
  void dispose() {
    _shiftsSubscription?.cancel();
    _constraintsSubscription?.cancel();
    super.dispose();
  }
}