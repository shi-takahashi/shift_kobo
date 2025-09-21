import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';
import '../providers/staff_provider.dart';
import '../models/shift.dart';

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
    return shiftProvider.getShiftsForDate(day);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, child) {
        final monthlyShifts = shiftProvider.getMonthlyShiftMap(
          _focusedDay.year,
          _focusedDay.month,
        );

        return Column(
          children: [
            TableCalendar<Shift>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: (day) {
                final dateKey = DateTime(day.year, day.month, day.day);
                return monthlyShifts[dateKey] ?? [];
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
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
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
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
                _focusedDay = focusedDay;
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, shifts) {
                  if (shifts.isEmpty) return null;
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${shifts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
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
                    return const Center(
                      child: Text(
                        'この日のシフトはありません',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      return _ShiftTile(shift: value[index]);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;

  const _ShiftTile({required this.shift});

  @override
  Widget build(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final staff = staffProvider.getStaffById(shift.staffId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            staff?.name.substring(0, 1) ?? '?',
          ),
        ),
        title: Text(staff?.name ?? 'スタッフ名不明'),
        subtitle: Text(
          '${shift.shiftType} | '
          '${shift.startTime.hour.toString().padLeft(2, '0')}:'
          '${shift.startTime.minute.toString().padLeft(2, '0')} - '
          '${shift.endTime.hour.toString().padLeft(2, '0')}:'
          '${shift.endTime.minute.toString().padLeft(2, '0')}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('編集機能は準備中です')),
            );
          },
        ),
      ),
    );
  }
}