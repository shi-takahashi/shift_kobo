import 'package:hive/hive.dart';

part 'shift.g.dart';

@HiveType(typeId: 1)
class Shift extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String staffId;

  @HiveField(3)
  String shiftType;

  @HiveField(4)
  DateTime startTime;

  @HiveField(5)
  DateTime endTime;

  @HiveField(6)
  String? note;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? updatedAt;

  @HiveField(9)
  String? assignmentStrategy;

  Shift({
    required this.id,
    required this.date,
    required this.staffId,
    required this.shiftType,
    required this.startTime,
    required this.endTime,
    this.note,
    DateTime? createdAt,
    this.updatedAt,
    this.assignmentStrategy,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'staffId': staffId,
      'shiftType': shiftType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (assignmentStrategy != null) 'assignmentStrategy': assignmentStrategy,
    };
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      date: DateTime.parse(json['date']),
      staffId: json['staffId'],
      shiftType: json['shiftType'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      note: json['note'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      assignmentStrategy: json['assignmentStrategy'] as String?,
    );
  }

  Duration get duration => endTime.difference(startTime);
}