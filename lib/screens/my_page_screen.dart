import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/staff.dart';
import '../models/shift.dart';
import '../models/shift_time_setting.dart';
import '../models/constraint_request.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/constraint_request_provider.dart';
import '../models/shift_type.dart' as old_shift_type;
import '../utils/japanese_calendar_utils.dart';

/// マイページ画面（自分のシフト確認・休み希望入力）
class MyPageScreen extends StatefulWidget {
  final AppUser appUser;

  const MyPageScreen({
    super.key,
    required this.appUser,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  /// 自分のスタッフ情報を取得（userIdで照合）
  Staff? _getMyStaff(StaffProvider staffProvider) {
    final myUid = widget.appUser.uid;

    debugPrint('🔍 [MyPage] ログインユーザー: ${widget.appUser.email} (uid: $myUid)');
    debugPrint('🔍 [MyPage] 全スタッフ数: ${staffProvider.staff.length}');

    for (var staff in staffProvider.staff) {
      debugPrint('  - ${staff.name}: userId=${staff.userId}, email=${staff.email}');
    }

    // 1. userIdで紐付けられているスタッフを探す（優先）
    try {
      final foundStaff = staffProvider.staff.firstWhere(
        (staff) => staff.userId != null && staff.userId == myUid,
      );
      debugPrint('✅ [MyPage] userIdで紐付け成功: ${foundStaff.name}');
      return foundStaff;
    } catch (e) {
      debugPrint('⚠️ [MyPage] userIdで紐付け失敗、メールアドレスで再試行');
      // userIdで見つからない場合、メールアドレスで照合（フォールバック）
      final userEmail = widget.appUser.email;
      if (userEmail.isNotEmpty) {
        try {
          final foundStaff = staffProvider.staff.firstWhere(
            (staff) => staff.email != null && staff.email!.toLowerCase() == userEmail.toLowerCase(),
          );
          debugPrint('✅ [MyPage] メールアドレスで紐付け成功: ${foundStaff.name}');
          return foundStaff;
        } catch (e) {
          debugPrint('❌ [MyPage] メールアドレスでも紐付け失敗');
        }
      }
    }

    debugPrint('❌ [MyPage] スタッフが見つかりませんでした');
    return null; // 紐付けられたスタッフが見つからない
  }

  /// 指定日の自分のシフトを取得
  List<Shift> _getMyShiftsForDay(DateTime day, ShiftProvider shiftProvider, Staff? myStaff) {
    if (myStaff == null) return [];

    return shiftProvider.getShiftsForDate(day)
        .where((shift) => shift.staffId == myStaff.id)
        .toList();
  }

  /// シフトタイプ名から色を取得
  Color _getShiftTypeColor(String shiftTypeName, ShiftTimeProvider shiftTimeProvider) {
    final setting = shiftTimeProvider.settings
        .where((s) => s.displayName == shiftTypeName)
        .firstOrNull;

    if (setting != null) {
      return setting.shiftType.color;
    }

    return old_shift_type.ShiftType.getColor(shiftTypeName);
  }

  /// シフトの時間をフォーマット（HH:MM-HH:MM形式）
  String _formatShiftTime(Shift shift) {
    final startHour = shift.startTime.hour.toString().padLeft(2, '0');
    final startMinute = shift.startTime.minute.toString().padLeft(2, '0');
    final endHour = shift.endTime.hour.toString().padLeft(2, '0');
    final endMinute = shift.endTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMinute-$endHour:$endMinute';
  }

  /// 今後の自分のシフトを取得（今日から30日間）
  List<Shift> _getUpcomingShifts(ShiftProvider shiftProvider, Staff? myStaff) {
    if (myStaff == null) {
      debugPrint('⚠️ [MyPage] myStaffがnullのため今後の予定を取得できません');
      return [];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // 時刻を00:00:00にリセット
    final endDate = today.add(const Duration(days: 30));

    debugPrint('🔍 [MyPage] 今後の予定検索: ${myStaff.name} (staffId: ${myStaff.id})');
    debugPrint('🔍 [MyPage] 全シフト数: ${shiftProvider.shifts.length}');
    debugPrint('🔍 [MyPage] 検索期間: ${today.toString().substring(0, 10)} 〜 ${endDate.toString().substring(0, 10)}');

    final upcomingShifts = shiftProvider.shifts
        .where((shift) {
          final isMyShift = shift.staffId == myStaff.id;
          final isInRange = (shift.date.isAfter(today.subtract(const Duration(days: 1))) ||
                            shift.date.isAtSameMomentAs(today)) &&
                           shift.date.isBefore(endDate);

          if (isMyShift) {
            debugPrint('  - ${shift.date.toString().substring(0, 10)}: ${shift.shiftType} (範囲内: $isInRange)');
          }

          return isMyShift && isInRange;
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    debugPrint('✅ [MyPage] 今後の予定: ${upcomingShifts.length}件');
    return upcomingShifts;
  }

  /// 曜日の申請状態を取得
  ConstraintRequest? _getWeekdayRequest(int weekday, List<ConstraintRequest> requests) {
    // pendingステータスのリクエストのみ取得（承認済み・却下済みは除外）
    return requests
        .where((r) =>
            r.requestType == ConstraintRequest.typeWeekday &&
            r.weekday == weekday &&
            r.status == ConstraintRequest.statusPending)
        .firstOrNull;
  }

  /// 特定日の申請状態を取得
  ConstraintRequest? _getSpecificDayRequest(DateTime date, List<ConstraintRequest> requests) {
    // pendingステータスのリクエストのみ取得（承認済み・却下済みは除外）
    return requests
        .where((r) =>
            r.requestType == ConstraintRequest.typeSpecificDay &&
            r.specificDate != null &&
            r.specificDate!.year == date.year &&
            r.specificDate!.month == date.month &&
            r.specificDate!.day == date.day &&
            r.status == ConstraintRequest.statusPending)
        .firstOrNull;
  }

  /// シフトタイプの申請状態を取得
  ConstraintRequest? _getShiftTypeRequest(String shiftType, List<ConstraintRequest> requests) {
    // pendingステータスのリクエストのみ取得（承認済み・却下済みは除外）
    return requests
        .where((r) =>
            r.requestType == ConstraintRequest.typeShiftType &&
            r.shiftType == shiftType &&
            r.status == ConstraintRequest.statusPending)
        .firstOrNull;
  }

  /// 申請状態バッジを表示（スタッフのみ、管理者は表示しない）
  Widget? _buildStatusBadge(ConstraintRequest? request, {bool compactMode = false}) {
    // 管理者の場合はバッジを表示しない（即時反映のため）
    if (widget.appUser.isAdmin) {
      debugPrint('⚠️ [StatusBadge] 管理者なのでバッジ非表示: ${widget.appUser.email}');
      return null;
    }

    // スタッフの場合
    if (request == null) {
      // 申請なし = バッジなし（承認済みデータはStaffに保存されている）
      return null;
    }

    debugPrint('🔍 [StatusBadge] リクエスト: type=${request.requestType}, status=${request.status}, isDelete=${request.isDelete}');

    // 申請あり
    if (request.status == ConstraintRequest.statusPending) {
      // 承認待ち（削除申請か追加申請かで表示を分ける）
      if (request.isDelete) {
        debugPrint('✅ [StatusBadge] 削除申請中バッジを表示 (compactMode: $compactMode)');
        // 削除申請中
        if (compactMode) {
          // コンパクトモード：アイコンのみ（Chip内で使用）
          return Tooltip(
            message: '削除申請中',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 4),
                Icon(Icons.delete_outline, size: 14, color: Colors.red.shade700),
              ],
            ),
          );
        } else {
          // 通常モード：アイコン + テキスト（特定日で使用）
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              Icon(Icons.delete_outline, size: 14, color: Colors.red.shade700),
              const SizedBox(width: 2),
              Text(
                '削除申請中',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }
      } else {
        // 追加申請中
        if (compactMode) {
          return Tooltip(
            message: '追加申請中',
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 4),
                Icon(Icons.schedule, size: 14, color: Colors.orange),
              ],
            ),
          );
        } else {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 4),
              Icon(Icons.schedule, size: 14, color: Colors.orange),
            ],
          );
        }
      }
    }

    // 承認済み（approved）・却下済み（rejected）の場合はバッジなし
    return null;
  }

  /// 直近のシフトを取得（今日から7日間 + 該当なしの場合は次回1件）
  List<Shift> _getImmediateShifts(ShiftProvider shiftProvider, Staff? myStaff) {
    if (myStaff == null) {
      debugPrint('⚠️ [MyPage Immediate] myStaffがnullのため直近の予定を取得できません');
      return [];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    debugPrint('🔍 [MyPage Immediate] 直近予定検索: ${myStaff.name} (staffId: ${myStaff.id})');
    debugPrint('🔍 [MyPage Immediate] 全シフト数: ${shiftProvider.shifts.length}');

    // 自分のシフトを日付順にソート
    final myShifts = shiftProvider.shifts
        .where((shift) => shift.staffId == myStaff.id)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    debugPrint('🔍 [MyPage Immediate] 自分のシフト数: ${myShifts.length}件');

    final oneWeekLater = today.add(const Duration(days: 7));

    // 1. 今日から7日間のシフトを取得
    final shiftsWithinWeek = myShifts
        .where((shift) =>
            !shift.date.isBefore(today) && shift.date.isBefore(oneWeekLater))
        .toList();

    if (shiftsWithinWeek.isNotEmpty) {
      debugPrint('✅ [MyPage Immediate] 1週間以内の予定: ${shiftsWithinWeek.length}件');
      return shiftsWithinWeek;
    }

    // 2. 1週間以内に予定がない場合は、次回の予定を1件だけ表示
    final nextShift = myShifts.where((shift) => shift.date.isAfter(today)).firstOrNull;

    if (nextShift != null) {
      debugPrint('✅ [MyPage Immediate] 次回の予定1件: ${nextShift.date.toString().substring(0, 10)}');
      return [nextShift];
    }

    debugPrint('✅ [MyPage Immediate] 直近の予定: なし');
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<StaffProvider, ShiftProvider, ShiftTimeProvider, ConstraintRequestProvider>(
      builder: (context, staffProvider, shiftProvider, shiftTimeProvider, requestProvider, child) {
        final myStaff = _getMyStaff(staffProvider);
        final immediateShifts = _getImmediateShifts(shiftProvider, myStaff);

        // 自分の申請を取得
        final myRequests = myStaff != null
            ? requestProvider.getRequestsByStaffId(myStaff.id)
            : <ConstraintRequest>[];

        if (myStaff == null) {
          // 管理者の場合
          if (widget.appUser.isAdmin) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'マイページはスタッフのシフト確認用です',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'あなたは管理者のため、現在シフトデータは表示されません。',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'ご自身もシフトに入る場合',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. スタッフ管理画面を開く\n'
                            '2. ご自身をスタッフとして登録\n'
                            '3. メールアドレスに以下を設定:\n'
                            '   ${widget.appUser.email}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[800],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // スタッフの場合
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'スタッフ情報が見つかりません',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'あなたのアカウントに紐付けられたスタッフ情報がありません。',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.appUser.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, size: 20, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              '考えられる原因',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• 管理者がまだスタッフ登録を行っていない\n'
                          '• スタッフ登録は済んでいるが、メールアドレスが一致しない',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.arrow_forward, size: 20, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              '管理者にご依頼ください',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• スタッフ登録（未登録の場合）\n'
                          '• スタッフ編集でメールアドレスの確認・修正\n'
                          '  （登録済みの場合）',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ヘッダー
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    myStaff.name.substring(0, 1),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        myStaff.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        myStaff.email ?? widget.appUser.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 【最優先】今日から1週間の予定
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.today, size: 24, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '今日から1週間の予定',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (immediateShifts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          '今後の勤務予定はありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...immediateShifts.map((shift) {
                        final color = _getShiftTypeColor(shift.shiftType, shiftTimeProvider);
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final tomorrow = today.add(const Duration(days: 1));

                        // 日付ラベルの決定
                        String dayLabel;
                        if (isSameDay(shift.date, today)) {
                          dayLabel = '今日';
                        } else if (isSameDay(shift.date, tomorrow)) {
                          dayLabel = '明日';
                        } else {
                          // それ以降の日付
                          final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
                          final weekday = weekdays[shift.date.weekday - 1];
                          dayLabel = '${shift.date.month}/${shift.date.day}($weekday)';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${shift.shiftType} (${_formatShiftTime(shift)})',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // カレンダー（折りたたみ式）
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text(
                  'カレンダーで確認',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('タップして展開'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 年月表示と前後の矢印
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                final newMonth = DateTime(
                                  _focusedDay.year,
                                  _focusedDay.month - 1,
                                  1,
                                );
                                setState(() {
                                  _focusedDay = newMonth;
                                  _selectedDay = null;
                                });
                                // ShiftProviderに表示月を通知（データ取得範囲を更新）
                                shiftProvider.setCurrentMonth(newMonth);
                              },
                              tooltip: '前月',
                            ),
                            Text(
                              '${_focusedDay.year}年${_focusedDay.month}月',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                final newMonth = DateTime(
                                  _focusedDay.year,
                                  _focusedDay.month + 1,
                                  1,
                                );
                                setState(() {
                                  _focusedDay = newMonth;
                                  _selectedDay = null;
                                });
                                // ShiftProviderに表示月を通知（データ取得範囲を更新）
                                shiftProvider.setCurrentMonth(newMonth);
                              },
                              tooltip: '次月',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // カレンダー内部のスクロール通知を無視
                            return true;
                          },
                          child: TableCalendar<Shift>(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: CalendarFormat.month,
                            locale: 'ja_JP',
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            eventLoader: (day) => _getMyShiftsForDay(day, shiftProvider, myStaff),
                            startingDayOfWeek: StartingDayOfWeek.sunday,
                            daysOfWeekVisible: true,
                            availableCalendarFormats: const {
                              CalendarFormat.month: '月',
                            },
                            rowHeight: 40.0,
                            sixWeekMonthsEnforced: true,
                            calendarStyle: const CalendarStyle(
                              outsideDaysVisible: false,
                              selectedDecoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              weekendTextStyle: TextStyle(color: Colors.red, fontSize: 12),
                              holidayTextStyle: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            headerVisible: false,
                            pageJumpingEnabled: false,
                            pageAnimationEnabled: false,
                            onDaySelected: (selectedDay, focusedDay) {
                              if (!isSameDay(_selectedDay, selectedDay)) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              }
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                                _selectedDay = null;
                              });
                            },
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, shifts) {
                                if (shifts.isEmpty) return null;
                                // シフトを時間順にソート
                                final sortedShifts = List<Shift>.from(shifts)
                                  ..sort((a, b) => a.startTime.compareTo(b.startTime));

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: sortedShifts.take(3).map((shift) {
                                    final color = _getShiftTypeColor(shift.shiftType, shiftTimeProvider);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              dowBuilder: (context, day) {
                                final text = JapaneseCalendarUtils.getJapaneseDayOfWeek(day);
                                return Center(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: day.weekday == DateTime.saturday
                                          ? Colors.blue
                                          : day.weekday == DateTime.sunday
                                          ? Colors.red
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                              defaultBuilder: (context, day, focusedDay) {
                                final isHoliday = holiday_jp.isHoliday(day);
                                return Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: isHoliday || day.weekday == DateTime.sunday
                                          ? Colors.red
                                          : day.weekday == DateTime.saturday
                                          ? Colors.blue
                                          : Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const Divider(),
                        // 選択日のシフト
                        if (_selectedDay != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedDay!.month}/${_selectedDay!.day}(${['月', '火', '水', '木', '金', '土', '日'][_selectedDay!.weekday % 7]})のシフト',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...() {
                            final shifts = _getMyShiftsForDay(_selectedDay!, shiftProvider, myStaff);
                            if (shifts.isEmpty) {
                              return [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'この日のシフトはありません',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ];
                            }
                            return shifts.map((shift) {
                              final color = _getShiftTypeColor(shift.shiftType, shiftTimeProvider);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  title: Text(shift.shiftType),
                                  subtitle: Text(_formatShiftTime(shift)),
                                ),
                              );
                            }).toList();
                          }(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 特定日の休み希望（重要）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_busy, size: 20, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '特定日の休み希望',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditConstraintsDialog(myStaff, shiftTimeProvider, myRequests),
                          tooltip: '編集',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    () {
                      // 今月の初日を計算
                      final now = DateTime.now();
                      final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

                      // Staffデータの特定日（承認済み、今月以降のみ）
                      final approvedDates = myStaff.specificDaysOff.map((dateStr) {
                        try {
                          return DateTime.parse(dateStr);
                        } catch (e) {
                          return null;
                        }
                      }).whereType<DateTime>()
                          .where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1))))
                          .toList();

                      // 承認待ちの特定日申請（今月以降のみ、却下済みは除外）
                      final pendingRequests = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeSpecificDay &&
                              r.specificDate != null &&
                              r.specificDate!.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1))) &&
                              r.status == ConstraintRequest.statusPending)
                          .toList();

                      // マージしてユニークな日付リストを作成
                      final allDates = <DateTime>{};
                      allDates.addAll(approvedDates);
                      allDates.addAll(pendingRequests.map((r) => r.specificDate!));

                      // 日付順にソート
                      final sortedDates = allDates.toList()..sort();

                      if (sortedDates.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            '特定日の休み希望はありません\n右上の編集ボタンから追加できます',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortedDates.map((date) {
                          final displayText = DateFormat('yyyy/MM/dd(E)', 'ja').format(date);
                          final request = _getSpecificDayRequest(date, myRequests);
                          return Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(displayText),
                                if (_buildStatusBadge(request) != null)
                                  _buildStatusBadge(request)!,
                              ],
                            ),
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide(color: Colors.red.shade300),
                          );
                        }).toList(),
                      );
                    }(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 最近の申請状況（承認・却下）
            () {
              // 承認済み・却下されたリクエストを取得（直近7日以内、最大5件）
              final now = DateTime.now();
              final sevenDaysAgo = now.subtract(const Duration(days: 7));

              final recentRequests = myRequests
                  .where((r) =>
                      (r.status == ConstraintRequest.statusApproved ||
                          r.status == ConstraintRequest.statusRejected) &&
                      r.updatedAt.isAfter(sevenDaysAgo))
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // 新しい順

              final displayRequests = recentRequests.take(5).toList();

              if (displayRequests.isEmpty) {
                return const SizedBox.shrink(); // 何も表示しない
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_active, size: 20, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '最近の申請状況',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => _showRequestHistoryDialog(myRequests),
                            child: const Text('すべて見る'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...displayRequests.map((request) {
                        final isApproved = request.status == ConstraintRequest.statusApproved;
                        String contentText = '';
                        String actionText = '';

                        if (request.requestType == ConstraintRequest.typeSpecificDay && request.specificDate != null) {
                          contentText = '${DateFormat('MM/dd(E)', 'ja').format(request.specificDate!)}の休み希望';
                          actionText = request.isDelete ? 'を削除' : 'を追加';
                        } else if (request.requestType == ConstraintRequest.typeWeekday && request.weekday != null) {
                          final dayNames = ['月', '火', '水', '木', '金', '土', '日'];
                          contentText = '${dayNames[request.weekday! - 1]}曜の休み希望';
                          actionText = request.isDelete ? 'を削除' : 'を追加';
                        } else if (request.requestType == ConstraintRequest.typeShiftType && request.shiftType != null) {
                          contentText = '${request.shiftType}の勤務不可';
                          actionText = request.isDelete ? 'を削除' : 'を追加';
                        } else if (request.requestType == ConstraintRequest.typeMaxShiftsPerMonth && request.maxShiftsPerMonth != null) {
                          contentText = '月間最大シフト数を${request.maxShiftsPerMonth}日に変更';
                          actionText = '';
                        }

                        // 却下理由がある場合のみ表示（空文字列もチェック）
                        final hasReason = !isApproved &&
                            request.rejectedReason != null &&
                            request.rejectedReason!.trim().isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isApproved ? Colors.green.shade300 : Colors.orange.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isApproved ? Icons.check_circle : Icons.cancel,
                                    color: isApproved ? Colors.green.shade700 : Colors.orange.shade700,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$contentText$actionText → ${isApproved ? '承認' : '却下'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isApproved ? Colors.green.shade900 : Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasReason) ...[
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 26),
                                  child: Text(
                                    '理由: ${request.rejectedReason}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }(),
            const SizedBox(height: 16),

            // その他の制約（休み希望曜日、勤務不可シフトタイプ）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.settings, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'その他の制約',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditConstraintsDialog(myStaff, shiftTimeProvider, myRequests),
                          tooltip: '編集',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 休み希望曜日
                    const Text(
                      '休み希望曜日',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    () {
                      // Staffデータの曜日（承認済み、1-7の範囲内）
                      final approvedDays = myStaff.preferredDaysOff
                          .where((dayNumber) => dayNumber >= 1 && dayNumber <= 7)
                          .toSet();

                      // 承認待ちの曜日申請（却下済みは除外）
                      final pendingRequests = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeWeekday &&
                              r.weekday != null &&
                              r.weekday! >= 1 &&
                              r.weekday! <= 7 &&
                              r.status == ConstraintRequest.statusPending)
                          .toList();

                      // マージしてユニークな曜日リストを作成
                      final allDays = <int>{};
                      allDays.addAll(approvedDays);
                      allDays.addAll(pendingRequests.map((r) => r.weekday!));

                      // 曜日順にソート
                      final sortedDays = allDays.toList()..sort();

                      if (sortedDays.isEmpty) {
                        return const Text(
                          'なし',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortedDays.map((dayNumber) {
                          final dayNames = ['月', '火', '水', '木', '金', '土', '日'];
                          final dayName = dayNames[dayNumber - 1];
                          final request = _getWeekdayRequest(dayNumber, myRequests);
                          return SizedBox(
                            width: 80, // 固定幅
                            child: Chip(
                              label: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dayName,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (_buildStatusBadge(request, compactMode: true) != null)
                                      _buildStatusBadge(request, compactMode: true)!,
                                  ],
                                ),
                              ),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              side: const BorderSide(color: Colors.blue, width: 1),
                            ),
                          );
                        }).toList(),
                      );
                    }(),

                    const SizedBox(height: 16),

                    // 勤務不可シフトタイプ
                    const Text(
                      '勤務不可シフトタイプ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    () {
                      // Staffデータのシフトタイプ（承認済み）
                      final approvedTypes = myStaff.unavailableShiftTypes.toSet();

                      // 承認待ちのシフトタイプ申請（却下済みは除外）
                      final pendingRequests = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeShiftType &&
                              r.shiftType != null &&
                              r.status == ConstraintRequest.statusPending)
                          .toList();

                      // マージしてユニークなシフトタイプリストを作成
                      final allTypes = <String>{};
                      allTypes.addAll(approvedTypes);
                      allTypes.addAll(pendingRequests.map((r) => r.shiftType!));

                      if (allTypes.isEmpty) {
                        return const Text(
                          'なし',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      // 時間順にソート（shiftTimeProviderのsettings順序に従う）
                      final sortedTypes = <String>[];
                      for (final setting in shiftTimeProvider.settings) {
                        if (setting.isActive && allTypes.contains(setting.displayName)) {
                          sortedTypes.add(setting.displayName);
                        }
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortedTypes.map((shiftTypeName) {
                          final color = _getShiftTypeColor(shiftTypeName, shiftTimeProvider);
                          final request = _getShiftTypeRequest(shiftTypeName, myRequests);
                          return Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  shiftTypeName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (_buildStatusBadge(request, compactMode: true) != null) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusBadge(request, compactMode: true)!,
                                ],
                              ],
                            ),
                            backgroundColor: color.withOpacity(0.1),
                            side: BorderSide(color: color, width: 1),
                          );
                        }).toList(),
                      );
                    }(),

                    const SizedBox(height: 16),

                    // 月間最大シフト数
                    const Text(
                      '月間最大シフト数',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    () {
                      // 承認済みの月間最大シフト数（0は未設定とみなす）
                      final approvedMaxShifts = myStaff.maxShiftsPerMonth;

                      // 承認待ちの月間最大シフト数申請（却下済みは除外）
                      final pendingRequest = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeMaxShiftsPerMonth &&
                              r.maxShiftsPerMonth != null &&
                              r.status == ConstraintRequest.statusPending)
                          .firstOrNull;

                      // 表示する値（承認待ちがあればそれを優先、0は未設定）
                      final displayMaxShifts = pendingRequest?.maxShiftsPerMonth ?? (approvedMaxShifts > 0 ? approvedMaxShifts : null);

                      return Row(
                        children: [
                          Text(
                            displayMaxShifts != null ? '$displayMaxShifts日' : '未設定',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: displayMaxShifts != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          if (pendingRequest != null && _buildStatusBadge(pendingRequest, compactMode: true) != null) ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge(pendingRequest, compactMode: true)!,
                          ],
                        ],
                      );
                    }(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 休み希望・制約編集ダイアログ
  void _showEditConstraintsDialog(
    Staff myStaff,
    ShiftTimeProvider shiftTimeProvider,
    List<ConstraintRequest> myRequests,
  ) {
    // Staffデータ（承認済み）を初期値として取得
    final approvedDays = List<int>.from(myStaff.preferredDaysOff);
    final approvedShiftTypes = List<String>.from(myStaff.unavailableShiftTypes);
    final approvedSpecificDays = myStaff.specificDaysOff
        .map((dateStr) {
          try {
            final parsed = DateTime.parse(dateStr);
            return DateTime(parsed.year, parsed.month, parsed.day);
          } catch (e) {
            // 古い形式（YYYY-MM-DD）の場合
            final parts = dateStr.split('-');
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        })
        .toList();
    final approvedMaxShifts = myStaff.maxShiftsPerMonth > 0 ? myStaff.maxShiftsPerMonth : null; // 0は未設定とみなす

    // 承認待ち・却下の申請も含める
    final selectedDays = approvedDays.toSet();
    final selectedShiftTypes = approvedShiftTypes.toSet();
    final selectedSpecificDays = approvedSpecificDays.toSet();
    int? selectedMaxShifts = approvedMaxShifts;

    // 承認待ちの曜日申請を反映（却下済みは除外）
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeWeekday &&
          request.weekday != null &&
          request.status == ConstraintRequest.statusPending) {
        if (request.isDelete) {
          // 削除申請：リストから削除
          selectedDays.remove(request.weekday!);
        } else {
          // 追加申請：リストに追加
          selectedDays.add(request.weekday!);
        }
      }
    }

    // 承認待ちのシフトタイプ申請を反映（却下済みは除外）
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeShiftType &&
          request.shiftType != null &&
          request.status == ConstraintRequest.statusPending) {
        if (request.isDelete) {
          // 削除申請：リストから削除
          selectedShiftTypes.remove(request.shiftType!);
        } else {
          // 追加申請：リストに追加
          selectedShiftTypes.add(request.shiftType!);
        }
      }
    }

    // 承認待ちの特定日申請を反映（却下済みは除外）
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeSpecificDay &&
          request.specificDate != null &&
          request.status == ConstraintRequest.statusPending) {
        if (request.isDelete) {
          // 削除申請：リストから削除
          selectedSpecificDays.removeWhere((date) =>
              date.year == request.specificDate!.year &&
              date.month == request.specificDate!.month &&
              date.day == request.specificDate!.day);
        } else {
          // 追加申請：リストに追加
          selectedSpecificDays.add(request.specificDate!);
        }
      }
    }

    // 承認待ちの月間最大シフト数申請を反映（却下済みは除外）
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeMaxShiftsPerMonth &&
          request.maxShiftsPerMonth != null &&
          request.status == ConstraintRequest.statusPending) {
        selectedMaxShifts = request.maxShiftsPerMonth;
      }
    }

    // 外側のcontextを保存
    final outerContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('休み希望・制約の編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 特定日の休み希望（最重要）
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '特定日の休み希望',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              final selectedDate = DateTime(date.year, date.month, date.day);
                              setDialogState(() {
                                if (!selectedSpecificDays.any((d) =>
                                    d.year == selectedDate.year &&
                                    d.month == selectedDate.month &&
                                    d.day == selectedDate.day)) {
                                  selectedSpecificDays.add(selectedDate);
                                  // Set doesn't need sorting - will sort when converting to List
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('追加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 今月の初日を計算
                    () {
                      final now = DateTime.now();
                      final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

                      // 今月以降の休み希望日のみ表示（日付順にソート）
                      final visibleDays = selectedSpecificDays
                          .where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1))))
                          .toList()
                          ..sort((a, b) => a.compareTo(b));

                      if (visibleDays.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            '特定日の休み希望はありません\n右上の「追加」ボタンから追加できます',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: visibleDays.map((date) {
                          final displayText = '${date.month}/${date.day}';
                          return Chip(
                            label: Text(displayText),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setDialogState(() {
                                selectedSpecificDays.removeWhere((d) =>
                                    d.year == date.year &&
                                    d.month == date.month &&
                                    d.day == date.day);
                              });
                            },
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide(color: Colors.red.shade300),
                          );
                        }).toList(),
                      );
                    }(),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // 休み希望曜日
                    const Text(
                      '休み希望曜日',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (index) {
                        final dayNumber = index + 1; // 1-7
                        final dayNames = ['月', '火', '水', '木', '金', '土', '日'];
                        final dayName = dayNames[index];
                        final isSelected = selectedDays.contains(dayNumber);
                        return SizedBox(
                          width: 80, // 全てのチップを同じ幅に統一
                          child: FilterChip(
                            label: Center(
                              child: Text(
                                dayName,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(dayNumber);
                                } else {
                                  selectedDays.remove(dayNumber);
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // 勤務不可シフトタイプ
                    const Text(
                      '勤務不可シフトタイプ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shiftTimeProvider.settings
                          .where((setting) => setting.isActive)
                          .map((setting) {
                        final shiftTypeName = setting.displayName;
                        final isSelected = selectedShiftTypes.contains(shiftTypeName);
                        final color = setting.shiftType.color;
                        return SizedBox(
                          width: 100, // 固定幅
                          child: FilterChip(
                            label: Center(
                              child: Text(
                                shiftTypeName,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedShiftTypes.add(shiftTypeName);
                                } else {
                                  selectedShiftTypes.remove(shiftTypeName);
                                }
                              });
                            },
                            selectedColor: color,
                            backgroundColor: color.withOpacity(0.1),
                            side: BorderSide(color: color, width: 1),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // 月間最大シフト数
                    const Text(
                      '月間最大シフト数',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: selectedMaxShifts?.toString() ?? '',
                            decoration: const InputDecoration(
                              hintText: '未設定',
                              suffixText: '日',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              setDialogState(() {
                                selectedMaxShifts = parsed;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (selectedMaxShifts != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setDialogState(() {
                                selectedMaxShifts = null;
                              });
                            },
                            tooltip: 'クリア',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () async {
                    // 管理者かスタッフかで処理を分岐
                    if (widget.appUser.isAdmin) {
                      // 【管理者】即時反映（従来通り）
                      await _saveAsAdmin(
                        outerContext,
                        dialogContext,
                        myStaff,
                        selectedDays.toList(),
                        (selectedSpecificDays.toList()..sort((a, b) => a.compareTo(b))),
                        selectedShiftTypes.toList(),
                        selectedMaxShifts,
                      );
                    } else {
                      // 【スタッフ】申請作成
                      await _saveAsStaff(
                        outerContext,
                        dialogContext,
                        myStaff,
                        selectedDays.toList(),
                        (selectedSpecificDays.toList()..sort((a, b) => a.compareTo(b))),
                        selectedShiftTypes.toList(),
                        selectedMaxShifts,
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 【管理者】即時反映（従来通り）
  Future<void> _saveAsAdmin(
    BuildContext outerContext,
    BuildContext dialogContext,
    Staff myStaff,
    List<int> selectedDays,
    List<DateTime> selectedSpecificDays,
    List<String> selectedShiftTypes,
    int? selectedMaxShifts,
  ) async {
    // DateTimeのリストをISO8601文字列のリストに変換
    final specificDaysOffStrings = selectedSpecificDays
        .map((date) => DateTime(date.year, date.month, date.day).toIso8601String())
        .toList();

    // Firestore更新（外側のcontextを使用）
    final staffProvider = outerContext.read<StaffProvider>();
    final updatedStaff = Staff(
      id: myStaff.id,
      name: myStaff.name,
      phoneNumber: myStaff.phoneNumber,
      email: myStaff.email,
      maxShiftsPerMonth: selectedMaxShifts ?? 0, // nullの場合は0（自動割り当て対象外）
      preferredDaysOff: List.from(selectedDays),
      isActive: myStaff.isActive,
      createdAt: myStaff.createdAt,
      updatedAt: DateTime.now(),
      constraints: myStaff.constraints,
      unavailableShiftTypes: List.from(selectedShiftTypes),
      specificDaysOff: specificDaysOffStrings,
      userId: myStaff.userId,
    );

    await staffProvider.updateStaff(updatedStaff);

    if (outerContext.mounted) {
      Navigator.pop(dialogContext);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// 【スタッフ】申請作成
  Future<void> _saveAsStaff(
    BuildContext outerContext,
    BuildContext dialogContext,
    Staff myStaff,
    List<int> selectedDays,
    List<DateTime> selectedSpecificDays,
    List<String> selectedShiftTypes,
    int? selectedMaxShifts,
  ) async {
    final requestProvider = outerContext.read<ConstraintRequestProvider>();
    final uuid = const Uuid();

    // 既存の制約を取得（承認済みのデータ）
    final approvedDays = myStaff.preferredDaysOff;
    final approvedSpecificDays = myStaff.specificDaysOff
        .map((dateStr) => DateTime.parse(dateStr))
        .toList();
    final approvedShiftTypes = myStaff.unavailableShiftTypes;
    final approvedMaxShifts = myStaff.maxShiftsPerMonth > 0 ? myStaff.maxShiftsPerMonth : null; // 0は未設定とみなす

    // 既存のpending申請を取得
    final myRequests = requestProvider.getRequestsByUserId(widget.appUser.uid);

    // 【重要】既存のpending申請のみ削除してから、新しい内容で再作成（rejectedは履歴として残す）
    for (final request in myRequests) {
      if (request.status == ConstraintRequest.statusPending) {
        await requestProvider.deleteRequest(request.id);
      }
    }

    // 編集後の内容で新規申請を作成（追加と削除の両方に対応）
    int newRequestCount = 0;

    // 1. 曜日の休み希望
    debugPrint('🔍 [申請作成] approvedDays: $approvedDays');
    debugPrint('🔍 [申請作成] selectedDays: $selectedDays');

    // 追加申請：selectedDaysにあるが、approvedDays（承認済み）にない
    for (final day in selectedDays) {
      if (!approvedDays.contains(day)) {
        debugPrint('✅ [曜日追加申請] 曜日 $day を追加申請');
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeWeekday,
          weekday: day,
          status: ConstraintRequest.statusPending,
          isDelete: false,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }
    // 削除申請：approvedDays（承認済み）にあるが、selectedDaysにない
    for (final day in approvedDays) {
      if (!selectedDays.contains(day)) {
        debugPrint('✅ [曜日削除申請] 曜日 $day の削除申請を作成');
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeWeekday,
          weekday: day,
          status: ConstraintRequest.statusPending,
          isDelete: true,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }

    // 2. 特定日の休み希望
    debugPrint('🔍 [申請作成] approvedSpecificDays: $approvedSpecificDays');
    debugPrint('🔍 [申請作成] selectedSpecificDays: $selectedSpecificDays');

    // 追加申請：selectedSpecificDaysにあるが、approvedSpecificDays（承認済み）にない
    for (final date in selectedSpecificDays) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final isApproved = approvedSpecificDays.any((approved) =>
          approved.year == normalizedDate.year &&
          approved.month == normalizedDate.month &&
          approved.day == normalizedDate.day);

      if (!isApproved) {
        debugPrint('✅ [特定日追加申請] $normalizedDate を追加申請');
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeSpecificDay,
          specificDate: normalizedDate,
          status: ConstraintRequest.statusPending,
          isDelete: false,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }
    // 削除申請：approvedSpecificDays（承認済み）にあるが、selectedSpecificDaysにない
    for (final approvedDate in approvedSpecificDays) {
      final normalizedApproved = DateTime(approvedDate.year, approvedDate.month, approvedDate.day);
      final isSelected = selectedSpecificDays.any((selected) =>
          selected.year == normalizedApproved.year &&
          selected.month == normalizedApproved.month &&
          selected.day == normalizedApproved.day);

      if (!isSelected) {
        debugPrint('✅ [特定日削除申請] $normalizedApproved の削除申請を作成');
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeSpecificDay,
          specificDate: normalizedApproved,
          status: ConstraintRequest.statusPending,
          isDelete: true,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }

    // 3. シフトタイプの勤務不可
    debugPrint('🔍 [申請作成] approvedShiftTypes: $approvedShiftTypes');
    debugPrint('🔍 [申請作成] selectedShiftTypes: $selectedShiftTypes');

    // 追加申請：selectedShiftTypesにあるが、approvedShiftTypes（承認済み）にない
    for (final shiftType in selectedShiftTypes) {
      if (!approvedShiftTypes.contains(shiftType)) {
        debugPrint('✅ [シフトタイプ追加申請] $shiftType を追加申請');
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeShiftType,
          shiftType: shiftType,
          status: ConstraintRequest.statusPending,
          isDelete: false,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }
    // 削除申請：approvedShiftTypes（承認済み）にあるが、selectedShiftTypesにない
    for (final shiftType in approvedShiftTypes) {
      if (!selectedShiftTypes.contains(shiftType)) {
        debugPrint('✅ [シフトタイプ削除申請] $shiftType の削除申請を作成');
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeShiftType,
          shiftType: shiftType,
          status: ConstraintRequest.statusPending,
          isDelete: true,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }

    // 4. 月間最大シフト数
    debugPrint('🔍 [申請作成] approvedMaxShifts: $approvedMaxShifts');
    debugPrint('🔍 [申請作成] selectedMaxShifts: $selectedMaxShifts');

    // 月間最大シフト数が変更されている場合のみ申請作成
    if (selectedMaxShifts != approvedMaxShifts) {
      debugPrint('✅ [月間最大シフト数変更申請] $selectedMaxShifts を申請');
      final request = ConstraintRequest(
        id: uuid.v4(),
        staffId: myStaff.id,
        userId: widget.appUser.uid,
        requestType: ConstraintRequest.typeMaxShiftsPerMonth,
        maxShiftsPerMonth: selectedMaxShifts,
        status: ConstraintRequest.statusPending,
        isDelete: false,
      );
      await requestProvider.createRequest(request);
      newRequestCount++;
    }

    if (outerContext.mounted) {
      Navigator.pop(dialogContext);
      if (mounted) {
        setState(() {});
      }
      // メッセージの内容を申請件数によって変更
      final message = newRequestCount > 0
          ? '制約を申請しました。管理者の承認をお待ちください。'
          : '変更を保存しました。';
      ScaffoldMessenger.of(outerContext).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 申請履歴を全て表示するダイアログ
  void _showRequestHistoryDialog(List<ConstraintRequest> allRequests) {
    final historyRequests = allRequests
        .where((r) =>
            r.status == ConstraintRequest.statusApproved ||
            r.status == ConstraintRequest.statusRejected)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('申請履歴'),
          content: SizedBox(
            width: double.maxFinite,
            child: historyRequests.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '申請履歴がありません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: historyRequests.length,
                    itemBuilder: (context, index) {
                      final request = historyRequests[index];
                      final isApproved = request.status == ConstraintRequest.statusApproved;
                      String contentText = '';
                      String actionText = '';

                      if (request.requestType == ConstraintRequest.typeSpecificDay &&
                          request.specificDate != null) {
                        contentText = '${DateFormat('MM/dd(E)', 'ja').format(request.specificDate!)}の休み希望';
                        actionText = request.isDelete ? 'を削除' : 'を追加';
                      } else if (request.requestType == ConstraintRequest.typeWeekday &&
                          request.weekday != null) {
                        final dayNames = ['月', '火', '水', '木', '金', '土', '日'];
                        contentText = '${dayNames[request.weekday! - 1]}曜の休み希望';
                        actionText = request.isDelete ? 'を削除' : 'を追加';
                      } else if (request.requestType == ConstraintRequest.typeShiftType &&
                          request.shiftType != null) {
                        contentText = '${request.shiftType}の勤務不可';
                        actionText = request.isDelete ? 'を削除' : 'を追加';
                      } else if (request.requestType == ConstraintRequest.typeMaxShiftsPerMonth &&
                          request.maxShiftsPerMonth != null) {
                        contentText = '月間最大シフト数を${request.maxShiftsPerMonth}日に変更';
                        actionText = '';
                      }

                      final hasReason = !isApproved &&
                          request.rejectedReason != null &&
                          request.rejectedReason!.trim().isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isApproved ? Colors.green.shade300 : Colors.orange.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isApproved ? Icons.check_circle : Icons.cancel,
                                  color: isApproved ? Colors.green.shade700 : Colors.orange.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$contentText$actionText → ${isApproved ? '承認' : '却下'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isApproved ? Colors.green.shade900 : Colors.orange.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('yyyy/MM/dd HH:mm', 'ja').format(request.updatedAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (hasReason) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 26),
                                child: Text(
                                  '理由: ${request.rejectedReason}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}
