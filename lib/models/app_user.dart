import 'package:cloud_firestore/cloud_firestore.dart';

/// ユーザーロール
enum UserRole {
  admin,  // 管理者
  member, // スタッフ
}

/// アプリユーザー（Firebase Authと紐づく）
class AppUser {
  final String uid;           // Firebase Auth UID
  final String? email;        // メールアドレス（匿名ユーザーはnull）
  final String displayName;   // 表示名
  final UserRole role;        // 権限
  final String? teamId;       // 所属チームID（未所属の場合はnull）
  final DateTime createdAt;   // 作成日時
  final DateTime updatedAt;   // 更新日時
  final List<String> readAnnouncementIds; // 既読のお知らせID一覧
  final String? fcmToken;     // FCMトークン（Push通知用、Web版では使用しない）
  final Map<String, bool> notificationSettings; // 通知設定

  AppUser({
    required this.uid,
    this.email,                // nullable
    required this.displayName,
    required this.role,
    this.teamId,
    required this.createdAt,
    required this.updatedAt,
    this.readAnnouncementIds = const [],
    this.fcmToken,
    Map<String, bool>? notificationSettings,
  }) : notificationSettings = notificationSettings ?? {
    'requestCreated': true,  // 申請通知（管理者用）
    'requestApproved': true, // 承認通知（スタッフ用）
    'requestRejected': true, // 却下通知（スタッフ用）
  };

  /// Firestoreから取得
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'],  // nullableなのでそのまま
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.member,
      ),
      teamId: data['teamId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAnnouncementIds: List<String>.from(data['readAnnouncementIds'] ?? []),
      fcmToken: data['fcmToken'],
      notificationSettings: data['notificationSettings'] != null
          ? Map<String, bool>.from(data['notificationSettings'])
          : null,
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
      'readAnnouncementIds': readAnnouncementIds,
      'fcmToken': fcmToken,
      'notificationSettings': notificationSettings,
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
    List<String>? readAnnouncementIds,
    String? fcmToken,
    Map<String, bool>? notificationSettings,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAnnouncementIds: readAnnouncementIds ?? this.readAnnouncementIds,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }

  /// 管理者かどうか
  bool get isAdmin => role == UserRole.admin;

  /// スタッフかどうか
  bool get isMember => role == UserRole.member;
}
