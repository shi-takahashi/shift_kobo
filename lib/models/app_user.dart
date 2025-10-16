import 'package:cloud_firestore/cloud_firestore.dart';

/// ユーザーロール
enum UserRole {
  admin,  // 管理者
  member, // メンバー
}

/// アプリユーザー（Firebase Authと紐づく）
class AppUser {
  final String uid;           // Firebase Auth UID
  final String email;         // メールアドレス
  final String displayName;   // 表示名
  final UserRole role;        // 権限
  final String? teamId;       // 所属チームID（未所属の場合はnull）
  final DateTime createdAt;   // 作成日時
  final DateTime updatedAt;   // 更新日時

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.teamId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestoreから取得
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.member,
      ),
      teamId: data['teamId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestoreへ保存
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'teamId': teamId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// コピー作成
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? teamId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 管理者かどうか
  bool get isAdmin => role == UserRole.admin;

  /// メンバーかどうか
  bool get isMember => role == UserRole.member;
}
