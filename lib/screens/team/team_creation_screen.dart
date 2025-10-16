import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
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

  /// チーム作成処理
  Future<void> _handleCreateTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.createTeam(
        teamName: _teamNameController.text.trim(),
        ownerId: widget.userId,
      );

      if (!mounted) return;

      // 初回ヘルプ表示フラグを先に保存（2回表示されるのを防ぐ）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_first_time_help', true);

      // ホーム画面へ遷移（ウェルカムダイアログを表示）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(showWelcomeDialog: true),
        ),
        (route) => false, // 全ての前の画面を削除
      );

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ チームを作成しました')),
      );
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
                        Text('• 将来的にメンバーを招待できます'),
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
