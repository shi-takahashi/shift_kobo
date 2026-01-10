import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/shift_lock.dart';

/// シフトの締め（ロック）状態を管理するProvider
class ShiftLockProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, ShiftLock> _locks = {}; // id -> ShiftLock
  StreamSubscription? _lockSubscription;
  bool _isLoading = true;

  Map<String, ShiftLock> get locks => _locks;
  bool get isLoading => _isLoading;

  ShiftLockProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    _subscribeToLocks();
  }

  /// Firestoreからロック状態をリアルタイムで購読
  void _subscribeToLocks() {
    if (teamId == null) return;

    _lockSubscription?.cancel();
    _lockSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shift_locks')
        .snapshots()
        .listen((snapshot) {
      _locks = {};
      for (var doc in snapshot.docs) {
        final lock = ShiftLock.fromMap(doc.data(), doc.id);
        _locks[lock.id] = lock;
      }

      if (_isLoading) {
        _isLoading = false;
      }

      notifyListeners();
    }, onError: (error) {
      debugPrint('⚠️ [ShiftLockProvider] データ読み込みエラー: $error');
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// 指定した年月のロック状態を取得
  ShiftLock? getLock(int year, int month) {
    final id = ShiftLock.generateId(year, month);
    return _locks[id];
  }

  /// 指定した年月がロックされているかどうか
  bool isLocked(int year, int month) {
    final lock = getLock(year, month);
    return lock?.isLocked ?? false;
  }

  /// シフトをロック（締める）
  Future<void> lockShift(int year, int month, String userId) async {
    if (teamId == null) return;

    final id = ShiftLock.generateId(year, month);
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shift_locks')
        .doc(id)
        .set({
      'isLocked': true,
      'lockedAt': FieldValue.serverTimestamp(),
      'lockedBy': userId,
    });
  }

  /// シフトをロック解除
  Future<void> unlockShift(int year, int month, String userId) async {
    if (teamId == null) return;

    final id = ShiftLock.generateId(year, month);
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('shift_locks')
        .doc(id)
        .set({
      'isLocked': false,
      'lockedAt': FieldValue.serverTimestamp(),
      'lockedBy': userId,
    });
  }

  @override
  void dispose() {
    _lockSubscription?.cancel();
    super.dispose();
  }
}
