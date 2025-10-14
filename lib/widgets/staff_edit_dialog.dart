import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_time_provider.dart';
import '../models/staff.dart';
import '../models/shift_type.dart';

class StaffEditDialog extends StatefulWidget {
  final Staff? existingStaff;

  const StaffEditDialog({
    super.key,
    this.existingStaff,
  });

  @override
  State<StaffEditDialog> createState() => _StaffEditDialogState();
}

class _StaffEditDialogState extends State<StaffEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _maxShiftsController;
  
  late List<int> _selectedDaysOff;
  late List<String> _unavailableShiftTypes;
  late List<DateTime> _specificDaysOff;
  bool _showPastDaysOff = false; // 過去の休み希望日を表示するか

  @override
  void initState() {
    super.initState();

    if (widget.existingStaff != null) {
      // 編集モード
      _nameController = TextEditingController(text: widget.existingStaff!.name);
      _phoneController = TextEditingController(text: widget.existingStaff!.phoneNumber ?? '');
      _emailController = TextEditingController(text: widget.existingStaff!.email ?? '');
      _maxShiftsController = TextEditingController(text: widget.existingStaff!.maxShiftsPerMonth.toString());
      _selectedDaysOff = List.from(widget.existingStaff!.preferredDaysOff);
      _unavailableShiftTypes = List.from(widget.existingStaff!.unavailableShiftTypes);
      _specificDaysOff = widget.existingStaff!.specificDaysOff
          .map((dateStr) => DateTime.parse(dateStr))
          .toList();
    } else {
      // 追加モード
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _emailController = TextEditingController();
      _maxShiftsController = TextEditingController(text: '20');
      _selectedDaysOff = [];
      _unavailableShiftTypes = [];
      _specificDaysOff = [];
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _maxShiftsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // スクロール可能なコンテンツ部分
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 6.0,
                  radius: const Radius.circular(3.0),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingStaff != null ? 'スタッフ編集' : 'スタッフ追加',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildShiftConstraintsSection(),
                        const SizedBox(height: 24),
                        _buildDaysOffSection(),
                        const SizedBox(height: 24),
                        _buildSpecificDaysOffSection(),
                        const SizedBox(height: 24),
                        _buildUnavailableShiftTypesSection(),
                      ],
                    ),
                  ),
                ),
              ),
              // 固定のアクションボタン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: const Border(
                    top: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本情報',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名前',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '名前を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '電話番号（任意）',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス（任意）',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return '正しいメールアドレスを入力してください';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftConstraintsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'シフト制約',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxShiftsController,
              decoration: const InputDecoration(
                labelText: '月間最大シフト数',
                prefixIcon: Icon(Icons.event_repeat),
                border: OutlineInputBorder(),
                suffixText: '回',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '月間最大シフト数を入力してください';
                }
                final num = int.tryParse(value);
                if (num == null || num < 1 || num > 31) {
                  return '1〜31の範囲で入力してください';
                }
                return null;
              },
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
              '休み希望曜日',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '定期的に休みを希望する曜日を選択',
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
                  width: 80, // 全てのチップを同じ幅に統一
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
                      });
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificDaysOffSection() {
    // 日付順にソート
    _specificDaysOff.sort((a, b) => a.compareTo(b));

    // 今月の最初の日を取得
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    // 表示する日付をフィルタリング
    final displayDaysOff = _showPastDaysOff
        ? _specificDaysOff
        : _specificDaysOff.where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1)))).toList();

    // 過去の休み希望日の件数
    final pastCount = _specificDaysOff.where((date) => date.isBefore(firstDayOfCurrentMonth)).length;

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
                        '休み希望日（特定日）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '特定の日付で休みを希望する日を追加',
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
                        // 日付のみを保存（時刻は00:00:00）
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
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: '休み希望日を追加',
                ),
              ],
            ),
            if (pastCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _showPastDaysOff,
                    onChanged: (value) {
                      setState(() {
                        _showPastDaysOff = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      '過去の休み希望日も表示（${pastCount}件）',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (displayDaysOff.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayDaysOff.map((date) {
                  final isPast = date.isBefore(firstDayOfCurrentMonth);
                  return Chip(
                    label: Text(
                      DateFormat('yyyy/MM/dd(E)', 'ja').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPast ? Colors.grey : null,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    backgroundColor: isPast ? Colors.grey.shade200 : null,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _specificDaysOff.remove(date);
                      });
                    },
                  );
                }).toList(),
              ),
            ] else if (_specificDaysOff.isEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '登録されていません',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '今月以降の休み希望日はありません',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableShiftTypesSection() {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context);
    final activeShiftTypes = shiftTimeProvider.settings
        .where((setting) => setting.isActive)
        .map((setting) => setting.displayName)
        .toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '勤務不可シフトタイプ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '勤務できないシフトタイプを選択',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeShiftTypes.map((type) {
                final isSelected = _unavailableShiftTypes.contains(type);
                return SizedBox(
                  width: 100, // 固定幅
                  child: FilterChip(
                    label: Center(
                      child: Text(
                        type,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _unavailableShiftTypes.add(type);
                        } else {
                          _unavailableShiftTypes.remove(type);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('キャンセル'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: _handleSave,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ),
      ],
    );
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final staffProvider = context.read<StaffProvider>();
      
      if (widget.existingStaff != null) {
        // 編集モード
        final updatedStaff = Staff(
          id: widget.existingStaff!.id,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          maxShiftsPerMonth: int.parse(_maxShiftsController.text),
          preferredDaysOff: List.from(_selectedDaysOff),
          unavailableShiftTypes: List.from(_unavailableShiftTypes),
          specificDaysOff: _specificDaysOff.map((date) =>
            DateTime(date.year, date.month, date.day).toIso8601String()
          ).toList(),
          isActive: widget.existingStaff!.isActive,
          createdAt: widget.existingStaff!.createdAt,
        );
        
        staffProvider.updateStaff(updatedStaff);
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedStaff.name}の情報を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 追加モード
        final staff = Staff(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          maxShiftsPerMonth: int.parse(_maxShiftsController.text),
          preferredDaysOff: List.from(_selectedDaysOff),
          unavailableShiftTypes: List.from(_unavailableShiftTypes),
          specificDaysOff: _specificDaysOff.map((date) =>
            DateTime(date.year, date.month, date.day).toIso8601String()
          ).toList(),
          isActive: true,
          createdAt: DateTime.now(),
        );
        
        staffProvider.addStaff(staff);
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name}を追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}