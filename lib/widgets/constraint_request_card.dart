import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/constraint_request.dart';
import '../models/staff.dart';
import '../providers/constraint_request_provider.dart';

/// 休み希望申請カードウィジェット
class ConstraintRequestCard extends StatelessWidget {
  final ConstraintRequest request;
  final Staff staff;
  final AppUser appUser;

  const ConstraintRequestCard({
    super.key,
    required this.request,
    required this.staff,
    required this.appUser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー（スタッフ名、申請日時）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        staff.name.isNotEmpty ? staff.name[0] : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      staff.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('MM/dd HH:mm', 'ja').format(request.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // 申請内容
            _buildRequestContent(context),

            const SizedBox(height: 16),

            // 承認・却下ボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('却下'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approveRequest(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('承認'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestContent(BuildContext context) {
    final label = _getRequestTypeLabel();
    final content = _getRequestContentText(context);
    final icon = _getRequestIcon();

    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRequestTypeLabel() {
    debugPrint('🔍 [RequestCard] isDelete=${request.isDelete}, type=${request.requestType}, status=${request.status}');
    final prefix = request.isDelete ? '【削除申請】' : '';
    switch (request.requestType) {
      case ConstraintRequest.typeSpecificDay:
        return '$prefix特定日の休み希望';
      case ConstraintRequest.typeWeekday:
        return '$prefix休み希望曜日';
      case ConstraintRequest.typeShiftType:
        return '$prefix勤務不可シフトタイプ';
      default:
        return '$prefix休み希望';
    }
  }

  String _getRequestContentText(BuildContext context) {
    final actionText = request.isDelete ? 'を削除' : '';
    switch (request.requestType) {
      case ConstraintRequest.typeSpecificDay:
        if (request.specificDate != null) {
          return '${DateFormat('yyyy/MM/dd(E)', 'ja').format(request.specificDate!)}$actionText';
        }
        return '不明な日付';
      case ConstraintRequest.typeWeekday:
        if (request.weekday != null) {
          final dayNames = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
          return '${dayNames[request.weekday! - 1]}$actionText';
        }
        return '不明な曜日';
      case ConstraintRequest.typeShiftType:
        final shiftTypeName = request.shiftType ?? '不明なシフトタイプ';
        return '$shiftTypeName$actionText';
      default:
        return '不明な申請';
    }
  }

  IconData _getRequestIcon() {
    switch (request.requestType) {
      case ConstraintRequest.typeSpecificDay:
        return Icons.event_busy;
      case ConstraintRequest.typeWeekday:
        return Icons.calendar_today;
      case ConstraintRequest.typeShiftType:
        return Icons.work_off;
      default:
        return Icons.info_outline;
    }
  }

  /// 承認処理
  Future<void> _approveRequest(BuildContext context) async {
    final requestProvider = context.read<ConstraintRequestProvider>();

    try {
      await requestProvider.approveRequest(
        request,
        appUser.uid,
        staff,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name}さんの申請を承認しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('承認処理に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 却下ダイアログを表示
  Future<void> _showRejectDialog(BuildContext context) async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('申請を却下'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${staff.name}さんの申請を却下します。',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '却下理由（任意）',
                hintText: '例：シフトが埋まっているため',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('却下'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _rejectRequest(context, reasonController.text.trim());
    }

    reasonController.dispose();
  }

  /// 却下処理
  Future<void> _rejectRequest(BuildContext context, String reason) async {
    final requestProvider = context.read<ConstraintRequestProvider>();

    try {
      await requestProvider.rejectRequest(
        request,
        appUser.uid,
        reason,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name}さんの申請を却下しました'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('却下処理に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
