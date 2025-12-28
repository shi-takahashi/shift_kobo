import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift.dart';
import '../models/staff.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../utils/constraint_checker.dart';

const String _kQuickActionHintShownKey = 'quick_action_hint_shown';

class ShiftQuickActionDialog extends StatefulWidget {
  final Shift shift;
  final Function(Shift, DateTime)? onDateMove;
  final Function(Shift)? onSwapStart;

  const ShiftQuickActionDialog({
    super.key,
    required this.shift,
    this.onDateMove,
    this.onSwapStart,
  });

  @override
  State<ShiftQuickActionDialog> createState() => _ShiftQuickActionDialogState();
}

class _ShiftQuickActionDialogState extends State<ShiftQuickActionDialog> {
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeHint();
  }

  Future<void> _checkFirstTimeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hintShown = prefs.getBool(_kQuickActionHintShownKey) ?? false;
    if (!hintShown && mounted) {
      setState(() {
        _showHint = true;
      });
      // フラグを保存（次回以降は表示しない）
      await prefs.setBool(_kQuickActionHintShownKey, true);
    }
  }

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
          // 初回のみヒントを表示
          if (_showHint) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'シフトを長押しすることでも\nこのメニューを開けます',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        TextButton(
          onPressed: widget.onSwapStart != null
              ? () {
                  Navigator.of(context).pop();
                  widget.onSwapStart!(widget.shift);
                }
              : null,
          child: Text(
            'スタッフ入替',
            style: TextStyle(
              color: widget.onSwapStart != null ? Colors.orange.shade700 : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showStaffChangeDialog(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    final activeStaff = staffProvider.activeStaffList;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                    : () => _changeStaffWithProvider(dialogContext, staff, shiftProvider),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
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
        // 制約チェックはcalendar_screen.dartの_moveShiftToDateで行う
        if (widget.onDateMove != null) {
          widget.onDateMove!(widget.shift, selectedDate);
        }
      }
    });
  }

  void _changeStaffWithProvider(BuildContext dialogContext, Staff newStaff, ShiftProvider shiftProvider) async {
    // スタッフ変更の制約チェック - 重複チェック
    final conflictShifts = shiftProvider.getShiftsForDate(widget.shift.date)
        .where((s) => s.staffId == newStaff.id && s.id != widget.shift.id)
        .toList();
    final conflictShift = conflictShifts.isNotEmpty ? conflictShifts.first : null;

    if (conflictShift != null) {
      Navigator.of(dialogContext).pop();
      _showConflictDialog(dialogContext,
        '${newStaff.name}は既に${widget.shift.date.month}/${widget.shift.date.day}に'
        '${conflictShift.shiftType}のシフトが入っています。\n\n'
        '同じ日に同じスタッフを複数のシフトに割り当てることはできません。'
      );
      return;
    }

    // ConstraintCheckerで包括的な制約チェック
    final violations = ConstraintChecker.checkViolations(
      staff: newStaff,
      date: widget.shift.date,
      shiftType: widget.shift.shiftType,
      shiftProvider: shiftProvider,
      existingShiftId: widget.shift.id,
    );

    if (violations.isNotEmpty) {
      Navigator.of(dialogContext).pop();
      final confirmed = await showDialog<bool>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          title: const Text('制約違反の警告'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${newStaff.name}には以下の制約違反があります：'),
              const SizedBox(height: 8),
              ...violations.map((v) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(v)),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              const Text('それでもスタッフを変更しますか？'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('変更する', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    } else {
      // 制約違反がない場合はダイアログを閉じる
      Navigator.of(dialogContext).pop();
    }

    final updatedShift = widget.shift..staffId = newStaff.id;
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