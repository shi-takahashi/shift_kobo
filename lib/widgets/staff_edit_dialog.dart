import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/staff.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class StaffEditDialog extends StatefulWidget {
  final Staff? existingStaff;

  const StaffEditDialog({
    super.key,
    this.existingStaff,
  });

  @override
  State<StaffEditDialog> createState() => _StaffEditDialogState();
}

class _StaffEditDialogState extends State<StaffEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _maxShiftsController;

  late List<int> _selectedDaysOff;
  late List<String> _unavailableShiftTypes;
  late List<DateTime> _specificDaysOff;
  late List<DateTime> _preferredDates; // 勤務希望日
  late bool _holidaysOff; // 祝日を休み希望とするか
  bool _showPastDaysOff = false; // 過去の休み希望日を表示するか
  bool _showPastPreferredDates = false; // 過去の勤務希望日を表示するか
  int? _maxConsecutiveDays; // 個別の連続勤務日数上限
  int? _minRestHours; // 個別の勤務間インターバル
  bool _useCustomMaxConsecutiveDays = false; // 個別連続勤務日数上限を使用するか
  bool _useCustomMinRestHours = false; // 個別勤務間インターバルを使用するか

  // ロール管理用
  AppUser? _linkedUser;
  UserRole? _selectedRole;
  bool _isLastAdmin = false;

  @override
  void initState() {
    super.initState();

    if (widget.existingStaff != null) {
      // 編集モード
      _nameController = TextEditingController(text: widget.existingStaff!.name);
      _phoneController = TextEditingController(text: widget.existingStaff!.phoneNumber ?? '');
      _emailController = TextEditingController(text: widget.existingStaff!.email ?? '');
      _maxShiftsController = TextEditingController(text: widget.existingStaff!.maxShiftsPerMonth.toString());
      _selectedDaysOff = List.from(widget.existingStaff!.preferredDaysOff);
      _unavailableShiftTypes = List.from(widget.existingStaff!.unavailableShiftTypes);
      _specificDaysOff = widget.existingStaff!.specificDaysOff.map((dateStr) => DateTime.parse(dateStr)).toList();
      _preferredDates = widget.existingStaff!.preferredDates.map((dateStr) => DateTime.parse(dateStr)).toList();
      _holidaysOff = widget.existingStaff!.holidaysOff;
      _maxConsecutiveDays = widget.existingStaff!.maxConsecutiveDays;
      _minRestHours = widget.existingStaff!.minRestHours;
      _useCustomMaxConsecutiveDays = widget.existingStaff!.maxConsecutiveDays != null;
      _useCustomMinRestHours = widget.existingStaff!.minRestHours != null;

      // 紐付け済みの場合、ユーザー情報とロールを取得
      _loadUserRoleInfo();
    } else {
      // 追加モード
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _emailController = TextEditingController();
      _maxShiftsController = TextEditingController(text: '20');
      _selectedDaysOff = [];
      _unavailableShiftTypes = [];
      _specificDaysOff = [];
      _preferredDates = [];
      _holidaysOff = false;
    }
  }

  Future<void> _loadUserRoleInfo() async {
    final userId = widget.existingStaff?.userId;
    if (userId == null) return;

    try {
      final authService = AuthService();

      // ユーザー情報を取得
      final user = await authService.getUser(userId);
      if (user == null) return;

      // 管理者数を取得
      final teamId = user.teamId;
      if (teamId == null) {
        setState(() {
          _linkedUser = user;
          _selectedRole = user.role;
        });
        return;
      }

      final adminCount = await authService.getAdminCount(teamId);

      setState(() {
        _linkedUser = user;
        _selectedRole = user.role;
        _isLastAdmin = (adminCount == 1 && user.role == UserRole.admin);
      });
    } catch (e) {
      // エラーハンドリング（本番環境ではログ記録等を検討）
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _maxShiftsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // スクロール可能なコンテンツ部分
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 6.0,
                  radius: const Radius.circular(3.0),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingStaff != null ? 'スタッフ編集' : 'スタッフ追加',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        // 編集モードの場合のみ紐付け状態を表示
                        if (widget.existingStaff != null) ...[
                          _buildLinkStatusCard(),
                          const SizedBox(height: 16),
                        ],
                        // 紐付け済みの場合のみロール選択を表示
                        if (_linkedUser != null && _selectedRole != null) ...[
                          _buildRoleSelectionSection(),
                          const SizedBox(height: 16),
                        ],
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildShiftConstraintsSection(),
                        const SizedBox(height: 24),
                        _buildDaysOffSection(),
                        const SizedBox(height: 24),
                        _buildSpecificDaysOffSection(),
                        const SizedBox(height: 24),
                        _buildPreferredDatesSection(),
                        const SizedBox(height: 24),
                        _buildUnavailableShiftTypesSection(),
                        const SizedBox(height: 24),
                        _buildIndividualConstraintsSection(),
                      ],
                    ),
                  ),
                ),
              ),
              // 固定のアクションボタン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: const Border(
                    top: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkStatusCard() {
    final isLinked = widget.existingStaff?.userId != null;

    return Card(
      color: isLinked ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isLinked ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isLinked ? Colors.green : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLinked ? 'アプリ利用中' : 'アプリ未登録',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isLinked ? Colors.green.shade900 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLinked ? 'このスタッフはアプリアカウントと紐付いています' : 'メールアドレスを入力すると、同じメールアドレスでアカウント作成した時に自動紐付き',
                    style: TextStyle(
                      fontSize: 12,
                      color: isLinked ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '権限設定',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'このスタッフの権限を選択してください',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.admin,
                  label: Text('管理者'),
                  icon: Icon(Icons.admin_panel_settings),
                ),
                ButtonSegment(
                  value: UserRole.member,
                  label: Text('スタッフ'),
                  icon: Icon(Icons.person),
                ),
              ],
              selected: {_selectedRole!},
              onSelectionChanged: (Set<UserRole> newSelection) {
                setState(() {
                  _selectedRole = newSelection.first;
                });
              },
            ),
            // 唯一の管理者を降格させようとした場合の警告
            if (_isLastAdmin && _selectedRole == UserRole.member) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '唯一の管理者を降格させることはできません。先に他のスタッフを管理者に昇格させてください。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ロール変更の説明
            if (_linkedUser?.role != _selectedRole) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedRole == UserRole.admin) ...[
                      Text(
                        '管理者に昇格',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• シフト編集・自動生成が可能になります\n• スタッフ管理が可能になります\n• 設定変更が可能になります',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ] else ...[
                      Text(
                        'スタッフに降格',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• シフト閲覧のみになります\n• スタッフ管理ができなくなります\n• 設定変更ができなくなります',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本情報',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名前',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '名前を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '電話番号（任意）',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス（任意）',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // メールアドレス形式チェック
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return '正しいメールアドレスを入力してください';
                  }

                  // チーム内での重複チェック
                  final staffProvider = Provider.of<StaffProvider>(context, listen: false);
                  final duplicateStaff = staffProvider.staffList.where((staff) {
                    // 編集モードの場合は自分自身を除外
                    if (widget.existingStaff != null && staff.id == widget.existingStaff!.id) {
                      return false;
                    }
                    // メールアドレスが一致するスタッフを検索
                    return staff.email != null && staff.email!.toLowerCase() == value.toLowerCase();
                  }).toList();

                  if (duplicateStaff.isNotEmpty) {
                    return '${duplicateStaff.first.name}と同じメールアドレスです';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftConstraintsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'シフト制約',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxShiftsController,
              decoration: const InputDecoration(
                labelText: '月間最大シフト数',
                prefixIcon: Icon(Icons.event_repeat),
                border: OutlineInputBorder(),
                suffixText: '回',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '月間最大シフト数を入力してください';
                }
                final num = int.tryParse(value);
                if (num == null || num < 0 || num > 31) {
                  return '0〜31の範囲で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '※ 0にすると自動割り当ての対象外（手動では追加可能）',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysOffSection() {
    const dayNames = ['月', '火', '水', '木', '金', '土', '日'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '休み希望曜日',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '定期的に休みを希望する曜日を選択',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayNumber = index + 1;
                final isSelected = _selectedDaysOff.contains(dayNumber);

                return SizedBox(
                  width: 80, // 全てのチップを同じ幅に統一
                  child: FilterChip(
                    label: Center(
                      child: Text(
                        dayNames[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDaysOff.add(dayNumber);
                        } else {
                          _selectedDaysOff.remove(dayNumber);
                        }
                      });
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _holidaysOff,
              onChanged: (value) {
                setState(() {
                  _holidaysOff = value ?? false;
                });
              },
              title: const Text(
                '祝日を休み希望とする',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificDaysOffSection() {
    // 日付順にソート
    _specificDaysOff.sort((a, b) => a.compareTo(b));

    // 今月の最初の日を取得
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    // 表示する日付をフィルタリング
    final displayDaysOff =
        _showPastDaysOff ? _specificDaysOff : _specificDaysOff.where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1)))).toList();

    // 過去の休み希望日の件数
    final pastCount = _specificDaysOff.where((date) => date.isBefore(firstDayOfCurrentMonth)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '休み希望日（特定日）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '特定の日付で休みを希望する日を追加',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showSpecificDaysOffDialog,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('設定'),
                ),
              ],
            ),
            if (pastCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _showPastDaysOff,
                    onChanged: (value) {
                      setState(() {
                        _showPastDaysOff = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      '過去の休み希望日も表示（${pastCount}件）',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (displayDaysOff.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayDaysOff.map((date) {
                  final isPast = date.isBefore(firstDayOfCurrentMonth);
                  return Chip(
                    label: Text(
                      DateFormat('M/d(E)', 'ja').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPast ? Colors.grey : null,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    backgroundColor: isPast ? Colors.grey.shade200 : null,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _specificDaysOff.remove(date);
                      });
                    },
                  );
                }).toList(),
              ),
            ] else if (_specificDaysOff.isEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '登録されていません',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '今月以降の休み希望日はありません',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferredDatesSection() {
    // 日付順にソート
    _preferredDates.sort((a, b) => a.compareTo(b));

    // 今月の最初の日を取得
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    // 表示する日付をフィルタリング
    final displayPreferredDates = _showPastPreferredDates
        ? _preferredDates
        : _preferredDates.where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1)))).toList();

    // 過去の勤務希望日の件数
    final pastCount = _preferredDates.where((date) => date.isBefore(firstDayOfCurrentMonth)).length;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '勤務希望日',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.blue.shade900,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'シフトに入りたい日を設定',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showPreferredDatesDialog,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('設定'),
                ),
              ],
            ),
            if (pastCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _showPastPreferredDates,
                    onChanged: (value) {
                      setState(() {
                        _showPastPreferredDates = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      '過去の勤務希望日も表示（${pastCount}件）',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (displayPreferredDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayPreferredDates.map((date) {
                  final isPast = date.isBefore(firstDayOfCurrentMonth);
                  return Chip(
                    label: Text(
                      DateFormat('M/d(E)', 'ja').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPast ? Colors.grey : Colors.blue.shade900,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    backgroundColor: isPast ? Colors.grey.shade200 : Colors.blue.shade100,
                    side: BorderSide.none,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _preferredDates.remove(date);
                      });
                    },
                  );
                }).toList(),
              ),
            ] else if (_preferredDates.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '設定されていません',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                '今月以降の勤務希望日はありません',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSpecificDaysOffDialog() async {
    final result = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) => _SpecificDaysOffDialog(
        initialDates: _specificDaysOff,
      ),
    );

    if (result != null) {
      setState(() {
        _specificDaysOff = result;
      });
    }
  }

  Future<void> _showPreferredDatesDialog() async {
    final result = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) => _PreferredDatesDialog(
        initialDates: _preferredDates,
        unavailableDaysOff: _selectedDaysOff,
        specificDaysOff: _specificDaysOff,
        holidaysOff: _holidaysOff,
      ),
    );

    if (result != null) {
      setState(() {
        _preferredDates = result;
      });
    }
  }

  Widget _buildUnavailableShiftTypesSection() {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final activeShiftTypes = shiftTimeProvider.settings.where((setting) => setting.isActive).map((setting) => setting.displayName).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '勤務不可シフトタイプ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '勤務できないシフトタイプを選択',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeShiftTypes.map((type) {
                final isSelected = _unavailableShiftTypes.contains(type);
                return SizedBox(
                  width: 100, // 固定幅
                  child: FilterChip(
                    label: Center(
                      child: Text(
                        type,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _unavailableShiftTypes.add(type);
                        } else {
                          _unavailableShiftTypes.remove(type);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualConstraintsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.purple.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '個別制約設定',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'チーム設定より優先される個別の制約を設定',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // 連続勤務日数上限
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _useCustomMaxConsecutiveDays ? Colors.purple.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _useCustomMaxConsecutiveDays,
                          onChanged: (value) {
                            setState(() {
                              _useCustomMaxConsecutiveDays = value ?? false;
                              if (!_useCustomMaxConsecutiveDays) {
                                _maxConsecutiveDays = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '連続勤務日数上限を個別に設定',
                          style: TextStyle(
                            fontSize: 14,
                            color: _useCustomMaxConsecutiveDays ? Colors.purple.shade900 : Colors.grey.shade700,
                            fontWeight: _useCustomMaxConsecutiveDays ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_useCustomMaxConsecutiveDays) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: _maxConsecutiveDays?.toString() ?? '',
                            decoration: const InputDecoration(
                              hintText: '',
                              suffixText: '日',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              setState(() {
                                _maxConsecutiveDays = value.isEmpty ? null : int.tryParse(value);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'まで連続勤務可能',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 勤務間インターバル
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _useCustomMinRestHours ? Colors.purple.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _useCustomMinRestHours,
                          onChanged: (value) {
                            setState(() {
                              _useCustomMinRestHours = value ?? false;
                              if (!_useCustomMinRestHours) {
                                _minRestHours = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '勤務間インターバルを個別に設定',
                          style: TextStyle(
                            fontSize: 14,
                            color: _useCustomMinRestHours ? Colors.purple.shade900 : Colors.grey.shade700,
                            fontWeight: _useCustomMinRestHours ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_useCustomMinRestHours) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: _minRestHours?.toString() ?? '',
                            decoration: const InputDecoration(
                              hintText: '',
                              suffixText: '時間',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              setState(() {
                                _minRestHours = value.isEmpty ? null : int.tryParse(value);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '以上空ける',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.purple.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '責任者などが他のスタッフより柔軟に勤務できるように設定できます',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('キャンセル'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: _handleSave,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // 唯一の管理者を降格させようとした場合はエラー
    if (_isLastAdmin && _selectedRole == UserRole.member) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('唯一の管理者を降格させることはできません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final staffProvider = context.read<StaffProvider>();

    if (widget.existingStaff != null) {
      // 編集モード
      final updatedStaff = Staff(
        id: widget.existingStaff!.id,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        maxShiftsPerMonth: int.parse(_maxShiftsController.text),
        preferredDaysOff: List.from(_selectedDaysOff),
        unavailableShiftTypes: List.from(_unavailableShiftTypes),
        specificDaysOff: _specificDaysOff.map((date) => DateTime(date.year, date.month, date.day).toIso8601String()).toList(),
        preferredDates: _preferredDates.map((date) => DateTime(date.year, date.month, date.day).toIso8601String()).toList(),
        holidaysOff: _holidaysOff,
        isActive: widget.existingStaff!.isActive,
        createdAt: widget.existingStaff!.createdAt,
        userId: widget.existingStaff!.userId,
        maxConsecutiveDays: _useCustomMaxConsecutiveDays ? _maxConsecutiveDays : null,
        minRestHours: _useCustomMinRestHours ? _minRestHours : null,
      );

      // ロール変更がある場合、確認ダイアログを表示
      if (_linkedUser != null && _selectedRole != null && _linkedUser!.role != _selectedRole) {
        final confirmed = await _showRoleChangeConfirmationDialog();
        if (!confirmed) return;
      }

      // スタッフ情報を更新
      await staffProvider.updateStaff(updatedStaff);

      // 勤務希望日が設定されている場合はAnalyticsイベントを送信
      if (_preferredDates.isNotEmpty) {
        try {
          await AnalyticsService.logPreferredDatesSet(count: _preferredDates.length);
        } catch (_) {
          // Analyticsエラーは無視
        }
      }

      // ロール変更がある場合、AuthServiceで更新
      bool isSelfRoleChange = false;
      if (_linkedUser != null && _selectedRole != null && _linkedUser!.role != _selectedRole) {
        try {
          final authService = AuthService();
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          // 自分自身のロール変更かチェック
          isSelfRoleChange = (_linkedUser!.uid == currentUserId);

          await authService.updateUserRole(
            userId: _linkedUser!.uid,
            teamId: _linkedUser!.teamId!,
            newRole: _selectedRole!,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ロール変更に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      // 自分自身のロールを変更した場合は再ログインを促す
      if (isSelfRoleChange) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('ロール変更完了'),
            content: const Text(
              '自分のロールが変更されました。\n'
              '変更を反映するため、再度ログインしてください。',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // ログアウト処理
                  final authService = AuthService();
                  await authService.signOut();
                  // AuthGateに戻る（自動的にログイン画面に遷移）
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (route) => false,
                  );
                },
                child: const Text('ログアウト'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedStaff.name}の情報を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // 追加モード
      final staff = Staff(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        maxShiftsPerMonth: int.parse(_maxShiftsController.text),
        preferredDaysOff: List.from(_selectedDaysOff),
        unavailableShiftTypes: List.from(_unavailableShiftTypes),
        specificDaysOff: _specificDaysOff.map((date) => DateTime(date.year, date.month, date.day).toIso8601String()).toList(),
        preferredDates: _preferredDates.map((date) => DateTime(date.year, date.month, date.day).toIso8601String()).toList(),
        holidaysOff: _holidaysOff,
        isActive: true,
        createdAt: DateTime.now(),
        maxConsecutiveDays: _useCustomMaxConsecutiveDays ? _maxConsecutiveDays : null,
        minRestHours: _useCustomMinRestHours ? _minRestHours : null,
      );

      await staffProvider.addStaff(staff);

      // 勤務希望日が設定されている場合はAnalyticsイベントを送信
      if (_preferredDates.isNotEmpty) {
        try {
          await AnalyticsService.logPreferredDatesSet(count: _preferredDates.length);
        } catch (_) {
          // Analyticsエラーは無視
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${staff.name}を追加しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// ロール変更確認ダイアログ
  Future<bool> _showRoleChangeConfirmationDialog() async {
    final isUpgrading = _selectedRole == UserRole.admin;
    final staffName = widget.existingStaff?.name ?? 'このスタッフ';

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isUpgrading ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isUpgrading ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(isUpgrading ? '管理者に昇格' : 'スタッフに降格'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$staffName の権限を変更します。',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (isUpgrading) ...[
                  const Text('管理者になると以下の操作が可能になります：'),
                  const SizedBox(height: 8),
                  _buildPermissionItem(Icons.edit_calendar, 'シフトの編集・自動生成'),
                  _buildPermissionItem(Icons.group, 'スタッフ管理'),
                  _buildPermissionItem(Icons.settings, '各種設定の変更'),
                ] else ...[
                  const Text('スタッフになると以下の操作ができなくなります：'),
                  const SizedBox(height: 8),
                  _buildPermissionItem(Icons.edit_calendar, 'シフトの編集・自動生成'),
                  _buildPermissionItem(Icons.group, 'スタッフ管理'),
                  _buildPermissionItem(Icons.settings, '各種設定の変更'),
                  const SizedBox(height: 12),
                  const Text(
                    'シフトの閲覧と自分の休み希望入力のみ可能になります。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(isUpgrading ? '昇格する' : '降格する'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildPermissionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 勤務希望日選択ダイアログ
class _PreferredDatesDialog extends StatefulWidget {
  final List<DateTime> initialDates;
  final List<int> unavailableDaysOff; // 勤務不可曜日
  final List<DateTime> specificDaysOff; // 勤務不可日
  final bool holidaysOff; // 祝日を休み希望とするか

  const _PreferredDatesDialog({
    required this.initialDates,
    required this.unavailableDaysOff,
    required this.specificDaysOff,
    required this.holidaysOff,
  });

  @override
  State<_PreferredDatesDialog> createState() => _PreferredDatesDialogState();
}

class _PreferredDatesDialogState extends State<_PreferredDatesDialog> {
  late List<DateTime> _selectedDates;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDates = List.from(widget.initialDates);
  }

  /// 日付が勤務不可日かどうかをチェック
  bool _isUnavailableDate(DateTime date) {
    // 勤務不可曜日チェック（1=月曜, 7=日曜）
    final weekday = date.weekday;
    if (widget.unavailableDaysOff.contains(weekday)) {
      return true;
    }

    // 勤務不可日チェック
    for (final offDate in widget.specificDaysOff) {
      if (offDate.year == date.year && offDate.month == date.month && offDate.day == date.day) {
        return true;
      }
    }

    return false;
  }

  /// 日付が選択されているかどうかをチェック
  bool _isSelectedDate(DateTime date) {
    return _selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
  }

  /// 日付の選択/解除
  void _toggleDate(DateTime date) {
    setState(() {
      if (_isSelectedDate(date)) {
        _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      } else {
        _selectedDates.add(DateTime(date.year, date.month, date.day));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '勤務希望日の設定',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'シフトに入りたい日をタップして選択',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // カレンダー
            _buildCalendar(),

            // 凡例
            const SizedBox(height: 16),
            _buildLegend(),

            // 選択中の日付
            if (_selectedDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSelectedDates(),
            ],

            // ボタン
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedDates),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year + 1, now.month, 0);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 月切り替えヘッダー
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                      if (_focusedDay.isBefore(firstDay)) {
                        _focusedDay = firstDay;
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat('yyyy年M月', 'ja').format(_focusedDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                      if (_focusedDay.isAfter(lastDay)) {
                        _focusedDay = lastDay;
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // 曜日ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['日', '月', '火', '水', '木', '金', '土'].map((day) {
                final isWeekend = day == '日' || day == '土';
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isWeekend ? Colors.red.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 日付グリッド
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 日曜を0に

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    List<Widget> rows = [];
    List<Widget> currentRow = [];

    // 前月の空白
    for (int i = 0; i < firstWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }

    // 日付
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      final isToday = date.year == todayOnly.year && date.month == todayOnly.month && date.day == todayOnly.day;
      final isPast = date.isBefore(todayOnly);
      final isUnavailable = _isUnavailableDate(date);
      final isSelected = _isSelectedDate(date);
      final isWeekend = date.weekday == DateTime.sunday || date.weekday == DateTime.saturday;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: (isPast || isUnavailable) ? null : () => _toggleDate(date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade400
                    : isUnavailable
                        ? Colors.grey.shade200
                        : null,
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: Colors.blue.shade700, width: 2) : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : isPast
                            ? Colors.grey.shade400
                            : isUnavailable
                                ? Colors.grey.shade500
                                : isWeekend
                                    ? Colors.red.shade400
                                    : Colors.black87,
                    decoration: isUnavailable ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    // 最後の行の空白を埋める
    while (currentRow.isNotEmpty && currentRow.length < 7) {
      currentRow.add(const Expanded(child: SizedBox()));
    }
    if (currentRow.isNotEmpty) {
      rows.add(Row(children: currentRow));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(children: rows),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.blue.shade400, '希望日'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.grey.shade300, '勤務不可'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSelectedDates() {
    final sortedDates = List<DateTime>.from(_selectedDates)..sort((a, b) => a.compareTo(b));
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    // 今月以降のみ表示
    final displayDates = sortedDates.where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1)))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選択中: ${displayDates.length}日',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: displayDates.map((date) {
            return Chip(
              label: Text(
                DateFormat('M/d(E)', 'ja').format(date),
                style: const TextStyle(fontSize: 11),
              ),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => _toggleDate(date),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 休み希望日（特定日）選択ダイアログ
class _SpecificDaysOffDialog extends StatefulWidget {
  final List<DateTime> initialDates;

  const _SpecificDaysOffDialog({
    required this.initialDates,
  });

  @override
  State<_SpecificDaysOffDialog> createState() => _SpecificDaysOffDialogState();
}

class _SpecificDaysOffDialogState extends State<_SpecificDaysOffDialog> {
  late List<DateTime> _selectedDates;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDates = List.from(widget.initialDates);
  }

  /// 日付が選択されているかどうかをチェック
  bool _isSelectedDate(DateTime date) {
    return _selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
  }

  /// 日付の選択/解除
  void _toggleDate(DateTime date) {
    setState(() {
      if (_isSelectedDate(date)) {
        _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      } else {
        _selectedDates.add(DateTime(date.year, date.month, date.day));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(Icons.event_busy, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '休み希望日の設定',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orange.shade900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '休みを希望する日をタップして選択',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // カレンダー
            _buildCalendar(),

            // 凡例
            const SizedBox(height: 16),
            _buildLegend(),

            // 選択中の日付
            if (_selectedDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSelectedDates(),
            ],

            // ボタン
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedDates),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year + 1, now.month, 0);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 月切り替えヘッダー
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                      if (_focusedDay.isBefore(firstDay)) {
                        _focusedDay = firstDay;
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat('yyyy年M月', 'ja').format(_focusedDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                      if (_focusedDay.isAfter(lastDay)) {
                        _focusedDay = lastDay;
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // 曜日ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['日', '月', '火', '水', '木', '金', '土'].map((day) {
                final isWeekend = day == '日' || day == '土';
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isWeekend ? Colors.red.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 日付グリッド
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 日曜を0に

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    List<Widget> rows = [];
    List<Widget> currentRow = [];

    // 前月の空白
    for (int i = 0; i < firstWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }

    // 日付
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      final isToday = date.year == todayOnly.year && date.month == todayOnly.month && date.day == todayOnly.day;
      final isPast = date.isBefore(todayOnly);
      final isSelected = _isSelectedDate(date);
      final isWeekend = date.weekday == DateTime.sunday || date.weekday == DateTime.saturday;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: isPast ? null : () => _toggleDate(date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange.shade400 : null,
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: Colors.orange.shade700, width: 2) : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : isPast
                            ? Colors.grey.shade400
                            : isWeekend
                                ? Colors.red.shade400
                                : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    // 最後の行の空白を埋める
    while (currentRow.isNotEmpty && currentRow.length < 7) {
      currentRow.add(const Expanded(child: SizedBox()));
    }
    if (currentRow.isNotEmpty) {
      rows.add(Row(children: currentRow));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(children: rows),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.orange.shade400, '休み希望日'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSelectedDates() {
    final sortedDates = List<DateTime>.from(_selectedDates)..sort((a, b) => a.compareTo(b));
    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);

    // 今月以降のみ表示
    final displayDates = sortedDates.where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1)))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選択中: ${displayDates.length}日',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: displayDates.map((date) {
            return Chip(
              label: Text(
                DateFormat('M/d(E)', 'ja').format(date),
                style: const TextStyle(fontSize: 11),
              ),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => _toggleDate(date),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}
