import 'package:cloud_firestore/cloud_firestore.dart';

import 'shift.dart';

/// シフト案（複数案管理用）
class ShiftPlan {
  final String id; // Firestore document ID
  final List<Shift> shifts; // 案に含まれるシフト
  final DateTime createdAt; // 作成日時
  final String? note; // メモ
  final int totalShifts; // シフト数
  final String month; // 対象月
  final String planId; // 案ID
  final String strategy; // 生成戦略

  ShiftPlan({
    required this.id,
    required this.shifts,
    required this.createdAt,
    this.note,
    required this.totalShifts,
    required this.month,
    required this.planId,
    required this.strategy,
  });

  factory ShiftPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final metadata = data['metadata'] as Map<String, dynamic>?;

    return ShiftPlan(
      id: doc.id,
      shifts: (data['shifts'] as List).map((json) => Shift.fromJson(json as Map<String, dynamic>)).toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      note: metadata?['note'] as String?,
      totalShifts: metadata?['totalShifts'] as int? ?? 0,
      month: metadata?['month'] as String? ?? '',
      planId: metadata?['plan_id'] as String? ?? '',
      strategy: metadata?['strategy'] as String? ?? 'balanced',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'shifts': shifts.map((s) => s.toJson()).toList(),
      'metadata': {
        'totalShifts': totalShifts,
        'month': month,
        'note': note,
        'plan_id': planId,
        'strategy': strategy,
      },
    };
  }
}

/// 現在有効な案の情報
class ShiftActivePlan {
  final String month; // 対象月（例: "2025-12"）、ドキュメントIDとしても使用
  final String planId; // 現在有効な案ID
  final DateTime updatedAt; // 更新日時
  final String? strategy; // 生成戦略（例: "fairness", "distributed"）

  ShiftActivePlan({
    required this.month,
    required this.planId,
    required this.updatedAt,
    this.strategy,
  });

  factory ShiftActivePlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftActivePlan(
      month: doc.id,
      planId: data['plan_id'] as String,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      strategy: data['strategy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'plan_id': planId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (strategy != null) 'strategy': strategy,
    };
  }
}
