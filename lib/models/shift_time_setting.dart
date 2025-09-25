import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'shift_time_setting.g.dart';

@HiveType(typeId: 4)
enum ShiftType {
  @HiveField(0)
  shift1,
  @HiveField(1)
  shift2,
  @HiveField(2)
  shift3,
  @HiveField(3)
  shift4,
  @HiveField(4)
  shift5,
  @HiveField(5)
  shift6,
  @HiveField(6)
  shift7,
  @HiveField(7)
  shift8,
  @HiveField(8)
  shift9,
  @HiveField(9)
  shift10,
}

extension ShiftTypeExtension on ShiftType {
  String get defaultName {
    switch (this) {
      case ShiftType.shift1:
        return '早番';
      case ShiftType.shift2:
        return '日勤';
      case ShiftType.shift3:
        return '遅番';
      case ShiftType.shift4:
        return '夜勤';
      case ShiftType.shift5:
        return '未使用';
      case ShiftType.shift6:
        return '未使用';
      case ShiftType.shift7:
        return '未使用';
      case ShiftType.shift8:
        return '未使用';
      case ShiftType.shift9:
        return '未使用';
      case ShiftType.shift10:
        return '未使用';
    }
  }

  IconData get icon {
    return Icons.work_outline;
  }

  Color get color {
    switch (this) {
      case ShiftType.shift1:
        return Colors.orange;
      case ShiftType.shift2:
        return Colors.blue;
      case ShiftType.shift3:
        return Colors.purple;
      case ShiftType.shift4:
        return Colors.indigo;
      case ShiftType.shift5:
        return Colors.teal;
      case ShiftType.shift6:
        return Colors.teal;
      case ShiftType.shift7:
        return Colors.brown;
      case ShiftType.shift8:
        return Colors.pink;
      case ShiftType.shift9:
        return Colors.cyan;
      case ShiftType.shift10:
        return Colors.amber;
    }
  }
}

@HiveType(typeId: 5)
class ShiftTimeSetting extends HiveObject {
  @HiveField(0)
  ShiftType shiftType;

  @HiveField(1)
  String startTime;

  @HiveField(2)
  String endTime;

  @HiveField(3)
  bool isActive;

  @HiveField(4)
  String customName;

  ShiftTimeSetting({
    required this.shiftType,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    String? customName,
  }) : customName = customName ?? shiftType.defaultName;

  static List<ShiftTimeSetting> getDefaultSettings() {
    return [
      ShiftTimeSetting(
        shiftType: ShiftType.shift1,
        startTime: '06:00',
        endTime: '14:00',
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift2,
        startTime: '08:00',
        endTime: '17:00',
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift3,
        startTime: '14:00',
        endTime: '22:00',
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift4,
        startTime: '22:00',
        endTime: '06:00',
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift5,
        startTime: '10:00',
        endTime: '16:00',
        isActive: false,
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift6,
        startTime: '12:00',
        endTime: '20:00',
        isActive: false,
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift7,
        startTime: '07:00',
        endTime: '15:00',
        isActive: false,
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift8,
        startTime: '16:00',
        endTime: '24:00',
        isActive: false,
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift9,
        startTime: '00:00',
        endTime: '08:00',
        isActive: false,
      ),
      ShiftTimeSetting(
        shiftType: ShiftType.shift10,
        startTime: '09:00',
        endTime: '18:00',
        isActive: false,
      ),
    ];
  }

  String get displayName => customName;
  String get timeRange => '$startTime - $endTime';

  @override
  String toString() {
    return 'ShiftTimeSetting(shiftType: $shiftType, startTime: $startTime, endTime: $endTime, isActive: $isActive)';
  }
}