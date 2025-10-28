import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement.dart';

/// お知らせサービス
class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 未読のお知らせを取得（全ユーザー対象）
  Future<List<Announcement>> getUnreadAnnouncements(String userId) async {
    try {
      // ユーザーの既読リストを取得
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final readIds = List<String>.from(userDoc.data()?['readAnnouncementIds'] ?? []);

      // 全お知らせを取得（インデックス不要にするためorderByを削除）
      final querySnapshot = await _firestore
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .get();

      // 未読かつ表示期間内のお知らせをフィルタ
      final announcements = querySnapshot.docs
          .map((doc) => Announcement.fromFirestore(doc))
          .where((announcement) {
            final isUnread = !readIds.contains(announcement.id);
            final shouldShow = announcement.shouldDisplay();
            return isUnread && shouldShow;
          })
          .toList();

      // アプリ側で日付順にソート（新しい順）
      announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return announcements;
    } catch (e) {
      return [];
    }
  }

  /// お知らせを既読にする
  Future<void> markAsRead(String userId, String announcementId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'readAnnouncementIds': FieldValue.arrayUnion([announcementId]),
      });
    } catch (e) {
      // エラーは無視
    }
  }

  /// 複数のお知らせを既読にする
  Future<void> markMultipleAsRead(String userId, List<String> announcementIds) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'readAnnouncementIds': FieldValue.arrayUnion(announcementIds),
      });
    } catch (e) {
      // エラーは無視
    }
  }
}
