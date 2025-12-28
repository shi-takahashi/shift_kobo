import 'package:firebase_analytics/firebase_analytics.dart';

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
}
