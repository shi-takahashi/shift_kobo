import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shift_time_setting.dart';
import '../providers/shift_time_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/shift_time_edit_dialog.dart';

class ShiftTimeSettingsScreen extends StatefulWidget {
  const ShiftTimeSettingsScreen({super.key});

  @override
  State<ShiftTimeSettingsScreen> createState() => _ShiftTimeSettingsScreenState();
}

class _ShiftTimeSettingsScreenState extends State<ShiftTimeSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('shift_time_settings_screen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('シフト時間設定'),
        backgroundColor: Colors.blue[50],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ShiftTimeProvider>(
              builder: (context, provider, child) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: provider.settings.length,
                  itemBuilder: (context, index) {
                    final setting = provider.settings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: setting.isActive
                              ? setting.shiftType.color
                              : Colors.grey,
                          child: Icon(
                            setting.shiftType.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          setting.displayName,
                          style: TextStyle(
                            color: setting.isActive ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          setting.timeRange,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: setting.isActive ? null : Colors.grey,
                          ),
                        ),
                        onTap: () {
                          _showEditDialog(context, provider, setting);
                        },
                        trailing: Switch(
                          value: setting.isActive,
                          onChanged: (value) {
                            // 無効→有効の場合、重複チェック
                            if (!setting.isActive &&
                                provider.isNameDuplicate(
                                    setting.displayName, setting.shiftType)) {
                              _showDuplicateWarningDialog(
                                  context, setting.displayName);
                            } else {
                              provider.toggleShiftTypeActive(setting.shiftType);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SafeArea(
            top: false,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    ShiftTimeProvider provider,
    ShiftTimeSetting setting,
  ) {
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider<ShiftTimeProvider>.value(
        value: provider,
        child: ShiftTimeEditDialog(setting: setting),
      ),
    );
  }

  void _showDuplicateWarningDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('名前が重複しています'),
        content: Text(
          '「$name」という名前は既に他のシフトタイプで使用されています。\n\n'
          'このシフトタイプを有効にする前に、名前を変更してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}