import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/companion_rule.dart';
import '../models/staff.dart';
import '../models/team.dart';
import '../providers/shift_provider.dart';
import '../providers/staff_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/banner_ad_widget.dart';

/// ペア設定画面（管理者専用）
/// NGペア（組ませない）を設定する。固定ペア（必ず一緒）は今後追加予定。
class PairSettingsScreen extends StatefulWidget {
  const PairSettingsScreen({super.key});

  @override
  State<PairSettingsScreen> createState() => _PairSettingsScreenState();
}

class _PairSettingsScreenState extends State<PairSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Team? _currentTeam;

  @override
  void initState() {
    super.initState();
    _loadTeam();
    AnalyticsService.logScreenView('pair_settings_screen');
  }

  Future<void> _loadTeam() async {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final teamId = shiftProvider.teamId;

    if (teamId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
      if (teamDoc.exists && mounted) {
        setState(() {
          _currentTeam = Team.fromFirestore(teamDoc);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('チーム情報の読み込みに失敗しました: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// スタッフID → 表示名
  String _staffName(String id) {
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final staff = staffProvider.staffList.where((s) => s.id == id).firstOrNull;
    return staff?.name ?? '(削除されたスタッフ)';
  }

  Future<void> _saveNgPairs(List<String> ngPairs) async {
    if (_currentTeam == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = _currentTeam!.copyWith(ngPairs: ngPairs, updatedAt: DateTime.now());
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(_currentTeam!.id)
          .update({'ngPairs': ngPairs, 'updatedAt': Timestamp.fromDate(updated.updatedAt)});
      if (mounted) {
        setState(() {
          _currentTeam = updated;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _addNgPair() async {
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final staffList = staffProvider.activeStaffList;

    if (staffList.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ペアを作るにはスタッフが2人以上必要です')),
      );
      return;
    }

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _PairPickerDialog(staffList: staffList),
    );

    if (result == null) return;

    final key = Team.pairKey(result.$1, result.$2);
    final ngPairs = List<String>.from(_currentTeam!.ngPairs);
    if (ngPairs.contains(key)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('そのペアは既に登録されています')),
        );
      }
      return;
    }
    ngPairs.add(key);
    await _saveNgPairs(ngPairs);
  }

  Future<void> _removeNgPair(String key) async {
    final ngPairs = List<String>.from(_currentTeam!.ngPairs)..remove(key);
    await _saveNgPairs(ngPairs);
  }

  Future<void> _saveCompanionRules(List<CompanionRule> rules) async {
    if (_currentTeam == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = _currentTeam!.copyWith(companionRules: rules, updatedAt: DateTime.now());
      await FirebaseFirestore.instance.collection('teams').doc(_currentTeam!.id).update({
        'companionRules': rules.map((e) => e.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(updated.updatedAt),
      });
      if (mounted) {
        setState(() {
          _currentTeam = updated;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _addOrEditCompanionRule({CompanionRule? existing}) async {
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final staffList = staffProvider.activeStaffList;

    if (staffList.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定にはスタッフが2人以上必要です')),
      );
      return;
    }

    final result = await showDialog<CompanionRule>(
      context: context,
      builder: (context) => _CompanionRuleDialog(staffList: staffList, existing: existing),
    );
    if (result == null) return;

    // 同じ対象スタッフのルールは1つに統一（上書き）
    final rules = List<CompanionRule>.from(_currentTeam!.companionRules)
      ..removeWhere((r) => r.staffId == result.staffId);
    rules.add(result);
    await _saveCompanionRules(rules);
  }

  Future<void> _removeCompanionRule(String staffId) async {
    final rules = List<CompanionRule>.from(_currentTeam!.companionRules)
      ..removeWhere((r) => r.staffId == staffId);
    await _saveCompanionRules(rules);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ペア設定'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentTeam == null
              ? const Center(child: Text('チーム情報が見つかりません'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildCompanionSection(),
                          const SizedBox(height: 32),
                          _buildNgSection(),
                        ],
                      ),
                    ),
                    const SafeArea(top: false, child: BannerAdWidget()),
                  ],
                ),
    );
  }

  Widget _buildCompanionSection() {
    final rules = _currentTeam!.companionRules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.school_outlined, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '新人など「一人で勤務させたくないスタッフ」を、指定したベテランの誰か1人と必ず同じシフトに入れます。'
                    '（例：新人Aは、B・C・Dの誰かと一緒）',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.group, size: 20),
            const SizedBox(width: 8),
            Text('付き添い必須', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const Divider(),
        if (rules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('付き添い必須の設定はまだありません', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...rules.map((rule) {
            final target = _staffName(rule.staffId);
            final companions = rule.companionIds.map(_staffName).join('、');
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('$target ＋ 誰か1人'),
                subtitle: Text(
                  '相方候補: ${companions.isEmpty ? "(未設定)" : companions}\n'
                  '${rule.hard ? "絶対（相方がいなければ入れない）" : "なるべく（最悪は単独も可）"}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _isSaving ? null : () => _addOrEditCompanionRule(existing: rule),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _isSaving ? null : () => _removeCompanionRule(rule.staffId),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : () => _addOrEditCompanionRule(),
          icon: const Icon(Icons.add),
          label: const Text('付き添い必須を追加'),
        ),
      ],
    );
  }

  Widget _buildNgSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    'NGペアに登録した2人は、自動シフト作成で同じ日の同じシフトに一緒に割り当てられなくなります。',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.block, size: 20),
            const SizedBox(width: 8),
            Text('NGペア（組ませない）', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const Divider(),
        if (_currentTeam!.ngPairs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('NGペアはまだ登録されていません', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._currentTeam!.ngPairs.map((key) {
            final ids = key.split('|');
            final name1 = ids.isNotEmpty ? _staffName(ids[0]) : '?';
            final name2 = ids.length > 1 ? _staffName(ids[1]) : '?';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text('$name1 ✕ $name2'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _isSaving ? null : () => _removeNgPair(key),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _addNgPair,
          icon: const Icon(Icons.add),
          label: const Text('NGペアを追加'),
        ),
      ],
    );
  }
}

/// 2人のスタッフを選んでペアを作るダイアログ
class _PairPickerDialog extends StatefulWidget {
  final List<Staff> staffList;

  const _PairPickerDialog({required this.staffList});

  @override
  State<_PairPickerDialog> createState() => _PairPickerDialogState();
}

class _PairPickerDialogState extends State<_PairPickerDialog> {
  String? _first;
  String? _second;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ペアを選択'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _first,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '1人目'),
            items: widget.staffList
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _first = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _second,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '2人目'),
            items: widget.staffList
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _second = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: (_first != null && _second != null && _first != _second)
              ? () => Navigator.of(context).pop((_first!, _second!))
              : null,
          child: const Text('追加'),
        ),
      ],
    );
  }
}

/// 付き添い必須ルールを作成・編集するダイアログ
class _CompanionRuleDialog extends StatefulWidget {
  final List<Staff> staffList;
  final CompanionRule? existing;

  const _CompanionRuleDialog({required this.staffList, this.existing});

  @override
  State<_CompanionRuleDialog> createState() => _CompanionRuleDialogState();
}

class _CompanionRuleDialogState extends State<_CompanionRuleDialog> {
  String? _targetId;
  late Set<String> _companionIds;
  late bool _hard;

  @override
  void initState() {
    super.initState();
    _targetId = widget.existing?.staffId;
    _companionIds = {...?widget.existing?.companionIds};
    _hard = widget.existing?.hard ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '付き添い必須を追加' : '付き添い必須を編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('一人にしたくないスタッフ', style: TextStyle(fontWeight: FontWeight.w500)),
              DropdownButtonFormField<String>(
                initialValue: _targetId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '対象スタッフ'),
                items: widget.staffList
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _targetId = v;
                  _companionIds.remove(v); // 自分自身は相方候補から外す
                }),
              ),
              const SizedBox(height: 16),
              const Text('相方候補（誰か1人と同席すればOK）', style: TextStyle(fontWeight: FontWeight.w500)),
              ...widget.staffList.where((s) => s.id != _targetId).map((s) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _companionIds.contains(s.id),
                  title: Text(s.name),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _companionIds.add(s.id);
                    } else {
                      _companionIds.remove(s.id);
                    }
                  }),
                );
              }),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hard,
                onChanged: (v) => setState(() => _hard = v),
                title: const Text('絶対に付き添いをつける', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  _hard
                      ? '相方がいない枠には本人を入れません（単独勤務NG）'
                      : 'なるべく相方をつけますが、無理なら本人だけでも入れます',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: (_targetId != null && _companionIds.isNotEmpty)
              ? () => Navigator.of(context).pop(CompanionRule(
                    staffId: _targetId!,
                    companionIds: _companionIds.toList(),
                    hard: _hard,
                  ))
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
