import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shift_time_setting.dart';
import '../providers/shift_time_provider.dart';
import '../services/analytics_service.dart';

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
      body: Consumer<ShiftTimeProvider>(
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
                      provider.toggleShiftTypeActive(setting.shiftType);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    ShiftTimeProvider provider,
    ShiftTimeSetting setting,
  ) {
    String newName = setting.displayName;
    String startTime = setting.startTime;
    String endTime = setting.endTime;
    final nameController = TextEditingController(text: newName);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${setting.shiftType.defaultName}の設定'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'シフト名',
                    hintText: '例: 朝シフト、開店準備、A勤務',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    newName = value;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  '勤務時間',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 60, child: Text('開始:')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final time = await _selectTime(context, startTime);
                          if (time != null) {
                            setState(() {
                              startTime = time;
                            });
                          }
                        },
                        child: Text(startTime),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 60, child: Text('終了:')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final time = await _selectTime(context, endTime);
                          if (time != null) {
                            setState(() {
                              endTime = time;
                            });
                          }
                        },
                        child: Text(endTime),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newName.trim().isNotEmpty) {
                  provider.updateShiftName(setting.shiftType, newName.trim());
                  provider.updateShiftTime(setting.shiftType, startTime, endTime);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${newName.trim()}の設定を更新しました'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _selectTime(BuildContext context, String initialTime) async {
    final parts = initialTime.split(':');
    final initialTimeOfDay = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTimeOfDay,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final hour = selectedTime.hour.toString().padLeft(2, '0');
      final minute = selectedTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return null;
  }
}