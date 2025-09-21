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

  @override
  void initState() {
    super.initState();
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
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingShift != null ? 'シフト編集' : 'シフト追加',
                style: Theme.of(context).textTheme.headlineSmall,
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

  void _saveShift() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final shiftProvider = context.read<ShiftProvider>();
    
    final startDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    
    final endDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (widget.existingShift != null) {
      final updatedShift = widget.existingShift!
        ..staffId = _selectedStaffId!
        ..shiftType = _selectedShiftType
        ..startTime = startDateTime
        ..endTime = endDateTime
        ..note = _note.isEmpty ? null : _note;
      
      shiftProvider.updateShift(updatedShift);
    } else {
      final newShift = Shift(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: widget.selectedDate,
        staffId: _selectedStaffId!,
        shiftType: _selectedShiftType,
        startTime: startDateTime,
        endTime: endDateTime,
        note: _note.isEmpty ? null : _note,
      );
      
      shiftProvider.addShift(newShift);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.existingShift != null
              ? 'シフトを更新しました'
              : 'シフトを追加しました',
        ),
      ),
    );
  }
}