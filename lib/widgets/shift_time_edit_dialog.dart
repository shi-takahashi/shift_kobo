import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shift_time_setting.dart';
import '../providers/shift_time_provider.dart';

/// シフトの「名前・開始・終了」を1画面で編集する共有ダイアログ。
/// シフト時間設定画面と初回セットアップウィザードの両方で使用する。
/// 表示には ShiftTimeProvider がスコープ内にあること。
class ShiftTimeEditDialog extends StatefulWidget {
  final ShiftTimeSetting setting;

  const ShiftTimeEditDialog({super.key, required this.setting});

  @override
  State<ShiftTimeEditDialog> createState() => _ShiftTimeEditDialogState();
}

class _ShiftTimeEditDialogState extends State<ShiftTimeEditDialog> {
  late final TextEditingController _nameController;
  late String _startTime;
  late String _endTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.setting.displayName);
    _startTime = widget.setting.startTime;
    _endTime = widget.setting.endTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<String?> _selectTime(String initialTime) async {
    final parts = initialTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null) return null;
    return '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShiftTimeProvider>();
    final name = _nameController.text.trim();
    final canSave = _errorMessage == null && name.isNotEmpty;

    return AlertDialog(
      title: Text('${widget.setting.shiftType.defaultName}の設定'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'シフト名',
                hintText: '例: 朝シフト、開店準備、A勤務',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              onChanged: (value) {
                setState(() {
                  if (value.trim().isNotEmpty &&
                      provider.isNameDuplicate(
                          value.trim(), widget.setting.shiftType)) {
                    _errorMessage = 'この名前は既に使用されています';
                  } else {
                    _errorMessage = null;
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '勤務時間',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('開始:')),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await _selectTime(_startTime);
                      if (t != null) setState(() => _startTime = t);
                    },
                    child: Text(_startTime),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('終了:')),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await _selectTime(_endTime);
                      if (t != null) setState(() => _endTime = t);
                    },
                    child: Text(_endTime),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: canSave
              ? () {
                  final trimmed = _nameController.text.trim();
                  provider.updateShiftName(widget.setting.shiftType, trimmed);
                  provider.updateShiftTime(
                      widget.setting.shiftType, _startTime, _endTime);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$trimmedの設定を更新しました'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
