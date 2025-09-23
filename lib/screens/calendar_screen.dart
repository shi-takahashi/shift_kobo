import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';
import '../providers/staff_provider.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../widgets/shift_edit_dialog.dart';
import '../utils/japanese_calendar_utils.dart';
import '../widgets/auto_assignment_dialog.dart';
import '../widgets/shift_quick_action_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<Shift>> _selectedShifts;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedShifts = ValueNotifier(_getShiftsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedShifts.dispose();
    super.dispose();
  }

  List<Shift> _getShiftsForDay(DateTime day) {
    final shiftProvider = context.read<ShiftProvider>();
    final shifts = shiftProvider.getShiftsForDate(day);
    
    // ソート: 1.シフトタイプ順 2.スタッフID順
    shifts.sort((a, b) {
      // シフトタイプの順序を定義
      int aTypeIndex = ShiftType.all.indexOf(a.shiftType);
      int bTypeIndex = ShiftType.all.indexOf(b.shiftType);
      
      // シフトタイプが見つからない場合は最後に配置
      if (aTypeIndex == -1) aTypeIndex = ShiftType.all.length;
      if (bTypeIndex == -1) bTypeIndex = ShiftType.all.length;
      
      // まずシフトタイプで比較
      int typeComparison = aTypeIndex.compareTo(bTypeIndex);
      if (typeComparison != 0) return typeComparison;
      
      // シフトタイプが同じ場合はスタッフIDで比較
      return a.staffId.compareTo(b.staffId);
    });
    
    return shifts;
  }

  /// カレンダーマーカー用に時間順でソートしたシフトリストを取得
  List<Shift> _getSortedShiftsForMarker(List<Shift> shifts) {
    final sortedShifts = List<Shift>.from(shifts);
    sortedShifts.sort((a, b) {
      final aIndex = ShiftType.getTimeOrderIndex(a.shiftType);
      final bIndex = ShiftType.getTimeOrderIndex(b.shiftType);
      return aIndex.compareTo(bIndex);
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
            title: const Text('シフト管理'),
            toolbarHeight: 50, // デフォルト56 → 50に縮小
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0, // スクロール時の色変化を防ぐ
            actions: [
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
                      // 左側スペーサー（少し小さく）
                      Expanded(flex: 2, child: Container()),
                      // 前月ボタン
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                            _selectedDay = null;
                          });
                          _selectedShifts.value = [];
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
                      // 次月ボタン
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                            _selectedDay = null;
                          });
                          _selectedShifts.value = [];
                        },
                      ),
                      // 右側スペーサー（大きく）
                      Expanded(flex: 3, child: Container()),
                    ],
                  ),
                ),
                TableCalendar<Shift>(
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
                startingDayOfWeek: StartingDayOfWeek.monday,
                daysOfWeekVisible: true,
                availableCalendarFormats: const {
                  CalendarFormat.month: '月',
                  CalendarFormat.week: '週',
                },
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
                  cellMargin: EdgeInsets.all(4.0),
                  defaultTextStyle: TextStyle(fontSize: 14),
                  weekendTextStyle: TextStyle(color: Colors.red, fontSize: 14),
                  holidayTextStyle: TextStyle(color: Colors.red, fontSize: 14),
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
                          color: day.weekday == DateTime.saturday || day.weekday == DateTime.sunday
                              ? Colors.red
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4.0),
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
                                    onEdit: (shift) => _showEditShiftDialog(context, shift),
                                    onDelete: (shift) => _showDeleteConfirmDialog(context, shift),
                                    onQuickAction: (shift) => _showQuickActionDialog(context, shift),
                                  );
                                },
                            ),
                          ),
                        ),
                      ],
                      // 日付が選択されている時は常に追加ボタンを表示
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
    showDialog<bool>(
      context: context,
      builder: (context) => AutoAssignmentDialog(
        selectedMonth: _focusedDay,
      ),
    ).then((result) {
      if (result == true && _selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    });
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
    if (_selectedDay == null) return;
    
    showDialog<void>(
      context: context,
      builder: (context) => ShiftEditDialog(selectedDate: _selectedDay!),
    ).then((_) {
      if (_selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    });
  }

  void _showEditShiftDialog(BuildContext context, Shift shift) {
    showDialog<void>(
      context: context,
      builder: (context) => ShiftEditDialog(
        selectedDate: shift.date,
        existingShift: shift,
      ),
    ).then((_) {
      if (_selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    });
  }

  void _showDeleteConfirmDialog(BuildContext context, Shift shift) async {
    final staffProvider = context.read<StaffProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    final staff = staffProvider.getStaffById(shift.staffId);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('シフト削除'),
        content: Text(
          '${staff?.name ?? 'スタッフ名不明'}の'
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
    showDialog(
      context: context,
      builder: (context) => ShiftQuickActionDialog(shift: shift),
    ).then((_) {
      if (_selectedDay != null) {
        setState(() {});
        _selectedShifts.value = _getShiftsForDay(_selectedDay!);
      }
    });
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
            color: ShiftType.getColor(shifts.first.shiftType),
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
                    color: ShiftType.getColor(shift.shiftType),
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
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  final Function(Shift) onEdit;
  final Function(Shift)? onDelete;
  final Function(Shift)? onQuickAction;

  const _ShiftTile({
    required this.shift, 
    required this.onEdit,
    this.onDelete,
    this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final staff = staffProvider.getStaffById(shift.staffId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: ShiftType.getColor(shift.shiftType),
              width: 4,
            ),
          ),
        ),
        child: InkWell(
          onTap: () => onEdit(shift), // タップで編集画面を開く
          onLongPress: () {
            if (onQuickAction != null) onQuickAction!(shift);
          },
          child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: ShiftType.getColor(shift.shiftType).withOpacity(0.2),
            child: Text(
              staff?.name.substring(0, 1) ?? '?',
              style: TextStyle(
                color: ShiftType.getColor(shift.shiftType),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            staff?.name ?? 'スタッフ名不明',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: ShiftType.getColor(shift.shiftType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  shift.shiftType,
                  style: TextStyle(
                    color: ShiftType.getColor(shift.shiftType),
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
          trailing: PopupMenuButton<String>(
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
          ),
          ),
        ),
      ),
    );
  }
}