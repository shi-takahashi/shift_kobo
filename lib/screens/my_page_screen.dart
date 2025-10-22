import 'package:flutter/material.dart';
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
  CalendarFormat _calendarFormat = CalendarFormat.month;

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
    return requests
        .where((r) =>
            r.requestType == ConstraintRequest.typeWeekday &&
            r.weekday == weekday)
        .firstOrNull;
  }

  /// 特定日の申請状態を取得
  ConstraintRequest? _getSpecificDayRequest(DateTime date, List<ConstraintRequest> requests) {
    return requests
        .where((r) =>
            r.requestType == ConstraintRequest.typeSpecificDay &&
            r.specificDate != null &&
            r.specificDate!.year == date.year &&
            r.specificDate!.month == date.month &&
            r.specificDate!.day == date.day)
        .firstOrNull;
  }

  /// シフトタイプの申請状態を取得
  ConstraintRequest? _getShiftTypeRequest(String shiftType, List<ConstraintRequest> requests) {
    return requests
        .where((r) =>
            r.requestType == ConstraintRequest.typeShiftType &&
            r.shiftType == shiftType)
        .firstOrNull;
  }

  /// 申請状態バッジを表示（スタッフのみ、管理者は表示しない）
  Widget? _buildStatusBadge(ConstraintRequest? request) {
    // 管理者の場合はバッジを表示しない（即時反映のため）
    if (widget.appUser.isAdmin) {
      return null;
    }

    // スタッフの場合
    if (request == null) {
      // 申請なし = バッジなし（承認済みデータはStaffに保存されている）
      return null;
    }

    // 申請あり
    if (request.status == ConstraintRequest.statusPending) {
      // 承認待ち
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 4),
          Icon(Icons.schedule, size: 14, color: Colors.orange),
        ],
      );
    } else if (request.status == ConstraintRequest.statusRejected) {
      // 却下
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 4),
          Icon(Icons.cancel, size: 14, color: Colors.grey),
        ],
      );
    }

    // 承認済み（approved）の場合はStaffデータに反映されているはずなのでバッジなし
    return null;
  }

  /// 直近のシフトを取得（今日 + 次の勤務予定）
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

    final result = <Shift>[];
    final addedDates = <DateTime>{};

    // 1. 今日のシフトを全て追加
    for (var shift in myShifts) {
      if (shift.date.year == today.year &&
          shift.date.month == today.month &&
          shift.date.day == today.day) {
        result.add(shift);
        addedDates.add(shift.date);
        debugPrint('  ✅ 今日のシフト追加: ${shift.date.toString().substring(0, 10)} ${shift.shiftType}');
      }
    }

    // 2. 今日より後の最初のシフト日を見つけて、その日のシフトを全て追加
    DateTime? nextDate;
    for (var shift in myShifts) {
      if (shift.date.isAfter(today)) {
        nextDate = shift.date;
        debugPrint('  📅 次の勤務日を発見: ${nextDate.toString().substring(0, 10)}');
        break;
      }
    }

    if (nextDate != null && !addedDates.contains(nextDate)) {
      for (var shift in myShifts) {
        if (shift.date.year == nextDate.year &&
            shift.date.month == nextDate.month &&
            shift.date.day == nextDate.day) {
          result.add(shift);
          debugPrint('  ✅ 次の勤務シフト追加: ${shift.date.toString().substring(0, 10)} ${shift.shiftType}');
        }
      }
    }

    debugPrint('✅ [MyPage Immediate] 直近の予定: ${result.length}件');
    return result;
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

            // 【最優先】直近の予定（今日・明日）
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
                          '直近の予定',
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
                          final weekday = weekdays[shift.date.weekday % 7];
                          dayLabel = '${shift.date.month}/${shift.date.day}($weekday)';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shift.shiftType,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatShiftTime(shift),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
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

            // カレンダー（全予定）
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
                            Icon(Icons.calendar_month, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '全ての予定',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              borderRadius: BorderRadius.circular(8.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _calendarFormat = _calendarFormat == CalendarFormat.month
                                      ? CalendarFormat.week
                                      : CalendarFormat.month;
                                });
                              },
                              borderRadius: BorderRadius.circular(8.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _calendarFormat == CalendarFormat.month
                                          ? Icons.calendar_view_month
                                          : Icons.calendar_view_week,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _calendarFormat == CalendarFormat.month ? '月' : '週',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    TableCalendar<Shift>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      locale: 'ja_JP',
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: (day) => _getMyShiftsForDay(day, shiftProvider, myStaff),
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      daysOfWeekVisible: true,
                      availableCalendarFormats: const {
                        CalendarFormat.month: '月',
                        CalendarFormat.week: '週',
                      },
                      rowHeight: _calendarFormat == CalendarFormat.month ? 40.0 : 48.0,
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

                      // 承認待ち・却下の特定日申請（今月以降のみ）
                      final pendingRequests = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeSpecificDay &&
                              r.specificDate != null &&
                              r.specificDate!.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1))) &&
                              (r.status == ConstraintRequest.statusPending ||
                                  r.status == ConstraintRequest.statusRejected))
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

                      // 承認待ち・却下の曜日申請
                      final pendingRequests = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeWeekday &&
                              r.weekday != null &&
                              r.weekday! >= 1 &&
                              r.weekday! <= 7 &&
                              (r.status == ConstraintRequest.statusPending ||
                                  r.status == ConstraintRequest.statusRejected))
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
                                    if (_buildStatusBadge(request) != null)
                                      _buildStatusBadge(request)!,
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

                      // 承認待ち・却下のシフトタイプ申請
                      final pendingRequests = myRequests
                          .where((r) =>
                              r.requestType == ConstraintRequest.typeShiftType &&
                              r.shiftType != null &&
                              (r.status == ConstraintRequest.statusPending ||
                                  r.status == ConstraintRequest.statusRejected))
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
                                if (_buildStatusBadge(request) != null) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusBadge(request)!,
                                ],
                              ],
                            ),
                            backgroundColor: color.withOpacity(0.1),
                            side: BorderSide(color: color, width: 1),
                          );
                        }).toList(),
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

    // 承認待ち・却下の申請も含める
    final selectedDays = approvedDays.toSet();
    final selectedShiftTypes = approvedShiftTypes.toSet();
    final selectedSpecificDays = approvedSpecificDays.toSet();

    // 承認待ち・却下の曜日申請を追加
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeWeekday &&
          request.weekday != null &&
          (request.status == ConstraintRequest.statusPending ||
              request.status == ConstraintRequest.statusRejected)) {
        selectedDays.add(request.weekday!);
      }
    }

    // 承認待ち・却下のシフトタイプ申請を追加
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeShiftType &&
          request.shiftType != null &&
          (request.status == ConstraintRequest.statusPending ||
              request.status == ConstraintRequest.statusRejected)) {
        selectedShiftTypes.add(request.shiftType!);
      }
    }

    // 承認待ち・却下の特定日申請を追加
    for (final request in myRequests) {
      if (request.requestType == ConstraintRequest.typeSpecificDay &&
          request.specificDate != null &&
          (request.status == ConstraintRequest.statusPending ||
              request.status == ConstraintRequest.statusRejected)) {
        selectedSpecificDays.add(request.specificDate!);
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
      maxShiftsPerMonth: myStaff.maxShiftsPerMonth,
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
  ) async {
    final requestProvider = outerContext.read<ConstraintRequestProvider>();
    final uuid = const Uuid();

    // 既存の制約を取得（承認済みのデータ）
    final existingDays = myStaff.preferredDaysOff;
    final existingSpecificDays = myStaff.specificDaysOff
        .map((dateStr) => DateTime.parse(dateStr))
        .toList();
    final existingShiftTypes = myStaff.unavailableShiftTypes;

    // 【重要】既存のpending/rejected申請をすべて削除してから、新しい内容で再作成
    final myRequests = requestProvider.getRequestsByUserId(widget.appUser.uid);
    for (final request in myRequests) {
      if (request.status == ConstraintRequest.statusPending ||
          request.status == ConstraintRequest.statusRejected) {
        await requestProvider.deleteRequest(request.id);
      }
    }

    // 編集後の内容で新規申請を作成（既存のStaffデータと重複しないものだけ）
    int newRequestCount = 0;

    // 1. 曜日の休み希望
    for (final day in selectedDays) {
      if (!existingDays.contains(day)) {
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeWeekday,
          weekday: day,
          status: ConstraintRequest.statusPending,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }

    // 2. 特定日の休み希望
    for (final date in selectedSpecificDays) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final isNew = !existingSpecificDays.any((existing) =>
          existing.year == normalizedDate.year &&
          existing.month == normalizedDate.month &&
          existing.day == normalizedDate.day);

      if (isNew) {
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeSpecificDay,
          specificDate: normalizedDate,
          status: ConstraintRequest.statusPending,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }

    // 3. シフトタイプの勤務不可
    for (final shiftType in selectedShiftTypes) {
      if (!existingShiftTypes.contains(shiftType)) {
        final request = ConstraintRequest(
          id: uuid.v4(),
          staffId: myStaff.id,
          userId: widget.appUser.uid,
          requestType: ConstraintRequest.typeShiftType,
          shiftType: shiftType,
          status: ConstraintRequest.statusPending,
        );
        await requestProvider.createRequest(request);
        newRequestCount++;
      }
    }

    if (outerContext.mounted) {
      Navigator.pop(dialogContext);
      if (mounted) {
        setState(() {});
      }
      // メッセージの内容を申請件数によって変更
      final message = newRequestCount > 0
          ? '休み希望を申請しました。管理者の承認をお待ちください。'
          : '変更を保存しました。';
      ScaffoldMessenger.of(outerContext).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
