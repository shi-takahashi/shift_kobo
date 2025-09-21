import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('準備中の機能です')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('月間シフト設定'),
          subtitle: const Text('1日あたりの必要人数を設定'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('準備中の機能です')),
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
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('準備中の機能です')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('データ復元'),
          subtitle: const Text('バックアップからデータを復元'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('準備中の機能です')),
            );
          },
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
          subtitle: const Text('バージョン 1.0.0'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'シフト工房',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2024 Shift Kobo',
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip),
          title: const Text('プライバシーポリシー'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('準備中の機能です')),
            );
          },
        ),
      ],
    );
  }
}