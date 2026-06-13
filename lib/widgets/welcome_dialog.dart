import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// ウェルカムダイアログ
class WelcomeDialog extends StatelessWidget {
  final AppUser appUser;
  final VoidCallback onStart;

  const WelcomeDialog({
    super.key,
    required this.appUser,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.waving_hand,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('ようこそ！'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'シフト工房へようこそ！\n基本的な使い方をご説明します。',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 管理者とスタッフで説明を分岐
            if (appUser.isAdmin) ...[
              const Text('1. スタッフ画面でスタッフを登録'),
              const SizedBox(height: 8),
              const Text('2. チーム画面でシフト時間と割当を設定'),
              const SizedBox(height: 8),
              const Text('3. カレンダー画面でシフトを自動作成'),
              const SizedBox(height: 8),
              const Text('4. 必要に応じて手動で調整'),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                const Text('5. 完成したシフト表を共有'),
              ],
            ] else ...[
              const Text('1. マイページで自分のシフトを確認'),
              const SizedBox(height: 8),
              const Text('2. カレンダーで全員分のシフトを確認'),
              const SizedBox(height: 8),
              const Text('3. 休み希望・勤務希望などを申請'),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 ヒント：右上の？ボタンや「その他」タブからいつでも詳しいヘルプを見られます。',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // 「次に何をすればいいか」を一目で示すため、全幅の目立つボタンにする。
        // 管理者は最初の行動（スタッフ登録）へ誘導する文言にする。
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: Icon(appUser.isAdmin ? Icons.person_add : Icons.play_arrow),
            label: Text(appUser.isAdmin ? 'スタッフ登録へ進む' : '始める'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
