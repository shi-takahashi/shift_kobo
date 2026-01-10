import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/shift_time_setting.dart';
import '../providers/shift_time_provider.dart';
import '../providers/monthly_requirements_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'shift_time_settings_screen.dart';

class MonthlyShiftSettingsScreen extends StatefulWidget {
  const MonthlyShiftSettingsScreen({super.key});

  @override
  State<MonthlyShiftSettingsScreen> createState() => _MonthlyShiftSettingsScreenState();
}

class _MonthlyShiftSettingsScreenState extends State<MonthlyShiftSettingsScreen> {
  // 基本設定用
  final Map<String, TextEditingController> _requirementControllers = {};
  final Map<String, String> _originalValues = {};
  final Map<String, String?> _errorMessages = {};
  bool _hasChanges = false;

  // 曜日別設定用
  bool _useWeekdaySettings = false;
  final Map<int, Map<String, int>> _weekdaySettings = {};

  // 日付個別設定用
  bool _showPastDateSettings = false;

  // 曜日名
  static const List<String> _weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

  /// シフト設定を開始時間順にソート
  List<ShiftTimeSetting> _sortByStartTime(List<ShiftTimeSetting> settings) {
    final sorted = List<ShiftTimeSetting>.from(settings);
    sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted;
  }

  /// 必要人数マップを開始時間順にソートされたエントリリストに変換
  List<MapEntry<String, int>> _sortedRequirementEntries(
    Map<String, int> requirements,
    List<ShiftTimeSetting> activeSettings,
  ) {
    final sortedSettings = _sortByStartTime(activeSettings);
    final result = <MapEntry<String, int>>[];
    for (final setting in sortedSettings) {
      if (requirements.containsKey(setting.displayName)) {
        result.add(MapEntry(setting.displayName, requirements[setting.displayName]!));
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });

    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('monthly_shift_settings_screen');
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
      // 基本設定を読み込み
      for (String shiftType in _requirementControllers.keys) {
        int savedValue;

        // 設定が存在する場合はその値を使用、存在しない場合は0
        savedValue = requirementsProvider.getRequirement(shiftType);

        final valueStr = savedValue.toString();
        _requirementControllers[shiftType]!.text = valueStr;
        _originalValues[shiftType] = valueStr;
      }
      _hasChanges = false;

      // 曜日別設定を読み込み
      _useWeekdaySettings = requirementsProvider.useWeekdaySettings;
      _weekdaySettings.clear();
      _weekdaySettings.addAll(requirementsProvider.weekdayRequirements);
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
        title: const Text('シフト割当て設定'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<ShiftTimeProvider, MonthlyRequirementsProvider>(
        builder: (context, shiftTimeProvider, requirementsProvider, child) {
          final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();

          if (activeSettings.isEmpty) {
            return _buildEmptyState();
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
                        _buildDefaultSettingsCard(activeSettings),
                        const SizedBox(height: 16),
                        _buildWeekdaySettingsCard(activeSettings, requirementsProvider),
                        const SizedBox(height: 16),
                        _buildDateSettingsCard(activeSettings, requirementsProvider),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSaveButton(),
              const SafeArea(
                top: false,
                child: BannerAdWidget(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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

  /// 基本設定（全日共通）カード
  Widget _buildDefaultSettingsCard(List<ShiftTimeSetting> activeSettings) {
    // 時間順にソート
    final sortedSettings = _sortByStartTime(activeSettings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '基本設定（全日共通）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '各シフトタイプの1日あたりの必要人数を設定',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const Divider(),
            ...sortedSettings.map((setting) => _buildRequirementField(setting)),
          ],
        ),
      ),
    );
  }

  /// 曜日別設定カード
  Widget _buildWeekdaySettingsCard(
    List<ShiftTimeSetting> activeSettings,
    MonthlyRequirementsProvider requirementsProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_week, size: 20, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '曜日別設定',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: _useWeekdaySettings,
                  onChanged: (value) async {
                    setState(() {
                      _useWeekdaySettings = value;
                    });
                    await requirementsProvider.setUseWeekdaySettings(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '曜日ごとに異なる人数を設定できます',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (_useWeekdaySettings) ...[
              const Divider(),
              ...List.generate(7, (index) {
                final weekday = index + 1; // 1=月曜〜7=日曜
                final hasOverride = requirementsProvider.hasWeekdayOverride(weekday);
                final weekdayReqs = _weekdaySettings[weekday] ?? {};

                return _buildWeekdayRow(
                  weekday: weekday,
                  weekdayName: _weekdayNames[index],
                  hasOverride: hasOverride,
                  requirements: weekdayReqs,
                  activeSettings: activeSettings,
                  requirementsProvider: requirementsProvider,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// 曜日行
  Widget _buildWeekdayRow({
    required int weekday,
    required String weekdayName,
    required bool hasOverride,
    required Map<String, int> requirements,
    required List<ShiftTimeSetting> activeSettings,
    required MonthlyRequirementsProvider requirementsProvider,
  }) {
    final isSaturday = weekday == 6;
    final isSunday = weekday == 7;

    // 背景色と文字色を決定
    Color backgroundColor;
    Color textColor;
    if (isSunday) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
    } else if (isSaturday) {
      backgroundColor = Colors.blue.shade100;
      textColor = Colors.blue.shade700;
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return InkWell(
      onTap: () => _showWeekdaySettingsDialog(
        weekday: weekday,
        weekdayName: weekdayName,
        currentRequirements: requirements,
        activeSettings: activeSettings,
        requirementsProvider: requirementsProvider,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  weekdayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasOverride
                  ? Wrap(
                      spacing: 8,
                      children: _sortedRequirementEntries(requirements, activeSettings).map((e) {
                        return Chip(
                          label: Text('${e.key}: ${e.value}人'),
                          backgroundColor: Colors.orange.shade100,
                          labelStyle: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    )
                  : Text(
                      '基本設定を使用',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// 曜日設定ダイアログ
  Future<void> _showWeekdaySettingsDialog({
    required int weekday,
    required String weekdayName,
    required Map<String, int> currentRequirements,
    required List<ShiftTimeSetting> activeSettings,
    required MonthlyRequirementsProvider requirementsProvider,
  }) async {
    final controllers = <String, TextEditingController>{};
    bool useDefault = currentRequirements.isEmpty;
    String? validationError;

    // 時間順にソート
    final sortedSettings = _sortByStartTime(activeSettings);

    // コントローラー初期化
    for (var setting in sortedSettings) {
      final currentValue = currentRequirements[setting.displayName] ??
                          requirementsProvider.getRequirement(setting.displayName);
      controllers[setting.displayName] = TextEditingController(text: currentValue.toString());
    }

    // バリデーション関数
    bool validateFields() {
      for (var entry in controllers.entries) {
        if (entry.value.text.trim().isEmpty) {
          return false;
        }
      }
      return true;
    }

    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('$weekdayName曜日の設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('基本設定を使用'),
                    subtitle: const Text('チェックを外すと個別に設定できます'),
                    value: useDefault,
                    onChanged: (value) {
                      setDialogState(() {
                        useDefault = value ?? true;
                        validationError = null;
                      });
                    },
                  ),
                  if (!useDefault) ...[
                    const Divider(),
                    ...sortedSettings.map((setting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: setting.shiftType.color,
                              child: Icon(setting.shiftType.icon, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(setting.displayName)),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: controllers[setting.displayName],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  suffixText: '人',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                onChanged: (_) {
                                  setDialogState(() {
                                    validationError = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          validationError!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  if (useDefault) {
                    Navigator.pop(context, <String, int>{});
                  } else {
                    if (!validateFields()) {
                      setDialogState(() {
                        validationError = '人数を入力してください';
                      });
                      return;
                    }
                    final result = <String, int>{};
                    for (var entry in controllers.entries) {
                      result[entry.key] = int.tryParse(entry.value.text) ?? 0;
                    }
                    Navigator.pop(context, result);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await requirementsProvider.setWeekdayRequirement(weekday, result);
      setState(() {
        if (result.isEmpty) {
          _weekdaySettings.remove(weekday);
        } else {
          _weekdaySettings[weekday] = result;
        }
      });
    }
  }

  /// 日付個別設定カード
  Widget _buildDateSettingsCard(
    List<ShiftTimeSetting> activeSettings,
    MonthlyRequirementsProvider requirementsProvider,
  ) {
    final dateReqs = requirementsProvider.dateRequirements;
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    // 当月以降の日付のみフィルタリング（_showPastDateSettingsがtrueの場合は全て表示）
    final sortedDates = dateReqs.keys
        .where((dateKey) {
          if (_showPastDateSettings) return true;
          try {
            final date = DateTime.parse(dateKey);
            return !date.isBefore(firstDayOfCurrentMonth);
          } catch (e) {
            return false;
          }
        })
        .toList()
      ..sort();

    // 過去（先月以前）の日付の件数をカウント
    final pastCount = dateReqs.keys.where((dateKey) {
      try {
        final date = DateTime.parse(dateKey);
        return date.isBefore(firstDayOfCurrentMonth);
      } catch (e) {
        return false;
      }
    }).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, size: 20, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '日付個別設定',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddDateSettingDialog(activeSettings, requirementsProvider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '特定の日付に異なる人数を設定できます（最優先）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (sortedDates.isNotEmpty) ...[
              const Divider(),
              ...sortedDates.map((dateKey) {
                final reqs = dateReqs[dateKey];
                if (reqs == null) return const SizedBox.shrink();

                DateTime? date;
                try {
                  date = DateTime.parse(dateKey);
                } catch (e) {
                  return const SizedBox.shrink();
                }

                final dateFormat = DateFormat('M/d(E)', 'ja');

                return _buildDateRow(
                  dateKey: dateKey,
                  formattedDate: dateFormat.format(date),
                  requirements: reqs,
                  activeSettings: activeSettings,
                  requirementsProvider: requirementsProvider,
                );
              }),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '日付個別設定はありません',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 過去の設定がある場合、表示/非表示トグルを表示
            if (pastCount > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showPastDateSettings = !_showPastDateSettings;
                    });
                  },
                  child: Text(
                    _showPastDateSettings
                        ? '過去の設定を非表示'
                        : '過去の設定を表示 ($pastCount件)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 日付行
  Widget _buildDateRow({
    required String dateKey,
    required String formattedDate,
    required Map<String, int> requirements,
    required List<ShiftTimeSetting> activeSettings,
    required MonthlyRequirementsProvider requirementsProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formattedDate,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: _sortedRequirementEntries(requirements, activeSettings).map((e) {
                return Chip(
                  label: Text('${e.key}: ${e.value}人'),
                  backgroundColor: Colors.purple.shade50,
                  labelStyle: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 20, color: Colors.grey.shade600),
            onPressed: () => _showEditDateSettingDialog(
              dateKey: dateKey,
              currentRequirements: requirements,
              activeSettings: activeSettings,
              requirementsProvider: requirementsProvider,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
            onPressed: () => _confirmDeleteDateSetting(dateKey, requirementsProvider),
          ),
        ],
      ),
    );
  }

  /// 日付設定追加ダイアログ
  Future<void> _showAddDateSettingDialog(
    List<ShiftTimeSetting> activeSettings,
    MonthlyRequirementsProvider requirementsProvider,
  ) async {
    DateTime? selectedDate;
    final controllers = <String, TextEditingController>{};
    String? validationError;

    // 時間順にソート
    final sortedSettings = _sortByStartTime(activeSettings);

    // コントローラー初期化（基本設定値で）
    for (var setting in sortedSettings) {
      final currentValue = requirementsProvider.getRequirement(setting.displayName);
      controllers[setting.displayName] = TextEditingController(text: currentValue.toString());
    }

    // バリデーション関数
    bool validateFields() {
      for (var entry in controllers.entries) {
        if (entry.value.text.trim().isEmpty) {
          return false;
        }
      }
      return true;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('日付個別設定を追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日付選択
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(selectedDate != null
                        ? DateFormat('yyyy/M/d(E)', 'ja').format(selectedDate!)
                        : '日付を選択'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('ja'),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const Divider(),
                  const Text('必要人数', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...sortedSettings.map((setting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: setting.shiftType.color,
                            child: Icon(setting.shiftType.icon, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(setting.displayName)),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: controllers[setting.displayName],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                suffixText: '人',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                              ),
                              onChanged: (_) {
                                setDialogState(() {
                                  validationError = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        validationError!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: selectedDate == null
                    ? null
                    : () {
                        if (!validateFields()) {
                          setDialogState(() {
                            validationError = '人数を入力してください';
                          });
                          return;
                        }
                        final reqs = <String, int>{};
                        for (var entry in controllers.entries) {
                          reqs[entry.key] = int.tryParse(entry.value.text) ?? 0;
                        }
                        Navigator.pop(context, {
                          'date': selectedDate,
                          'requirements': reqs,
                        });
                      },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final date = result['date'] as DateTime;
      final reqs = result['requirements'] as Map<String, int>;
      final dateKey = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];

      await requirementsProvider.setDateRequirement(dateKey, reqs);

      // Analytics: 日付個別設定イベント
      await AnalyticsService.logDateSpecificRequirementSet(date: dateKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日付個別設定を追加しました')),
        );
      }
    }
  }

  /// 日付設定編集ダイアログ
  Future<void> _showEditDateSettingDialog({
    required String dateKey,
    required Map<String, int> currentRequirements,
    required List<ShiftTimeSetting> activeSettings,
    required MonthlyRequirementsProvider requirementsProvider,
  }) async {
    DateTime? date;
    try {
      date = DateTime.parse(dateKey);
    } catch (e) {
      // 無効なdateKeyの場合は何もしない
      return;
    }

    final controllers = <String, TextEditingController>{};
    String? validationError;

    // 時間順にソート
    final sortedSettings = _sortByStartTime(activeSettings);

    // コントローラー初期化
    for (var setting in sortedSettings) {
      final currentValue = currentRequirements[setting.displayName] ?? 0;
      controllers[setting.displayName] = TextEditingController(text: currentValue.toString());
    }

    // バリデーション関数
    bool validateFields() {
      for (var entry in controllers.entries) {
        if (entry.value.text.trim().isEmpty) {
          return false;
        }
      }
      return true;
    }

    final formattedDate = DateFormat('yyyy/M/d(E)', 'ja').format(date);

    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('$formattedDate の設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...sortedSettings.map((setting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: setting.shiftType.color,
                            child: Icon(setting.shiftType.icon, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(setting.displayName)),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: controllers[setting.displayName],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                suffixText: '人',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                              ),
                              onChanged: (_) {
                                setDialogState(() {
                                  validationError = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        validationError!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  if (!validateFields()) {
                    setDialogState(() {
                      validationError = '人数を入力してください';
                    });
                    return;
                  }
                  final reqs = <String, int>{};
                  for (var entry in controllers.entries) {
                    reqs[entry.key] = int.tryParse(entry.value.text) ?? 0;
                  }
                  Navigator.pop(context, reqs);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await requirementsProvider.setDateRequirement(dateKey, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定を更新しました')),
        );
      }
    }
  }

  /// 日付設定削除確認
  Future<void> _confirmDeleteDateSetting(
    String dateKey,
    MonthlyRequirementsProvider requirementsProvider,
  ) async {
    DateTime? date;
    try {
      date = DateTime.parse(dateKey);
    } catch (e) {
      // 無効なdateKeyの場合は削除だけ実行
      await requirementsProvider.removeDateRequirement(dateKey);
      return;
    }
    final formattedDate = DateFormat('yyyy/M/d(E)', 'ja').format(date);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('$formattedDate の個別設定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await requirementsProvider.removeDateRequirement(dateKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('個別設定を削除しました')),
        );
      }
    }
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

  Widget _buildSaveButton() {
    return SafeArea(
      child: Container(
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _hasChanges ? _saveRequirements : null,
              icon: const Icon(Icons.save),
              label: const Text('基本設定を保存'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
