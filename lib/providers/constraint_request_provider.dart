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
  List<ConstraintRequest> _processedRequests = []; // 承認済み + 却下済み
  StreamSubscription? _requestSubscription;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreProcessed = true;
  DocumentSnapshot? _lastProcessedDoc;
  static const int _processedPageSize = 100;

  List<ConstraintRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreApproved => _hasMoreProcessed;

  /// 承認待ちのリクエストのみ取得
  List<ConstraintRequest> get pendingRequests =>
      _requests.where((r) => r.status == ConstraintRequest.statusPending).toList();

  /// 処理済みのリクエストを取得（承認済み + 却下済み、ページネーション対応）
  List<ConstraintRequest> get approvedRequests => _processedRequests;

  /// 却下されたリクエストのみ取得
  List<ConstraintRequest> get rejectedRequests =>
      _processedRequests.where((r) => r.status == ConstraintRequest.statusRejected).toList();

  ConstraintRequestProvider({this.teamId}) {
    if (teamId != null) {
      _init();
    }
  }

  void _init() {
    // リアルタイム更新を開始（pendingのみ）
    _subscribeToRequests();
    // 処理済み（承認済み + 却下済み）の初回読み込み
    _loadProcessedRequests();
  }

  /// Firestoreからリクエストをリアルタイムで購読（pendingのみ）
  void _subscribeToRequests() {
    if (teamId == null) return;

    _requestSubscription?.cancel();
    _requestSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraint_requests')
        .where('status', isEqualTo: ConstraintRequest.statusPending)
        .snapshots()
        .listen((snapshot) {
      _requests = snapshot.docs.map((doc) {
        return _docToConstraintRequest(doc);
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

  /// 処理済みリクエストを読み込み（承認済み + 却下済み、ページネーション対応）
  Future<void> _loadProcessedRequests({bool loadMore = false}) async {
    if (teamId == null) return;
    if (loadMore && !_hasMoreProcessed) return;
    if (_isLoadingMore) return;

    if (loadMore) {
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      Query query = _firestore
          .collection('teams')
          .doc(teamId)
          .collection('constraint_requests')
          .where('status', whereIn: [
            ConstraintRequest.statusApproved,
            ConstraintRequest.statusRejected,
          ])
          .orderBy('updatedAt', descending: true)
          .limit(_processedPageSize);

      if (loadMore && _lastProcessedDoc != null) {
        query = query.startAfterDocument(_lastProcessedDoc!);
      }

      final snapshot = await query.get();

      final newRequests = snapshot.docs.map((doc) {
        return _docToConstraintRequest(doc);
      }).toList();

      if (loadMore) {
        _processedRequests.addAll(newRequests);
      } else {
        _processedRequests = newRequests;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastProcessedDoc = snapshot.docs.last;
      }

      _hasMoreProcessed = snapshot.docs.length >= _processedPageSize;
    } catch (e) {
      debugPrint('⚠️ [ConstraintRequestProvider] 処理済みデータ読み込みエラー: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 処理済みデータを追加読み込み
  Future<void> loadMoreApproved() async {
    await _loadProcessedRequests(loadMore: true);
  }

  /// 処理済みデータをリフレッシュ
  Future<void> refreshApprovedRequests() async {
    _lastProcessedDoc = null;
    _hasMoreProcessed = true;
    await _loadProcessedRequests();
  }

  /// DocumentSnapshotからConstraintRequestを生成
  ConstraintRequest _docToConstraintRequest(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      holidaysOff: data['holidaysOff'] as bool?,
      status: data['status'] as String,
      isDelete: data['isDelete'] as bool? ?? false,
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
      'holidaysOff': request.holidaysOff,
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
    } else if (request.requestType == ConstraintRequest.typeHoliday) {
      // 祝日の休み希望
      if (request.holidaysOff != null) {
        batch.update(staffRef, {
          'holidaysOff': request.holidaysOff,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else if (request.requestType == ConstraintRequest.typePreferredDate) {
      // 勤務希望日
      final updatedPreferredDates = List<String>.from(staff.preferredDates);
      if (request.specificDate != null) {
        final dateStr = request.specificDate!.toIso8601String();
        if (request.isDelete) {
          // 削除申請の場合：リストから削除
          updatedPreferredDates.remove(dateStr);
        } else {
          // 追加申請の場合：リストに追加
          if (!updatedPreferredDates.contains(dateStr)) {
            updatedPreferredDates.add(dateStr);
          }
        }
      }
      batch.update(staffRef, {
        'preferredDates': updatedPreferredDates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // バッチコミット
    await batch.commit();

    // 承認済みリストをリフレッシュ
    await refreshApprovedRequests();
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

    // 処理済みリストをリフレッシュ
    await refreshApprovedRequests();
  }

  /// 複数のリクエストを一括承認（バッチ処理で高速化）
  /// 承認した件数を返す
  Future<int> approveAllRequests(
    List<ConstraintRequest> requests,
    String approverUserId,
    Map<String, Staff> staffMap,
  ) async {
    if (teamId == null) return 0;
    if (requests.isEmpty) return 0;

    final batch = _firestore.batch();
    int approvedCount = 0;

    // スタッフごとの更新データを蓄積するマップ
    final staffUpdates = <String, Map<String, dynamic>>{};

    // スタッフの現在データをコピー（変更を蓄積するため）
    final staffDataCopy = <String, Staff>{};
    for (final entry in staffMap.entries) {
      staffDataCopy[entry.key] = Staff(
        id: entry.value.id,
        name: entry.value.name,
        email: entry.value.email,
        userId: entry.value.userId,
        preferredDaysOff: List<int>.from(entry.value.preferredDaysOff),
        specificDaysOff: List<String>.from(entry.value.specificDaysOff),
        unavailableShiftTypes: List<String>.from(entry.value.unavailableShiftTypes),
        maxShiftsPerMonth: entry.value.maxShiftsPerMonth,
        holidaysOff: entry.value.holidaysOff,
        preferredDates: List<String>.from(entry.value.preferredDates),
      );
    }

    for (final request in requests) {
      final staff = staffDataCopy[request.staffId];
      if (staff == null) continue;

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

      // 2. スタッフデータの更新を蓄積
      _applyRequestToStaff(request, staff, staffUpdates);
      approvedCount++;
    }

    // 3. スタッフデータの更新をバッチに追加
    for (final entry in staffUpdates.entries) {
      final staffRef = _firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .doc(entry.key);

      final updateData = Map<String, dynamic>.from(entry.value);
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      batch.update(staffRef, updateData);
    }

    // 4. バッチコミット（1回で全て更新）
    await batch.commit();

    // 5. リフレッシュは最後に1回だけ
    await refreshApprovedRequests();

    return approvedCount;
  }

  /// リクエストをスタッフデータに適用し、更新データを蓄積
  void _applyRequestToStaff(
    ConstraintRequest request,
    Staff staff,
    Map<String, Map<String, dynamic>> staffUpdates,
  ) {
    staffUpdates[request.staffId] ??= {};
    final updates = staffUpdates[request.staffId]!;

    if (request.requestType == ConstraintRequest.typeWeekday) {
      if (request.isDelete) {
        staff.preferredDaysOff.remove(request.weekday);
      } else if (request.weekday != null && !staff.preferredDaysOff.contains(request.weekday)) {
        staff.preferredDaysOff.add(request.weekday!);
      }
      updates['preferredDaysOff'] = staff.preferredDaysOff;
    } else if (request.requestType == ConstraintRequest.typeSpecificDay) {
      if (request.specificDate != null) {
        final dateStr = request.specificDate!.toIso8601String();
        if (request.isDelete) {
          staff.specificDaysOff.remove(dateStr);
        } else if (!staff.specificDaysOff.contains(dateStr)) {
          staff.specificDaysOff.add(dateStr);
        }
      }
      updates['specificDaysOff'] = staff.specificDaysOff;
    } else if (request.requestType == ConstraintRequest.typeShiftType) {
      if (request.isDelete) {
        staff.unavailableShiftTypes.remove(request.shiftType);
      } else if (request.shiftType != null && !staff.unavailableShiftTypes.contains(request.shiftType)) {
        staff.unavailableShiftTypes.add(request.shiftType!);
      }
      updates['unavailableShiftTypes'] = staff.unavailableShiftTypes;
    } else if (request.requestType == ConstraintRequest.typeMaxShiftsPerMonth) {
      if (request.maxShiftsPerMonth != null) {
        updates['maxShiftsPerMonth'] = request.maxShiftsPerMonth;
      }
    } else if (request.requestType == ConstraintRequest.typeHoliday) {
      if (request.holidaysOff != null) {
        updates['holidaysOff'] = request.holidaysOff;
      }
    } else if (request.requestType == ConstraintRequest.typePreferredDate) {
      if (request.specificDate != null) {
        final dateStr = request.specificDate!.toIso8601String();
        if (request.isDelete) {
          staff.preferredDates.remove(dateStr);
        } else if (!staff.preferredDates.contains(dateStr)) {
          staff.preferredDates.add(dateStr);
        }
      }
      updates['preferredDates'] = staff.preferredDates;
    }
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
