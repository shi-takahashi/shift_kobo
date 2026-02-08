import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/analytics_service.dart';

/// 月間シフト必要人数の管理Provider
///
/// 優先順位: 日付個別設定 > 曜日別設定 > 基本設定
class MonthlyRequirementsProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 基本設定（全日共通）
  Map<String, int> _requirements = {};

  // 曜日別設定（1=月曜〜7=日曜）
  bool _useWeekdaySettings = false;
  Map<int, Map<String, int>> _weekdayRequirements = {};

  // 日付個別設定（キー: ISO8601形式の日付文字列）
  Map<String, Map<String, int>> _dateRequirements = {};

  StreamSubscription? _requirementsSubscription;
  StreamSubscription? _weekdaySubscription;
  StreamSubscription? _dateSubscription;
  bool _isLoading = true;

  Map<String, int> get requirements => _requirements;
  bool get isLoading => _isLoading;
  bool get useWeekdaySettings => _useWeekdaySettings;
  Map<int, Map<String, int>> get weekdayRequirements => _weekdayRequirements;
  Map<String, Map<String, int>> get dateRequirements => _dateRequirements;

  MonthlyRequirementsProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    _subscribeToRequirements();
    _subscribeToWeekdayRequirements();
    _subscribeToDateRequirements();
  }

  /// Firestoreから月間必要人数をリアルタイムで購読
  void _subscribeToRequirements() {
    if (teamId == null) return;

    _requirementsSubscription?.cancel();
    _requirementsSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('monthly_requirements')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          _requirements = Map<String, int>.from(
            data..remove('updatedAt'), // タイムスタンプを除外
          );
        }
      } else {
        // ドキュメントが存在しない場合は空のマップ
        _requirements = {};
      }

      // 初回ロード完了
      if (_isLoading) {
        _isLoading = false;
      }

      notifyListeners();
    });
  }

  /// 曜日別設定をリアルタイムで購読
  void _subscribeToWeekdayRequirements() {
    if (teamId == null) return;

    _weekdaySubscription?.cancel();
    _weekdaySubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('weekday_requirements')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          _useWeekdaySettings = data['enabled'] ?? false;

          // 曜日ごとの設定を読み込み
          _weekdayRequirements = {};
          for (int weekday = 1; weekday <= 7; weekday++) {
            final weekdayData = data['weekday_$weekday'];
            if (weekdayData != null && weekdayData is Map) {
              _weekdayRequirements[weekday] = Map<String, int>.from(
                (weekdayData as Map).map((key, value) =>
                    MapEntry(key.toString(), value is int ? value : 0)),
              );
            }
          }
        }
      } else {
        _useWeekdaySettings = false;
        _weekdayRequirements = {};
      }

      notifyListeners();
    });
  }

  /// 日付個別設定をリアルタイムで購読
  void _subscribeToDateRequirements() {
    if (teamId == null) return;

    _dateSubscription?.cancel();
    _dateSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('date_requirements')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          _dateRequirements = {};
          data.forEach((key, value) {
            if (key != 'updatedAt' && value is Map) {
              _dateRequirements[key] = Map<String, int>.from(
                value.map((k, v) => MapEntry(k.toString(), v is int ? v : 0)),
              );
            }
          });
        }
      } else {
        _dateRequirements = {};
      }

      notifyListeners();
    });
  }

  /// 基本設定（全日共通）を保存
  Future<void> setRequirements(Map<String, int> requirements) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('monthly_requirements')
        .set({
      ...requirements,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ファネル分析用イベント送信（失敗しても設定保存には影響しない）
    try {
      final totalRequired = requirements.values.fold(0, (acc, v) => acc + v);
      await AnalyticsService.logRequirementSet(
        totalShiftTypes: requirements.length,
        totalRequired: totalRequired,
      );
    } catch (e) {
      debugPrint('⚠️ Analytics送信エラー（無視）: $e');
    }
  }

  /// 曜日別設定を保存
  Future<void> setWeekdayRequirements({
    required bool enabled,
    required Map<int, Map<String, int>> weekdaySettings,
  }) async {
    if (teamId == null) return;

    final data = <String, dynamic>{
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (var entry in weekdaySettings.entries) {
      data['weekday_${entry.key}'] = entry.value;
    }

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('weekday_requirements')
        .set(data);
  }

  /// 曜日別設定の有効/無効を切り替え
  Future<void> setUseWeekdaySettings(bool enabled) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('weekday_requirements')
        .set({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 特定の曜日の設定を保存
  Future<void> setWeekdayRequirement(int weekday, Map<String, int> requirements) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('weekday_requirements')
        .set({
      'weekday_$weekday': requirements,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 日付個別設定を追加/更新
  Future<void> setDateRequirement(String dateKey, Map<String, int> requirements) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('settings')
        .doc('date_requirements')
        .set({
      dateKey: requirements,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 日付個別設定を削除
  Future<void> removeDateRequirement(String dateKey) async {
    if (teamId == null) return;

    try {
      final docRef = _firestore
          .collection('teams')
          .doc(teamId)
          .collection('settings')
          .doc('date_requirements');

      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({
          dateKey: FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // ドキュメントが存在しない場合は無視
    }
  }

  /// 基本設定から特定のシフトタイプの必要人数を取得
  int getRequirement(String shiftType) {
    return _requirements[shiftType] ?? 0;
  }

  /// 基本設定に特定のシフトタイプが設定されているかどうか
  bool hasRequirement(String shiftType) {
    return _requirements.containsKey(shiftType);
  }

  /// 特定の日付に対する有効な必要人数を取得
  /// 優先順位: 日付個別設定 > 曜日別設定 > 基本設定
  Map<String, int> getRequirementsForDate(DateTime date) {
    // 日付個別設定をチェック
    final dateKey = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    if (_dateRequirements.containsKey(dateKey)) {
      return _dateRequirements[dateKey]!;
    }

    // 曜日別設定をチェック
    if (_useWeekdaySettings && _weekdayRequirements.containsKey(date.weekday)) {
      return _weekdayRequirements[date.weekday]!;
    }

    // 基本設定を返す
    return _requirements;
  }

  /// 特定の曜日に個別設定があるかどうか
  bool hasWeekdayOverride(int weekday) {
    return _weekdayRequirements.containsKey(weekday) &&
           _weekdayRequirements[weekday]!.isNotEmpty;
  }

  /// 特定の日付に個別設定があるかどうか
  bool hasDateOverride(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    return _dateRequirements.containsKey(dateKey);
  }

  /// データの再読み込み
  void reload() {
    _subscribeToRequirements();
    _subscribeToWeekdayRequirements();
    _subscribeToDateRequirements();
  }

  @override
  void dispose() {
    _requirementsSubscription?.cancel();
    _weekdaySubscription?.cancel();
    _dateSubscription?.cancel();
    super.dispose();
  }
}
