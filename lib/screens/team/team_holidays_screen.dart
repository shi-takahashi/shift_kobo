import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../services/auth_service.dart';
import '../../widgets/banner_ad_widget.dart';

/// チーム休み設定画面
class TeamHolidaysScreen extends StatefulWidget {
  final AppUser appUser;
  final Team team;

  const TeamHolidaysScreen({
    super.key,
    required this.appUser,
    required this.team,
  });

  @override
  State<TeamHolidaysScreen> createState() => _TeamHolidaysScreenState();
}

class _TeamHolidaysScreenState extends State<TeamHolidaysScreen> {
  late List<int> _selectedDaysOff;
  late List<DateTime> _specificDaysOff;
  late bool _holidaysOff;
  bool _showPastDaysOff = false;
  bool _hasChanges = false;

  // 元の値を保持
  late List<int> _originalDaysOff;
  late List<DateTime> _originalSpecificDaysOff;
  late bool _originalHolidaysOff;

  @override
  void initState() {
    super.initState();
    _selectedDaysOff = List.from(widget.team.teamDaysOff);
    _specificDaysOff = widget.team.teamSpecificDaysOff
        .map((dateStr) => DateTime.parse(dateStr))
        .toList();
    _holidaysOff = widget.team.teamHolidaysOff;

    // 元の値を保存
    _originalDaysOff = List.from(_selectedDaysOff);
    _originalSpecificDaysOff = List.from(_specificDaysOff);
    _originalHolidaysOff = _holidaysOff;
  }

  void _checkForChanges() {
    final hasChanges = _selectedDaysOff.toSet().difference(_originalDaysOff.toSet()).isNotEmpty ||
        _originalDaysOff.toSet().difference(_selectedDaysOff.toSet()).isNotEmpty ||
        _specificDaysOff.length != _originalSpecificDaysOff.length ||
        !_specificDaysOff.every((date) => _originalSpecificDaysOff.any((d) =>
            d.year == date.year && d.month == date.month && d.day == date.day)) ||
        _holidaysOff != _originalHolidaysOff;

    setState(() {
      _hasChanges = hasChanges;
    });
  }

  Future<void> _saveSettings() async {
    try {
      final authService = AuthService();

      // 特定日をISO8601形式の文字列リストに変換
      final specificDaysOffStrings = _specificDaysOff
          .map((date) => date.toIso8601String())
          .toList();

      await authService.updateTeamHolidays(
        teamId: widget.team.id,
        teamDaysOff: _selectedDaysOff,
        teamSpecificDaysOff: specificDaysOffStrings,
        teamHolidaysOff: _holidaysOff,
      );

      // 保存後、元の値を更新
      setState(() {
        _originalDaysOff = List.from(_selectedDaysOff);
        _originalSpecificDaysOff = List.from(_specificDaysOff);
        _originalHolidaysOff = _holidaysOff;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チーム休み設定を保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チーム休み設定'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildDaysOffSection(),
                  const SizedBox(height: 16),
                  _buildSpecificDaysOffSection(),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _hasChanges ? _saveSettings : null,
                    icon: const Icon(Icons.save),
                    label: const Text('設定を保存'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            top: false,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'チーム全体の休みを設定します。設定した日は自動シフト作成で誰もシフトに入りません。',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysOffSection() {
    const dayNames = ['月', '火', '水', '木', '金', '土', '日'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'チーム休み曜日',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '定期的にチーム全体で休みとする曜日を選択',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayNumber = index + 1;
                final isSelected = _selectedDaysOff.contains(dayNumber);

                return SizedBox(
                  width: 80,
                  child: FilterChip(
                    label: Center(
                      child: Text(
                        dayNames[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDaysOff.add(dayNumber);
                        } else {
                          _selectedDaysOff.remove(dayNumber);
                        }
                        _checkForChanges();
                      });
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _holidaysOff,
              onChanged: (value) {
                setState(() {
                  _holidaysOff = value ?? false;
                  _checkForChanges();
                });
              },
              title: const Text(
                '祝日をチーム休みとする',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificDaysOffSection() {
    _specificDaysOff.sort((a, b) => a.compareTo(b));

    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    final displayDaysOff = _showPastDaysOff
        ? _specificDaysOff
        : _specificDaysOff
            .where((date) =>
                date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1))))
            .toList();

    final pastCount =
        _specificDaysOff.where((date) => date.isBefore(firstDayOfCurrentMonth)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'チーム休み日（特定日）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '特定の日付でチーム全体を休みとする日を追加',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: () => _showMultipleDatePickerDialog(),
                  icon: const Icon(Icons.add),
                  tooltip: '休み日を追加',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (displayDaysOff.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '特定日の休み設定はありません',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayDaysOff.map((date) {
                  final formatter = DateFormat('yyyy/MM/dd (E)', 'ja');
                  return Chip(
                    label: Text(
                      formatter.format(date),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _specificDaysOff.removeWhere((d) =>
                            d.year == date.year &&
                            d.month == date.month &&
                            d.day == date.day);
                        _checkForChanges();
                      });
                    },
                  );
                }).toList(),
              ),
            if (pastCount > 0) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showPastDaysOff = !_showPastDaysOff;
                  });
                },
                child: Text(
                  _showPastDaysOff
                      ? '過去の休み日を非表示'
                      : '過去の休み日を表示 ($pastCount件)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMultipleDatePickerDialog() async {
    final result = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) => _TeamHolidaysCalendarDialog(
        initialDates: _specificDaysOff,
        teamDaysOff: _selectedDaysOff,
        holidaysOff: _holidaysOff,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        for (final date in result) {
          final dateOnly = DateTime(date.year, date.month, date.day);
          if (!_specificDaysOff.any((d) =>
              d.year == dateOnly.year &&
              d.month == dateOnly.month &&
              d.day == dateOnly.day)) {
            _specificDaysOff.add(dateOnly);
          }
        }
        _checkForChanges();
      });
    }
  }
}

/// チーム休み日複数選択カレンダーダイアログ
class _TeamHolidaysCalendarDialog extends StatefulWidget {
  final List<DateTime> initialDates;
  final List<int> teamDaysOff;
  final bool holidaysOff;

