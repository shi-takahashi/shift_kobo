import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import 'constraint_settings_screen.dart';
import 'monthly_shift_settings_screen.dart';
import 'shift_time_settings_screen.dart';
import 'team/team_holidays_screen.dart';
import 'team/team_invite_screen.dart';

/// チーム設定画面（管理者専用）
class TeamSettingsScreen extends StatefulWidget {
  final AppUser appUser;

  const TeamSettingsScreen({
    super.key,
    required this.appUser,
  });

  @override
  State<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends State<TeamSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('team_settings_screen');
  }

  @override
  Widget build(BuildContext context) {
    // 匿名ユーザーかどうかを判定
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

    return ListView(
      children: [
        // 匿名ユーザーには共有機能を非表示
        if (!isAnonymous) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              '共有機能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('チーム招待'),
            subtitle: const Text('スタッフを招待する'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TeamInviteScreen(),
                ),
              );
            },
          ),
          const Divider(),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            '自動シフト作成',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('シフト割当て設定'),
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
        ListTile(
          leading: const Icon(Icons.event_busy),
          title: const Text('チーム休み設定'),
          subtitle: const Text('チーム全体の休み（曜日・祝日・特定日）を設定'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            // チーム情報を取得
            final authService = AuthService();
            try {
              final team = await authService.getTeam(widget.appUser.teamId!);
              if (team != null && mounted) {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => TeamHolidaysScreen(
                      appUser: widget.appUser,
                      team: team,
                    ),
                  ),
                );
                // 保存されたら何もしない（画面を閉じるだけ）
                if (result == true && mounted) {
                  // 必要に応じてリフレッシュ処理を追加
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('チーム情報の取得に失敗しました: $e')),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.rule),
          title: const Text('制約条件設定'),
          subtitle: const Text('連続勤務日数と勤務間インターバルを設定'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final shiftProvider = context.read<ShiftProvider>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider<ShiftProvider>.value(
                  value: shiftProvider,
                  child: const ConstraintSettingsScreen(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
