import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_time_provider.dart';
import '../models/staff.dart';
import '../models/app_user.dart';
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
  bool _showPastDaysOff = false; // 過去の休み希望日を表示するか

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
      _specificDaysOff = widget.existingStaff!.specificDaysOff
          .map((dateStr) => DateTime.parse(dateStr))
          .toList();

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
                        if (widget.existingStaff != null)
                          ...[
                            _buildLinkStatusCard(),
                            const SizedBox(height: 16),
                          ],
                        // 紐付け済みの場合のみロール選択を表示
                        if (_linkedUser != null && _selectedRole != null)
                          ...[
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
                        _buildUnavailableShiftTypesSection(),
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
                    isLinked
                        ? 'このスタッフはアプリアカウントと紐付いています'
                        : 'メールアドレスを入力すると、同じメールアドレスでアカウント作成した時に自動紐付き',
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
                    return staff.email != null &&
                           staff.email!.toLowerCase() == value.toLowerCase();
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
    final displayDaysOff = _showPastDaysOff
        ? _specificDaysOff
        : _specificDaysOff.where((date) => date.isAfter(firstDayOfCurrentMonth.subtract(const Duration(days: 1)))).toList();

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
                IconButton.filled(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('ja'),
                    );

                    if (selectedDate != null) {
                      setState(() {
                        // 日付のみを保存（時刻は00:00:00）
                        final dateOnly = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                        );
                        if (!_specificDaysOff.any((d) =>
                            d.year == dateOnly.year &&
                            d.month == dateOnly.month &&
                            d.day == dateOnly.day)) {
                          _specificDaysOff.add(dateOnly);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: '休み希望日を追加',
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
                      DateFormat('yyyy/MM/dd(E)', 'ja').format(date),
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

  Widget _buildUnavailableShiftTypesSection() {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final activeShiftTypes = shiftTimeProvider.settings
        .where((setting) => setting.isActive)
        .map((setting) => setting.displayName)
        .toList();

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
        specificDaysOff: _specificDaysOff.map((date) =>
          DateTime(date.year, date.month, date.day).toIso8601String()
        ).toList(),
        isActive: widget.existingStaff!.isActive,
        createdAt: widget.existingStaff!.createdAt,
        userId: widget.existingStaff!.userId,
      );

      // ロール変更がある場合、確認ダイアログを表示
      if (_linkedUser != null && _selectedRole != null && _linkedUser!.role != _selectedRole) {
        final confirmed = await _showRoleChangeConfirmationDialog();
        if (!confirmed) return;
      }

      // スタッフ情報を更新
      await staffProvider.updateStaff(updatedStaff);

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
        specificDaysOff: _specificDaysOff.map((date) =>
          DateTime(date.year, date.month, date.day).toIso8601String()
        ).toList(),
        isActive: true,
        createdAt: DateTime.now(),
      );

      await staffProvider.addStaff(staff);

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
    ) ?? false;
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