  const _TeamHolidaysCalendarDialog({
    required this.initialDates,
    required this.teamDaysOff,
    required this.holidaysOff,
  });

  @override
  State<_TeamHolidaysCalendarDialog> createState() => _TeamHolidaysCalendarDialogState();
}

class _TeamHolidaysCalendarDialogState extends State<_TeamHolidaysCalendarDialog> {
  late Set<DateTime> _selectedDates;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDates = {};
  }

  bool _isAlreadyRegistered(DateTime date) {
    return widget.initialDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  bool _isTeamDayOff(DateTime date) {
    if (widget.teamDaysOff.contains(date.weekday)) return true;
    if (widget.holidaysOff && holiday_jp.isHoliday(date)) return true;
    return false;
  }

  bool _isSelectedDate(DateTime date) {
    return _selectedDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  void _toggleDate(DateTime date) {
    setState(() {
      final normalized = DateTime(date.year, date.month, date.day);
      if (_isSelectedDate(date)) {
        _selectedDates.removeWhere((d) =>
            d.year == date.year && d.month == date.month && d.day == date.day);
      } else {
        _selectedDates.add(normalized);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'チーム休み日の追加',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orange.shade900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '休みにしたい日をタップして選択',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _buildCalendar(),
            const SizedBox(height: 16),
            _buildLegend(),
            if (_selectedDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSelectedDates(),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedDates.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedDates.toList()),
                    child: Text('追加 (${_selectedDates.length}件)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year + 1, now.month, 0);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                      if (_focusedDay.isBefore(firstDay)) _focusedDay = firstDay;
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat('yyyy年M月', 'ja').format(_focusedDay),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                      if (_focusedDay.isAfter(lastDay)) _focusedDay = lastDay;
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['日', '月', '火', '水', '木', '金', '土'].map((day) {
                final isWeekend = day == '日' || day == '土';
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isWeekend ? Colors.red.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    List<Widget> rows = [];
    List<Widget> currentRow = [];

    for (int i = 0; i < firstWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      final isToday = date.year == todayOnly.year &&
          date.month == todayOnly.month &&
          date.day == todayOnly.day;
      final isPast = date.isBefore(todayOnly);
      final isAlreadyRegistered = _isAlreadyRegistered(date);
      final isTeamDayOff = _isTeamDayOff(date);
      final isSelected = _isSelectedDate(date);
      final isWeekend = date.weekday == DateTime.sunday ||
          date.weekday == DateTime.saturday;
      final isDisabled = isPast || isAlreadyRegistered || isTeamDayOff;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: isDisabled ? null : () => _toggleDate(date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.shade400
                    : isAlreadyRegistered
                        ? Colors.orange.shade100
                        : isTeamDayOff
                            ? Colors.grey.shade200
                            : null,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: Colors.orange.shade700, width: 2)
                    : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : isPast
                            ? Colors.grey.shade400
                            : isAlreadyRegistered
                                ? Colors.orange.shade700
                                : isTeamDayOff
                                    ? Colors.grey.shade500
                                    : isWeekend
                                        ? Colors.red.shade400
                                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    while (currentRow.isNotEmpty && currentRow.length < 7) {
      currentRow.add(const Expanded(child: SizedBox()));
    }
    if (currentRow.isNotEmpty) {
      rows.add(Row(children: currentRow));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(children: rows),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.orange.shade400,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        const Text('選択中', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 16),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        const Text('登録済', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSelectedDates() {
    final sortedDates = _selectedDates.toList()..sort();
    final formatter = DateFormat('M/d(E)', 'ja');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '選択中: ${sortedDates.length}日',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: sortedDates.map((date) {
                  return Chip(
                    label: Text(formatter.format(date), style: const TextStyle(fontSize: 11)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _toggleDate(date),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.only(left: 4),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
