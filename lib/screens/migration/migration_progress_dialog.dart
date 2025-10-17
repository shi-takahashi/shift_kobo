import 'package:flutter/material.dart';
import '../../services/migration_service.dart';

/// データ移行進捗ダイアログ
class MigrationProgressDialog extends StatefulWidget {
  final String teamId;

  const MigrationProgressDialog({
    super.key,
    required this.teamId,
  });

  @override
  State<MigrationProgressDialog> createState() =>
      _MigrationProgressDialogState();
}

class _MigrationProgressDialogState extends State<MigrationProgressDialog> {
  bool _isCompleted = false;
  MigrationResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🔵 MigrationProgressDialog initState - teamId: ${widget.teamId}');
    _startMigration();
  }

  Future<void> _startMigration() async {
    print('🚀 データ移行開始 - teamId: ${widget.teamId}');
    try {
      // データ移行実行
      final result = await MigrationService.migrateToFirestore(widget.teamId);
      print('✅ データ移行完了: success=${result.success}');

      if (mounted) {
        setState(() {
          _result = result;
          _isCompleted = true;
        });
      }

      if (result.success) {
        // 移行成功後、Hiveデータを削除
        await MigrationService.clearHiveData();

        // 2秒待ってから完了メッセージを表示
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pop(true); // 成功を返す
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompleted = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 移行中はバックボタンで閉じられないようにする
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _isCompleted && _errorMessage == null
                  ? Icons.check_circle
                  : Icons.cloud_upload,
              color: _isCompleted && _errorMessage == null
                  ? Colors.green
                  : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              _isCompleted && _errorMessage == null
                  ? 'データ移行完了'
                  : _errorMessage != null
                      ? 'データ移行エラー'
                      : 'データ移行中...',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isCompleted || _errorMessage != null)
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                'エラーが発生しました:\n$_errorMessage',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              )
            else if (_result != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '移行が完了しました！',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCountRow('スタッフ', _result!.staffCount),
                  _buildCountRow('シフト', _result!.shiftsCount),
                  _buildCountRow('制約', _result!.constraintsCount),
                  _buildCountRow('シフト時間設定', _result!.shiftTimeSettingsCount),
                  if (_result!.monthlyRequirementsCount > 0)
                    _buildCountRow('月間設定', _result!.monthlyRequirementsCount),
                  const Divider(height: 24),
                  _buildCountRow(
                    '合計',
                    _result!.totalCount,
                    isTotal: true,
                  ),
                ],
              )
            else
              const Text(
                '既存のデータをクラウドに移行しています...\nしばらくお待ちください',
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: _errorMessage != null
            ? [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // 失敗を返す
                  },
                  child: const Text('閉じる'),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildCountRow(String label, int count, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '$count件',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
