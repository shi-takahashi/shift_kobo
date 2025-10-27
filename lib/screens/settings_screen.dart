import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/team.dart';
import '../providers/constraint_request_provider.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../widgets/auth_gate.dart';
import 'help_screen.dart';
import 'monthly_shift_settings_screen.dart';
import 'shift_time_settings_screen.dart';
import 'team/team_invite_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppUser appUser;

  const SettingsScreen({
    super.key,
    required this.appUser,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;
  PackageInfo? _packageInfo;
  Map<String, bool> _notificationSettings = {};
  bool _isLoadingNotifications = true;
  String? _cachedTeamName;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadNotificationSettings();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = packageInfo;
      });
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (kIsWeb) {
      setState(() {
        _isLoadingNotifications = false;
      });
      return;
    }

    final settings = await NotificationService.getNotificationSettings();
    if (mounted) {
      setState(() {
        _notificationSettings = settings;
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    setState(() {
      _notificationSettings[key] = value;
    });

    await NotificationService.updateNotificationSettings(_notificationSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知設定を更新しました')),
      );
    }
  }

  /// 通知許可状態をチェック
  Future<bool> _checkNotificationPermission() async {
    if (kIsWeb) return true;

    try {
      return await NotificationService.isNotificationEnabled();
    } catch (e) {
      debugPrint('通知許可状態チェックエラー: $e');
      return true; // エラー時は警告を表示しない
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // アカウントセクション
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'アカウント',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // 所属チーム情報
        if (widget.appUser.teamId != null)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .doc(widget.appUser.teamId!)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data?.data() != null) {
                final teamName = (snapshot.data!.data() as Map<String, dynamic>)['name'] as String?;
                if (teamName != null) {
                  _cachedTeamName = teamName;
                }
              }

              return ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('所属チーム'),
                subtitle: Text(_cachedTeamName ?? '読み込み中...'),
                onTap: widget.appUser.isAdmin ? _showTeamNameEditDialog : null,
              );
            },
          ),

        // チーム招待メニュー（管理者のみ）
        if (FirebaseAuth.instance.currentUser != null && widget.appUser.isAdmin)
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('チーム招待'),
            subtitle: const Text('スタッフを招待する'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToTeamInvite,
          ),

        // ログインユーザー情報
        if (FirebaseAuth.instance.currentUser != null)
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('ログイン中'),
            subtitle: Text(FirebaseAuth.instance.currentUser!.email ?? ''),
          ),

        // ログアウトボタン
        if (FirebaseAuth.instance.currentUser != null)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'ログアウト',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _handleLogout,
          ),

        const Divider(),

        // 管理者のみ基本設定を表示
        if (widget.appUser.isAdmin) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '基本設定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('シフト時間設定'),
            subtitle: const Text('各シフトタイプの時間を設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final shiftTimeProvider = context.read<ShiftTimeProvider>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider<ShiftTimeProvider>.value(
                    value: shiftTimeProvider,
                    child: const ShiftTimeSettingsScreen(),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('月間シフト設定'),
            subtitle: const Text('各シフト時間の必要人数を設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final shiftTimeProvider = context.read<ShiftTimeProvider>();
              final monthlyRequirementsProvider = context.read<MonthlyRequirementsProvider>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
                      ChangeNotifierProvider<MonthlyRequirementsProvider>.value(value: monthlyRequirementsProvider),
                    ],
                    child: const MonthlyShiftSettingsScreen(),
                  ),
                ),
              );
            },
          ),
          const Divider(),
        ],

        // Push通知設定（アプリ版のみ）
        if (!kIsWeb && FirebaseAuth.instance.currentUser != null) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '通知設定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isLoadingNotifications)
            const ListTile(
              leading: Icon(Icons.notifications),
              title: Text('読み込み中...'),
            )
          else ...[
            // 通知許可状態の確認と案内
            FutureBuilder<bool>(
              future: _checkNotificationPermission(),
              builder: (context, snapshot) {
                final isNotificationEnabled = snapshot.data ?? true;

                return Column(
                  children: [
                    if (!isNotificationEnabled)
                      // 通知が拒否されている場合の警告
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '通知が無効になっています',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '通知を受け取るには、端末の設定から\nこのアプリの通知を許可してください。',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '【設定方法】\n'
                              '設定 → アプリ → シフト工房 → 通知',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 管理者向け通知設定
                    if (widget.appUser.isAdmin)
                      SwitchListTile(
                        secondary: const Icon(Icons.notification_add),
                        title: const Text('新しい申請の通知'),
                        subtitle: Text(
                          isNotificationEnabled
                              ? 'スタッフが申請・取り消しをしたときに通知'
                              : '端末の設定で通知を許可してください',
                        ),
                        value: _notificationSettings['requestCreated'] ?? true,
                        onChanged: isNotificationEnabled
                            ? (value) => _updateNotificationSetting('requestCreated', value)
                            : null, // 無効化
                      ),
                    // スタッフ向け通知設定
                    if (!widget.appUser.isAdmin)
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active),
                        title: const Text('申請結果の通知'),
                        subtitle: Text(
                          isNotificationEnabled
                              ? '制約申請が承認・却下されたときに通知'
                              : '端末の設定で通知を許可してください',
                        ),
                        value: (_notificationSettings['requestApproved'] ?? true) &&
                               (_notificationSettings['requestRejected'] ?? true),
                        onChanged: isNotificationEnabled
                            ? (value) async {
                                // 承認と却下の両方を同じ値に設定
                                setState(() {
                                  _notificationSettings['requestApproved'] = value;
                                  _notificationSettings['requestRejected'] = value;
                                });
                                await NotificationService.updateNotificationSettings(_notificationSettings);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('通知設定を更新しました')),
                                  );
                                }
                              }
                            : null, // 無効化
                      ),
                  ],
                );
              },
            ),
          ],
          const Divider(),
        ],

        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'ヘルプ・情報',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('ヘルプ'),
          subtitle: const Text('使い方・よくある質問'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('アプリについて'),
          subtitle: Text(_packageInfo != null ? 'バージョン ${_packageInfo!.version}' : 'バージョン 情報取得中...'),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('シフト工房'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'バージョン ${_packageInfo != null ? _packageInfo!.version : '1.0.0'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'シフト管理を簡単に。チームでシフトを共有し、休み希望の申請・承認もスムーズに。',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '主な機能:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• チームでシフト共有\n'
                        '• シフト自動割り当て\n'
                        '• 休み希望の申請・承認\n'
                        '• スタッフ管理\n'
                        '• シフト表出力',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '© 2025 Shift Kobo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
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
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip),
          title: const Text('プライバシーポリシー'),
          subtitle: const Text('個人情報保護方針'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _launchPrivacyPolicy(),
        ),
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('お問い合わせ'),
          subtitle: const Text('不具合報告や改善要望はこちら'),
          onTap: _sendContactEmail,
        ),
        const SizedBox(height: 24),
        const Divider(thickness: 2, height: 1),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            'アカウント削除',
            style: TextStyle(color: Colors.red),
          ),
          onTap: _showDeleteAccountDialog,
        ),
      ],
    );
  }

  /// チーム招待画面へ遷移
  void _navigateToTeamInvite() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TeamInviteScreen(),
      ),
    );
  }

  /// チーム名変更ダイアログを表示
  Future<void> _showTeamNameEditDialog() async {
    final teamId = widget.appUser.teamId;
    if (teamId == null) return;

    // 現在のチーム情報を取得
    final team = await AuthService().getTeam(teamId);
    if (team == null || !mounted) return;

    final controller = TextEditingController(text: team.name);

    try {
      final newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('チーム名変更'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'チーム名',
              hintText: '新しいチーム名を入力',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('チーム名を入力してください')),
                  );
                  return;
                }
                Navigator.pop(context, name);
              },
              child: const Text('変更'),
            ),
          ],
        ),
      );

      if (newName == null || !mounted) return;
      if (newName == team.name) return; // 変更なし

      // チーム名を更新
      try {
        await AuthService().updateTeamName(teamId: teamId, newName: newName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('チーム名を「$newName」に変更しました')),
          );

          // 画面を再描画
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('チーム名の変更に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      controller.dispose();
    }
  }

  /// ログアウト処理
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = AuthService();
        await authService.signOut();

        if (!mounted) return;

        // 全画面をクリアしてログイン画面に戻る
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );

        // ログアウト成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログアウトしました')),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログアウトに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendContactEmail() async {
    const emailAddress = 'takapps.dev@gmail.com';
    final version = _packageInfo?.version ?? '不明';
    final buildNumber = _packageInfo?.buildNumber ?? '不明';
    final osInfo = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : 'その他';

    final subject = Uri.encodeComponent('【シフト工房】お問い合わせ');
    final body = Uri.encodeComponent('━━━━━━━━━━━━━━\n'
        '◆お問い合わせ内容\n'
        '（ここに記入してください）\n'
        '\n'
        '\n'
        '\n'
        '━━━━━━━━━━━━━━\n'
        '【アプリ情報】\n'
        'バージョン：$version\n'
        'ビルド番号：$buildNumber\n'
        'OS：$osInfo\n'
        '━━━━━━━━━━━━━━');

    final emailUrl = Uri.parse('mailto:$emailAddress?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUrl)) {
        await launchUrl(emailUrl);
      } else {
        // メーラー起動できない場合、メールアドレスを表示
        if (mounted) {
          _showEmailAddressDialog(emailAddress);
        }
      }
    } catch (e) {
      // エラー時もメールアドレスを表示
      if (mounted) {
        _showEmailAddressDialog(emailAddress);
      }
    }
  }

  void _showEmailAddressDialog(String emailAddress) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('お問い合わせ先'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'メールアプリを起動できませんでした。\n以下のメールアドレスにお問い合わせください。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      emailAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'コピー',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: emailAddress));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('メールアドレスをコピーしました'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
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
  }

  /// アカウント削除確認ダイアログ
  Future<void> _showDeleteAccountDialog() async {
    // 管理者かどうかをチェック
    final isAdmin = widget.appUser.isAdmin;

    if (isAdmin) {
      // 管理者の場合、管理者数をチェック
      try {
        final authService = AuthService();
        final adminCount = await authService.getAdminCount(widget.appUser.teamId!);

        if (adminCount == 1) {
          // 唯一の管理者の場合 → 特別な警告ダイアログ
          await _showLastAdminDeleteDialog();
        } else {
          // 複数管理者の場合 → 通常のダイアログ（管理者向け）
          await _showAdminDeleteDialog();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // スタッフの場合 → 通常のダイアログ
      await _showStaffDeleteDialog();
    }
  }

  /// 唯一の管理者向けの削除ダイアログ
  Future<void> _showLastAdminDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('チームが解散されます')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ あなたは唯一の管理者です',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'アカウントを削除すると、チームが管理不能になります。\n'
                '他のスタッフもアプリを使用できなくなります。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'チームを継続したい場合',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'スタッフ画面から、アプリ利用中のユーザー\n'
                      '（アプリ利用中のスタッフ）を\n'
                      '次の管理者に指定してください。',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '本当に削除しますか？',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performDeleteTeamAndAccount();
    }
  }

  /// 管理者（複数いる場合）向けの削除ダイアログ
  Future<void> _showAdminDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント削除'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'アカウントを削除すると以下が削除されます：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('• ログイン情報（メールアドレス・パスワード）'),
              const Text('• 制約の申請データ'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '注意',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '他の管理者がログインできない場合、\n'
                      'チームが管理不能になる可能性があります。',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '本当に削除しますか？',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performDeleteAccount();
    }
  }

  /// スタッフ向けの削除ダイアログ
  Future<void> _showStaffDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント削除'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アカウントを削除すると以下が削除されます：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• ログイン情報（メールアドレス・パスワード）'),
              Text('• 制約の申請データ'),
              SizedBox(height: 16),
              Text(
                'スタッフ登録データは管理者側に残ります。\n'
                '再度同じメールアドレスで登録・紐付けできます。',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '本当に削除しますか？',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performDeleteAccount();
    }
  }

  /// アカウント削除処理
  Future<void> _performDeleteAccount({bool isRetry = false}) async {
    try {
      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final authService = AuthService();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'ログインしていません';
      }

      // セキュリティのため、必ず再認証を要求
      if (!isRetry) {
        // アカウント削除処理を先に実行
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw 'ユーザー情報が見つかりません';
        }

        final teamId = userDoc.data()?['teamId'] as String?;
        if (teamId == null) {
          throw 'チーム情報が見つかりません';
        }

        // 紐付けられたstaffIdを検索
        final staffQuery = await FirebaseFirestore.instance
            .collection('teams')
            .doc(teamId)
            .collection('staff')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        final staffId = staffQuery.docs.isNotEmpty ? staffQuery.docs.first.id : null;

        // 1. constraint_requests削除（staffIdがある場合のみ）
        if (staffId != null && mounted) {
          final constraintRequestProvider = Provider.of<ConstraintRequestProvider>(
            context,
            listen: false,
          );
          await constraintRequestProvider.deleteRequestsByStaffId(staffId);
        }

        // 2. Staff紐付け解除（staffIdがある場合のみ）
        if (staffId != null && mounted) {
          final staffProvider = Provider.of<StaffProvider>(context, listen: false);
          await staffProvider.unlinkStaffUser(staffId);
        }

        // 3. users/{userId} 削除
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

        // セキュリティのため、必ず再認証を要求
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'アカウント削除にはパスワードの確認が必要です',
        );
      }

      if (isRetry) {
        // 再認証後の再試行：Authenticationのみ削除
        // （Firestore削除処理は既に完了しているため）
        await user.delete();
        print('✅ Authenticationアカウント削除成功（再試行）');
      }

      // ローディング非表示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 削除完了メッセージを表示
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text('アカウントを削除しました'),
                ),
              ],
            ),
            content: const Text(
              'アカウントの削除が完了しました。\n'
              'ご利用ありがとうございました。',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      }

      // 削除成功後、AuthGateに遷移（全画面をクリア）
      // アカウント削除によりauthStateChangesが発火し、AuthGateがウェルカム画面に遷移する
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      // ローディング非表示
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // ローディングが既に閉じられている場合は無視
        }
      }

      // 再認証が必要な場合
      if (e.code == 'requires-recent-login' && !isRetry) {
        if (mounted) {
          final reauthenticated = await _showReauthenticationDialog();
          if (reauthenticated == true && mounted) {
            // 再認証成功後、削除を再試行（isRetry=trueで再帰防止）
            await _performDeleteAccount(isRetry: true);
          }
        }
      } else {
        // その他のFirebaseAuthエラー
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('エラー'),
              content: Text(e.message ?? e.toString()),
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
    } catch (e) {
      // ローディング非表示
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // ローディングが既に閉じられている場合は無視
        }
      }

      // エラーメッセージ表示
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('エラー'),
            content: Text(e.toString()),
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
  }

  /// チーム解散とアカウント削除（唯一の管理者専用）
  Future<void> _performDeleteTeamAndAccount({bool isRetry = false}) async {
    try {
      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final authService = AuthService();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'ログインしていません';
      }

      if (!isRetry) {
        // セキュリティのため、まず再認証を要求
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'チーム解散にはパスワードの確認が必要です',
        );
      }

      if (isRetry) {
        // 再認証後の処理
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw 'ユーザー情報が見つかりません';
        }

        final teamId = userDoc.data()?['teamId'] as String?;
        if (teamId == null) {
          throw 'チーム情報が見つかりません';
        }

        // 1. Cloud Functionsでチーム解散（他のメンバーのAuthenticationを削除）
        await authService.deleteTeamAndAccount(teamId);
        print('✅ チーム解散完了（Cloud Functions）');

        // 2. 自分のAuthenticationを削除
        await user.delete();
        print('✅ 自分のAuthenticationアカウント削除成功');
      }

      // ローディング非表示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 削除完了メッセージを表示
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text('チームを解散しました'),
                ),
              ],
            ),
            content: const Text(
              'チームとアカウントの削除が完了しました。\n'
              'ご利用ありがとうございました。',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      }

      // 削除成功後、AuthGateに遷移（全画面をクリア）
      // アカウント削除によりauthStateChangesが発火し、AuthGateがウェルカム画面に遷移する
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      // ローディング非表示
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // ローディングが既に閉じられている場合は無視
        }
      }

      // 再認証が必要な場合
      if (e.code == 'requires-recent-login' && !isRetry) {
        if (mounted) {
          final reauthenticated = await _showReauthenticationDialog();
          if (reauthenticated == true && mounted) {
            // 再認証成功後、削除を再試行（isRetry=trueで再帰防止）
            await _performDeleteTeamAndAccount(isRetry: true);
          }
        }
      } else {
        // その他のFirebaseAuthエラー
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('エラー'),
              content: Text(e.message ?? e.toString()),
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
    } catch (e) {
      // ローディング非表示
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // ローディングが既に閉じられている場合は無視
        }
      }

      // エラーメッセージ表示
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('エラー'),
            content: Text(e.toString()),
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
  }

  /// 再認証ダイアログ
  Future<bool?> _showReauthenticationDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('パスワードの確認'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'セキュリティ保護のため、パスワードを再入力してください。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              // ローディング表示
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final authService = AuthService();
                await authService.reauthenticateWithPassword(passwordController.text);

                // ローディング非表示
                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                // 再認証ダイアログを閉じる（成功）
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              } catch (e) {
                // ローディング非表示
                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                // エラーメッセージ表示
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('再認証に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データバックアップ'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下のデータをバックアップファイルとして保存します：'),
            SizedBox(height: 8),
            Text('• スタッフ情報'),
            Text('• シフトデータ'),
            Text('• 制約条件'),
            Text('• シフト時間設定'),
            Text('• 月間シフト設定'),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _performBackup(context);  // 外側のcontextを使用
            },
            icon: const Icon(Icons.backup),
            label: const Text('バックアップ'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データ復元'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('バックアップファイルからデータを復元します。'),
            SizedBox(height: 16),
            Text(
              '⚠️ 注意',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '復元を実行すると、現在のデータは削除されます。事前にバックアップを取ることをお勧めします。',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 少し待機してからファイル選択開始
              Future.delayed(const Duration(milliseconds: 300), () {
                _performRestore();
              });
            },
            icon: const Icon(Icons.restore),
            label: const Text('復元'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackup(BuildContext context) async {
    // Navigatorの参照を事前に保存
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // teamIdを取得（StaffProviderから）
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final teamId = staffProvider.teamId;

    if (teamId == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('チーム情報が見つかりません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('バックアップを作成中...'),
            ],
          ),
        ),
      );

      // バックアップを実行
      final result = await BackupService.shareBackupFile(teamId);

      // ローディングを閉じる（保存した参照を使用）
      navigator.pop();

      if (result != null) {
        // 成功メッセージ
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('バックアップが完了しました\n選択した場所に保存されました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // ローディングを閉じる
      try {
        navigator.pop();
      } catch (navError) {
        // ローディングダイアログが既に閉じられている場合は無視
      }

      // エラーメッセージ
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('バックアップに失敗しました: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performRestore() async {
    if (!mounted) return;

    setState(() {
      _isRestoring = true;
    });

    // teamIdを取得（StaffProviderから）
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final teamId = staffProvider.teamId;

    if (teamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('チーム情報が見つかりません'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isRestoring = false;
      });
      return;
    }

    String? selectedFilePath;

    try {
      // ファイル選択
      selectedFilePath = await BackupService.pickBackupFile();

      if (selectedFilePath == null || !mounted) {
        setState(() {
          _isRestoring = false;
        });
        return; // ユーザーがキャンセル
      }
    } catch (e) {
      print('File picker error: $e');
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ファイル選択に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('データを復元中...'),
            ],
          ),
        ),
      );

      // 復元を実行（上書きモード）
      await BackupService.restoreFromFile(selectedFilePath, teamId, overwrite: true);

      if (!mounted) return;

      // ローディングを閉じる
      Navigator.of(context).pop();

      // Providerをリロードしてデータを再読み込み
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
      final monthlyRequirementsProvider = Provider.of<MonthlyRequirementsProvider>(context, listen: false);

      staffProvider.reload();
      shiftProvider.reload();
      shiftTimeProvider.reload();
      monthlyRequirementsProvider.reload();

      if (!mounted) return;

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('データの復元が完了しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (restoreError) {
      print('Restore error: $restoreError');

      if (mounted) {
        // ローディングを閉じる
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          print('Navigator error during restore failure: $navError');
        }

        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: ${restoreError.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  /// プライバシーポリシーを外部ブラウザで開く
  Future<void> _launchPrivacyPolicy() async {
    const String privacyPolicyUrl = 'https://shi-takahashi.github.io/shift_kobo/privacy-policy.html';
    final Uri uri = Uri.parse(privacyPolicyUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $privacyPolicyUrl';
      }
    } catch (e) {
      debugPrint('Error launching privacy policy URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ブラウザで開けませんでした'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
