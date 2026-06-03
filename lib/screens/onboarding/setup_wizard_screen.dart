import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/shift_time_setting.dart';
import '../../models/staff.dart';
import '../../providers/monthly_requirements_provider.dart';
import '../../providers/shift_time_provider.dart';
import '../../providers/staff_provider.dart';
import '../../services/analytics_service.dart';
import '../../widgets/shift_time_edit_dialog.dart';
import '../../widgets/staff_edit_dialog.dart';

/// 初回セットアップウィザード
///
/// 新規管理者を「考えさせず」に、スタッフ登録 → シフト時間 → 必要人数 →
/// 自動作成まで一度だけ手を引いて連れて行く。完了したら二度と表示しない。
///
/// 既存のProvider（StaffProvider / ShiftTimeProvider /
/// MonthlyRequirementsProvider / ShiftProvider）のスコープ内で表示すること。
class SetupWizardScreen extends StatefulWidget {
  /// 完了（または途中終了）時に呼ばれる。初回フラグの保存・画面遷移は呼び出し側で行う。
  final VoidCallback onFinished;

  /// 再開時の開始ステップ（前回の続きから）。
  final int initialStep;

  const SetupWizardScreen({
    super.key,
    required this.onFinished,
    this.initialStep = 0,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

/// シフト構成テンプレート（考えない出発点）
class _ShiftTemplate {
  final String label;
  final String description;
  final Set<ShiftType> shifts;
  const _ShiftTemplate(this.label, this.description, this.shifts);
}

const _templates = [
  _ShiftTemplate('日勤のみ', '日中の1シフトだけ', {ShiftType.shift2}),
  _ShiftTemplate('2交代', '日勤・夜勤', {ShiftType.shift2, ShiftType.shift4}),
  _ShiftTemplate('3交代', '早番・遅番・夜勤', {ShiftType.shift1, ShiftType.shift3, ShiftType.shift4}),
  _ShiftTemplate('4交代', '早番・日勤・遅番・夜勤', {ShiftType.shift1, ShiftType.shift2, ShiftType.shift3, ShiftType.shift4}),
];

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0; // 0:スタッフ 1:シフト時間 2:必要人数 3:自動作成
  static const _totalSteps = 4;

  final TextEditingController _nameController = TextEditingController();
  int _staffCounter = 0;

  String? _selectedTemplate;
  final Map<String, int> _headcounts = {}; // displayName -> 人数

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, _totalSteps - 1);
    // 新規開始のみ計測（再開＝initialStep>0 は除く）
    if (_step == 0) {
      AnalyticsService.logWizardStep('start');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 進捗（ステップ）を保存して次回再開できるようにする。
  /// 最終ステップは案内のみ（自動作成はしない）。完了フラグ onboarding_completed は
  /// 「カレンダーへ」/「スキップ」押下時に呼び出し側(onFinished)で立てる。
  Future<void> _persistStep() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onboarding_step', _step);
  }

  // ---- ステップ1：スタッフ ----
  Future<void> _addStaff() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final staffProvider = context.read<StaffProvider>();
    _staffCounter++;
    final staff = Staff(
      id: '${DateTime.now().millisecondsSinceEpoch}_$_staffCounter',
      name: name,
      maxShiftsPerMonth: 20,
    );
    await staffProvider.addStaff(staff);
    _nameController.clear();
    if (mounted) setState(() {});
  }

