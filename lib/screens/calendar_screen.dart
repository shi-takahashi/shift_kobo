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
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_fix_high),
                tooltip: '自動割り当て',
                onPressed: () => _showAutoAssignmentDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
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
                  CalendarFormat.twoWeeks: '2週',
                  CalendarFormat.week: '週',
                },
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: Colors.red),
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
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  formatButtonTextStyle: const TextStyle(
                    color: Colors.white,
                  ),
                  titleTextFormatter: (date, locale) => JapaneseCalendarUtils.formatMonthYear(date),
                ),
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
            const SizedBox(height: 8.0),
            Expanded(
              child: ValueListenableBuilder<List<Shift>>(
                valueListenable: _selectedShifts,
                builder: (context, value, _) {
                  if (value.isEmpty) {
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
                            _selectedDay == null 
                              ? '日付を選択してシフトを確認・追加できます'
                              : 'この日のシフトはありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_selectedDay != null) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddShiftDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('シフトを追加'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      return _ShiftTile(
                        shift: value[index],
                        onEdit: (shift) => _showEditShiftDialog(context, shift),
                      );
                    },
                  );
                },
              ),
            ),
          ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAutoAssignmentDialog(context),
            label: const Text('自動作成'),
            icon: const Icon(Icons.auto_fix_high),
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
            children: shifts.take(3).map((shift) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                decoration: BoxDecoration(
                  color: ShiftType.getColor(shift.shiftType),
                  shape: BoxShape.circle,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  final Function(Shift) onEdit;

  const _ShiftTile({required this.shift, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final staff = staffProvider.getStaffById(shift.staffId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: ShiftType.getColor(shift.shiftType),
              width: 4,
            ),
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: ShiftType.getColor(shift.shiftType).withOpacity(0.2),
            child: Text(
              staff?.name.substring(0, 1) ?? '?',
              style: TextStyle(
                color: ShiftType.getColor(shift.shiftType),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            staff?.name ?? 'スタッフ名不明',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ShiftType.getColor(shift.shiftType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  shift.shiftType,
                  style: TextStyle(
                    color: ShiftType.getColor(shift.shiftType),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${shift.startTime.hour.toString().padLeft(2, '0')}:'
                '${shift.startTime.minute.toString().padLeft(2, '0')} - '
                '${shift.endTime.hour.toString().padLeft(2, '0')}:'
                '${shift.endTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => onEdit(shift),
          ),
        ),
      ),
    );
  }
}