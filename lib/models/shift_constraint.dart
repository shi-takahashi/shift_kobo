import 'package:hive/hive.dart';

part 'shift_constraint.g.dart';

@HiveType(typeId: 2)
class ShiftConstraint extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String staffId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  bool isAvailable;

  @HiveField(4)
  String? reason;

  @HiveField(5)
  DateTime createdAt;

  ShiftConstraint({
    required this.id,
    required this.staffId,
    required this.date,
    required this.isAvailable,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'date': date.toIso8601String(),
      'isAvailable': isAvailable,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ShiftConstraint.fromJson(Map<String, dynamic> json) {
    return ShiftConstraint(
      id: json['id'],
      staffId: json['staffId'],
      date: DateTime.parse(json['date']),
      isAvailable: json['isAvailable'],
      reason: json['reason'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}