import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'signup_screen.dart';

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
                'シフト管理を簡単に、もっと便利に',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 1人でも十分価値がある
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '管理者1人でも使えます',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _FeatureItem(
                      icon: Icons.auto_awesome,
                      text: '自動シフト作成',
                      description: 'スタッフの制約を考慮して最適なシフトを自動生成',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    const _FeatureItem(
                      icon: Icons.table_chart,
                      text: 'シフト表を簡単に作成・共有',
                      description: 'PNG・Excel形式で出力して配布できます',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // プラスアルファの機能
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle, color: Colors.blue, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'スタッフを招待するともっと便利',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _FeatureItem(
                        icon: Icons.sync,
                        text: 'リアルタイムでシフト共有',
                        description: 'スタッフ全員が最新のシフトを確認',
                        color: Colors.blue,
                      ),
                      SizedBox(height: 8),
                      _FeatureItem(
                        icon: Icons.calendar_today,
                        text: '休み希望の入力・承認',
                        description: 'スタッフが直接希望を入力できます',
                        color: Colors.blue,
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
  final MaterialColor color;

  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.description,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
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
