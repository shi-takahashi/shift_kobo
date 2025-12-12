import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../services/analytics_service.dart';
import 'constraint_settings_screen.dart';
import 'monthly_shift_settings_screen.dart';
import 'shift_time_settings_screen.dart';

/// チーム設定画面（管理者専用）
class TeamSettingsScreen extends StatefulWidget {
  const TeamSettingsScreen({super.key});

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
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'チーム設定',
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
