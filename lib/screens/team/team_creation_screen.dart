import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../widgets/invite_guide_dialog.dart';
import '../home_screen.dart';
import '../migration/migration_progress_dialog.dart';

/// チーム作成画面
class TeamCreationScreen extends StatefulWidget {
  final String userId;
  final bool shouldMigrateData; // データ移行フラグ

  const TeamCreationScreen({
    super.key,
    required this.userId,
    this.shouldMigrateData = false,
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

    // AppUserを取得
    final appUser = await _authService.getUser(widget.userId);
    if (!mounted) return;

    if (appUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー情報の取得に失敗しました')),
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

      // データ移行が必要な場合
      print('🔍 shouldMigrateData: ${widget.shouldMigrateData}');
      if (widget.shouldMigrateData) {
        print('🔵 データ移行ダイアログを表示 - teamId: ${team.id}');
        // データ移行ダイアログを表示
        final migrationSuccess = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // 移行中は閉じられない
          builder: (context) => MigrationProgressDialog(teamId: team.id),
        );

        if (!mounted) return;

        if (migrationSuccess == true) {
          // 移行成功 - 招待案内ダイアログを表示してからホーム画面へ
          await _showInviteGuideDialog(team.id, team.name, team.inviteCode);
        } else {
          // 移行失敗 - エラーメッセージは既にダイアログで表示されている
          // ユーザーは「閉じる」ボタンで戻る
        }
      } else {
        // データ移行不要の場合は通常フロー
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ チームを作成しました')),
        );

        // 招待案内ダイアログを表示してからホーム画面へ
        await _showInviteGuideDialog(team.id, team.name, team.inviteCode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
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
                        Text('• 将来的にスタッフを招待できます'),
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
