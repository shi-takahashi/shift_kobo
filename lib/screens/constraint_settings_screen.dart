import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/consecutive_days_off_rule.dart';
import '../models/team.dart';
import '../providers/shift_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/banner_ad_widget.dart';

class ConstraintSettingsScreen extends StatefulWidget {
  const ConstraintSettingsScreen({super.key});

  @override
  State<ConstraintSettingsScreen> createState() => _ConstraintSettingsScreenState();
}

class _ConstraintSettingsScreenState extends State<ConstraintSettingsScreen> {
  final TextEditingController _maxConsecutiveDaysController = TextEditingController();
  final TextEditingController _minRestHoursController = TextEditingController();

  String? _originalMaxDays;
  String? _originalMinHours;
  bool _countOvernightAsTwoDays = true;
  bool _originalCountOvernight = true;
  bool _hasChanges = false;
  bool _isLoading = true;
  Team? _currentTeam;

  // 連休（日付未指定）の確保ルール群。空なら機能オフ。
  List<ConsecutiveDaysOffRule> _daysOffRules = [];
  List<ConsecutiveDaysOffRule> _originalDaysOffRules = [];

  String? _maxDaysError;
  String? _minHoursError;

  @override
  void initState() {
    super.initState();
    _maxConsecutiveDaysController.addListener(_checkForChanges);
    _minRestHoursController.addListener(_checkForChanges);
    _loadTeamSettings();

    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('constraint_settings_screen');
  }

