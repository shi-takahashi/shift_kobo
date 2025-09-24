import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/staff_provider.dart';
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
    } else {
      // 追加モード
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _emailController = TextEditingController();
      _maxShiftsController = TextEditingController(text: '20');
      _selectedDaysOff = [];
      _unavailableShiftTypes = [];
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

  Widget _buildUnavailableShiftTypesSection() {
    final shiftTypes = ShiftType.all;
    
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
            Column(
              children: [
                // 1行目: 早番、日勤、遅番
                Row(
                  children: ['早番', '日勤', '遅番'].map((type) {
                    final isSelected = _unavailableShiftTypes.contains(type);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: FilterChip(
                          label: Center(child: Text(type, style: const TextStyle(fontSize: 12))),
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
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                // 2行目: 夜勤、終日
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: FilterChip(
                          label: Center(child: Text('夜勤', style: const TextStyle(fontSize: 12))),
                          selected: _unavailableShiftTypes.contains('夜勤'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _unavailableShiftTypes.add('夜勤');
                              } else {
                                _unavailableShiftTypes.remove('夜勤');
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: FilterChip(
                          label: Center(child: Text('終日', style: const TextStyle(fontSize: 12))),
                          selected: _unavailableShiftTypes.contains('終日'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _unavailableShiftTypes.add('終日');
                              } else {
                                _unavailableShiftTypes.remove('終日');
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const Expanded(child: SizedBox()), // 3番目は空
                  ],
                ),
              ],
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