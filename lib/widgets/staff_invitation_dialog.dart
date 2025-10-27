import 'package:flutter/material.dart';
import '../models/staff.dart';
import '../services/invitation_service.dart';

/// スタッフ選択＆招待メール送信ダイアログ
class StaffInvitationDialog extends StatefulWidget {
  final List<Staff> staffList;
  final String teamName;
  final String inviteCode;

  const StaffInvitationDialog({
    super.key,
    required this.staffList,
    required this.teamName,
    required this.inviteCode,
  });

  @override
  State<StaffInvitationDialog> createState() => _StaffInvitationDialogState();
}

class _StaffInvitationDialogState extends State<StaffInvitationDialog> {
  late Set<String> _selectedStaffIds;

  @override
  void initState() {
    super.initState();
    // デフォルトで招待対象のスタッフを選択
    _selectedStaffIds = widget.staffList
        .where((staff) => _shouldInviteByDefault(staff))
        .map((staff) => staff.id)
        .toSet();
  }

  /// デフォルトで招待対象にするべきか判定
  bool _shouldInviteByDefault(Staff staff) {
    return staff.userId == null && // まだアプリ利用していない
        staff.isActive && // 有効
        staff.email != null &&
        staff.email!.isNotEmpty; // メールアドレスあり
  }

  /// 選択されたスタッフのリストを取得
  List<Staff> get _selectedStaffs {
    return widget.staffList
        .where((staff) => _selectedStaffIds.contains(staff.id))
        .toList();
  }

  /// 選択されたスタッフのメールアドレスリストを取得
  List<String> get _selectedEmails {
    return _selectedStaffs
        .where((staff) => staff.email != null && staff.email!.isNotEmpty)
        .map((staff) => staff.email!)
        .toList();
  }

  /// 10人以上選択時の警告ダイアログを表示
  Future<bool> _showWarningDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text(
          '${_selectedEmails.length}人選択されています。\n'
          '一度に多数のメールアドレスを指定すると、'
          'メーラーが起動しない場合があります。\n\n'
          '続けますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('続ける'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// 招待メールを送信
  Future<void> _sendInvitationEmail() async {
    // 10人以上選択時は警告を表示
    if (_selectedEmails.length > 10) {
      final proceed = await _showWarningDialog();
      if (!proceed) return;
    }

    try {
      await InvitationService.sendInvitationEmail(
        recipientEmails: _selectedEmails,
        teamName: widget.teamName,
        inviteCode: widget.inviteCode,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メーラーを起動しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 招待可能なスタッフ（メールアドレスあり）のみ表示
    final invitableStaffs = widget.staffList
        .where((staff) => staff.email != null && staff.email!.isNotEmpty)
        .toList();

    return AlertDialog(
      title: const Text('招待メール送信'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '招待メールを送信するスタッフを選択してください',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '選択: ${_selectedEmails.length}人',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: invitableStaffs.length,
                itemBuilder: (context, index) {
                  final staff = invitableStaffs[index];
                  final isSelected = _selectedStaffIds.contains(staff.id);

                  // 招待できない理由を表示
                  String? subtitle;
                  if (staff.userId != null) {
                    subtitle = '既にアプリ利用中';
                  } else if (!staff.isActive) {
                    subtitle = '無効なスタッフ';
                  }

                  return CheckboxListTile(
                    title: Text(staff.name),
                    subtitle: subtitle != null
                        ? Text(
                            '$subtitle\n${staff.email ?? ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        : Text(
                            staff.email ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedStaffIds.add(staff.id);
                        } else {
                          _selectedStaffIds.remove(staff.id);
                        }
                      });
                    },
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _sendInvitationEmail,
          child: Text(_selectedEmails.isEmpty
              ? '送信（宛先なし）'
              : '送信 (${_selectedEmails.length}人)'),
        ),
      ],
    );
  }
}
