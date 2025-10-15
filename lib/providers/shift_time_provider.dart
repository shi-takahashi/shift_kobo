import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/shift_time_setting.dart';

class ShiftTimeProvider extends ChangeNotifier {
  static const String _boxName = 'shift_time_settings';
  Box<ShiftTimeSetting>? _box;
  List<ShiftTimeSetting> _settings = [];

  List<ShiftTimeSetting> get settings {
    final sorted = List<ShiftTimeSetting>.from(_settings);
    sorted.sort((a, b) {
      // 1. 有効/無効順（有効が上）
      if (a.isActive != b.isActive) {
        return b.isActive ? 1 : -1;
      }
      
      // 2. 開始時間順
      final aStart = _timeToMinutes(a.startTime);
      final bStart = _timeToMinutes(b.startTime);
      if (aStart != bStart) {
        return aStart.compareTo(bStart);
      }
      
      // 3. 終了時間順
      final aEnd = _timeToMinutes(a.endTime);
      final bEnd = _timeToMinutes(b.endTime);
      return aEnd.compareTo(bEnd);
    });
    return sorted;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  Future<void> initialize() async {
    _box = await Hive.openBox<ShiftTimeSetting>(_boxName);
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_box == null) return;

    if (_box!.isEmpty) {
      await _createDefaultSettings();
    } else {
      _settings = _box!.values.toList();
    }
    notifyListeners();
  }

  Future<void> _createDefaultSettings() async {
    final defaultSettings = ShiftTimeSetting.getDefaultSettings();
    for (final setting in defaultSettings) {
      await _box!.add(setting);
    }
    // ボックスに保存された後、ボックスから取得し直す
    _settings = _box!.values.toList();
  }

  Future<void> updateShiftTime(ShiftType shiftType, String startTime, String endTime) async {
    if (_box == null) return;

    final index = _settings.indexWhere((s) => s.shiftType == shiftType);
    if (index >= 0) {
      final setting = _settings[index];
      if (setting.isInBox) {
        setting.startTime = startTime;
        setting.endTime = endTime;
        await setting.save();
      } else {
        // オブジェクトがボックスにない場合は、新しく作成して追加
        final newSetting = ShiftTimeSetting(
          shiftType: shiftType,
          startTime: startTime,
          endTime: endTime,
          isActive: setting.isActive,
          customName: setting.customName,
        );
        await _box!.add(newSetting);
        _settings = _box!.values.toList();
      }
    }
    notifyListeners();
  }

  Future<void> updateShiftName(ShiftType shiftType, String newName) async {
    if (_box == null) return;

    final index = _settings.indexWhere((s) => s.shiftType == shiftType);
    if (index >= 0) {
      final setting = _settings[index];
      if (setting.isInBox) {
        setting.customName = newName;
        await setting.save();
      } else {
        // オブジェクトがボックスにない場合は、新しく作成して追加
        final newSetting = ShiftTimeSetting(
          shiftType: shiftType,
          startTime: setting.startTime,
          endTime: setting.endTime,
          isActive: setting.isActive,
          customName: newName,
        );
        await _box!.add(newSetting);
        _settings = _box!.values.toList();
      }
    }
    notifyListeners();
  }

  Future<void> toggleShiftTypeActive(ShiftType shiftType) async {
    if (_box == null) return;

    final index = _settings.indexWhere((s) => s.shiftType == shiftType);
    if (index >= 0) {
      final setting = _settings[index];
      if (setting.isInBox) {
        setting.isActive = !setting.isActive;
        await setting.save();
      } else {
        // オブジェクトがボックスにない場合は、新しく作成して追加
        final newSetting = ShiftTimeSetting(
          shiftType: shiftType,
          startTime: setting.startTime,
          endTime: setting.endTime,
          isActive: !setting.isActive,
          customName: setting.customName,
        );
        await _box!.add(newSetting);
        _settings = _box!.values.toList();
      }
    }
    notifyListeners();
  }

  ShiftTimeSetting? getSettingByType(ShiftType shiftType) {
    try {
      return _settings.firstWhere((s) => s.shiftType == shiftType);
    } catch (e) {
      return null;
    }
  }

  List<ShiftType> getActiveShiftTypes() {
    return _settings.where((s) => s.isActive).map((s) => s.shiftType).toList();
  }

  String getTimeRange(ShiftType shiftType) {
    final setting = getSettingByType(shiftType);
    return setting?.timeRange ?? '';
  }

  /// データの再読み込み（バックアップ復元後などに使用）
  Future<void> reload() async {
    await _loadSettings();
  }
}