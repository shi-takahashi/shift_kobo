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

      // 有効なシフト: 開始時間順 → 終了時間順
      if (a.isActive) {
        final aStart = _timeToMinutes(a.startTime);
        final bStart = _timeToMinutes(b.startTime);
        if (aStart != bStart) {
          return aStart.compareTo(bStart);
        }
        final aEnd = _timeToMinutes(a.endTime);
        final bEnd = _timeToMinutes(b.endTime);
        return aEnd.compareTo(bEnd);
      }

      // 無効なシフト: シフト名順
      return a.displayName.compareTo(b.displayName);
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
        .listen(
      (snapshot) async {
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
      },
      onError: (error) {
        // チーム削除後の権限エラーを無視
        if (error.toString().contains('permission-denied')) {
          print('⚠️ ShiftTimeProvider: チーム削除後のアクセスエラーを無視');
          return;
        }
        print('❌ ShiftTimeProvider エラー: $error');
      },
    );
  }

  Future<void> _createDefaultSettings() async {
    if (teamId == null) return;

    // チームドキュメントが存在するか確認
    // 削除処理中の場合、チームドキュメントは存在しないため自動作成しない
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) {
      print('⚠️ チームドキュメントが存在しないため、デフォルト設定を作成しません');
      return;
    }

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

  /// 指定された名前が他の有効なシフトタイプと重複しているかチェック
  /// [name] チェックする名前
  /// [excludeShiftType] 除外するシフトタイプ（自分自身）
  /// 戻り値: 有効なシフトタイプと重複している場合true
  bool isNameDuplicate(String name, ShiftType excludeShiftType) {
    return _settings.any((setting) =>
        setting.shiftType != excludeShiftType &&
        setting.isActive &&
        setting.displayName == name);
  }

  /// 表示名からシフト設定を取得
  ShiftTimeSetting? getSettingByDisplayName(String displayName) {
    try {
      return _settings.firstWhere((s) => s.displayName == displayName);
    } catch (e) {
      return null;
    }
  }

  /// 2つのシフトタイプ（表示名）の時間が重複するかチェック
  /// 夜勤などの日をまたぐシフトも正しく処理
  /// 注意: これはシフトタイプのデフォルト時間でチェックする。
  /// 個別シフトの実際の時間でチェックする場合は doShiftTimesOverlap を使用
  bool doShiftsOverlap(String shiftType1, String shiftType2) {
    final setting1 = getSettingByDisplayName(shiftType1);
    final setting2 = getSettingByDisplayName(shiftType2);

    if (setting1 == null || setting2 == null) {
      // 設定が見つからない場合は重複とみなす（安全側に倒す）
      return true;
    }

    return _doTimeRangesOverlap(
      setting1.startTime,
      setting1.endTime,
      setting2.startTime,
      setting2.endTime,
    );
  }

  /// 2つのシフトの実際の時間が重複するかチェック
  /// 個別シフトに設定された startTime/endTime を使用
  bool doShiftTimesOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    // DateTime から時間文字列に変換
    final s1 = '${start1.hour.toString().padLeft(2, '0')}:${start1.minute.toString().padLeft(2, '0')}';
    final e1 = '${end1.hour.toString().padLeft(2, '0')}:${end1.minute.toString().padLeft(2, '0')}';
    final s2 = '${start2.hour.toString().padLeft(2, '0')}:${start2.minute.toString().padLeft(2, '0')}';
    final e2 = '${end2.hour.toString().padLeft(2, '0')}:${end2.minute.toString().padLeft(2, '0')}';

    return _doTimeRangesOverlap(s1, e1, s2, e2);
  }

  /// 2つの時間範囲が重複するかチェック
  /// 夜勤などの日をまたぐシフト（endTime < startTime）も正しく処理
  bool _doTimeRangesOverlap(
    String start1,
    String end1,
    String start2,
    String end2,
  ) {
    final s1 = _timeToMinutes(start1);
    final e1 = _timeToMinutes(end1);
    final s2 = _timeToMinutes(start2);
    final e2 = _timeToMinutes(end2);

    // 日をまたぐかどうかを判定
    final crossesMidnight1 = e1 <= s1;
    final crossesMidnight2 = e2 <= s2;

    if (!crossesMidnight1 && !crossesMidnight2) {
      // 両方とも日をまたがない通常のシフト
      // 重複条件: s1 < e2 && s2 < e1
      return s1 < e2 && s2 < e1;
    } else if (crossesMidnight1 && crossesMidnight2) {
      // 両方とも日をまたぐ場合は常に重複
      return true;
    } else {
      // 一方だけが日をまたぐ場合
      // 日をまたぐシフトを2つの区間に分割して考える
      if (crossesMidnight1) {
        // shift1が日をまたぐ: [s1, 24:00) と [0:00, e1)
        // shift2との重複をチェック
        return (s1 < 1440 && s2 < 1440 && s1 < e2) || // s1-24:00 と s2-e2の重複
            (s2 < e1); // 0:00-e1 と s2-e2の重複
      } else {
        // shift2が日をまたぐ: [s2, 24:00) と [0:00, e2)
        return (s2 < 1440 && s1 < 1440 && s2 < e1) || // s2-24:00 と s1-e1の重複
            (s1 < e2); // 0:00-e2 と s1-e1の重複
      }
    }
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