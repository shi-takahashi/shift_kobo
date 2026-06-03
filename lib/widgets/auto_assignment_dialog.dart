import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../screens/shift_time_settings_screen.dart';
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
  // 割り当て戦略は公平重視(fairness)に一本化。種別の公平・ペア分散・best-of-Nは
  // すべてこの中で処理される（ユーザーに戦略を選ばせるUIは廃止）。
  final AssignmentStrategy _selectedStrategy = AssignmentStrategy.fairness;

  // 制約条件
  final TextEditingController _maxConsecutiveDaysController = TextEditingController(text: '5');
  final TextEditingController _minRestHoursController = TextEditingController(text: '12');
  Team? _currentTeam;

  // 初回の自動作成時だけ「広告が流れる」案内を出すためのフラグ
  bool _showFirstTimeNotice = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    _endDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
    _loadTeamSettings();
    _loadFirstTimeFlag();

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

  /// 初回の自動作成かどうかを判定して、広告案内の表示有無を決める。
  /// （完了メッセージの「作り直せる」ヒントと同じフラグを共有。初回作成完了時に立つ）
  Future<void> _loadFirstTimeFlag() async {
    if (kIsWeb) return; // Web版は広告なしなので案内不要
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('auto_create_regenerate_hint_shown_v2') ?? false;
    if (!mounted) return;
    setState(() => _showFirstTimeNotice = !done);
  }

  @override
  void dispose() {
    _maxConsecutiveDaysController.dispose();
    _minRestHoursController.dispose();
    super.dispose();
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
    return Consumer3<ShiftTimeProvider, StaffProvider, MonthlyRequirementsProvider>(
      builder: (context, shiftTimeProvider, staffProvider, requirementsProvider, child) {
        final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
        final allStaff = staffProvider.staff;
        final activeStaff = staffProvider.activeStaffList;
        final hasNoStaff = allStaff.isEmpty;
        final hasNoActiveStaff = allStaff.isNotEmpty && activeStaff.isEmpty;
        final requirements = requirementsProvider.requirements;
        // 有効なシフトタイプに対する必要人数が1以上あるかチェック
        final hasValidRequirements = activeSettings.any((setting) {
          final requirement = requirements[setting.displayName] ?? 0;
          return requirement > 0;
        });
        final hasNoRequirements = !hasValidRequirements;

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
                          'シフト時間設定とシフト割り当て設定に従ってシフトを自動作成します。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateToShiftTimeSettings(),
                            icon: const Icon(Icons.schedule, size: 16),
                            label: const Text('シフト時間設定'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateToMonthlyShiftSettings(),
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('シフト割り当て設定'),
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
                  if (hasNoStaff || hasNoActiveStaff) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '有効なスタッフがいません。\nスタッフ画面でスタッフを登録してください。',
                        style: TextStyle(color: Colors.orange.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (hasNoRequirements) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '必要人数が設定されていません。\nシフト割当て設定で必要人数を設定してください。',
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '作成結果が気に入らなければ、もう一度「作成」を押すと別の案が作られます（毎回違う結果になります）。前の案は自動でバックアップされ、いつでも切り替えできます。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 初回だけ：広告が流れることを事前に案内する
                  if (_showFirstTimeNotice) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.smart_display_outlined, size: 20, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '「作成」を押すと広告が表示されます。広告を閉じると、作成されたシフトを確認できます。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
            if (activeSettings.isNotEmpty && activeStaff.isNotEmpty && !hasNoRequirements)
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

        // 初回の自動作成時だけ、完了メッセージに「作り直せる」ヒントを含める。
        // 2回目以降は鬱陶しいので出さない（SharedPreferencesで記録）。
        const hintKey = 'auto_create_regenerate_hint_shown_v2';
        final prefs = await SharedPreferences.getInstance();
        final showRegenerateHint = !(prefs.getBool(hintKey) ?? false);
        if (showRegenerateHint) await prefs.setBool(hintKey, true);

        // 12. ダイアログを閉じる
        navigatorContext.pop(true);

        // 13. 広告表示（閉じた後に完了メッセージを表示）
        AdService.showInterstitialAd(
          onAdShown: () {},
          onAdClosed: () {
            _showCompletionMessage(scaffoldMessengerContext, shiftsCount, showRegenerateHint: showRegenerateHint);
          },
          onAdFailedToShow: () {
            _showCompletionMessage(scaffoldMessengerContext, shiftsCount, showRegenerateHint: showRegenerateHint);
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

  /// シフト時間設定画面へ遷移
  void _navigateToShiftTimeSettings() {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider<ShiftTimeProvider>.value(
          value: shiftTimeProvider,
          child: const ShiftTimeSettingsScreen(),
        ),
      ),
    );
  }

  /// シフト割当て設定画面へ遷移
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

  /// シフト作成完了メッセージを表示
  /// [showRegenerateHint] が true の時（＝初回作成時）は、
  /// 「気に入らなければ作り直せる」ヒントを1行追加する。
  void _showCompletionMessage(
    ScaffoldMessengerState scaffoldMessenger,
    int shiftsCount, {
    bool showRegenerateHint = false,
  }) {
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
                  if (showRegenerateHint) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '💡 気に入らなければ、もう一度「自動作成」を押すと別の案が作れます',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: showRegenerateHint ? 7 : 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
