import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
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
          subtitle: Text(_packageInfo != null ? 'バージョン ${_packageInfo!.version}' : 'バージョン 情報取得中...'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'シフト工房',
              applicationVersion: _packageInfo != null ? _packageInfo!.version : '1.0.0',
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
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('お問い合わせ'),
          subtitle: const Text('不具合報告や改善要望はこちら'),
          onTap: _sendContactEmail,
        ),
      ],
    );
  }

  Future<void> _sendContactEmail() async {
    const emailAddress = 'fdks487351@yahoo.co.jp';
    final version = _packageInfo?.version ?? '不明';
    final buildNumber = _packageInfo?.buildNumber ?? '不明';
    final osInfo = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : 'その他';

    final subject = Uri.encodeComponent('【シフト工房】お問い合わせ');
    final body = Uri.encodeComponent('━━━━━━━━━━━━━━\n'
        '◆お問い合わせ内容\n'
        '（ここに記入してください）\n'
        '\n'
        '\n'
        '\n'
        '━━━━━━━━━━━━━━\n'
        '【アプリ情報】\n'
        'バージョン：$version\n'
        'ビルド番号：$buildNumber\n'
        'OS：$osInfo\n'
        '━━━━━━━━━━━━━━');

    final emailUrl = Uri.parse('mailto:$emailAddress?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUrl)) {
        await launchUrl(emailUrl);
      } else {
        // メーラー起動できない場合、メールアドレスを表示
        if (mounted) {
          _showEmailAddressDialog(emailAddress);
        }
      }
    } catch (e) {
      // エラー時もメールアドレスを表示
      if (mounted) {
        _showEmailAddressDialog(emailAddress);
      }
    }
  }

  void _showEmailAddressDialog(String emailAddress) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('お問い合わせ先'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'メールアプリを起動できませんでした。\n以下のメールアドレスにお問い合わせください。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      emailAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'コピー',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: emailAddress));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('メールアドレスをコピーしました'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
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

      // Providerをリロードしてデータを再読み込み
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);

      staffProvider.reload();
      shiftProvider.reload();
      await shiftTimeProvider.reload();

      if (!mounted) return;

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('データの復元が完了しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
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
