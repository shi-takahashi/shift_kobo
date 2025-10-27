import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/invitation_service.dart';
import '../../models/staff.dart';
import '../../widgets/staff_invitation_dialog.dart';

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

  /// 招待メール送信ダイアログを表示
  Future<void> _showInvitationDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ユーザー情報を取得してteamIdを確認
      final appUser = await _authService.getUser(user.uid);
      if (appUser?.teamId == null) {
        throw '❌ チームに所属していません';
      }

      // Firestoreから直接スタッフ一覧を取得
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(appUser!.teamId!)
          .collection('staff')
          .get();

      final staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        // TimestampをISO8601文字列に変換
        final convertedData = {
          ...data,
          'id': doc.id,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
          'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate().toIso8601String(),
        };
        return Staff.fromJson(convertedData);
      }).toList();

      // メールアドレスが登録されているスタッフのみ抽出
      final invitableStaffs = staffList
          .where((staff) => staff.email != null && staff.email!.isNotEmpty)
          .toList();

      if (!mounted) return;

      // メールアドレスが登録されているスタッフが0人の場合は、宛先なしでメーラーを起動
      if (invitableStaffs.isEmpty) {
        try {
          await InvitationService.sendInvitationEmail(
            recipientEmails: [],
            teamName: _teamName ?? '',
            inviteCode: _inviteCode ?? '',
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メーラーを起動しました')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
        return;
      }

      // スタッフがいる場合は選択ダイアログを表示
      showDialog(
        context: context,
        builder: (context) => StaffInvitationDialog(
          staffList: staffList,
          teamName: _teamName ?? '',
          inviteCode: _inviteCode ?? '',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スタッフ情報の取得に失敗しました: $e')),
      );
    }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
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
                      '招待コードを共有してください',
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

                    // 招待メール送信ボタン
                    FilledButton.icon(
                      onPressed: _showInvitationDialog,
                      icon: const Icon(Icons.email),
                      label: const Text('招待メールを送る'),
                    ),
                    const SizedBox(height: 16),

                    // 使い方の説明
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
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
                            const SizedBox(height: 12),

                            // 方法1: 招待メール（推奨）
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.email, size: 18, color: Colors.green.shade700),
                                      const SizedBox(width: 6),
                                      Text(
                                        '方法1: 招待メールを送る（おすすめ）',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '上の「招待メールを送る」ボタンから、スタッフを選択してメール送信',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 方法2: 招待コードを伝える
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.chat, size: 18, color: Colors.grey),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '方法2: 招待コードを口頭で伝える',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '上の招待コードとアプリの利用手順をスタッフに伝える\n'
                                    '※ 詳しい手順はヘルプ画面の「スタッフを招待する方法」をご確認ください',
                                    style: TextStyle(fontSize: 12, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
