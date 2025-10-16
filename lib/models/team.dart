import 'package:cloud_firestore/cloud_firestore.dart';

/// チーム（組織単位）
class Team {
  final String id;              // チームID
  final String name;            // チーム名
  final String ownerId;         // 作成者のUID
  final List<String> adminIds;  // 管理者のUIDリスト
  final List<String> memberIds; // メンバーのUIDリスト（管理者も含む）
  final DateTime? shiftDeadline; // 休み希望締め日
  final DateTime createdAt;     // 作成日時
  final DateTime updatedAt;     // 更新日時

  Team({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.adminIds,
    required this.memberIds,
    this.shiftDeadline,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestoreから取得
  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      adminIds: List<String>.from(data['adminIds'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      shiftDeadline: (data['shiftDeadline'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestoreへ保存
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'shiftDeadline': shiftDeadline != null
          ? Timestamp.fromDate(shiftDeadline!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// コピー作成
  Team copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? adminIds,
    List<String>? memberIds,
    DateTime? shiftDeadline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      shiftDeadline: shiftDeadline ?? this.shiftDeadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 指定したユーザーが管理者かどうか
  bool isAdmin(String uid) => adminIds.contains(uid);

  /// 指定したユーザーがメンバーかどうか
  bool isMember(String uid) => memberIds.contains(uid);
}
