import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push通知サービス
/// Web版では無効化される
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// 通知許可をリクエスト（初回のみ）
  static Future<void> requestPermission() async {
    if (kIsWeb) {
      debugPrint('🌐 Web版ではPush通知を無効化');
      return;
    }

    debugPrint('📱 FCM通知許可リクエスト開始');

    try {
      // Android通知チャンネルを作成
      await _createNotificationChannel();

      // 通知権限をリクエスト
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Push通知権限が許可されました');
        await syncToken();
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ Push通知権限が拒否されました');
      } else {
        debugPrint('⚠️ Push通知権限が未決定です');
      }
    } catch (e) {
      debugPrint('❌ FCM通知許可リクエストエラー: $e');
    }
  }

  /// 通知が役立つ文脈（チーム招待・チーム参加など）になったタイミングで呼ぶ。
  /// まだ一度も許可を聞いていなければ聞き、既に聞いていればトークン同期のみ行う。
  /// 初回起動では呼ばないこと（オンボーディングを邪魔しないため）。
  static Future<void> requestPermissionIfNeeded() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequested = prefs.getBool('has_requested_fcm_permission') ?? false;
      if (!hasRequested) {
        await requestPermission(); // 内部で許可されればsyncTokenも実行
        await prefs.setBool('has_requested_fcm_permission', true);
      } else {
        await syncToken();
      }
    } catch (e) {
      debugPrint('⚠️ FCM許可リクエスト（文脈）エラー: $e');
    }
  }

  /// FCMトークンを同期（毎回起動時）
  static Future<void> syncToken() async {
    if (kIsWeb) return;

    debugPrint('🔄 FCMトークン同期開始');

    try {
      // 現在の許可状態を確認
      final settings = await _messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Push通知が許可されています');

        // FCMトークンを取得
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('📝 FCMトークン: $token');
          await _saveFcmToken(token);
        }

        // トークン更新時の処理（リスナーの重複登録を避ける）
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 FCMトークンが更新されました: $newToken');
          _saveFcmToken(newToken);
        });

        // フォアグラウンド通知の処理
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // バックグラウンド通知の処理
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

        // アプリ起動時の通知処理
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('🚀 アプリ起動時の通知: ${initialMessage.notification?.title}');
          _handleBackgroundMessage(initialMessage);
        }
      } else {
        debugPrint('⚠️ Push通知が許可されていません（状態: ${settings.authorizationStatus}）');
      }
    } catch (e) {
      debugPrint('❌ FCMトークン同期エラー: $e');
    }
  }

  /// FCMを初期化（アプリ版のみ）
  @Deprecated('requestPermission()とsyncToken()を使用してください')
  static Future<void> initialize() async {
    await requestPermission();
  }

  /// FCMトークンをFirestoreに保存
  static Future<void> _saveFcmToken(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ ユーザーIDがnullのためFCMトークンを保存できません');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCMトークンをFirestoreに保存しました');
    } catch (e) {
      debugPrint('❌ FCMトークン保存エラー: $e');
    }
  }

  /// フォアグラウンド通知の処理
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 フォアグラウンド通知を受信:');
    debugPrint('  - タイトル: ${message.notification?.title}');
    debugPrint('  - 本文: ${message.notification?.body}');
    debugPrint('  - データ: ${message.data}');

    // TODO: アプリ内通知表示（SnackBarなど）
  }

  /// バックグラウンド通知の処理（タップ時）
  static void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📭 バックグラウンド通知をタップ:');
    debugPrint('  - タイトル: ${message.notification?.title}');
    debugPrint('  - 本文: ${message.notification?.body}');
    debugPrint('  - データ: ${message.data}');

    // TODO: 適切な画面に遷移
    // 例: 申請通知 → 承認画面、承認/却下通知 → マイページ
    final type = message.data['type'];
    switch (type) {
      case 'request_created':
        // 承認画面に遷移
        debugPrint('→ 承認画面に遷移');
        break;
      case 'request_approved':
      case 'request_rejected':
        // マイページに遷移
        debugPrint('→ マイページに遷移');
        break;
      default:
        debugPrint('→ 不明な通知タイプ: $type');
    }
  }

  /// 通知設定を取得
  static Future<Map<String, bool>> getNotificationSettings() async {
    if (kIsWeb) return {};

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return _defaultNotificationSettings();

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null || !data.containsKey('notificationSettings')) {
        return _defaultNotificationSettings();
      }

      final settings = data['notificationSettings'] as Map<String, dynamic>;
      return {
        'requestCreated': settings['requestCreated'] ?? true,
        'requestApproved': settings['requestApproved'] ?? true,
        'requestRejected': settings['requestRejected'] ?? true,
      };
    } catch (e) {
      debugPrint('❌ 通知設定取得エラー: $e');
      return _defaultNotificationSettings();
    }
  }

  /// 通知設定を更新
  static Future<void> updateNotificationSettings(
    Map<String, bool> settings,
  ) async {
    if (kIsWeb) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ ユーザーIDがnullのため通知設定を更新できません');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationSettings': settings,
      });
      debugPrint('✅ 通知設定を更新しました: $settings');
    } catch (e) {
      debugPrint('❌ 通知設定更新エラー: $e');
    }
  }

  /// デフォルトの通知設定
  static Map<String, bool> _defaultNotificationSettings() {
    return {
      'requestCreated': true, // 申請通知（管理者用）
      'requestApproved': true, // 承認通知（スタッフ用）
      'requestRejected': true, // 却下通知（スタッフ用）
    };
  }

  /// FCMトークンを削除（ログアウト時）
  static Future<void> deleteFcmToken() async {
    if (kIsWeb) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      await _messaging.deleteToken();
      debugPrint('✅ FCMトークンを削除しました');
    } catch (e) {
      debugPrint('❌ FCMトークン削除エラー: $e');
    }
  }

  /// Android通知チャンネルを作成
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      '重要な通知', // name
      description: '休み希望の申請・承認・却下通知',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Android通知チャンネルを作成しました');
  }

  /// 通知が有効かどうかをチェック
  static Future<bool> isNotificationEnabled() async {
    if (kIsWeb) return false;

    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('⚠️ 通知許可状態チェックエラー: $e');
      return false;
    }
  }
}
