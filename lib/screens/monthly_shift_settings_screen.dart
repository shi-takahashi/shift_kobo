import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shift_time_setting.dart';
import '../providers/shift_time_provider.dart';
import '../providers/monthly_requirements_provider.dart';
import 'shift_time_settings_screen.dart';

class MonthlyShiftSettingsScreen extends StatefulWidget {
  const MonthlyShiftSettingsScreen({super.key});

  @override
  State<MonthlyShiftSettingsScreen> createState() => _MonthlyShiftSettingsScreenState();
}

class _MonthlyShiftSettingsScreenState extends State<MonthlyShiftSettingsScreen> {
  final Map<String, TextEditingController> _requirementControllers = {};
  final Map<String, String> _originalValues = {};
  final Map<String, String?> _errorMessages = {};
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  void _initializeControllers() async {
    final shiftTimeProvider = context.read<ShiftTimeProvider>();
    final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
    
    // 既存のコントローラーをクリア
    for (var controller in _requirementControllers.values) {
      controller.dispose();
    }
    _requirementControllers.clear();
    
    // アクティブな設定に対してコントローラーを作成
    for (var setting in activeSettings) {
      final controller = TextEditingController(text: '0');
      controller.addListener(() => _checkForChanges());
      _requirementControllers[setting.displayName] = controller;
    }
    
    await _loadSavedRequirements();
  }

  void _checkForChanges() {
    bool hasChanges = false;
    bool isValid = true;
    final newErrorMessages = <String, String?>{};
    
    for (var entry in _requirementControllers.entries) {
      final currentValue = entry.value.text;
      final originalValue = _originalValues[entry.key] ?? '0';
      
      // 空白または無効な値をチェック
      if (currentValue.isEmpty) {
        newErrorMessages[entry.key] = '必須';
        isValid = false;
      } else {
        final intValue = int.tryParse(currentValue);
        if (intValue == null) {
          newErrorMessages[entry.key] = '数値を入力';
          isValid = false;
        } else if (intValue < 0) {
          newErrorMessages[entry.key] = '0以上';
          isValid = false;
        } else {
          newErrorMessages[entry.key] = null;
        }
      }
      
      if (currentValue != originalValue) {
        hasChanges = true;
      }
    }
    
    // 変更があり、かつすべての値が有効な場合のみ保存可能
    final canSave = hasChanges && isValid;
    
    setState(() {
      _hasChanges = canSave;
      _errorMessages.clear();
      _errorMessages.addAll(newErrorMessages);
    });
  }

  Future<void> _loadSavedRequirements() async {
    final requirementsProvider = context.read<MonthlyRequirementsProvider>();

    setState(() {
      for (String shiftType in _requirementControllers.keys) {
        int defaultValue = 0;
        // 日勤のみデフォルト値を1にする
        if (shiftType == '日勤') {
          defaultValue = 1;
        }

        final savedValue = requirementsProvider.getRequirement(shiftType) != 0
            ? requirementsProvider.getRequirement(shiftType)
            : defaultValue;
        final valueStr = savedValue.toString();
        _requirementControllers[shiftType]!.text = valueStr;
        _originalValues[shiftType] = valueStr;
      }
      _hasChanges = false;
    });
  }

  Future<void> _saveRequirements() async {
    // バリデーション
    for (var entry in _requirementControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.key}の人数を入力してください')),
        );
        return;
      }

      final intValue = int.tryParse(value);
      if (intValue == null || intValue < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.key}の人数は0以上の数値を入力してください')),
        );
        return;
      }
    }

    final requirementsProvider = context.read<MonthlyRequirementsProvider>();

    // 全ての設定を一括で保存
    final requirements = <String, int>{};
    for (var entry in _requirementControllers.entries) {
      final value = int.tryParse(entry.value.text) ?? 0;
      requirements[entry.key] = value;
    }

    await requirementsProvider.setRequirements(requirements);

    // 保存後、現在の値を元の値として記録
    for (var entry in _requirementControllers.entries) {
      _originalValues[entry.key] = entry.value.text;
    }

    setState(() {
      _hasChanges = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _requirementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月間シフト設定'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ShiftTimeProvider>(
        builder: (context, shiftTimeProvider, child) {
          final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
          
          if (activeSettings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 80,
                    color: Colors.orange[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'アクティブなシフトタイプがありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'シフト時間設定でシフトタイプを有効にしてください',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
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
                    child: const Text('シフト時間設定へ'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '各シフトタイプの1日あたりの必要人数を設定してください。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ここで設定した値は、自動シフト割り当て時のデフォルト値として使用されます。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'シフトタイプ別必要人数',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                ...activeSettings.map((setting) => _buildRequirementField(setting)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _hasChanges ? _saveRequirements : null,
                      icon: const Icon(Icons.save),
                      label: const Text('設定を保存'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequirementField(ShiftTimeSetting setting) {
    final controller = _requirementControllers[setting.displayName];
    if (controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: setting.shiftType.color,
            child: Icon(
              setting.shiftType.icon,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setting.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  setting.timeRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: '人数',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                suffixText: '名',
                suffixStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                errorText: _errorMessages[setting.displayName],
                errorStyle: const TextStyle(fontSize: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}