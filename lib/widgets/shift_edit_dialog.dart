import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shift.dart';
import '../models/shift_type.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';

class ShiftEditDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Shift? existingShift;

  const ShiftEditDialog({
    super.key,
    required this.selectedDate,
    this.existingShift,
  });

  @override
  State<ShiftEditDialog> createState() => _ShiftEditDialogState();
}

class _ShiftEditDialogState extends State<ShiftEditDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedStaffId;
  String _selectedShiftType = ShiftType.day;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String _note = '';
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    if (widget.existingShift != null) {
      _initializeWithExistingShift();
    }
  }

  void _initializeWithExistingShift() {
    final shift = widget.existingShift!;
    _selectedStaffId = shift.staffId;
    _selectedShiftType = shift.shiftType;
    _startTime = TimeOfDay.fromDateTime(shift.startTime);
    _endTime = TimeOfDay.fromDateTime(shift.endTime);
    _note = shift.note ?? '';
    _selectedDate = shift.date;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                widget.existingShift != null ? 'シフト編集' : 'シフト追加',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              // 日付選択
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日付',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Consumer<StaffProvider>(
                builder: (context, staffProvider, child) {
                  final activeStaff = staffProvider.activeStaffList;
                  
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'スタッフ',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedStaffId,
                    items: activeStaff.map((staff) {
                      return DropdownMenuItem(
                        value: staff.id,
                        child: Text(staff.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStaffId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'スタッフを選択してください';
                      }
                      return null;
                    },
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'シフトタイプ',
                  border: OutlineInputBorder(),
                ),
                value: _selectedShiftType,
                items: ShiftType.all.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedShiftType = value;
                      _updateTimesByShiftType(value);
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '開始時間',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_startTime.hour.toString().padLeft(2, '0')}:'
                          '${_startTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '終了時間',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_endTime.hour.toString().padLeft(2, '0')}:'
                          '${_endTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  border: OutlineInputBorder(),
                ),
                initialValue: _note,
                maxLines: 2,
                onChanged: (value) {
                  _note = value;
                },
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveShift,
                    child: Text(widget.existingShift != null ? '更新' : '追加'),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateTimesByShiftType(String shiftType) {
    final timeRange = ShiftType.defaultTimeRanges[shiftType];
    if (timeRange != null) {
      setState(() {
        _startTime = TimeOfDay(
          hour: timeRange.startHour,
          minute: timeRange.startMinute,
        );
        _endTime = TimeOfDay(
          hour: timeRange.endHour,
          minute: timeRange.endMinute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveShift() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final shiftProvider = context.read<ShiftProvider>();
    
    // 重複チェック
    final conflictShift = _checkForConflicts(shiftProvider);
    if (conflictShift != null) {
      _showConflictDialog(conflictShift);
      return;
    }
    
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    
    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (widget.existingShift != null) {
      final updatedShift = widget.existingShift!
        ..date = _selectedDate
        ..staffId = _selectedStaffId!
        ..shiftType = _selectedShiftType
        ..startTime = startDateTime
        ..endTime = endDateTime
        ..note = _note.isEmpty ? null : _note;
      
      await shiftProvider.updateShift(updatedShift);
    } else {
      final newShift = Shift(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        staffId: _selectedStaffId!,
        shiftType: _selectedShiftType,
        startTime: startDateTime,
        endTime: endDateTime,
        note: _note.isEmpty ? null : _note,
      );
      
      await shiftProvider.addShift(newShift);
    }

    Navigator.pop(context);
  }

  Shift? _checkForConflicts(ShiftProvider shiftProvider) {
    final existingShifts = shiftProvider.getShiftsForDate(_selectedDate);
    
    for (final existingShift in existingShifts) {
      // 自分自身は除外
      if (widget.existingShift != null && existingShift.id == widget.existingShift!.id) {
        continue;
      }
      
      // 同じスタッフの重複チェック
      if (existingShift.staffId == _selectedStaffId) {
        return existingShift;
      }
    }
    
    return null;
  }

  void _showConflictDialog(Shift conflictShift) {
    final staffProvider = context.read<StaffProvider>();
    final staff = staffProvider.getStaffById(conflictShift.staffId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('シフト重複エラー'),
        content: Text(
          '${staff?.name ?? 'スタッフ'}は既に${_selectedDate.month}/${_selectedDate.day}に'
          '${conflictShift.shiftType}のシフトが入っています。\n\n'
          '同じ日に同じスタッフを複数のシフトに割り当てることはできません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}