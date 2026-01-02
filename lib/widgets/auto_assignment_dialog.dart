import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment_strategy.dart';
import '../models/team.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
import '../screens/monthly_shift_settings_screen.dart';
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
  bool _isProcessing = false;
  String? _errorMessage;
  AssignmentStrategy _selectedStrategy = AssignmentStrategy.fairness;

  // 制約条件
  final TextEditingController _maxConsecutiveDaysController = TextEditingController(text: '5');
  final TextEditingController _minRestHoursController = TextEditingController(text: '12');
  Team? _currentTeam;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    _endDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
    _loadStrategyPreference();
    _loadTeamSettings();

    // ShiftProviderに正しい月を設定（購読範囲を確実に更新）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      shiftProvider.setCurrentMonth(widget.selectedMonth);
    });
  }

  /// Firestoreからチーム設定をロード
  Future<void> _loadTeamSettings() async {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final teamId = shiftProvider.teamId;
    if (teamId == null) return;

    try {
      final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();

      if (teamDoc.exists) {
        _currentTeam = Team.fromFirestore(teamDoc);
        setState(() {
          _maxConsecutiveDaysController.text = _currentTeam!.maxConsecutiveDays.toString();
          _minRestHoursController.text = _currentTeam!.minRestHours.toString();
        });
      }
    } catch (e) {
      print('チーム設定の読み込みエラー: $e');
    }
  }

  @override
  void dispose() {
    _maxConsecutiveDaysController.dispose();
    _minRestHoursController.dispose();
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

        return AlertDialog(
          title: const Text('自動シフト割り当て'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.selectedMonth.year}年${widget.selectedMonth.month}月のシフトを自動作成します',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '月間シフト設定に従ってシフトを自動作成します。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateToMonthlyShiftSettings(),
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('月間シフト設定を確認・変更'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeSettings.isEmpty) ...[
                    const SizedBox(height: 12),
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
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '制約条件：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '連続勤務日数上限',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: _maxConsecutiveDaysController,
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
                                const Text('日'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '勤務間インターバル',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: _minRestHoursController,
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
                                const Text('時間'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                            '戦略を変えると異なるシフトが作成されます。現在のシフトはバックアップされ復元できます。',
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
      final requirementsProvider = context.read<MonthlyRequirementsProvider>();

      // 基本設定から必要人数を取得
      final requirements = Map<String, int>.from(requirementsProvider.requirements);

      // 少なくとも1つのシフトタイプに1以上の人数が必要
      if (requirements.isEmpty || requirements.values.every((v) => v <= 0)) {
        setState(() {
          _isProcessing = false;
        });
        await _showRequirementsNotSetDialog();
        return;
      }

      // 制約条件のバリデーション
      final maxConsecutiveDaysText = _maxConsecutiveDaysController.text.trim();
      final minRestHoursText = _minRestHoursController.text.trim();

      String? validationError;

      if (maxConsecutiveDaysText.isEmpty) {
        validationError = '連続勤務日数上限を入力してください';
      } else if (minRestHoursText.isEmpty) {
        validationError = '勤務間インターバルを入力してください';
      } else {
        final maxConsecutiveDays = int.tryParse(maxConsecutiveDaysText);
        final minRestHours = int.tryParse(minRestHoursText);

        if (maxConsecutiveDays == null) {
          validationError = '連続勤務日数上限は数値で入力してください';
        } else if (minRestHours == null) {
          validationError = '勤務間インターバルは数値で入力してください';
        } else if (maxConsecutiveDays < 1) {
          validationError = '連続勤務日数上限は1日以上で入力してください';
        } else if (minRestHours < 0) {
          validationError = '勤務間インターバルは0時間以上で入力してください';
        }
      }

      if (validationError != null) {
        setState(() {
          _isProcessing = false;
        });
        await _showValidationErrorDialog(validationError);
        return;
      }

      final maxConsecutiveDays = int.parse(maxConsecutiveDaysText);
      final minRestHours = int.parse(minRestHoursText);

      if (_currentTeam != null) {
        final updatedTeam = _currentTeam!.copyWith(
          maxConsecutiveDays: maxConsecutiveDays,
          minRestHours: minRestHours,
          updatedAt: DateTime.now(),
        );
        await FirebaseFirestore.instance.collection('teams').doc(_currentTeam!.id).update(updatedTeam.toFirestore());
      }

      // 0. ShiftProviderに正しい月を設定（購読範囲を確実に更新）
      shiftProvider.setCurrentMonth(widget.selectedMonth);

      // Firestoreからのデータ読み込みを待つ（非同期処理完了を確実にする）
      await Future.delayed(const Duration(milliseconds: 100));

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
        team: _currentTeam,
        strategy: _selectedStrategy,
        maxConsecutiveDays: maxConsecutiveDays,
        minRestHours: minRestHours,
        requirementsProvider: requirementsProvider,
      );

      // 5. 新シフトをshiftsに保存
      await shiftProvider.batchAddShifts(shifts);

      // 6. 新しいplan_idを作成
      final newPlanId = await planService.generateUniquePlanId(month);

      // 7. shift_active_planを新しいplan_idで更新
      await planService.setActivePlanId(month, newPlanId, strategy: _selectedStrategy.name);

      // 8. 次回デフォルト表示されるように選択した戦略を端末に保存
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

  Future<void> _showValidationErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('入力エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 月間シフト設定画面へ遷移
  void _navigateToMonthlyShiftSettings() {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final monthlyRequirementsProvider = Provider.of<MonthlyRequirementsProvider>(context, listen: false);

    Navigator.of(context).pop();
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
  }

  /// 必要人数が設定されていない場合のダイアログ
  Future<void> _showRequirementsNotSetDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('必要人数が未設定です'),
        content: const Text(
          '自動作成するには、月間シフト設定で各シフトタイプの必要人数を1以上に設定してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('設定画面へ'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // 現在のProviderを取得
      final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
      final monthlyRequirementsProvider = Provider.of<MonthlyRequirementsProvider>(context, listen: false);

      // 自動作成ダイアログを閉じてから月間シフト設定画面へ遷移
      Navigator.of(context).pop();
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
    }
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
