import 'package:hive/hive.dart';
import 'shift_constraint.dart';

part 'staff.g.dart';

@HiveType(typeId: 0)
class Staff extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? phoneNumber;

  @HiveField(3)
  String? email;

  @HiveField(4)
  int maxShiftsPerMonth;

  @HiveField(5)
  List<int> preferredDaysOff;

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? updatedAt;

  @HiveField(9)
  List<ShiftConstraint> constraints = [];

  @HiveField(10)
  List<String> unavailableShiftTypes = [];

  Staff({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
    required this.maxShiftsPerMonth,
    List<int>? preferredDaysOff,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    List<ShiftConstraint>? constraints,
    List<String>? unavailableShiftTypes,
  })  : preferredDaysOff = preferredDaysOff ?? [],
        createdAt = createdAt ?? DateTime.now() {
    this.constraints = constraints ?? [];
    this.unavailableShiftTypes = unavailableShiftTypes ?? [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'maxShiftsPerMonth': maxShiftsPerMonth,
      'preferredDaysOff': preferredDaysOff,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      maxShiftsPerMonth: json['maxShiftsPerMonth'],
      preferredDaysOff: List<int>.from(json['preferredDaysOff'] ?? []),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}