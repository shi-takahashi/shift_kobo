import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team.dart';
import '../providers/shift_provider.dart';
import '../services/analytics_service.dart';

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
  bool _hasChanges = false;
  bool _isLoading = true;
  Team? _currentTeam;

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
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .get();

      if (teamDoc.exists && mounted) {
        _currentTeam = Team.fromFirestore(teamDoc);
        final maxDays = _currentTeam!.maxConsecutiveDays.toString();
        final minHours = _currentTeam!.minRestHours.toString();

        setState(() {
          _maxConsecutiveDaysController.text = maxDays;
          _minRestHoursController.text = minHours;
          _originalMaxDays = maxDays;
          _originalMinHours = minHours;
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
                       currentMinHours != _originalMinHours;
    final isValid = maxDaysError == null && minHoursError == null;

    setState(() {
      _hasChanges = hasChanges && isValid;
      _maxDaysError = maxDaysError;
      _minHoursError = minHoursError;
    });
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
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('teams')
          .doc(_currentTeam!.id)
          .update(updatedTeam.toFirestore());

      setState(() {
        _originalMaxDays = maxDays.toString();
        _originalMinHours = minHours.toString();
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
              ],
            ),
    );
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
