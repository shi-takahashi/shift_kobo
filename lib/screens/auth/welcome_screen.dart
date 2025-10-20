import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

/// オンライン版からの新規ユーザー向けウェルカム画面
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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

              // アプリアイコン
              Icon(
                Icons.calendar_month,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // タイトル
              Text(
                'シフト工房',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'チームでシフトを共有・管理',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 機能紹介
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
                            '主な機能',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _FeatureItem(
                        icon: Icons.auto_awesome,
                        text: '自動シフト作成',
                        description: 'AIが最適なシフトを自動生成',
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.people,
                        text: 'チームで共有',
                        description: 'スタッフ全員がシフトを確認',
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.calendar_today,
                        text: '休み希望管理',
                        description: 'スタッフの希望を簡単に収集',
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.sync,
                        text: 'リアルタイム同期',
                        description: '複数端末で最新データを表示',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // アカウント作成ボタン
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const SignupScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('アカウント作成して始める'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // ログインリンク
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '既にアカウントをお持ちの方は',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text('ログイン'),
                  ),
                ],
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