  /// 登録済みスタッフをタップ → 既存の編集ダイアログで勤務回数・休み希望等を設定
  void _editStaff(Staff staff) {
    final staffProvider = context.read<StaffProvider>();
    final shiftTimeProvider = context.read<ShiftTimeProvider>();
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
          ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
        ],
        child: StaffEditDialog(existingStaff: staff, showLinkStatus: false),
      ),
    );
  }

  // ---- ステップ2：テンプレ適用 ----
  Future<void> _applyTemplate(_ShiftTemplate template) async {
    final shiftTimeProvider = context.read<ShiftTimeProvider>();
    setState(() => _selectedTemplate = template.label);
    await shiftTimeProvider.setActiveShiftTypes(template.shifts);
  }

  /// シフトをタップ → 既存の共有編集ダイアログ（名前・開始・終了を一括編集）
  void _editShiftTime(ShiftTimeSetting setting) {
    final shiftTimeProvider = context.read<ShiftTimeProvider>();
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider<ShiftTimeProvider>.value(
        value: shiftTimeProvider,
        child: ShiftTimeEditDialog(setting: setting),
      ),
    );
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      // いま完了したステップを計測（離脱箇所の特定用）
      const doneEvents = ['staff_done', 'shifts_done', 'requirements_done'];
      if (_step < doneEvents.length) {
        AnalyticsService.logWizardStep(doneEvents[_step]);
      }
      setState(() => _step++);
      _persistStep();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _persistStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 初回ガイド中は端末の戻るでアプリを抜けさせない
      onPopInvokedWithResult: (didPop, result) {
        // 端末の戻るキーは「前のステップへ」に割り当てる
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('はじめの設定（${_step + 1}/$_totalSteps）'),
          automaticallyImplyLeading: false,
          leading: (_step > 0)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _back,
                )
              : null,
          actions: [
            // 最終ステップ（準備完了の案内）ではスキップは出さない
            if (_step < _totalSteps - 1)
              TextButton(
                onPressed: () {
                  AnalyticsService.logWizardStep('skipped');
                  widget.onFinished();
                },
                child: const Text('スキップ'),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_step + 1) / _totalSteps),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStaffStep();
      case 1:
        return _buildShiftTimeStep();
      case 2:
        return _buildHeadcountStep();
      default:
        return _buildGenerateStep();
    }
  }

  Widget _stepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _nextButton({required bool enabled, String label = '次へ', VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? (onPressed ?? _next) : null,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(label),
      ),
    );
  }

  // ===== ステップ1：スタッフ =====
  Widget _buildStaffStep() {
    return Consumer<StaffProvider>(
      builder: (context, staffProvider, child) {
        final staff = staffProvider.staff;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader('スタッフを登録しましょう', 'まず、名前を入力して必要なスタッフを追加してください。\nその後、必要に応じて各スタッフをタップして設定を変えられます。'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '名前',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addStaff(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addStaff,
                  child: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: staff.isEmpty
                  ? Center(child: Text('登録したスタッフがここに表示されます', style: TextStyle(color: Colors.grey[500])))
                  : ListView.builder(
                      itemCount: staff.length,
                      itemBuilder: (context, index) {
                        final s = staff[index];
                        return Card(
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(s.name),
                            onTap: () => _editStaff(s),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit, size: 16, color: Colors.grey),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => staffProvider.deleteStaff(s.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            _nextButton(enabled: staff.isNotEmpty),
          ],
        );
      },
    );
  }

  // ===== ステップ2：シフト時間 =====
  Widget _buildShiftTimeStep() {
    return Consumer<ShiftTimeProvider>(
      builder: (context, provider, child) {
        final active = provider.settings.where((s) => s.isActive).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader('シフトの種類を選びましょう', '一番近いものを選んでください。各シフトはタップで名前・時間を調整できます。'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates.map((t) {
                final selected = _selectedTemplate == t.label;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  showCheckmark: false, // 選択時に幅が変わって折り返すのを防ぐ
                  onSelected: (_) => _applyTemplate(t),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ぴったり合うものが無くても大丈夫。今は一番近いものでOKです。'
                      'あなたのチームに合わせた細かい設定は、この後いつでも変更できます。',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('シフト（タップで名前・時間を変更）', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                children: active
                    .map((s) => Card(
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(backgroundColor: s.shiftType.color, child: const Icon(Icons.schedule, color: Colors.white, size: 18)),
                            title: Text(s.displayName),
                            subtitle: Text(s.timeRange),
                            trailing: const Icon(Icons.edit, size: 18),
                            onTap: () => _editShiftTime(s),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            _nextButton(enabled: active.isNotEmpty),
          ],
        );
      },
    );
  }

  // ===== ステップ3：必要人数 =====
  Widget _buildHeadcountStep() {
    final reqProvider = context.read<MonthlyRequirementsProvider>();
    return Consumer<ShiftTimeProvider>(
      builder: (context, provider, child) {
        final active = provider.settings.where((s) => s.isActive).toList();
        // 未設定の有効シフトは、保存済みの値（再開時）かデフォルト1人
        for (final s in active) {
          _headcounts.putIfAbsent(s.displayName, () => reqProvider.requirements[s.displayName] ?? 1);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader('各シフト、1日に何人必要ですか？', 'あとからいつでも変更できます。'),
            Expanded(
              child: ListView(
                children: active.map((s) {
                  final count = _headcounts[s.displayName] ?? 1;
                  return Card(
                    child: ListTile(
                      title: Text(s.displayName),
                      subtitle: Text(s.timeRange),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: count > 0 ? () => setState(() => _headcounts[s.displayName] = count - 1) : null,
                          ),
                          Text('$count人', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _headcounts[s.displayName] = count + 1),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            _nextButton(
              enabled: active.any((s) => (_headcounts[s.displayName] ?? 0) > 0),
              label: '次へ',
              onPressed: () async {
                // 「次へ」の時点で必要人数を保存しておく。
                // こうすると、生成ステップでアプリを閉じて再開しても設定が残る。
                await reqProvider.setRequirements(Map<String, int>.from(_headcounts));
                if (mounted) _next();
              },
            ),
          ],
        );
      },
    );
  }

  /// 補足説明用の控えめなヒント行（主役の「次にすること」より目立たせない）
  Widget _miniHint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check, size: 14, color: Colors.grey[500]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
          ),
        ),
      ],
    );
  }

  // ===== ステップ4：準備完了の案内 =====
  // ここでは自動作成しない（広告も出さない）。最初の自動作成はカレンダー画面の
  // 「自動作成」ボタンで本人にやってもらう（ボタンの場所を学習＋初回ヒントもそこで出る）。
  Widget _buildGenerateStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.check_circle, color: Colors.green[600], size: 72),
          const SizedBox(height: 16),
          const Text('準備ができました！', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'スタッフ・シフト・必要人数の設定が完了しました。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[850]),
          ),
          const SizedBox(height: 24),

          // ===== 主役：次にすること（自動作成ボタンを押す）を強調 =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300, width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text('次にすること', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'このあと開くカレンダー画面の右上にある',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[850], height: 1.4),
                ),
                const SizedBox(height: 12),
                // 実際の「自動作成」ボタンに似せた見本（認識しやすくするため）
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_fix_high, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('自動作成', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'を押してシフトを作成するだけ！\nさぁ、シフト管理を始めましょう。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[850], height: 1.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===== 補足（控えめ） =====
          Align(
            alignment: Alignment.centerLeft,
            child: Text('ヒント', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          ),
          const SizedBox(height: 8),
          _miniHint('作成されたシフトが気に入らなければ、もう一度「自動作成」すると、別案が作れます（毎回ちがう案）'),
          const SizedBox(height: 6),
          _miniHint('作成されたシフトは、日付をタップして手動で調整できます（追加・削除・入れ替え・日付移動）'),
          const SizedBox(height: 6),
          _miniHint('シフト表は「シフト表」画面から出力できます（PDF・画像・Excel）'),
          const SizedBox(height: 6),
          _miniHint('使い方は画面右上の「？」からいつでも確認できます'),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                AnalyticsService.logWizardStep('finished');
                widget.onFinished();
              },
              icon: const Icon(Icons.calendar_month),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              label: const Text('カレンダーを開く'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
