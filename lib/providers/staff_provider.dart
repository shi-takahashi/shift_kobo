import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/staff.dart';

class StaffProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Staff> _staffList = [];
  StreamSubscription? _staffSubscription;

  List<Staff> get staffList => _staffList;
  List<Staff> get activeStaffList => _staffList.where((s) => s.isActive).toList();
  List<Staff> get staff => _staffList;

  StaffProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    // リアルタイム更新を開始
    _subscribeToStaff();
  }

  /// Firestoreからスタッフをリアルタイムで購読
  void _subscribeToStaff() {
    if (teamId == null) return;

    _staffSubscription?.cancel();
    _staffSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .snapshots()
        .listen((snapshot) {
      _staffList = snapshot.docs.map((doc) {
        final data = doc.data();
        return Staff(
          id: doc.id,
          name: data['name'] ?? '',
          phoneNumber: data['phoneNumber'],
          email: data['email'],
          maxShiftsPerMonth: data['maxShiftsPerMonth'] ?? 0,
          preferredDaysOff: List<int>.from(data['preferredDaysOff'] ?? []),
          isActive: data['isActive'] ?? true,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          unavailableShiftTypes: List<String>.from(data['unavailableShiftTypes'] ?? []),
          specificDaysOff: List<String>.from(data['specificDaysOff'] ?? []),
        );
      }).toList();
      notifyListeners();
    });
  }

  Future<void> addStaff(Staff staff) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(staff.id)
        .set({
      'name': staff.name,
      'phoneNumber': staff.phoneNumber,
      'email': staff.email,
      'maxShiftsPerMonth': staff.maxShiftsPerMonth,
      'isActive': staff.isActive,
      'preferredDaysOff': staff.preferredDaysOff,
      'unavailableShiftTypes': staff.unavailableShiftTypes,
      'specificDaysOff': staff.specificDaysOff,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStaff(Staff staff) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(staff.id)
        .update({
      'name': staff.name,
      'phoneNumber': staff.phoneNumber,
      'email': staff.email,
      'maxShiftsPerMonth': staff.maxShiftsPerMonth,
      'isActive': staff.isActive,
      'preferredDaysOff': staff.preferredDaysOff,
      'unavailableShiftTypes': staff.unavailableShiftTypes,
      'specificDaysOff': staff.specificDaysOff,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStaff(String staffId) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(staffId)
        .delete();
  }

  Future<void> toggleStaffStatus(String staffId) async {
    if (teamId == null) return;

    final staff = getStaffById(staffId);
    if (staff != null) {
      staff.isActive = !staff.isActive;
      await updateStaff(staff);
    }
  }

  Staff? getStaffById(String staffId) {
    try {
      return _staffList.firstWhere((staff) => staff.id == staffId);
    } catch (e) {
      return null;
    }
  }

  List<Staff> searchStaff(String query) {
    if (query.isEmpty) return _staffList;

    final lowerQuery = query.toLowerCase();
    return _staffList.where((staff) {
      return staff.name.toLowerCase().contains(lowerQuery) ||
             (staff.email?.toLowerCase().contains(lowerQuery) ?? false) ||
             (staff.phoneNumber?.contains(query) ?? false);
    }).toList();
  }

  /// データの再読み込み（バックアップ復元後などに使用）
  void reload() {
    _subscribeToStaff();
  }

  @override
  void dispose() {
    _staffSubscription?.cancel();
    super.dispose();
  }
}