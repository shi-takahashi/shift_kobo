import 'package:cloud_firestore/cloud_firestore.dart';

/// お知らせモデル
class Announcement {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  /// Firestoreから読み込み
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Firestoreに保存
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
    };
  }

  /// 現在表示すべきかどうか
  bool shouldDisplay() {
    if (!isActive) return false;

    final now = DateTime.now();

    // 開始日が設定されている場合、開始日以降かチェック
    if (startDate != null && now.isBefore(startDate!)) {
      return false;
    }

    // 終了日が設定されている場合、終了日以前かチェック
    if (endDate != null && now.isAfter(endDate!)) {
      return false;
    }

    return true;
  }
}
