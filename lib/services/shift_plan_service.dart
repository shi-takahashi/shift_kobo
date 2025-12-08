import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/shift.dart';
import '../models/shift_plan.dart';

class ShiftPlanService {
  final String teamId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  ShiftPlanService({required this.teamId});

  /// 現在有効なplan_idを取得
  /// 既存ユーザー（shift_active_planがない）の場合はnullを返す
  Future<String?> getActivePlanId(String month) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).collection('shift_active_plan').doc(month).get();

      if (!doc.exists) return null;
      return doc.data()?['plan_id'] as String?;
    } catch (e) {
      print('getActivePlanId エラー: $e');
      return null;
    }
  }

  /// 現在有効なシフトの戦略を取得
  /// 戦略情報がない場合はnullを返す
  Future<String?> getActiveStrategy(String month) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).collection('shift_active_plan').doc(month).get();

      if (!doc.exists) return null;
      return doc.data()?['strategy'] as String?;
    } catch (e) {
      print('getActiveStrategy エラー: $e');
      return null;
    }
  }

  /// 有効なplan_idを更新
  Future<void> setActivePlanId(String month, String planId, {String? strategy}) async {
    await _firestore.collection('teams').doc(teamId).collection('shift_active_plan').doc(month).set({
      'plan_id': planId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (strategy != null) 'strategy': strategy,
    });
  }

  /// 指定月の全案を取得（新しい順）
  Future<List<ShiftPlan>> getPlansForMonth(String month) async {
    final snapshot = await _firestore.collection('teams').doc(teamId).collection('shift_plans').where('metadata.month', isEqualTo: month).get();

    // クライアント側でソート（新しい順）
    final plans = snapshot.docs.map((doc) => ShiftPlan.fromFirestore(doc)).toList();

    plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return plans;
  }

  /// plan_idから案を取得
  Future<ShiftPlan?> getShiftPlanByPlanId(String planId) async {
    final snapshot = await _firestore.collection('teams').doc(teamId).collection('shift_plans').where('metadata.plan_id', isEqualTo: planId).limit(1).get();

    if (snapshot.docs.isEmpty) return null;

    return ShiftPlan.fromFirestore(snapshot.docs.first);
  }

  /// 案を保存
  /// 同じplan_idの案が既に存在する場合は削除してから保存
  Future<String> saveShiftPlan({
    required String planId,
    required List<Shift> shifts,
    required String month,
    String? note,
    required String strategy,
  }) async {
    // 同じplan_idの案が既に存在する場合は削除
    await deleteShiftPlanByPlanId(planId);

    // 新しい案を保存
    final docRef = await _firestore.collection('teams').doc(teamId).collection('shift_plans').add({
      'createdAt': FieldValue.serverTimestamp(),
      'shifts': shifts.map((s) => s.toJson()).toList(),
      'metadata': {
        'totalShifts': shifts.length,
        'month': month,
        'note': note,
        'plan_id': planId,
        'strategy': strategy,
      },
    });

    return docRef.id;
  }

  /// plan_idで案を削除
  Future<void> deleteShiftPlanByPlanId(String planId) async {
    final snapshot = await _firestore.collection('teams').doc(teamId).collection('shift_plans').where('metadata.plan_id', isEqualTo: planId).get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// ユニークなplan_idを生成（plan_1, plan_2, ...）
  Future<String> generateUniquePlanId(String month) async {
    // 指定月の全案を取得
    final snapshot = await _firestore.collection('teams').doc(teamId).collection('shift_plans').where('metadata.month', isEqualTo: month).get();

    // plan_数字 パターンのIDから最大番号を見つける
    int maxNumber = 0;
    final regex = RegExp(r'^plan_(\d+)$');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final planId = data['metadata']?['plan_id'] as String?;
      if (planId != null) {
        final match = regex.firstMatch(planId);
        if (match != null) {
          final number = int.parse(match.group(1)!);
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }
    }

    return 'plan_${maxNumber + 1}';
  }
}
