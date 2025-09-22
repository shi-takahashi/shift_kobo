import 'package:flutter/material.dart';

class ShiftType {
  static const String morning = '早番';
  static const String day = '日勤';
  static const String evening = '遅番';
  static const String night = '夜勤';
  static const String fullDay = '終日';

  static const List<String> all = [
    morning,
    day,
    evening,
    night,
    fullDay,
  ];

  static Map<String, ShiftTimeRange> defaultTimeRanges = {
    morning: ShiftTimeRange(
      startHour: 6,
      startMinute: 0,
      endHour: 14,
      endMinute: 0,
    ),
    day: ShiftTimeRange(
      startHour: 9,
      startMinute: 0,
      endHour: 17,
      endMinute: 0,
    ),
    evening: ShiftTimeRange(
      startHour: 14,
      startMinute: 0,
      endHour: 22,
      endMinute: 0,
    ),
    night: ShiftTimeRange(
      startHour: 22,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
    ),
    fullDay: ShiftTimeRange(
      startHour: 9,
      startMinute: 0,
      endHour: 21,
      endMinute: 0,
    ),
  };

  static Map<String, Color> colors = {
    morning: Colors.orange,
    day: Colors.blue,
    evening: Colors.purple,
    night: Colors.indigo,
    fullDay: Colors.green,
  };

  static Color getColor(String shiftType) {
    return colors[shiftType] ?? Colors.grey;
  }
}

class ShiftTimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  ShiftTimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  DateTime toStartDateTime(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startHour,
      startMinute,
    );
  }

  DateTime toEndDateTime(DateTime date) {
    DateTime endDate = DateTime(
      date.year,
      date.month,
      date.day,
      endHour,
      endMinute,
    );
    
    if (endHour < startHour) {
      endDate = endDate.add(const Duration(days: 1));
    }
    
    return endDate;
  }
}