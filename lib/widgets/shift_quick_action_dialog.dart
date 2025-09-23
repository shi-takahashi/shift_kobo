import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shift.dart';
import '../models/staff.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';

class ShiftQuickActionDialog extends StatefulWidget {
  final Shift shift;

  const ShiftQuickActionDialog({
    super.key,
    required this.shift,
  });

  @override
  State<ShiftQuickActionDialog> createState() => _ShiftQuickActionDialogState();
}

class _ShiftQuickActionDialogState extends State<ShiftQuickActionDialog> {
  @override
  Widget build(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final currentStaff = staffProvider.getStaffById(widget.shift.staffId);
    
    return AlertDialog(
      title: const Text('シフト操作'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${currentStaff?.name ?? '不明'} - ${widget.shift.shiftType}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${widget.shift.date.month}/${widget.shift.date.day}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          const Text('操作を選択してください：'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showStaffChangeDialog(context);
          },
          child: const Text('スタッフ変更'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showDateMoveDialog(context);
          },
          child: const Text('日付移動'),
        ),
      ],
    );
  }

  void _showStaffChangeDialog(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final activeStaff = staffProvider.activeStaffList;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スタッフ変更'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activeStaff.length,
            itemBuilder: (context, index) {
              final staff = activeStaff[index];
              final isCurrentStaff = staff.id == widget.shift.staffId;
              
              return ListTile(
                leading: CircleAvatar(
                  child: Text(staff.name.substring(0, 1)),
                ),
                title: Text(staff.name),
                subtitle: Text('月間最大: ${staff.maxShiftsPerMonth}回'),
                trailing: isCurrentStaff 
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: isCurrentStaff 
                    ? null 
                    : () => _changeStaff(context, staff),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _showDateMoveDialog(BuildContext context) {
    final today = DateTime.now();
    final initialDate = widget.shift.date;
    
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 90)),
    ).then((selectedDate) {
      if (selectedDate != null && selectedDate != widget.shift.date) {
        _moveToDate(context, selectedDate);
      }
    });
  }

  void _changeStaff(BuildContext context, Staff newStaff) async {
    final shiftProvider = context.read<ShiftProvider>();
    
    // スタッフ変更の制約チェック - 重複チェック
    final conflictShift = shiftProvider.getShiftsForDate(widget.shift.date)
        .where((s) => s.staffId == newStaff.id && s.id != widget.shift.id)
        .firstOrNull;
    
    if (conflictShift != null) {
      Navigator.of(context).pop();
      _showConflictDialog(context, 
        '${newStaff.name}は既に${widget.shift.date.month}/${widget.shift.date.day}に'
        '${conflictShift.shiftType}のシフトが入っています。\n\n'
        '同じ日に同じスタッフを複数のシフトに割り当てることはできません。'
      );
      return;
    }
    
    // スタッフのシフトタイプ制約チェック
    if (newStaff.unavailableShiftTypes.contains(widget.shift.shiftType)) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newStaff.name}は${widget.shift.shiftType}に対応できません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final updatedShift = widget.shift..staffId = newStaff.id;
    await shiftProvider.updateShift(updatedShift);
    
    Navigator.of(context).pop();
  }

  void _moveToDate(BuildContext context, DateTime newDate) async {
    final shiftProvider = context.read<ShiftProvider>();
    
    // 移動先の日付に同じスタッフのシフトがないかチェック
    final conflictShift = shiftProvider.getShiftsForDate(newDate)
        .where((s) => s.staffId == widget.shift.staffId)
        .firstOrNull;
    
    if (conflictShift != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      widget.shift.startTime.hour,
      widget.shift.startTime.minute,
    );
    
    final newEndTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      widget.shift.endTime.hour,
      widget.shift.endTime.minute,
    );
    
    final updatedShift = widget.shift
      ..date = newDate
      ..startTime = newStartTime
      ..endTime = newEndTime;
    
    await shiftProvider.updateShift(updatedShift);
  }

  void _showConflictDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('シフト重複エラー'),
        content: Text(message),
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