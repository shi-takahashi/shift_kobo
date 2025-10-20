import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

/// チーム招待画面（管理者用）
class TeamInviteScreen extends StatefulWidget {
  const TeamInviteScreen({super.key});

  @override
  State<TeamInviteScreen> createState() => _TeamInviteScreenState();
}

class _TeamInviteScreenState extends State<TeamInviteScreen> {
  final AuthService _authService = AuthService();
  String? _inviteCode;
  String? _teamName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
  }

  Future<void> _loadInviteCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw '❌ ログインしていません';
      }

      // ユーザー情報を取得してteamIdを確認
      final appUser = await _authService.getUser(user.uid);
      if (appUser?.teamId == null) {
        throw '❌ チームに所属していません';
      }

      // チーム情報を取得
      final team = await _authService.getTeam(appUser!.teamId!);
      if (team == null) {
        throw '❌ チーム情報が見つかりません';
      }

      // チームのinviteCodeフィールドを取得
      final inviteCode = team.inviteCode;

      setState(() {
        _inviteCode = inviteCode;
        _teamName = team.name;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('招待コードの取得に失敗しました: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _copyInviteCode() {
    if (_inviteCode == null) return;

    Clipboard.setData(ClipboardData(text: _inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('招待コードをコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チーム招待'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // アイコン
                    Icon(
                      Icons.group_add,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 32),

                    // チーム名
                    Text(
                      _teamName ?? '',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // 説明
                    const Text(
                      'スタッフに招待コードを共有してください',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // 招待コード表示
                    Card(
                      elevation: 4,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text(
                              '招待コード',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _inviteCode ?? '',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // コピーボタン
                    FilledButton.icon(
                      onPressed: _copyInviteCode,
                      icon: const Icon(Icons.copy),
                      label: const Text('招待コードをコピー'),
                    ),
                    const SizedBox(height: 16),

                    // 使い方の説明
                    Card(
                      color: Colors.blue.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '招待方法',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1. 上の招待コードをコピー\n'
                              '2. LINEやメールでスタッフに送信\n'
                              '3. スタッフがアプリで招待コードを入力',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