  @override
  void dispose() {
    _maxConsecutiveDaysController.dispose();
    _minRestHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamSettings() async {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final teamId = shiftProvider.teamId;

    if (teamId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();

      if (teamDoc.exists && mounted) {
        _currentTeam = Team.fromFirestore(teamDoc);
        final maxDays = _currentTeam!.maxConsecutiveDays.toString();
        final minHours = _currentTeam!.minRestHours.toString();

        setState(() {
          _maxConsecutiveDaysController.text = maxDays;
          _minRestHoursController.text = minHours;
          _originalMaxDays = maxDays;
          _originalMinHours = minHours;
          _daysOffRules = _currentTeam!.consecutiveDaysOffRules
              .map((r) => r.copyWith())
              .toList();
          _originalDaysOffRules = _currentTeam!.consecutiveDaysOffRules
              .map((r) => r.copyWith())
              .toList();
          _countOvernightAsTwoDays = _currentTeam!.countOvernightAsTwoDays;
          _originalCountOvernight = _currentTeam!.countOvernightAsTwoDays;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定の読み込みに失敗しました: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _checkForChanges() {
    final currentMaxDays = _maxConsecutiveDaysController.text;
    final currentMinHours = _minRestHoursController.text;

    // バリデーション（最小限）
    String? maxDaysError;
    String? minHoursError;

    if (currentMaxDays.isEmpty) {
      maxDaysError = '必須';
    } else {
      final intValue = int.tryParse(currentMaxDays);
      if (intValue == null) {
        maxDaysError = '数値を入力';
      } else if (intValue < 1) {
        maxDaysError = '1日以上';
      }
    }

    if (currentMinHours.isEmpty) {
      minHoursError = '必須';
    } else {
      final intValue = int.tryParse(currentMinHours);
      if (intValue == null) {
        minHoursError = '数値を入力';
      } else if (intValue < 0) {
        minHoursError = '0時間以上';
      }
    }

    final hasChanges = currentMaxDays != _originalMaxDays ||
        currentMinHours != _originalMinHours ||
        !_rulesEqual(_daysOffRules, _originalDaysOffRules) ||
        _countOvernightAsTwoDays != _originalCountOvernight;
    final isValid = maxDaysError == null && minHoursError == null;

    setState(() {
      _hasChanges = hasChanges && isValid;
      _maxDaysError = maxDaysError;
      _minHoursError = minHoursError;
    });
  }

  bool _rulesEqual(List<ConsecutiveDaysOffRule> a, List<ConsecutiveDaysOffRule> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _saveSettings() async {
    if (_currentTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チーム情報が見つかりません')),
      );
      return;
    }

    final maxDays = int.tryParse(_maxConsecutiveDaysController.text);
    final minHours = int.tryParse(_minRestHoursController.text);

    if (maxDays == null || minHours == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な数値を入力してください')),
      );
      return;
    }

    try {
      final updatedTeam = _currentTeam!.copyWith(
        maxConsecutiveDays: maxDays,
        minRestHours: minHours,
        consecutiveDaysOffRules: _daysOffRules.map((r) => r.copyWith()).toList(),
        countOvernightAsTwoDays: _countOvernightAsTwoDays,
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('teams').doc(_currentTeam!.id).update(updatedTeam.toFirestore());

      setState(() {
        _originalMaxDays = maxDays.toString();
        _originalMinHours = minHours.toString();
        _originalDaysOffRules = _daysOffRules.map((r) => r.copyWith()).toList();
        _originalCountOvernight = _countOvernightAsTwoDays;
        _hasChanges = false;
        _currentTeam = updatedTeam;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定を保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('制約条件設定'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '自動シフト作成時の制約条件を設定します。',
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
                                      const Icon(Icons.rule, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '勤務制約条件',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  _buildConstraintField(
                                    label: '連続勤務日数上限',
                                    controller: _maxConsecutiveDaysController,
                                    suffix: '日',
                                    errorText: _maxDaysError,
                                    icon: Icons.calendar_today,
                                    description: 'スタッフが連続して勤務できる最大日数（1日以上）',
                                  ),
                                  const SizedBox(height: 24),
                                  _buildConstraintField(
                                    label: '勤務間インターバル',
                                    controller: _minRestHoursController,
                                    suffix: '時間',
                                    errorText: _minHoursError,
                                    icon: Icons.access_time,
                                    description: '勤務終了から次の勤務開始までの最低休息時間（0時間以上）',
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _countOvernightAsTwoDays,
                                    onChanged: (value) {
                                      setState(() {
                                        _countOvernightAsTwoDays = value;
                                      });
                                      _checkForChanges();
                                    },
                                    title: Row(
                                      children: [
                                        Icon(Icons.nightlight_round, size: 16, color: Colors.grey[700]),
                                        const SizedBox(width: 8),
                                        const Text(
                                          '夜勤を連勤2日分として数える',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '日をまたぐ夜勤（例：22:00〜翌7:00）を連勤上限の2日分として数えます。'
                                        'オフにすると1日分として数えます。',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.weekend, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '連休の確保',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    '日付を指定せず「月のどこかで連続した休み」を確保します。'
                                    '設定した連休は必ず確保します（人手が足りない日でも優先して空けます）。\n'
                                    'これは"最低限"の連休です。自動割り当ての結果、'
                                    '指定より長い連休になることはあります（例: 3連休が4連休になる）。\n'
                                    '「2連休を2回」「3連休を1回」のように複数の組み合わせを設定できます。',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._buildDaysOffRuleRows(),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _daysOffRules.length < _daysOffLengthOptions.length
                                          ? _addDaysOffRule
                                          : null,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('連休パターンを追加'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '自動シフト作成時に、これらの制約条件に違反しないようにスタッフを割り当てます。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
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
                          onPressed: _hasChanges ? _saveSettings : null,
                          icon: const Icon(Icons.save),
                          label: const Text('設定を保存'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
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

  // ===== 連休ルール（リスト編集） =====

  static const List<int> _daysOffLengthOptions = [2, 3, 4, 5, 6, 7];
  static const List<int> _daysOffCountOptions = [1, 2, 3, 4, 5];

  List<Widget> _buildDaysOffRuleRows() {
    if (_daysOffRules.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '設定なし（連休の自動確保はオフ）',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
      ];
    }
    return List.generate(_daysOffRules.length, (index) {
      final rule = _daysOffRules[index];
      // 選択肢に無い値（旧データ等）が来ても落ちないように補正
      final lengthValue =
          _daysOffLengthOptions.contains(rule.length) ? rule.length : _daysOffLengthOptions.first;
      final countValue =
          _daysOffCountOptions.contains(rule.count) ? rule.count : _daysOffCountOptions.first;
      // 同じ長さの連休を複数行作っても意味がないので、他の行で使用中の長さは選べないようにする
      final usedByOthers = <int>{
        for (int j = 0; j < _daysOffRules.length; j++)
          if (j != index) _daysOffRules[j].length,
      };
      final lengthItems = _daysOffLengthOptions
          .where((v) => v == lengthValue || !usedByOthers.contains(v))
          .toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            DropdownButton<int>(
              value: lengthValue,
              items: lengthItems
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _daysOffRules[index] = rule.copyWith(length: v);
                });
                _checkForChanges();
              },
            ),
            const Text(' 連休 を '),
            DropdownButton<int>(
              value: countValue,
              items: _daysOffCountOptions
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _daysOffRules[index] = rule.copyWith(count: v);
                });
                _checkForChanges();
              },
            ),
            const Text(' 回 / 月'),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[600]),
              tooltip: '削除',
              onPressed: () {
                setState(() {
                  _daysOffRules.removeAt(index);
                });
                _checkForChanges();
              },
            ),
          ],
        ),
      );
    });
  }

  void _addDaysOffRule() {
    // まだ使われていない最小の連休長を選ぶ（同じ長さの重複を作らない）
    final used = _daysOffRules.map((r) => r.length).toSet();
    final next = _daysOffLengthOptions.firstWhere(
      (v) => !used.contains(v),
      orElse: () => -1,
    );
    if (next < 0) return; // すべての長さを使い切っている
    setState(() {
      _daysOffRules.add(ConsecutiveDaysOffRule(length: next, count: 1));
    });
    _checkForChanges();
  }

  Widget _buildConstraintField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required String description,
    required IconData icon,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 150,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixText: suffix,
              suffixStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              errorText: errorText,
              errorStyle: const TextStyle(fontSize: 11),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
