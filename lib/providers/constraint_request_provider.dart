import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/constraint_request.dart';
import '../models/staff.dart';

/// 制約承認リクエストを管理するProvider
class ConstraintRequestProvider extends ChangeNotifier {
  final String? teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ConstraintRequest> _requests = [];
  StreamSubscription? _requestSubscription;
  bool _isLoading = true;

  List<ConstraintRequest> get requests => _requests;
  bool get isLoading => _isLoading;

  /// 承認待ちのリクエストのみ取得
  List<ConstraintRequest> get pendingRequests =>
      _requests.where((r) => r.status == ConstraintRequest.statusPending).toList();

  /// 承認済みのリクエストのみ取得
  List<ConstraintRequest> get approvedRequests =>
      _requests.where((r) => r.status == ConstraintRequest.statusApproved).toList();

  /// 却下されたリクエストのみ取得
  List<ConstraintRequest> get rejectedRequests =>
      _requests.where((r) => r.status == ConstraintRequest.statusRejected).toList();

  ConstraintRequestProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    // リアルタイム更新を開始
    _subscribeToRequests();
  }

  /// Firestoreからリクエストをリアルタイムで購読（pending/rejected/approved）
  void _subscribeToRequests() {
    if (teamId == null) return;


    _requestSubscription?.cancel();
    _requestSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraint_requests')
        .where('status', whereIn: [
          ConstraintRequest.statusPending,
          ConstraintRequest.statusRejected,
          ConstraintRequest.statusApproved,
        ])
        .snapshots()
        .listen((snapshot) {
      _requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return ConstraintRequest(
          id: doc.id,
          staffId: data['staffId'] as String,
          userId: data['userId'] as String,
          requestType: data['requestType'] as String,
          specificDate: data['specificDate'] != null
              ? (data['specificDate'] as Timestamp).toDate()
              : null,
          weekday: data['weekday'] as int?,
          shiftType: data['shiftType'] as String?,
          maxShiftsPerMonth: data['maxShiftsPerMonth'] as int?,
          status: data['status'] as String,
          isDelete: data['isDelete'] as bool? ?? false,  // 追加：削除申請フラグ
          approvedBy: data['approvedBy'] as String?,
          approvedAt: data['approvedAt'] != null
              ? (data['approvedAt'] as Timestamp).toDate()
              : null,
          rejectedReason: data['rejectedReason'] as String?,
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          updatedAt: data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();

      // 初回ロード完了
      if (_isLoading) {
        _isLoading = false;
      }

      notifyListeners();
    }, onError: (error) {
      debugPrint('⚠️ [ConstraintRequestProvider] データ読み込みエラー: $error');
      // エラーが発生してもローディングを完了させる
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// 特定ユーザーのリクエストを取得
  List<ConstraintRequest> getRequestsByUserId(String userId) {
    return _requests.where((r) => r.userId == userId).toList();
  }

  /// 特定スタッフのリクエストを取得
  List<ConstraintRequest> getRequestsByStaffId(String staffId) {
    return _requests.where((r) => r.staffId == staffId).toList();
  }

  /// リクエストを作成
  Future<void> createRequest(ConstraintRequest request) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraint_requests')
        .doc(request.id)
        .set({
      'staffId': request.staffId,
      'userId': request.userId,
      'requestType': request.requestType,
      'specificDate': request.specificDate != null
          ? Timestamp.fromDate(request.specificDate!)
          : null,
      'weekday': request.weekday,
      'shiftType': request.shiftType,
      'maxShiftsPerMonth': request.maxShiftsPerMonth,
      'status': request.status,
      'isDelete': request.isDelete,
      'approvedBy': request.approvedBy,
      'approvedAt': request.approvedAt != null
          ? Timestamp.fromDate(request.approvedAt!)
          : null,
      'rejectedReason': request.rejectedReason,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

  }

  /// リクエストを承認（ステータス更新＋Staffデータに反映）
  Future<void> approveRequest(
    ConstraintRequest request,
    String approverUserId,
    Staff staff,
  ) async {
    if (teamId == null) return;


    final batch = _firestore.batch();

    // 1. リクエストのステータスを"approved"に更新
    final requestRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraint_requests')
        .doc(request.id);

    batch.update(requestRef, {
      'status': ConstraintRequest.statusApproved,
      'approvedBy': approverUserId,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Staffデータに反映
    final staffRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .doc(request.staffId);

    // リクエストタイプに応じてStaffデータを更新
    if (request.requestType == ConstraintRequest.typeWeekday) {
      // 曜日の休み希望
      final updatedDaysOff = List<int>.from(staff.preferredDaysOff);
      if (request.isDelete) {
        // 削除申請の場合：リストから削除
        updatedDaysOff.remove(request.weekday);
      } else {
        // 追加申請の場合：リストに追加
        if (request.weekday != null && !updatedDaysOff.contains(request.weekday)) {
          updatedDaysOff.add(request.weekday!);
        }
      }
      batch.update(staffRef, {
        'preferredDaysOff': updatedDaysOff,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (request.requestType == ConstraintRequest.typeSpecificDay) {
      // 特定日の休み希望
      final updatedSpecificDays = List<String>.from(staff.specificDaysOff);
      if (request.specificDate != null) {
        final dateStr = request.specificDate!.toIso8601String();
        if (request.isDelete) {
          // 削除申請の場合：リストから削除
          updatedSpecificDays.remove(dateStr);
        } else {
          // 追加申請の場合：リストに追加
          if (!updatedSpecificDays.contains(dateStr)) {
            updatedSpecificDays.add(dateStr);
          }
        }
      }
      batch.update(staffRef, {
        'specificDaysOff': updatedSpecificDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (request.requestType == ConstraintRequest.typeShiftType) {
      // シフトタイプの勤務不可
      final updatedShiftTypes = List<String>.from(staff.unavailableShiftTypes);
      if (request.isDelete) {
        // 削除申請の場合：リストから削除
        updatedShiftTypes.remove(request.shiftType);
      } else {
        // 追加申請の場合：リストに追加
        if (request.shiftType != null && !updatedShiftTypes.contains(request.shiftType)) {
          updatedShiftTypes.add(request.shiftType!);
        }
      }
      batch.update(staffRef, {
        'unavailableShiftTypes': updatedShiftTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (request.requestType == ConstraintRequest.typeMaxShiftsPerMonth) {
      // 月間最大シフト数の変更
      if (request.maxShiftsPerMonth != null) {
        batch.update(staffRef, {
          'maxShiftsPerMonth': request.maxShiftsPerMonth,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // バッチコミット
    await batch.commit();

  }

  /// リクエストを却下（ステータス更新＋却下理由設定）
  Future<void> rejectRequest(
    ConstraintRequest request,
    String approverUserId,
    String rejectedReason,
  ) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraint_requests')
        .doc(request.id)
        .update({
      'status': ConstraintRequest.statusRejected,
      'approvedBy': approverUserId,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': rejectedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

  }

  /// リクエストを削除
  Future<void> deleteRequest(String requestId) async {
    if (teamId == null) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraint_requests')
        .doc(requestId)
        .delete();

  }

  /// 特定スタッフの全リクエストを削除（アカウント削除時に使用）
  Future<void> deleteRequestsByStaffId(String staffId) async {
    if (teamId == null) return;

    try {
      // staffIdで検索
      final snapshot = await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('constraint_requests')
          .where('staffId', isEqualTo: staffId)
          .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      // バッチで削除（最大500件）
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }
}
