import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement.dart';

/// お知らせサービス
class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 未読のお知らせを取得（全ユーザー対象）
  Future<List<Announcement>> getUnreadAnnouncements(String userId) async {
    try {
      print('📢 お知らせチェック開始: userId=$userId');

      // ユーザーの既読リストを取得
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final readIds = List<String>.from(userDoc.data()?['readAnnouncementIds'] ?? []);
      print('📢 既読リスト: $readIds');

      // 全お知らせを取得（インデックス不要にするためorderByを削除）
      final querySnapshot = await _firestore
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .get();

      print('📢 取得したお知らせ数: ${querySnapshot.docs.length}');

      // 取得したお知らせの詳細をログ出力
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        print('📢 お知らせ: id=${doc.id}, title=${data['title']}, isActive=${data['isActive']}');
      }

      // 未読かつ表示期間内のお知らせをフィルタ
      final announcements = querySnapshot.docs
          .map((doc) => Announcement.fromFirestore(doc))
          .where((announcement) {
            final isUnread = !readIds.contains(announcement.id);
            final shouldShow = announcement.shouldDisplay();
            print('📢 フィルタ判定: id=${announcement.id}, 未読=$isUnread, 表示期間内=$shouldShow');
            return isUnread && shouldShow;
          })
          .toList();

      // アプリ側で日付順にソート（新しい順）
      announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('📢 表示するお知らせ数: ${announcements.length}');
      return announcements;
    } catch (e) {
      print('⚠️ お知らせ取得エラー: $e');
      return [];
    }
  }

  /// お知らせを既読にする
  Future<void> markAsRead(String userId, String announcementId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'readAnnouncementIds': FieldValue.arrayUnion([announcementId]),
      });
      print('✅ お知らせ既読: $announcementId');
    } catch (e) {
      print('⚠️ お知らせ既読マークエラー: $e');
    }
  }

  /// 複数のお知らせを既読にする
  Future<void> markMultipleAsRead(String userId, List<String> announcementIds) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'readAnnouncementIds': FieldValue.arrayUnion(announcementIds),
      });
      print('✅ お知らせ既読（複数）: ${announcementIds.length}件');
    } catch (e) {
      print('⚠️ お知らせ既読マークエラー: $e');
    }
  }
}
