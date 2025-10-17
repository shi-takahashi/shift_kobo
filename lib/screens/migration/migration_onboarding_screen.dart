import 'package:flutter/material.dart';
import '../auth/signup_screen.dart';

/// オフライン版からのアップデート時に表示するオンボーディング画面
class MigrationOnboardingScreen extends StatelessWidget {
  const MigrationOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // アイコン
              Icon(
                Icons.cloud_upload,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // タイトル
              Text(
                'シフト工房が\nオンライン対応しました！',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'より便利になった新機能をご利用いただけます',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // メリット説明
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.celebration, color: Colors.blue, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '新機能のご紹介',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _FeatureItem(
                        icon: Icons.people,
                        text: 'チームでシフトを共有',
                        description: 'スタッフ全員がシフトを確認できます',
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.calendar_today,
                        text: 'メンバーが休み希望を入力',
                        description: '管理者はメンバーの希望を確認できます',
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.sync,
                        text: '複数端末でリアルタイム同期',
                        description: 'スマホ・タブレットで最新データを表示',
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.backup,
                        text: 'データ自動バックアップ',
                        description: '端末を変えてもデータが消えません',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // データ移行の案内
              Card(
                color: Colors.green.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '既存データについて',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '✅ 既存のスタッフ・シフトデータは自動で移行されます',
                        style: TextStyle(height: 1.5),
                      ),
                      Text(
                        '✅ 移行後もこれまで通りご利用いただけます',
                        style: TextStyle(height: 1.5),
                      ),
                      Text(
                        '✅ データは安全にクラウドに保存されます',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 手順説明
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'ご利用手順（3ステップ）',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _StepItem(step: '1', text: 'アカウントを新規登録'),
                      SizedBox(height: 8),
                      _StepItem(step: '2', text: 'チーム名を入力'),
                      SizedBox(height: 8),
                      _StepItem(step: '3', text: 'データ移行完了（自動）'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // アカウント作成ボタン
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SignupScreen(
                        isFromMigration: true, // データ移行フラグを渡す
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('アカウント作成して始める'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// 機能紹介アイテム
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 手順アイテム
class _StepItem extends StatelessWidget {
  final String step;
  final String text;

  const _StepItem({
    required this.step,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
