import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shift_time_setting.dart';

class ShiftTimeProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ShiftTimeSetting> _settings = [];
  StreamSubscription? _settingsSubscription;
  final Map<ShiftType, String> _docIds = {}; // ShiftType -> Firestore Document ID
  bool _isLoading = true;

  ShiftTimeProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  bool get isLoading => _isLoading;

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

  void _init() {
    _subscribeToSettings();
  }

  /// Firestoreからシフト時間設定をリアルタイムで購読
  void _subscribeToSettings() {
    if (teamId == null) return;

    _settingsSubscription?.cancel();
    _settingsSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shift_time_settings')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) {
        // デフォルト設定を作成
        await _createDefaultSettings();
      } else {
        _settings = snapshot.docs.map((doc) {
          final data = doc.data();
          final shiftType = ShiftType.values[data['shiftType'] as int];
          _docIds[shiftType] = doc.id;
          return ShiftTimeSetting(
            shiftType: shiftType,
            customName: data['customName'] ?? '',
            startTime: data['startTime'] ?? '',
            endTime: data['endTime'] ?? '',
            isActive: data['isActive'] ?? true,
          );
        }).toList();

        // 初回ロード完了
        if (_isLoading) {
          _isLoading = false;
        }

        notifyListeners();
      }
    });
  }

  Future<void> _createDefaultSettings() async {
    if (teamId == null) return;

    final defaultSettings = ShiftTimeSetting.getDefaultSettings();
    final batch = _firestore.batch();

    for (final setting in defaultSettings) {
      final docRef = _firestore
          .collection('teams')
          .doc(teamId)
          .collection('shift_time_settings')
          .doc();

      batch.set(docRef, {
        'shiftType': setting.shiftType.index,
        'customName': setting.customName,
        'startTime': setting.startTime,
        'endTime': setting.endTime,
        'isActive': setting.isActive,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> updateShiftTime(ShiftType shiftType, String startTime, String endTime) async {
    if (teamId == null) return;

    final docId = _docIds[shiftType];
    if (docId != null) {
      await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('shift_time_settings')
          .doc(docId)
          .update({
        'startTime': startTime,
        'endTime': endTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateShiftName(ShiftType shiftType, String newName) async {
    if (teamId == null) return;

    final docId = _docIds[shiftType];
    if (docId != null) {
      await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('shift_time_settings')
          .doc(docId)
          .update({
        'customName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> toggleShiftTypeActive(ShiftType shiftType) async {
    if (teamId == null) return;

    final docId = _docIds[shiftType];
    if (docId != null) {
      final setting = getSettingByType(shiftType);
      if (setting != null) {
        await _firestore
            .collection('teams')
            .doc(teamId)
            .collection('shift_time_settings')
            .doc(docId)
            .update({
          'isActive': !setting.isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
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
    _subscribeToSettings();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }
}