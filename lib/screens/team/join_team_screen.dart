import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/auth_gate.dart';
import 'team_creation_screen.dart';

/// チーム参加画面（スタッフ用）
class JoinTeamScreen extends StatefulWidget {
  final String userId;

  const JoinTeamScreen({
    super.key,
    required this.userId,
  });

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _inviteCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showInviteCodeInput = false; // 招待コード入力フォームを表示するかどうか

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final inviteCode = _inviteCodeController.text.trim().toUpperCase();

      // チーム参加処理（Teamオブジェクトを取得）
      final team = await _authService.joinTeamByCode(
        inviteCode: inviteCode,
        userId: widget.userId,
      );

      if (!mounted) return;

      // チーム名を含む成功ダイアログを表示
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              const Text('参加完了！'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '「${team.name}」に参加しました',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'これから管理者がシフトを作成すると、あなたのマイページでシフトを確認できるようになります。',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('始める'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // AuthGateへ遷移（全画面をクリア）
      // AuthGateがteamIdを取得してHomeScreenへ遷移する
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      // エラーダイアログで詳細を表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('エラー'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              e.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  void _handleCreateTeam() {
    // チーム作成画面へ遷移
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TeamCreationScreen(
          userId: widget.userId,
          shouldMigrateData: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('シフト工房へようこそ'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: !_showInviteCodeInput ? _buildChoiceView() : _buildInviteCodeInputView(),
        ),
      ),
    );
  }

  /// 選択画面（チーム作成 or チーム参加）
  Widget _buildChoiceView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),

        // アイコン
        Icon(
          Icons.groups,
          size: 100,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 32),

        // タイトル
        Text(
          'シフト管理を始めよう',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 説明
        Text(
          kIsWeb ? '管理者から受け取った招待コードを入力してチームに参加してください。' : '新しいチームを作成するか、既存のチームに参加するかを選択してください。',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Web版ではチーム作成ボタンを非表示
        if (!kIsWeb) ...[
          // チーム作成ボタン（大きく目立たせる）
          Card(
            elevation: 4,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: InkWell(
              onTap: _handleCreateTeam,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '新しいチームを作成',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '管理者の場合（後からスタッフ招待可）',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // または
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('または', style: TextStyle(color: Colors.grey)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // チーム参加ボタン
        Card(
          elevation: 4,
          color: Colors.green.shade50,
          child: InkWell(
            onTap: () {
              setState(() {
                _showInviteCodeInput = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.group_add,
                    size: 64,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '既存のチームに参加',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '管理者から招待コードを受け取っている場合',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        // 説明カード
        Card(
          color: Colors.blue.shade50,
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'チームについて',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• チームは管理者とスタッフで構成されます\n'
                  '• 管理者：スタッフ登録・シフト作成が可能\n'
                  '• スタッフ：シフト閲覧・休み希望入力が可能\n'
                  '• チームに管理者は必須、スタッフは任意で招待',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 招待コード入力画面
  Widget _buildInviteCodeInputView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          // 戻るボタン
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showInviteCodeInput = false;
                  _inviteCodeController.clear();
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('選択画面に戻る'),
            ),
          ),
          const SizedBox(height: 24),

          // アイコン
          Icon(
            Icons.vpn_key,
            size: 80,
            color: Colors.green.shade700,
          ),
          const SizedBox(height: 32),

          // タイトル
          Text(
            'チームに参加',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 説明
          const Text(
            '管理者から受け取った8桁の招待コードを入力してください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // 招待コード入力フィールド
          TextFormField(
            controller: _inviteCodeController,
            decoration: const InputDecoration(
              labelText: '招待コード',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
              counterText: '',
            ),
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '招待コードを入力してください';
              }
              if (value.trim().length != 8) {
                return '招待コードは8文字です';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // チーム参加ボタン
          FilledButton.icon(
            onPressed: _isLoading ? null : _handleJoinTeam,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isLoading ? 'チームに参加中...' : 'チームに参加'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),

          // 説明カード
          Card(
            color: Colors.green.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        '招待コードについて',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '招待コードはチーム管理者から受け取った8文字のコードです。\n'
                    'チーム参加後、シフトの閲覧や休み希望の入力ができます。',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
