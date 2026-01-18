import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// ユーザーIDを設定（ログイン時に呼び出す）
  static Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// アプリ起動イベント
  static Future<void> logAppOpen() async {
    await _analytics.logEvent(name: 'app_open');
  }

  // ============================================================
  // 認証状態追跡（根本原因調査用）
  // ============================================================

  /// アプリ起動時の認証状態をログ
  static Future<void> logAuthStateOnStartup(User? user) async {
    if (user == null) {
      debugPrint('🔴 [Auth] 起動時: currentUser == null');
      await _analytics.logEvent(
        name: 'auth_startup_null',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } else {
      final lastSignIn = user.metadata.lastSignInTime;
      final creationTime = user.metadata.creationTime;
      debugPrint('🟢 [Auth] 起動時: uid=${user.uid}, isAnonymous=${user.isAnonymous}');
      debugPrint('   lastSignIn: $lastSignIn');
      debugPrint('   creationTime: $creationTime');
      await _analytics.logEvent(
        name: 'auth_startup_ok',
        parameters: {
          'uid': user.uid,
          'is_anonymous': user.isAnonymous.toString(),
          'last_sign_in': lastSignIn?.toIso8601String() ?? 'null',
          'creation_time': creationTime?.toIso8601String() ?? 'null',
        },
      );
    }
  }

  /// 認証状態が変化した時のログ
  static Future<void> logAuthStateChanged({
    required bool isSignedIn,
    String? uid,
    bool? isAnonymous,
  }) async {
    if (isSignedIn) {
      debugPrint('🟢 [Auth] 状態変化: サインイン (uid=$uid, anonymous=$isAnonymous)');
      await _analytics.logEvent(
        name: 'auth_state_signed_in',
        parameters: {
          'uid': uid ?? 'unknown',
          'is_anonymous': (isAnonymous ?? false).toString(),
        },
      );
    } else {
      debugPrint('🔴 [Auth] 状態変化: サインアウト');
      await _analytics.logEvent(
        name: 'auth_state_signed_out',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  /// IDトークン更新時のログ
  static Future<void> logIdTokenRefreshed(String uid) async {
    debugPrint('🔄 [Auth] IDトークン更新: uid=$uid');
    await _analytics.logEvent(
      name: 'auth_token_refreshed',
      parameters: {
        'uid': uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// IDトークン取得エラー時のログ
  static Future<void> logIdTokenError(String error) async {
    debugPrint('❌ [Auth] IDトークンエラー: $error');
    await _analytics.logEvent(
      name: 'auth_token_error',
      parameters: {
        'error': error.length > 100 ? error.substring(0, 100) : error,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 画面表示イベント
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logEvent(
      name: 'screen_view',
      parameters: {
        'screen_name': screenName,
        'screen_class': screenName,
      },
    );
  }

  /// シフト自動作成イベント
  static Future<void> logShiftGenerated({
    required int shiftCount,
    required String strategy,
    required String yearMonth, // "2025-12" 形式
  }) async {
    await _analytics.logEvent(
      name: 'auto_shift_generated',
      parameters: {
        'shift_count': shiftCount,
        'strategy': strategy,
        'year_month': yearMonth,
      },
    );
  }

  /// シフト切替イベント
  static Future<void> logShiftRestored() async {
    await _analytics.logEvent(name: 'shift_restored');
  }

  /// シフト手動編集イベント
  static Future<void> logShiftEdited(String shiftId) async {
    await _analytics.logEvent(
      name: 'shift_edited',
      parameters: {
        'shift_id': shiftId,
      },
    );
  }

  /// シフト表エクスポートイベント
  static Future<void> logShiftExported({
    required String action, // "save" or "share"
    required String format, // "pdf", "png", "excel"
    required String yearMonth, // "2025-01" 形式
  }) async {
    await _analytics.logEvent(
      name: 'shift_exported',
      parameters: {
        'action': action,
        'format': format,
        'year_month': yearMonth,
      },
    );
  }

  /// シフト操作イベント（スタッフ変更・日付移動・スタッフ入替）
  static Future<void> logShiftQuickAction(String action) async {
    await _analytics.logEvent(
      name: 'shift_quick_action',
      parameters: {
        'action': action, // "staff_change", "date_move", "staff_swap"
      },
    );
  }

  /// 勤務希望日を設定したイベント
  static Future<void> logPreferredDatesSet({
    required int count,
  }) async {
    await _analytics.logEvent(
      name: 'preferred_dates_set',
      parameters: {
        'count': count,
      },
    );
  }

  /// 自動割り当てで勤務希望日が考慮されたイベント
  static Future<void> logPreferredDatesAssigned({
    required int totalPreferences,
    required int granted,
  }) async {
    await _analytics.logEvent(
      name: 'preferred_dates_assigned',
      parameters: {
        'total_preferences': totalPreferences,
        'granted': granted,
      },
    );
  }

  /// 日付個別シフト設定イベント
  static Future<void> logDateSpecificRequirementSet({
    required String date,
  }) async {
    await _analytics.logEvent(
      name: 'date_specific_requirement_set',
      parameters: {
        'date': date,
      },
    );
  }
}
