import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static const String _firstOpenDateKey = 'first_open_date';
  static int? _daysSinceInstallCache; // キャッシュ（毎回計算しない）

  /// ユーザーIDを設定（ログイン時に呼び出す）
  static Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  // ============================================================
  // インストールからの経過日数追跡（継続利用調査用）
  // ============================================================

  /// 初回起動日を記録（アプリ起動時に呼び出す）
  static Future<void> recordFirstOpenDate() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_firstOpenDateKey)) {
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_firstOpenDateKey, now);
      debugPrint('📅 [Analytics] 初回起動日を記録: $now');
    }
  }

  /// インストールからの経過日数を取得
  static Future<int> getDaysSinceInstall() async {
    // キャッシュがあれば返す（同一セッション内で何度も計算しない）
    if (_daysSinceInstallCache != null) {
      return _daysSinceInstallCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final firstOpenStr = prefs.getString(_firstOpenDateKey);
      if (firstOpenStr == null) {
        // 初回起動日が記録されていない場合は0日目
        return 0;
      }
      final firstOpen = DateTime.parse(firstOpenStr);
      final now = DateTime.now();
      _daysSinceInstallCache = now.difference(firstOpen).inDays;
      return _daysSinceInstallCache!;
    } catch (e) {
      debugPrint('⚠️ [Analytics] 経過日数取得エラー: $e');
      return 0;
    }
  }

  /// アプリ起動イベント
  static Future<void> logAppOpen() async {
    // 初回起動日を記録
    await recordFirstOpenDate();
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

  /// シフト自動作成イベント（継続利用の指標）
  static Future<void> logShiftGenerated({
    required int shiftCount,
    required String strategy,
    required String yearMonth, // "2025-12" 形式
  }) async {
    final daysSinceInstall = await getDaysSinceInstall();
    await _analytics.logEvent(
      name: 'auto_shift_generated',
      parameters: {
        'shift_count': shiftCount,
        'strategy': strategy,
        'year_month': yearMonth,
        'days_since_install': daysSinceInstall,
      },
    );
  }

  /// シフト切替イベント
  static Future<void> logShiftRestored() async {
    await _analytics.logEvent(name: 'shift_restored');
  }

  /// シフト手動編集イベント（継続利用の指標）
  static Future<void> logShiftEdited(String shiftId) async {
    final daysSinceInstall = await getDaysSinceInstall();
    await _analytics.logEvent(
      name: 'shift_edited',
      parameters: {
        'shift_id': shiftId,
        'days_since_install': daysSinceInstall,
      },
    );
  }

  /// シフト表エクスポートイベント（継続利用の指標）
  static Future<void> logShiftExported({
    required String action, // "save" or "share"
    required String format, // "pdf", "png", "excel"
    required String yearMonth, // "2025-01" 形式
  }) async {
    final daysSinceInstall = await getDaysSinceInstall();
    await _analytics.logEvent(
      name: 'shift_exported',
      parameters: {
        'action': action,
        'format': format,
        'year_month': yearMonth,
        'days_since_install': daysSinceInstall,
      },
    );
  }

  /// シフト操作イベント（スタッフ変更・日付移動・スタッフ入替）（継続利用の指標）
  static Future<void> logShiftQuickAction(String action) async {
    final daysSinceInstall = await getDaysSinceInstall();
    await _analytics.logEvent(
      name: 'shift_quick_action',
      parameters: {
        'action': action, // "staff_change", "date_move", "staff_swap"
        'days_since_install': daysSinceInstall,
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

  // ============================================================
  // ファネル分析用イベント（離脱ポイント調査）
  // ============================================================

  /// 役割選択画面表示イベント（最初の画面）
  static Future<void> logRoleSelectionViewed() async {
    await _analytics.logEvent(name: 'role_selection_viewed');
  }

  /// ウェルカム画面表示イベント（「シフト作成を始める」を押した）
  static Future<void> logWelcomeScreenViewed() async {
    await _analytics.logEvent(name: 'welcome_screen_viewed');
  }

  /// 初回セットアップウィザードの進捗イベント（ウィザード内の離脱計測用）
  /// step: 'start' | 'staff_done' | 'shifts_done' | 'requirements_done'
  ///       | 'generated' | 'skipped'
  static Future<void> logWizardStep(String step) async {
    await _analytics.logEvent(
      name: 'setup_wizard',
      parameters: {'step': step},
    );
  }

  /// スタッフ追加イベント
  static Future<void> logStaffAdded({
    required int totalStaffCount,
  }) async {
    final daysSinceInstall = await getDaysSinceInstall();
    await _analytics.logEvent(
      name: 'staff_added',
      parameters: {
        'total_staff_count': totalStaffCount,
        'days_since_install': daysSinceInstall,
      },
    );
  }

  /// シフト割り当て設定イベント（基本設定）
  static Future<void> logRequirementSet({
    required int totalShiftTypes,
    required int totalRequired,
  }) async {
    final daysSinceInstall = await getDaysSinceInstall();
    await _analytics.logEvent(
      name: 'requirement_set',
      parameters: {
        'total_shift_types': totalShiftTypes,
        'total_required': totalRequired,
        'days_since_install': daysSinceInstall,
      },
    );
  }
}
