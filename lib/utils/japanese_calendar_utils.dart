import 'package:intl/intl.dart';

class JapaneseCalendarUtils {
  // 日本語の月名
  static String getJapaneseMonthName(DateTime date) {
    final monthNames = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ];
    return monthNames[date.month - 1];
  }

  // 日本語の曜日（短縮形）
  static String getJapaneseDayOfWeek(DateTime date) {
    final dayNames = ['月', '火', '水', '木', '金', '土', '日'];
    // DateTime.weekdayは月曜日が1、日曜日が7
    // 配列は月曜日から始まるが、日曜日を最後に配置
    if (date.weekday == 7) {
      return dayNames[6]; // 日曜日
    }
    return dayNames[date.weekday - 1];
  }

  // 日本語の曜日（完全形）
  static String getJapaneseDayOfWeekFull(DateTime date) {
    final dayNames = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
    if (date.weekday == 7) {
      return dayNames[6]; // 日曜日
    }
    return dayNames[date.weekday - 1];
  }

  // カレンダーヘッダー用のフォーマット（例：2024年9月）
  static String formatMonthYear(DateTime date) {
    return '${date.year}年${getJapaneseMonthName(date)}';
  }

  // table_calendar用のフォーマッター
  static String formatMonth(DateTime date) {
    return getJapaneseMonthName(date);
  }

  // 今日の日付の日本語表示
  static String formatToday() {
    final now = DateTime.now();
    return '${now.month}月${now.day}日（${getJapaneseDayOfWeek(now)}）';
  }
}