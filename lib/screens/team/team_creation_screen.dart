import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../widgets/invite_guide_dialog.dart';
import '../home_screen.dart';

/// チーム作成画面
class TeamCreationScreen extends StatefulWidget {
  final String userId;

  const TeamCreationScreen({
    super.key,
    required this.userId,
  });

  @override
  State<TeamCreationScreen> createState() => _TeamCreationScreenState();
}

class _TeamCreationScreenState extends State<TeamCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  /// ユーザー情報を取得（リトライ機能付き）
  ///
  /// チーム作成直後はFirestoreへの書き込みとキャッシュの同期に時間がかかる場合があるため、
  /// nullの場合は500ms待ってから再度取得を試みる（最大3回）。
  Future<dynamic> _getUserWithRetry(String uid) async {
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);

    for (var i = 0; i < maxRetries; i++) {
      try {
        final appUser = await _authService.getUser(uid);
        if (appUser != null) {
          debugPrint('✅ [TeamCreation] ユーザー情報取得成功（試行${i + 1}回目）');
          return appUser;
        }
      } catch (e) {
        debugPrint('⚠️ [TeamCreation] ユーザー情報取得エラー（試行${i + 1}回目）: $e');
      }

      // 最後の試行以外は待機してリトライ
      if (i < maxRetries - 1) {
        debugPrint('⏳ [TeamCreation] ${retryDelay.inMilliseconds}ms後にリトライします...');
        await Future.delayed(retryDelay);
      }
    }

    debugPrint('❌ [TeamCreation] ユーザー情報取得失敗（$maxRetries回試行）');
    return null;
  }

  /// 招待案内ダイアログを表示してホーム画面へ遷移
  Future<void> _showInviteGuideDialog(
    String teamId,
    String teamName,
    String inviteCode,
  ) async {
    // 招待案内ダイアログを表示
    await showDialog(
      context: context,
      barrierDismissible: false, // 必ず「始める」ボタンを押してもらう
      builder: (context) => InviteGuideDialog(
        inviteCode: inviteCode,
        teamName: teamName,
      ),
    );

    if (!mounted) return;

    // AppUserを取得（リトライ機能付き）
    final appUser = await _getUserWithRetry(widget.userId);
    if (!mounted) return;

    if (appUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー情報の取得に失敗しました。もう一度お試しください。')),
        );
      }
      return;
    }

    // ホーム画面へ遷移（ウェルカムダイアログは表示しない）
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          appUser: appUser,
          showWelcomeDialog: false, // 招待案内を表示したのでウェルカムは不要
        ),
      ),
      (route) => false, // 全ての前の画面を削除
    );
  }

  /// チーム作成処理
  Future<void> _handleCreateTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // チーム作成
      final team = await _authService.createTeam(
        teamName: _teamNameController.text.trim(),
        ownerId: widget.userId,
      );

      if (!mounted) return;

      // 初回ヘルプ表示フラグを先に保存（2回表示されるのを防ぐ）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_first_time_help', true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ チームを作成しました')),
      );

      // 招待案内ダイアログを表示してからホーム画面へ
      await _showInviteGuideDialog(team.id, team.name, team.inviteCode);
    } catch (e) {
      if (!mounted) return;

      // エラーメッセージを整形
      final errorMessage = e.toString();
      final isAuthError =
          errorMessage.contains('認証エラー') || errorMessage.contains('PERMISSION_DENIED') || errorMessage.contains('Missing or insufficient permissions');

      // エラーダイアログを表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Text('チーム作成エラー'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              if (isAuthError) ...[
                const SizedBox(height: 16),
                const Text(
                  '認証に問題がある可能性があります。もう一度お試しください。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チーム作成'),
        automaticallyImplyLeading: false, // 戻るボタンを非表示（必須手順）
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // アイコン
                Icon(
                  Icons.groups,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),

                // タイトル
                Text(
                  'チームを作成',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'シフト管理を行うチームの名前を入力してください',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // チーム名入力
                TextFormField(
                  controller: _teamNameController,
                  decoration: const InputDecoration(
                    labelText: 'チーム名',
                    hintText: '例: ○○店、△△部署',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'チーム名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // チーム作成ボタン
                FilledButton.icon(
                  onPressed: _isLoading ? null : _handleCreateTeam,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('チームを作成'),
                ),
                const SizedBox(height: 32),

                // 説明カード
                Card(
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'チーム作成後',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('• あなたは管理者として登録されます'),
                        Text('• スタッフの登録・シフト作成ができます'),
                        Text('• 登録したスタッフをチームに招待できます'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
