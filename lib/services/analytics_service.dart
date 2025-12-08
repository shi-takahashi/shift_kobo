import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// アプリ起動イベント
  static Future<void> logAppOpen() async {
    await _analytics.logEvent(name: 'app_open');
  }

  /// 画面表示イベント
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  /// シフト作成イベント
  static Future<void> logShiftGenerated({
    required int shiftCount,
    required String strategy,
  }) async {
    await _analytics.logEvent(
      name: 'shift_generated',
      parameters: {
        'shift_count': shiftCount,
        'strategy': strategy,
      },
    );
  }

  /// シフト復元イベント
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

  /// シフト削除イベント
  static Future<void> logShiftDeleted(String shiftId) async {
    await _analytics.logEvent(
      name: 'shift_deleted',
      parameters: {
        'shift_id': shiftId,
      },
    );
  }
}
