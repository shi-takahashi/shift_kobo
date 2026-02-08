import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'role_selection_screen.dart';
import 'signup_screen.dart';

/// オンライン版からの新規ユーザー向けウェルカム画面
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ファネル分析用イベント送信（「シフト作成を始める」を押した）
    AnalyticsService.logWelcomeScreenViewed();
  }

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

              // 主な機能
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.blue, size: 24),
                        SizedBox(width: 8),
                        Text(
                          '主な機能',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.auto_awesome,
                      text: '自動シフト作成',
                      description: 'スタッフの希望を考慮して最適なシフトを自動生成',
                      color: Colors.blue,
                    ),
                    SizedBox(height: 8),
                    _FeatureItem(
                      icon: Icons.table_chart,
                      text: 'シフト表の出力',
                      description: 'PDF・PNG・Excel形式で簡単に出力できます',
                      color: Colors.blue,
                    ),
                    SizedBox(height: 8),
                    _FeatureItem(
                      icon: Icons.sync,
                      text: 'チームで共有（オプション）',
                      description: 'メンバーとリアルタイムで最新のシフトを共有',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // メインボタン: とりあえず試してみる（匿名ログイン）
              FilledButton.icon(
                onPressed: _isLoading ? null : _tryAnonymously,
                icon: const Icon(Icons.play_arrow),
                label: const Text('とりあえず試してみる'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),

              // 注意書き
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '※ すぐに使い始められます',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // サブボタン: アカウント作成（データ引き継ぎ目的）
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                icon: const Icon(Icons.app_registration),
                label: const Text('アカウント登録'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),

              // アカウント登録の説明
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '機種変更してもデータを引き継ぎたい方',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // 戻るリンク
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const RoleSelectionScreen(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('最初の画面に戻る'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 匿名ログインを実行
  Future<void> _tryAnonymously() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInAnonymously();

      if (user == null) {
        throw Exception('匿名ログインに失敗しました');
      }

      // ユーザー情報を取得
      final appUser = await authService.getUser(user.uid);
      if (appUser == null) {
        throw Exception('ユーザー情報の取得に失敗しました');
      }

      // HomeScreenに直接遷移（全ての画面をクリア）
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(appUser: appUser),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        // エラーの詳細をダイアログで表示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('エラー'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '匿名ログインに失敗しました。',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('考えられる原因:'),
                  const SizedBox(height: 8),
                  const Text('• Firebase Consoleで匿名認証が無効になっている'),
                  const Text('• ネットワーク接続エラー'),
                  const SizedBox(height: 16),
                  const Text('エラー詳細:'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.toString(),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
        setState(() => _isLoading = false);
      }
    }
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
