import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/staff.dart';

class StaffProvider extends ChangeNotifier {
  late Box<Staff> _staffBox;
  List<Staff> _staffList = [];

  List<Staff> get staffList => _staffList;
  List<Staff> get activeStaffList => _staffList.where((s) => s.isActive).toList();

  StaffProvider() {
    _init();
  }

  Future<void> _init() async {
    _staffBox = Hive.box<Staff>('staff');
    _loadStaff();
  }

  void _loadStaff() {
    _staffList = _staffBox.values.toList();
    notifyListeners();
  }

  Future<void> addStaff(Staff staff) async {
    await _staffBox.put(staff.id, staff);
    _loadStaff();
  }

  Future<void> updateStaff(Staff staff) async {
    staff.updatedAt = DateTime.now();
    await staff.save();
    _loadStaff();
  }

  Future<void> deleteStaff(String staffId) async {
    final staff = _staffBox.get(staffId);
    if (staff != null) {
      await staff.delete();
      _loadStaff();
    }
  }

  Future<void> toggleStaffStatus(String staffId) async {
    final staff = _staffBox.get(staffId);
    if (staff != null) {
      staff.isActive = !staff.isActive;
      staff.updatedAt = DateTime.now();
      await staff.save();
      _loadStaff();
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
}