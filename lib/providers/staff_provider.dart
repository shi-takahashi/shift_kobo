import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/staff.dart';

class StaffProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Staff> _staffList = [];
  StreamSubscription? _staffSubscription;
  bool _isLoading = true;

  List<Staff> get staffList => _staffList;
  List<Staff> get activeStaffList => _staffList.where((s) => s.isActive).toList();
  List<Staff> get staff => _staffList;
  bool get isLoading => _isLoading;

  StaffProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    // リアルタイム更新を開始
    _subscribeToStaff();
  }

  /// Firestoreからスタッフをリアルタイムで購読
  void _subscribeToStaff() {
    if (teamId == null) return;

    _staffSubscription?.cancel();
    _staffSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .snapshots()
        .listen((snapshot) {
      _staffList = snapshot.docs.map((doc) {
        final data = doc.data();
        return Staff(
          id: doc.id,
          name: data['name'] ?? '',
          phoneNumber: data['phoneNumber'],
          email: data['email'],
          maxShiftsPerMonth: data['maxShiftsPerMonth'] ?? 0,
          preferredDaysOff: List<int>.from(data['preferredDaysOff'] ?? []),
          isActive: data['isActive'] ?? true,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          unavailableShiftTypes: List<String>.from(data['unavailableShiftTypes'] ?? []),
          specificDaysOff: List<String>.from(data['specificDaysOff'] ?? []),
          userId: data['userId'],
        );
      }).toList();

      // 初回ロード完了
      if (_isLoading) {
        _isLoading = false;
      }

      notifyListeners();
    });
  }

  Future<void> addStaff(Staff staff) async {
    if (teamId == null) return;

    final data = <String, dynamic>{
      'name': staff.name,
      'phoneNumber': staff.phoneNumber,
      'email': staff.email,
      'maxShiftsPerMonth': staff.maxShiftsPerMonth,
      'isActive': staff.isActive,
      'preferredDaysOff': staff.preferredDaysOff,
      'unavailableShiftTypes': staff.unavailableShiftTypes,
      'specificDaysOff': staff.specificDaysOff,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // userIdがnullでない場合のみ設定（nullの場合はフィールド自体を設定しない）
    if (staff.userId != null) {
      data['userId'] = staff.userId;
    }

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(staff.id)
        .set(data);

    // メールアドレスが設定されている場合、自動紐付けを試行
    if (staff.email != null && staff.email!.isNotEmpty) {
      await _tryAutoLinkByEmail(staff.id, staff.email!);
    }
  }

  Future<void> updateStaff(Staff staff) async {
    if (teamId == null) return;

    final data = <String, dynamic>{
      'name': staff.name,
      'phoneNumber': staff.phoneNumber,
      'email': staff.email,
      'maxShiftsPerMonth': staff.maxShiftsPerMonth,
      'isActive': staff.isActive,
      'preferredDaysOff': staff.preferredDaysOff,
      'unavailableShiftTypes': staff.unavailableShiftTypes,
      'specificDaysOff': staff.specificDaysOff,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // userIdがnullでない場合のみ設定
    if (staff.userId != null) {
      data['userId'] = staff.userId;
    }

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(staff.id)
        .update(data);

    // メールアドレスが設定されている場合、自動紐付けを試行
    if (staff.email != null && staff.email!.isNotEmpty) {
      await _tryAutoLinkByEmail(staff.id, staff.email!);
    }
  }

  /// メールアドレスでユーザーと自動紐付けを試行
  Future<void> _tryAutoLinkByEmail(String staffId, String email) async {
    if (teamId == null) return;

    try {
      // 1. チームスタッフから同じメールアドレスのユーザーを検索
      final usersQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('teamId', isEqualTo: teamId)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        // 2. 一致するユーザーが見つかった場合、userIdを設定
        final userId = usersQuery.docs.first.id;
        await _firestore
            .collection('teams')
            .doc(teamId)
            .collection('staff')
            .doc(staffId)
            .update({
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ スタッフ手動紐付け成功: $email <-> $userId');
      } else {
        print('ℹ️ スタッフ手動紐付けスキップ: メールアドレス $email に一致するチームスタッフが見つかりません');
      }
    } catch (e) {
      // 紐付け失敗してもスタッフ更新は成功扱い（エラーを投げない）
      print('⚠️ スタッフ手動紐付けエラー: $e');
    }
  }

  Future<void> deleteStaff(String staffId) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(staffId)
        .delete();
  }

  Future<void> toggleStaffStatus(String staffId) async {
    if (teamId == null) return;

    final staff = getStaffById(staffId);
    if (staff != null) {
      staff.isActive = !staff.isActive;
      await updateStaff(staff);
    }
  }

  Staff? getStaffById(String staffId) {
    try {
      return _staffList.firstWhere((staff) => staff.id == staffId);
    } catch (e) {
      return null;
    }
  }

  List<Staff> searchStaff(String query) {
    if (query.isEmpty) return _staffList;

    final lowerQuery = query.toLowerCase();
    return _staffList.where((staff) {
      return staff.name.toLowerCase().contains(lowerQuery) ||
             (staff.email?.toLowerCase().contains(lowerQuery) ?? false) ||
             (staff.phoneNumber?.contains(query) ?? false);
    }).toList();
  }

  /// スタッフのユーザー紐付けを解除（アカウント削除時に使用）
  Future<void> unlinkStaffUser(String staffId) async {
    if (teamId == null) return;

    try {
      await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .doc(staffId)
          .update({
        'userId': FieldValue.delete(),  // フィールド自体を削除
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ スタッフ紐付け解除成功: $staffId');
    } catch (e) {
      print('⚠️ スタッフ紐付け解除エラー: $e');
      rethrow;
    }
  }

  /// スタッフをアカウントごと削除（管理者専用）
  ///
  /// 紐付け済みスタッフの場合、以下を削除します：
  /// 1. constraint_requests/ サブコレクション（申請データ）
  /// 2. users/{userId} ドキュメント
  /// 3. Firebase Authentication（Cloud Functions経由）
  /// 4. staffs/{staffId} ドキュメント
  ///
  /// 紐付けなしスタッフの場合、staffs/{staffId} のみ削除します。
  Future<void> deleteStaffWithAccount(
    String staffId, {
    required Function(String) deleteRequestsByStaffId,
    required Function(String) deleteStaffAccount,
  }) async {
    if (teamId == null) {
      throw 'チーム情報が見つかりません';
    }

    try {
      // スタッフ情報を取得
      final staff = getStaffById(staffId);
      if (staff == null) {
        throw 'スタッフ情報が見つかりません';
      }

      final userId = staff.userId;

      if (userId != null) {
        // 紐付け済みスタッフの場合
        print('🗑️ スタッフアカウント削除開始（アカウント付き）: $staffId, userId: $userId');

        // 1. constraint_requests/ 削除（ConstraintRequestProvider経由）
        await deleteRequestsByStaffId(staffId);
        print('✅ constraint_requests削除完了: $staffId');

        // 2. Authentication削除（AuthService経由、Cloud Functions）
        // 注意: users/{userId} を削除する前に Authentication を削除する
        await deleteStaffAccount(userId);
        print('✅ Authentication削除完了: $userId');

        // 3. users/{userId} 削除
        await _firestore.collection('users').doc(userId).delete();
        print('✅ usersドキュメント削除完了: $userId');

        // 4. staffs/{staffId} 削除
        await deleteStaff(staffId);
        print('✅ staffドキュメント削除完了: $staffId');
      } else {
        // 紐付けなしスタッフの場合、スタッフデータのみ削除
        print('🗑️ スタッフデータ削除開始（アカウントなし）: $staffId');
        await deleteStaff(staffId);
        print('✅ staffドキュメント削除完了: $staffId');
      }

      print('✅ スタッフ削除完了: $staffId');
    } catch (e) {
      print('❌ スタッフ削除エラー: $staffId, $e');
      rethrow;
    }
  }

  /// データの再読み込み（バックアップ復元後などに使用）
  void reload() {
    _subscribeToStaff();
  }

  @override
  void dispose() {
    _staffSubscription?.cancel();
    super.dispose();
  }
}