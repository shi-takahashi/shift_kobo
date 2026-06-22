import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../team/join_team_screen.dart';
import '../team/team_creation_screen.dart';
import 'login_screen.dart';

/// サインアップ（新規登録）画面
class SignupScreen extends StatefulWidget {
  /// 「招待を受けて参加する」経路かどうか。
  /// - true: 登録後に「既存チームに参加（招待コード入力）」へ直行する。
  /// - false（「シフト作成を始める」→アカウント登録）: 「新しいチーム作成」へ直行する。
  /// 役割選択で意図が決まっているため、登録後に作成/参加の選択画面は挟まない。
  final bool joinExisting;

  const SignupScreen({
    super.key,
    this.joinExisting = false,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// サインアップ処理
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // メールアドレスから表示名を生成（@の前の部分）
      final email = _emailController.text.trim();
      final displayName = email.split('@').first;

      final user = await _authService.signUp(
        email: email,
        password: _passwordController.text,
        displayName: displayName,
      );

      if (user == null) {
        throw '新規登録に失敗しました';
      }

      // 認証トークンが完全に反映され、Firestoreにアクセスできることを確認
      // リトライ付きでユーザー情報取得を試みる（最大5回、500msごと）
      AppUser? appUser;
      for (var i = 0; i < 5; i++) {
        try {
          appUser = await _authService.getUser(user.uid);
          if (appUser != null) {
            print('✅ [Signup] Firestoreアクセス確認成功（${i + 1}回目）');
            break;
          }
        } catch (e) {
          print('⚠️ [Signup] Firestoreアクセス確認失敗（${i + 1}回目）: $e');
        }

        if (i < 4) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (appUser == null) {
        throw 'アカウントは作成されましたが、データの初期化に失敗しました。アプリを再起動してください。';
      }

      if (!mounted) return;

      // 役割選択で選んだ意図に応じて、作成/参加の選択画面を挟まず直接その先へ進む。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.joinExisting
              // 招待を受けて参加：招待コード入力へ直行
              ? JoinTeamScreen(userId: user.uid, startInInviteMode: true)
              // シフト作成を始める：新しいチーム作成へ直行
              : TeamCreationScreen(userId: user.uid),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString();

      // 「既にメールアドレスが使用されている」エラーの場合
      if (errorMessage.contains('このメールアドレスは既に使用されています') || errorMessage.contains('email-already-in-use')) {
        // ログイン画面への誘導ダイアログを表示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('アカウント登録済み'),
              ],
            ),
            content: const Text(
              'このメールアドレスは既に登録されています。\n\nログイン画面に移動しますか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('ログインへ'),
              ),
            ],
          ),
        );
      } else {
        // その他のエラーはSnackBarで表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // アプリロゴ・タイトル
                Icon(
                  Icons.calendar_month,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'シフト工房',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // メールアドレス入力
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'メールアドレスを入力してください';
                    }
                    if (!value.contains('@')) {
                      return '正しいメールアドレスを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // パスワード入力
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'パスワード（6文字以上）',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    if (value.length < 6) {
                      return 'パスワードは6文字以上で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // パスワード確認入力
                TextFormField(
                  controller: _passwordConfirmController,
                  obscureText: _obscurePasswordConfirm,
                  decoration: InputDecoration(
                    labelText: 'パスワード（確認）',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'パスワード（確認）を入力してください';
                    }
                    if (value != _passwordController.text) {
                      return 'パスワードが一致しません';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 新規登録ボタン
                FilledButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('新規登録'),
                ),
                const SizedBox(height: 16),

                // 注意事項
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '新規登録後の流れ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.joinExisting) ...const [
                          Text('1. アカウント作成'),
                          Text('2. 招待コードを入力してチームに参加'),
                          Text('3. シフト確認・休み希望/勤務希望などの申請を開始'),
                        ] else ...const [
                          Text('1. アカウント作成'),
                          Text('2. 新しいチームを作成'),
                          Text('3. スタッフ登録・自動シフト作成を開始'),
                          SizedBox(height: 8),
                          Text(
                            '※ チームは1人から作成・利用できます\n   後からスタッフを招待することも可能',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ログイン画面へのリンク（小さく）
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '既にアカウントをお持ちの方は',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
