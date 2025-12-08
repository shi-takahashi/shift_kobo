import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment_strategy.dart';
import '../models/shift_time_setting.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/shift_assignment_service.dart';
import '../services/shift_plan_service.dart';

class AutoAssignmentDialog extends StatefulWidget {
  final DateTime selectedMonth;

  const AutoAssignmentDialog({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<AutoAssignmentDialog> createState() => _AutoAssignmentDialogState();
}

class _AutoAssignmentDialogState extends State<AutoAssignmentDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  final Map<String, TextEditingController> _requirementControllers = {};
  bool _isProcessing = false;
  String? _errorMessage;
  AssignmentStrategy _selectedStrategy = AssignmentStrategy.fairness;

  String _getStringFromShiftType(ShiftType shiftType, ShiftTimeSetting setting) {
    // ShiftTimeSettingのdisplayNameを直接使用
    return setting.displayName;
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    _endDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
    _loadStrategyPreference();
  }

  void _initializeControllers(List<ShiftTimeSetting> activeSettings) {
    // 既存のコントローラーをクリア
    for (var controller in _requirementControllers.values) {
      controller.dispose();
    }
    _requirementControllers.clear();

    // アクティブな設定に対してコントローラーを作成
    for (var setting in activeSettings) {
      final shiftTypeString = _getStringFromShiftType(setting.shiftType, setting);
      _requirementControllers[shiftTypeString] = TextEditingController(text: '0');
    }

    _loadSavedRequirements();
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

        final savedValue = requirementsProvider.getRequirement(shiftType) != 0 ? requirementsProvider.getRequirement(shiftType) : defaultValue;
        _requirementControllers[shiftType]!.text = savedValue.toString();
      }
    });
  }

  Future<void> _saveRequirements() async {
    final requirementsProvider = context.read<MonthlyRequirementsProvider>();

    final requirements = <String, int>{};
    for (var entry in _requirementControllers.entries) {
      final value = int.tryParse(entry.value.text) ?? 0;
      requirements[entry.key] = value;
    }

    await requirementsProvider.setRequirements(requirements);
  }

  @override
  void dispose() {
    for (var controller in _requirementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// SharedPreferencesから前回選択した戦略を読み込み
  Future<void> _loadStrategyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final strategyName = prefs.getString('last_assignment_strategy');
    if (strategyName != null) {
      setState(() {
        _selectedStrategy = AssignmentStrategy.values.firstWhere(
          (s) => s.name == strategyName,
          orElse: () => AssignmentStrategy.fairness,
        );
      });
    }
  }

  /// SharedPreferencesに選択した戦略を保存
  Future<void> _saveStrategyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_assignment_strategy', _selectedStrategy.name);
  }

  /// 戦略文字列から分かりやすいnoteを作成
  String _getNoteFromStrategy(String? strategy) {
    if (strategy == null || strategy == 'nothing') {
      return '割り当て戦略なし';
    }

    try {
      final assignmentStrategy = AssignmentStrategy.values.firstWhere(
        (s) => s.name == strategy,
      );
      return '${assignmentStrategy.displayName}で自動作成';
    } catch (e) {
      return '割り当て戦略なし';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftTimeProvider>(
      builder: (context, shiftTimeProvider, child) {
        final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();

        // 初回または活性設定変更時にコントローラーを初期化
        if (_requirementControllers.isEmpty || _requirementControllers.keys.length != activeSettings.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeControllers(activeSettings);
          });
        }

        return AlertDialog(
          title: const Text('自動シフト割り当て'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.selectedMonth.year}年${widget.selectedMonth.month}月のシフトを自動作成します',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '各シフトタイプの必要人数：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (activeSettings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'アクティブなシフトタイプがありません。\n「その他」タブのシフト時間設定でシフトタイプを有効にしてください。',
                        style: TextStyle(color: Colors.orange.shade700),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...activeSettings.map((setting) => _buildRequirementField(setting)),
                  const SizedBox(height: 16),
                  const Text(
                    '割り当て戦略：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<AssignmentStrategy>(
                      value: _selectedStrategy,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: AssignmentStrategy.values.map((strategy) {
                        return DropdownMenuItem(
                          value: strategy,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strategy.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strategy.description,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStrategy = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '戦略を変えると異なるシフトパターンが作成されます。\n現在のシフトはバックアップされ、いつでも復元できます。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            if (activeSettings.isNotEmpty)
              ElevatedButton(
                onPressed: _isProcessing ? null : _generateAndApply,
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('作成'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRequirementField(ShiftTimeSetting setting) {
    final shiftTypeString = _getStringFromShiftType(setting.shiftType, setting);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: setting.shiftType.color,
            child: Icon(
              setting.shiftType.icon,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              setting.displayName,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              setting.timeRange,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _requirementControllers[shiftTypeString],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('人'),
        ],
      ),
    );
  }

  /// シフト作成して即適用
  Future<void> _generateAndApply() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);

      // 必要人数を取得
      final requirements = <String, int>{};
      for (var entry in _requirementControllers.entries) {
        final value = int.tryParse(entry.value.text) ?? 0;
        if (value > 0) {
          requirements[entry.key] = value;
        }
      }

      if (requirements.isEmpty) {
        throw Exception('少なくとも1つのシフトタイプに人数を設定してください');
      }

      // 1. shift_active_planから現在有効なplan_idと戦略を取得
      final planService = ShiftPlanService(teamId: shiftProvider.teamId!);
      final month = '${widget.selectedMonth.year}-${widget.selectedMonth.month}';
      String? currentStrategy = await planService.getActiveStrategy(month);

      // 2. 現在のshiftsを取得（手動編集含む）
      final existingShifts = shiftProvider.getShiftsForMonth(
        widget.selectedMonth.year,
        widget.selectedMonth.month,
      );

      if (existingShifts.isNotEmpty) {
        final confirmed = await _showConfirmationDialog(
          '既存のシフトがあります',
          '既存のシフトは自動でバックアップされます。続けますか？',
        );
        if (!confirmed) {
          setState(() {
            _isProcessing = false;
          });
          FocusScope.of(context).unfocus();
          return;
        }

        // 既存ユーザー（shift_active_planがない）の場合は新規作成
        String? currentPlanId = await planService.getActivePlanId(month);
        currentPlanId ??= await planService.generateUniquePlanId(month);

        // 現在のシフトをバックアップ
        // 戦略がない場合は"nothing"（自動作成していないか、バージョンアップ前の既存ユーザー）
        final note = _getNoteFromStrategy(currentStrategy);
        await planService.saveShiftPlan(
          planId: currentPlanId,
          shifts: existingShifts,
          month: month,
          note: note,
          strategy: currentStrategy ?? 'nothing',
        );
      }

      // 3. shiftsを全削除
      if (existingShifts.isNotEmpty) {
        await shiftProvider.batchDeleteShifts(existingShifts);
      }

      // 4. 新シフトを作成
      final service = ShiftAssignmentService(
        staffProvider: staffProvider,
        shiftProvider: shiftProvider,
        shiftTimeProvider: shiftTimeProvider,
      );

      final shifts = await service.autoAssignShifts(
        _startDate,
        _endDate,
        requirements,
        strategy: _selectedStrategy,
      );

      // 5. 新シフトをshiftsに保存
      await shiftProvider.batchAddShifts(shifts);

      // 6. 新しいplan_idを作成
      final newPlanId = await planService.generateUniquePlanId(month);

      // 7. shift_active_planを新しいplan_idで更新
      await planService.setActivePlanId(month, newPlanId, strategy: _selectedStrategy.name);

      // 9. 月間必要人数を保存
      await _saveRequirements();

      // 10. 次回デフォルト表示されるように選択した戦略を端末に保存
      await _saveStrategyPreference();

      // 11. Analytics
      await AnalyticsService.logShiftGenerated(
        shiftCount: shifts.length,
        strategy: _selectedStrategy.name,
        yearMonth: '${widget.selectedMonth.year}-${widget.selectedMonth.month}',
      );

      if (mounted) {
        // Navigator参照を事前に保存
        final navigatorContext = Navigator.of(context);
        final scaffoldMessengerContext = ScaffoldMessenger.of(context);
        final shiftsCount = shifts.length;

        // 12. ダイアログを閉じる
        navigatorContext.pop(true);

        // 13. 広告表示
        AdService.showInterstitialAd(
          onAdShown: () {},
          onAdClosed: () {
            _showCompletionMessage(scaffoldMessengerContext, shiftsCount);
          },
          onAdFailedToShow: () {
            _showCompletionMessage(scaffoldMessengerContext, shiftsCount);
          },
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('続ける'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// シフト作成完了メッセージを表示
  void _showCompletionMessage(ScaffoldMessengerState scaffoldMessenger, int shiftsCount) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'シフトを自動作成しました！',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${widget.selectedMonth.month}月分のシフト ${shiftsCount}件を作成しました',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
