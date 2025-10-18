import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 月間シフト必要人数の管理Provider
class MonthlyRequirementsProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, int> _requirements = {};
  StreamSubscription? _requirementsSubscription;
  bool _isLoading = true;

  Map<String, int> get requirements => _requirements;
  bool get isLoading => _isLoading;

  MonthlyRequirementsProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    _subscribeToRequirements();
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

  /// 月間必要人数を設定（全体を上書き）
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
  }

  /// 特定のシフトタイプの必要人数を取得
  int getRequirement(String shiftType) {
    return _requirements[shiftType] ?? 0;
  }

  /// データの再読み込み
  void reload() {
    _subscribeToRequirements();
  }

  @override
  void dispose() {
    _requirementsSubscription?.cancel();
    super.dispose();
  }
}
