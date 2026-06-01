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
  DateTime _currentMonth = DateTime.now(); // 現在表示中の月

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

  /// 表示月を変更（カレンダー画面から呼び出される）
  void setCurrentMonth(DateTime month) {
    final newMonth = DateTime(month.year, month.month, 1);
    if (_currentMonth.year != newMonth.year || _currentMonth.month != newMonth.month) {
      _currentMonth = newMonth;
      _subscribeToShifts(); // 月が変わったら再購読
    }
  }

  /// Firestoreからシフトをリアルタイムで購読（表示月±3ヶ月のみ）
  void _subscribeToShifts() {
    if (teamId == null) return;

    // 表示範囲: 現在の月の前後3ヶ月（合計7ヶ月分）
    final startDate = DateTime(_currentMonth.year, _currentMonth.month - 3, 1);
    final endDate = DateTime(_currentMonth.year, _currentMonth.month + 4, 0, 23, 59, 59);

    print('📅 シフト購読範囲: ${startDate.toString().substring(0, 10)} 〜 ${endDate.toString().substring(0, 10)}');

    _shiftsSubscription?.cancel();
    _shiftsSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .listen((snapshot) {
      // 壊れたドキュメントが1件でもあると全体の読み込みが止まり、
      // アプリが永久に「読み込み中」で固まる事故を防ぐため、
      // ドキュメントごとにパースし、失敗した行はスキップする。
      final shifts = <Shift>[];
      for (final doc in snapshot.docs) {
        final shift = _parseShift(doc.id, doc.data());
        if (shift != null) shifts.add(shift);
      }
      _shifts = shifts;

      // 初回ロード完了
      if (_isShiftsLoading) {
        _isShiftsLoading = false;
      }

      notifyListeners();
    }, onError: (error) {
      debugPrint('⚠️ [ShiftProvider] シフト読み込みエラー: $error');
      // エラー時もローディングを必ず解除（永久スピナー防止）
      if (_isShiftsLoading) {
        _isShiftsLoading = false;
        notifyListeners();
      }
    });
  }

  /// シフトドキュメントを安全にパース
  /// 必須フィールド（date/startTime/endTime）が欠損・不正な場合はnullを返してスキップする
  Shift? _parseShift(String id, Map<String, dynamic> data) {
    try {
      final date = data['date'];
      final startTime = data['startTime'];
      final endTime = data['endTime'];
      if (date is! Timestamp || startTime is! Timestamp || endTime is! Timestamp) {
        debugPrint('⚠️ [ShiftProvider] 必須フィールド欠損のシフトをスキップ: $id');
        return null;
      }
      return Shift(
        id: id,
        date: date.toDate(),
        staffId: data['staffId'] ?? '',
        shiftType: data['shiftType'] ?? '',
        startTime: startTime.toDate(),
        endTime: endTime.toDate(),
        note: data['note'],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        assignmentStrategy: data['assignmentStrategy'] as String?,
      );
    } catch (e) {
      debugPrint('⚠️ [ShiftProvider] シフトのパース失敗（スキップ）: $id - $e');
      return null;
    }
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
      // 壊れたドキュメントでアプリが固まらないよう、行ごとにパースしてスキップする
      final constraints = <ShiftConstraint>[];
      for (final doc in snapshot.docs) {
        final constraint = _parseConstraint(doc.id, doc.data());
        if (constraint != null) constraints.add(constraint);
      }
      _constraints = constraints;

      // 初回ロード完了
      if (_isConstraintsLoading) {
        _isConstraintsLoading = false;
      }

      notifyListeners();
    }, onError: (error) {
      debugPrint('⚠️ [ShiftProvider] 制約読み込みエラー: $error');
      if (_isConstraintsLoading) {
        _isConstraintsLoading = false;
        notifyListeners();
      }
    });
  }

  /// 制約ドキュメントを安全にパース（必須のdate欠損時はnullを返してスキップ）
  ShiftConstraint? _parseConstraint(String id, Map<String, dynamic> data) {
    try {
      final date = data['date'];
      if (date is! Timestamp) {
        debugPrint('⚠️ [ShiftProvider] 必須フィールド欠損の制約をスキップ: $id');
        return null;
      }
      return ShiftConstraint(
        id: id,
        staffId: data['staffId'] ?? '',
        date: date.toDate(),
        isAvailable: data['isAvailable'] ?? true,
        reason: data['reason'],
      );
    } catch (e) {
      debugPrint('⚠️ [ShiftProvider] 制約のパース失敗（スキップ）: $id - $e');
      return null;
    }
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
      if (shift.assignmentStrategy != null) 'assignmentStrategy': shift.assignmentStrategy,
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
          if (shift.assignmentStrategy != null) 'assignmentStrategy': shift.assignmentStrategy,
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
      if (shift.assignmentStrategy != null) 'assignmentStrategy': shift.assignmentStrategy,
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

  /// 指定期間内のシフトを取得
  List<Shift> getShiftsInRange(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return _shifts.where((shift) {
      final shiftDate = DateTime(shift.date.year, shift.date.month, shift.date.day);
      return !shiftDate.isBefore(start) && !shiftDate.isAfter(end);
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