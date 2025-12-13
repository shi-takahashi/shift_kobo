import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../services/auth_service.dart';

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
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('ja'),
                    );

                    if (selectedDate != null) {
                      setState(() {
                        final dateOnly = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                        );

                        if (!_specificDaysOff.any((d) =>
                            d.year == dateOnly.year &&
                            d.month == dateOnly.month &&
                            d.day == dateOnly.day)) {
                          _specificDaysOff.add(dateOnly);
                          _checkForChanges();
                        }
                      });
                    }
                  },
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
}
