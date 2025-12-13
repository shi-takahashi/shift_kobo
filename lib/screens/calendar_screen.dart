import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/app_user.dart';
import '../models/assignment_strategy.dart';
import '../models/shift.dart';
import '../models/shift_plan.dart';
import '../models/shift_time_setting.dart';
import '../models/shift_type.dart' as old_shift_type;
import '../models/staff.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
import '../services/analytics_service.dart';
import '../services/shift_plan_service.dart';
import '../utils/japanese_calendar_utils.dart';
import '../widgets/auto_assignment_dialog.dart';
import '../widgets/restore_dialog.dart';
import '../widgets/shift_edit_dialog.dart';
import '../widgets/shift_quick_action_dialog.dart';
import 'export_screen.dart';

class CalendarScreen extends StatefulWidget {
  final AppUser appUser;

  const CalendarScreen({
    super.key,
    required this.appUser,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<Shift>> _selectedShifts;
  late CalendarFormat _calendarFormat;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, bool> _userRoleCache = {}; // userId -> isAdmin のキャッシュ

  @override
  void initState() {
    super.initState();
    // Web版ではデフォルトを週表示、アプリ版は月表示
    _calendarFormat = kIsWeb ? CalendarFormat.week : CalendarFormat.month;
    _selectedDay = DateTime.now();
    _selectedShifts = ValueNotifier(_getShiftsForDay(_selectedDay!));
    _loadTeamUserRoles();

    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('calendar_screen');
  }

  /// チーム内の全ユーザーのロール情報をキャッシュ
  Future<void> _loadTeamUserRoles() async {
    if (widget.appUser.teamId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').where('teamId', isEqualTo: widget.appUser.teamId).get();

      final roleCache = <String, bool>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String?;
        roleCache[doc.id] = role == 'admin';
      }

      if (mounted) {
        setState(() {
          _userRoleCache = roleCache;
        });
        // キャッシュが更新されたら、選択中の日のシフトを再ソート
        if (_selectedDay != null) {
          _selectedShifts.value = _getShiftsForDay(_selectedDay!);
        }
      }
    } catch (e) {
      print('ユーザーロール情報の取得エラー: $e');
    }
  }

  @override
  void dispose() {
    _selectedShifts.dispose();
    super.dispose();
  }

  /// シフトタイプ名から色を取得（新しいShiftTimeSettingに対応）
  Color _getShiftTypeColor(String shiftTypeName) {
    final shiftTimeProvider = context.read<ShiftTimeProvider>();

    // まず新しいShiftTimeSettingから検索
    final setting = shiftTimeProvider.settings.where((s) => s.displayName == shiftTypeName).firstOrNull;

    if (setting != null) {
      return setting.shiftType.color;
    }

    // 見つからない場合は従来のShiftType.getColor()を使用
    return old_shift_type.ShiftType.getColor(shiftTypeName);
  }

  List<Shift> _getShiftsForDay(DateTime day) {
    final shiftProvider = context.read<ShiftProvider>();
    final staffProvider = context.read<StaffProvider>();
    final shifts = shiftProvider.getShiftsForDate(day);

    // ソート: 1.開始時間順 2.終了時間順 3.ロール順（管理者を上） 4.createdAt順（昇順）
    shifts.sort((a, b) {
      final staffA = staffProvider.getStaffById(a.staffId);
      final staffB = staffProvider.getStaffById(b.staffId);

      // スタッフ情報が見つからない場合の処理
      if (staffA == null && staffB == null) return 0;
      if (staffA == null) return 1;
      if (staffB == null) return -1;

      // 1. 開始時間順
      int startComparison = a.startTime.compareTo(b.startTime);
      if (startComparison != 0) return startComparison;

      // 2. 終了時間順
      int endComparison = a.endTime.compareTo(b.endTime);
      if (endComparison != 0) return endComparison;

      // 3. ロール順（管理者を上、スタッフを下）
      final isAdminA = staffA.userId != null && (_userRoleCache[staffA.userId] ?? false);
      final isAdminB = staffB.userId != null && (_userRoleCache[staffB.userId] ?? false);

      if (isAdminA && !isAdminB) return -1;
      if (!isAdminA && isAdminB) return 1;

      // 4. createdAt順（昇順＝過去に作成されたスタッフが上）
      return staffA.createdAt.compareTo(staffB.createdAt);
    });

    return shifts;
  }

  /// カレンダーマーカー用にソートしたシフトリストを取得
  /// ソート順: 1.開始時間順 2.終了時間順 3.ロール順 4.createdAt順
  List<Shift> _getSortedShiftsForMarker(List<Shift> shifts) {
    final staffProvider = context.read<StaffProvider>();
    final sortedShifts = List<Shift>.from(shifts);

    sortedShifts.sort((a, b) {
      final staffA = staffProvider.getStaffById(a.staffId);
      final staffB = staffProvider.getStaffById(b.staffId);

      // スタッフ情報が見つからない場合の処理
      if (staffA == null && staffB == null) return 0;
      if (staffA == null) return 1;
      if (staffB == null) return -1;

      // 1. 開始時間順
      int startComparison = a.startTime.compareTo(b.startTime);
      if (startComparison != 0) return startComparison;

      // 2. 終了時間順
      int endComparison = a.endTime.compareTo(b.endTime);
      if (endComparison != 0) return endComparison;

      // 3. ロール順（管理者を上、スタッフを下）
      final isAdminA = staffA.userId != null && (_userRoleCache[staffA.userId] ?? false);
      final isAdminB = staffB.userId != null && (_userRoleCache[staffB.userId] ?? false);

      if (isAdminA && !isAdminB) return -1;
      if (!isAdminA && isAdminB) return 1;

      // 4. createdAt順（昇順）
      return staffA.createdAt.compareTo(staffB.createdAt);
    });

    return sortedShifts;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, child) {
        final monthlyShifts = shiftProvider.getMonthlyShiftMap(
          _focusedDay.year,
          _focusedDay.month,
        );

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 50, // デフォルト56 → 50に縮小
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0, // スクロール時の色変化を防ぐ
            title: widget.appUser.isAdmin
                ? FutureBuilder<String?>(
                    future: shiftProvider.teamId != null
                        ? ShiftPlanService(teamId: shiftProvider.teamId!).getActivePlanId('${_focusedDay.year}-${_focusedDay.month}')
                        : null,
                    builder: (context, planSnapshot) {
                      // プランIDが存在する場合は常に表示
                      if (planSnapshot.hasData && planSnapshot.data != null) {
                        return FutureBuilder<List<ShiftPlan>>(
                          future: ShiftPlanService(teamId: shiftProvider.teamId!).getPlansForMonth('${_focusedDay.year}-${_focusedDay.month}'),
                          builder: (context, snapshot) {
                            // 切替ボタンは複数プランがある場合のみ表示（shift_plansが1件以上）
                            final showSwitchButton = snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  planSnapshot.data!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (showSwitchButton) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade600,
                                      borderRadius: BorderRadius.circular(8.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.shade200,
                                          blurRadius: 3,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap: () => _showRestoreDialog(snapshot.data!),
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            const Text(
                                              '切替',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      }
                      return const SizedBox();
                    },
                  )
                : null,
            actions: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade200,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () async {
                    final shiftProvider = context.read<ShiftProvider>();
                    final staffProvider = context.read<StaffProvider>();
                    final shiftTimeProvider = context.read<ShiftTimeProvider>();

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MultiProvider(
                          providers: [
                            ChangeNotifierProvider<ShiftProvider>.value(value: shiftProvider),
                            ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
                            ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
                          ],
                          child: ExportScreen(
                            initialMonth: _focusedDay,
                          ),
                        ),
                      ),
                    );
                    // Export画面から戻った時に画面向きを確実に復元
                    if (mounted) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    }
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.save_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'シフト表',
                          style: TextStyle(
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
              const SizedBox(width: 8),
              // 管理者のみ自動作成ボタンを表示
              if (widget.appUser.isAdmin) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
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
                    onTap: () => _showAutoAssignmentDialog(context),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_fix_high,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '自動作成',
                            style: TextStyle(
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
                const SizedBox(width: 16),
              ],
              if (!widget.appUser.isAdmin) const SizedBox(width: 16),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              children: [
                // カスタムヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      // 月/週切り替えボタン（左端に配置）
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
                              _calendarFormat = _calendarFormat == CalendarFormat.month ? CalendarFormat.week : CalendarFormat.month;
                            });
                          },
                          borderRadius: BorderRadius.circular(8.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _calendarFormat == CalendarFormat.month ? Icons.calendar_view_month : Icons.calendar_view_week,
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
                      // 左側スペーサー（少し小さく）
                      Expanded(flex: 2, child: Container()),
                      // 前ボタン（月表示: 前月、週表示: 前週）
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: () {
                          final isMonthMode = _calendarFormat == CalendarFormat.month;
                          setState(() {
                            if (isMonthMode) {
                              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                            } else {
                              _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                            }
                            _selectedDay = null;
                          });
                          _selectedShifts.value = [];
                          // 月モードの場合のみShiftProviderに通知
                          if (isMonthMode) {
                            shiftProvider.setCurrentMonth(_focusedDay);
                          }
                        },
                      ),
                      // 月年表示（中央固定）
                      Container(
                        constraints: const BoxConstraints(minWidth: 100),
                        child: Text(
                          JapaneseCalendarUtils.formatMonthYear(_focusedDay),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 次ボタン（月表示: 次月、週表示: 次週）
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: () {
                          final isMonthMode = _calendarFormat == CalendarFormat.month;
                          setState(() {
                            if (isMonthMode) {
                              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                            } else {
                              _focusedDay = _focusedDay.add(const Duration(days: 7));
                            }
                            _selectedDay = null;
                          });
                          _selectedShifts.value = [];
                          // 月モードの場合のみShiftProviderに通知
                          if (isMonthMode) {
                            shiftProvider.setCurrentMonth(_focusedDay);
                          }
                        },
                      ),
                      // 右側スペーサー（大きく）
                      Expanded(flex: 3, child: Container()),
                    ],
                  ),
                ),
                // カレンダー（高さは週数に応じて可変）
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: TableCalendar<Shift>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    locale: 'ja_JP',
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    eventLoader: (day) {
                      final dateKey = DateTime(day.year, day.month, day.day);
                      return monthlyShifts[dateKey] ?? [];
                    },
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    daysOfWeekVisible: true,
                    availableCalendarFormats: const {
                      CalendarFormat.month: '月',
                      CalendarFormat.week: '週',
                    },
                    daysOfWeekHeight: 30.0,
                    rowHeight: _calendarFormat == CalendarFormat.month ? (kIsWeb ? 32.0 : 36.0) : 40.0,
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
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      // カレンダーの縦幅を縮小
                      cellMargin: EdgeInsets.all(2.0),
                      defaultTextStyle: TextStyle(fontSize: 12),
                      weekendTextStyle: TextStyle(color: Colors.red, fontSize: 12),
                      holidayTextStyle: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    headerVisible: false, // デフォルトヘッダーを非表示
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                        _selectedDay = null;
                      });
                      _selectedShifts.value = [];
                      // ShiftProviderに表示月を通知（データ取得範囲を更新）
                      shiftProvider.setCurrentMonth(focusedDay);
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, shifts) {
                        if (shifts.isEmpty) return null;
                        return _buildShiftMarkers(shifts);
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
                const SizedBox(height: 4.0),
                // スタッフ一覧（残りの縦スペースを全て使用）
                Expanded(
                  child: ValueListenableBuilder<List<Shift>>(
                    valueListenable: _selectedShifts,
                    builder: (context, value, _) {
                      if (_selectedDay == null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '日付を選択してシフトを確認・追加できます',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          if (value.isEmpty) ...[
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_available,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'この日のシフトはありません',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: Scrollbar(
                                thumbVisibility: true,
                                thickness: 6.0,
                                radius: const Radius.circular(3.0),
                                child: ListView.builder(
                                  itemCount: value.length,
                                  itemBuilder: (context, index) {
                                    return _ShiftTile(
                                      shift: value[index],
                                      shiftColor: _getShiftTypeColor(value[index].shiftType),
                                      onEdit: (shift) => _showEditShiftDialog(context, shift),
                                      onDelete: (shift) => _showDeleteConfirmDialog(context, shift),
                                      onQuickAction: (shift) => _showQuickActionDialog(context, shift),
                                      isAdmin: widget.appUser.isAdmin,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                          // 管理者のみシフト追加ボタンを表示
                          if (widget.appUser.isAdmin)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddShiftDialog(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('シフトを追加'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAutoAssignmentDialog(BuildContext context) {
    final shiftProvider = context.read<ShiftProvider>();
    final staffProvider = context.read<StaffProvider>();
    final shiftTimeProvider = context.read<ShiftTimeProvider>();
    final monthlyRequirementsProvider = context.read<MonthlyRequirementsProvider>();

    showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ShiftProvider>.value(value: shiftProvider),
          ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
          ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
          ChangeNotifierProvider<MonthlyRequirementsProvider>.value(value: monthlyRequirementsProvider),
        ],
        child: AutoAssignmentDialog(
          selectedMonth: _focusedDay,
        ),
      ),
    ).then((result) {
      if (result == true && _selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    });
  }

  /// プラン切替ダイアログを表示
  Future<void> _showRestoreDialog(List<ShiftPlan> plans) async {
    final shiftProvider = context.read<ShiftProvider>();

    await showDialog(
      context: context,
      builder: (context) => RestoreDialog(
        plans: plans,
        focusedDay: _focusedDay,
        teamId: shiftProvider.teamId!,
        onRestore: _switchToPlan,
      ),
    );
  }

  /// 案の切り替え
  Future<void> _switchToPlan(ShiftPlan targetPlan) async {
    try {
      final shiftProvider = context.read<ShiftProvider>();
      final planService = ShiftPlanService(teamId: shiftProvider.teamId!);
      final month = '${_focusedDay.year}-${_focusedDay.month}';

      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 0. ShiftProviderに正しい月を設定（購読範囲を確実に更新）
      shiftProvider.setCurrentMonth(_focusedDay);

      // Firestoreからのデータ読み込みを待つ（非同期処理完了を確実にする）
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. 現在のplan_idと戦略を取得
      String? currentPlanId = await planService.getActivePlanId(month);
      String? currentStrategy = await planService.getActiveStrategy(month);

      // 2. 現在のshiftsを取得
      final currentShifts = shiftProvider.getShiftsForMonth(
        _focusedDay.year,
        _focusedDay.month,
      );

      // 3. 現在のshiftsをバックアップ
      if (currentShifts.isNotEmpty && currentPlanId != null) {
        await planService.saveShiftPlan(
          planId: currentPlanId,
          shifts: currentShifts,
          month: month,
          note: currentStrategy != null ? '${_getStrategyDisplayName(currentStrategy)}で作成' : '手動作成',
          strategy: currentStrategy ?? 'nothing',
        );
      }

      // 4. 現在のshiftsを全削除
      if (currentShifts.isNotEmpty) {
        await shiftProvider.batchDeleteShifts(currentShifts);
      }

      // 5. 切り替え先のshift_planからシフトを取得
      final targetShifts = targetPlan.shifts;

      // 6. 取得したシフトをshiftsに保存
      if (targetShifts.isNotEmpty) {
        await shiftProvider.batchAddShifts(targetShifts);
      }

      // 7. shift_active_planを更新（戦略情報も保存）
      await planService.setActivePlanId(month, targetPlan.planId, strategy: targetPlan.strategy);

      // ローディング終了
      if (mounted) {
        Navigator.of(context).pop();

        // 画面を更新
        setState(() {});
        if (_selectedDay != null) {
          _selectedShifts.value = _getShiftsForDay(_selectedDay!);
        }

        // Analytics: シフト切替イベント
        await AnalyticsService.logShiftRestored();

        // 成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'プランを切り替えました（シフト${targetShifts.length}件）',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      // ローディング終了
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('切り替えに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedShifts.value = _getShiftsForDay(selectedDay);
    }
  }

  void _showAddShiftDialog(BuildContext context) {
    // 管理者のみシフト追加可能
    if (!widget.appUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者のみシフトを追加できます')),
      );
      return;
    }

    if (_selectedDay == null) return;

    final shiftProvider = context.read<ShiftProvider>();
    final staffProvider = context.read<StaffProvider>();
    final shiftTimeProvider = context.read<ShiftTimeProvider>();

    showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ShiftProvider>.value(value: shiftProvider),
          ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
          ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
        ],
        child: ShiftEditDialog(selectedDate: _selectedDay!),
      ),
    ).then((result) {
      if (result == true && _selectedDay != null) {
        // 少し遅延させてからデータを再取得（Providerの更新を待つため）
        Future.delayed(const Duration(milliseconds: 100), () {
          setState(() {});
          _selectedShifts.value = _getShiftsForDay(_selectedDay!);
        });
      }
    });
  }

  void _showEditShiftDialog(BuildContext context, Shift shift) {
    // 管理者のみシフト編集可能
    if (!widget.appUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者のみシフトを編集できます')),
      );
      return;
    }

    final shiftProvider = context.read<ShiftProvider>();
    final staffProvider = context.read<StaffProvider>();
    final shiftTimeProvider = context.read<ShiftTimeProvider>();

    showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ShiftProvider>.value(value: shiftProvider),
          ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
          ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
        ],
        child: ShiftEditDialog(
          selectedDate: shift.date,
          existingShift: shift,
        ),
      ),
    ).then((result) {
      if (result == true && _selectedDay != null) {
        // 少し遅延させてからデータを再取得（Providerの更新を待つため）
        Future.delayed(const Duration(milliseconds: 100), () {
          setState(() {});
          _selectedShifts.value = _getShiftsForDay(_selectedDay!);
        });
      }
    });
  }

  void _showDeleteConfirmDialog(BuildContext context, Shift shift) async {
    // 管理者のみシフト削除可能
    if (!widget.appUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者のみシフトを削除できます')),
      );
      return;
    }

    final staffProvider = context.read<StaffProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    final staff = staffProvider.getStaffById(shift.staffId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('シフト削除'),
        content: Text(
          '${_getStaffDisplayName(staff, shift.staffId)}の'
          '${shift.date.month}/${shift.date.day}（${shift.shiftType}）'
          'のシフトを削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await shiftProvider.deleteShift(shift.id);
      if (_selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    }
  }

  void _showQuickActionDialog(BuildContext context, Shift shift) {
    // 管理者のみクイックアクション可能
    if (!widget.appUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者のみシフトを変更できます')),
      );
      return;
    }

    final shiftProvider = context.read<ShiftProvider>();
    final staffProvider = context.read<StaffProvider>();

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ShiftProvider>.value(value: shiftProvider),
          ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
        ],
        child: ShiftQuickActionDialog(
          shift: shift,
          onDateMove: (shift, newDate) => _moveShiftToDate(shift, newDate),
        ),
      ),
    ).then((_) {
      if (_selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    });
  }

  Future<void> _moveShiftToDate(Shift shift, DateTime newDate) async {
    final shiftProvider = context.read<ShiftProvider>();

    // 移動先の日付に同じスタッフのシフトがないかチェック
    final conflictShifts = shiftProvider.getShiftsForDate(newDate).where((s) => s.staffId == shift.staffId).toList();
    final conflictShift = conflictShifts.isNotEmpty ? conflictShifts.first : null;

    if (conflictShift != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('移動先の日付に既にシフトが入っています'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 新しい日付で時間を再計算
    final newStartTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      shift.startTime.hour,
      shift.startTime.minute,
    );

    final newEndTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      shift.endTime.hour,
      shift.endTime.minute,
    );

    final updatedShift = shift
      ..date = newDate
      ..startTime = newStartTime
      ..endTime = newEndTime;

    await shiftProvider.updateShift(updatedShift);

    // 成功メッセージ表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('シフトを${newDate.month}/${newDate.day}に移動しました'),
        backgroundColor: Colors.green,
      ),
    );

    // 画面を更新
    if (_selectedDay != null) {
      setState(() {});
      _selectedShifts.value = _getShiftsForDay(_selectedDay!);
    }
  }

  Widget _buildShiftMarkers(List<Shift> shifts) {
    if (shifts.isEmpty) return const SizedBox();

    if (shifts.length == 1) {
      return Positioned(
        right: 1,
        bottom: 1,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _getShiftTypeColor(shifts.first.shiftType),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Positioned(
      right: 1,
      bottom: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              '${shifts.length}',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._getSortedShiftsForMarker(shifts).take(4).map((shift) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 0.3),
                  decoration: BoxDecoration(
                    color: _getShiftTypeColor(shift.shiftType),
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
              if (shifts.length > 4)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 0.3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// スタッフ名を取得（削除済みスタッフの場合はIDを含めて表示）
  String _getStaffDisplayName(Staff? staff, String staffId) {
    if (staff == null) {
      return '不明 (ID:${staffId.substring(0, 8)})';
    }
    return staff.name;
  }

  /// 戦略文字列から表示名を取得
  String _getStrategyDisplayName(String strategy) {
    if (strategy == 'nothing') {
      return '手動';
    }

    try {
      final assignmentStrategy = AssignmentStrategy.values.firstWhere(
        (s) => s.name == strategy,
      );
      return assignmentStrategy.displayName;
    } catch (e) {
      return '手動';
    }
  }
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  final Color shiftColor;
  final Function(Shift) onEdit;
  final Function(Shift)? onDelete;
  final Function(Shift)? onQuickAction;
  final bool isAdmin;

  const _ShiftTile({
    required this.shift,
    required this.shiftColor,
    required this.onEdit,
    this.onDelete,
    this.onQuickAction,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final staff = staffProvider.getStaffById(shift.staffId);

    // シフトタイプは文字列で保存されているので、そのまま表示
    final shiftDisplayName = shift.shiftType;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: shiftColor,
              width: 4,
            ),
          ),
        ),
        child: InkWell(
          onTap: isAdmin ? () => onEdit(shift) : null, // 管理者のみ編集可能
          onLongPress: isAdmin && onQuickAction != null ? () => onQuickAction!(shift) : null, // 管理者のみクイックアクション可能
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: shiftColor.withOpacity(0.2),
              child: Text(
                staff != null ? staff.name.substring(0, 1) : '?',
                style: TextStyle(
                  color: shiftColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              staff != null ? staff.name : '不明 (ID:${shift.staffId.substring(0, 8)})',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: shiftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    shiftDisplayName,
                    style: TextStyle(
                      color: shiftColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${shift.startTime.hour.toString().padLeft(2, '0')}:'
                  '${shift.startTime.minute.toString().padLeft(2, '0')} - '
                  '${shift.endTime.hour.toString().padLeft(2, '0')}:'
                  '${shift.endTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: isAdmin
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit(shift);
                          break;
                        case 'delete':
                          if (onDelete != null) onDelete!(shift);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('編集'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('削除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                : null, // スタッフの場合はボタンなし
          ),
        ),
      ),
    );
  }
}
