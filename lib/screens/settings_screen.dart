import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backup_service.dart';
import 'monthly_shift_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'shift_time_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = packageInfo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '基本設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.access_time),
          title: const Text('シフト時間設定'),
          subtitle: const Text('各シフトタイプの時間を設定'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ShiftTimeSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('月間シフト設定'),
          subtitle: const Text('各シフト時間の必要人数を設定'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MonthlyShiftSettingsScreen(),
              ),
            );
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'データ管理',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('データバックアップ'),
          subtitle: const Text('シフトデータをバックアップ'),
          onTap: () => _showBackupDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('データ復元'),
          subtitle: _isRestoring ? const Text('復元中...') : const Text('バックアップからデータを復元'),
          enabled: !_isRestoring,
          onTap: _isRestoring ? null : () => _showRestoreDialog(context),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'その他',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('アプリについて'),
          subtitle: Text(_packageInfo != null ? 'バージョン ${_packageInfo!.version}+${_packageInfo!.buildNumber}' : 'バージョン 情報取得中...'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'シフト工房',
              applicationVersion: _packageInfo != null ? '${_packageInfo!.version}+${_packageInfo!.buildNumber}' : '1.0.0',
              applicationLegalese: '© 2025 Shift Kobo\n\nシフト表自動作成アプリ\nスタッフの勤務スケジュールを効率的に管理',
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    '主な機能:\n'
                    '• シフト自動割り当て\n'
                    '• スタッフ管理\n'
                    '• カレンダー表示\n'
                    '• データバックアップ・復元\n'
                    '• 設定カスタマイズ',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip),
          title: const Text('プライバシーポリシー'),
          subtitle: const Text('個人情報保護方針'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データバックアップ'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下のデータをバックアップファイルとして保存します：'),
            SizedBox(height: 8),
            Text('• スタッフ情報'),
            Text('• シフトデータ'),
            Text('• 制約条件'),
            Text('• シフト時間設定'),
            Text('• 月間シフト設定'),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performBackup(context);
            },
            icon: const Icon(Icons.backup),
            label: const Text('バックアップ'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ復元'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('バックアップファイルからデータを復元します。'),
            SizedBox(height: 16),
            Text(
              '⚠️ 注意',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '復元を実行すると、現在のデータは削除されます。事前にバックアップを取ることをお勧めします。',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              // 少し待機してからファイル選択開始
              Future.delayed(const Duration(milliseconds: 300), () {
                _performRestore();
              });
            },
            icon: const Icon(Icons.restore),
            label: const Text('復元'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackup(BuildContext context) async {
    // Navigatorの参照を事前に保存
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('バックアップを作成中...'),
            ],
          ),
        ),
      );

      // バックアップを実行
      final result = await BackupService.shareBackupFile();

      // ローディングを閉じる（保存した参照を使用）
      navigator.pop();

      if (result != null) {
        // 成功メッセージ
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('バックアップが完了しました\n選択した場所に保存されました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // ローディングを閉じる
      try {
        navigator.pop();
      } catch (navError) {
        // ローディングダイアログが既に閉じられている場合は無視
      }

      // エラーメッセージ
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('バックアップに失敗しました: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performRestore() async {
    if (!mounted) return;

    setState(() {
      _isRestoring = true;
    });

    String? selectedFilePath;

    try {
      // ファイル選択
      selectedFilePath = await BackupService.pickBackupFile();

      if (selectedFilePath == null || !mounted) {
        setState(() {
          _isRestoring = false;
        });
        return; // ユーザーがキャンセル
      }
    } catch (e) {
      print('File picker error: $e');
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ファイル選択に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('データを復元中...'),
            ],
          ),
        ),
      );

      // 復元を実行（上書きモード）
      await BackupService.restoreFromFile(selectedFilePath, overwrite: true);

      if (!mounted) return;

      // ローディングを閉じる
      Navigator.of(context).pop();

      // 成功メッセージと再起動案内
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('復元完了'),
          content: const Text(
            'データの復元が完了しました。\n変更を反映するためにアプリを再起動してください。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (restoreError) {
      print('Restore error: $restoreError');

      if (mounted) {
        // ローディングを閉じる
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          print('Navigator error during restore failure: $navError');
        }

        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: ${restoreError.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

}
