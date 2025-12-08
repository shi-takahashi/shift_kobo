import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/constraint_request_provider.dart';
import '../models/staff.dart';
import '../models/app_user.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../widgets/staff_edit_dialog.dart';
import 'approval/constraint_approval_screen.dart';

class StaffListScreen extends StatefulWidget {
  final AppUser appUser;

  const StaffListScreen({
    super.key,
    required this.appUser,
  });

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  @override
  void initState() {
    super.initState();
    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('staff_list_screen');
  }

  String _getDayOffText(List<int> daysOff) {
    const dayNames = ['月', '火', '水', '木', '金', '土', '日'];
    return daysOff.map((day) => dayNames[day - 1]).join('・');
  }

  Widget _buildConstraintsText(Staff staff) {
    List<String> constraints = [];
    
    // 月間最大シフト数
    constraints.add('月間最大: ${staff.maxShiftsPerMonth}回');
    
    // 休み希望（曜日）
    if (staff.preferredDaysOff.isNotEmpty) {
      constraints.add('休み希望: ${_getDayOffText(staff.preferredDaysOff)}');
    }
    
    // 勤務不可シフトタイプ
    if (staff.unavailableShiftTypes.isNotEmpty) {
      constraints.add('不可: ${staff.unavailableShiftTypes.join('・')}');
    }
    
    return Text(
      constraints.join(' / '),
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'スタッフを検索...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        // 承認待ちバナー
        Consumer<ConstraintRequestProvider>(
          builder: (context, requestProvider, child) {
            final pendingCount = requestProvider.pendingRequests.length;

            if (pendingCount == 0) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Material(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    final constraintRequestProvider = context.read<ConstraintRequestProvider>();
                    final staffProvider = context.read<StaffProvider>();
                    final shiftProvider = context.read<ShiftProvider>();
                    final shiftTimeProvider = context.read<ShiftTimeProvider>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (newContext) => MultiProvider(
                          providers: [
                            ChangeNotifierProvider<ConstraintRequestProvider>.value(value: constraintRequestProvider),
                            ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
                            ChangeNotifierProvider<ShiftProvider>.value(value: shiftProvider),
                            ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
                          ],
                          child: ConstraintApprovalScreen(appUser: widget.appUser),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.approval,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '承認待ち ($pendingCount件)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'タップして確認',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Consumer<StaffProvider>(
              builder: (context, staffProvider, child) {
                var staffList = _searchQuery.isEmpty
                    ? staffProvider.staffList
                    : staffProvider.searchStaff(_searchQuery);
                
                // 有効なスタッフを上に、無効なスタッフを下に並べる
                staffList.sort((a, b) {
                  if (a.isActive && !b.isActive) return -1;
                  if (!a.isActive && b.isActive) return 1;
                  return a.name.compareTo(b.name);
                });

                if (staffList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'スタッフが登録されていません'
                              : '検索結果がありません',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Scrollbar(
                  thumbVisibility: true,
                  thickness: 6.0,
                  radius: const Radius.circular(3.0),
                  child: ListView.builder(
                    itemCount: staffList.length,
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          onTap: () {
                            // スタッフタップで編集画面起動
                            final shiftTimeProvider = context.read<ShiftTimeProvider>();
                            final staffProvider = context.read<StaffProvider>();
                            showDialog(
                              context: context,
                              useRootNavigator: false,
                              builder: (dialogContext) => MultiProvider(
                                providers: [
                                  ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
                                  ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
                                ],
                                child: StaffEditDialog(existingStaff: staff),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: staff.isActive
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            child: Text(
                              staff.name.isNotEmpty ? staff.name.substring(0, 1) : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            staff.name.isNotEmpty ? staff.name : '(名前未入力)',
                            style: TextStyle(
                              decoration: staff.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                              fontStyle: staff.name.isEmpty ? FontStyle.italic : null,
                              color: staff.name.isEmpty ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 紐付け状態バッジ
                              Row(
                                children: [
                                  Icon(
                                    staff.userId != null
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: staff.userId != null
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    staff.userId != null ? 'アプリ利用中' : 'アプリ未登録',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: staff.userId != null
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (staff.phoneNumber != null)
                                Text('📞 ${staff.phoneNumber}'),
                              const SizedBox(height: 4),
                              _buildConstraintsText(staff),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              _handleMenuAction(value, staff);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('編集'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(staff.isActive
                                        ? Icons.person_off
                                        : Icons.person),
                                    const SizedBox(width: 8),
                                    Text(staff.isActive ? '無効化' : '有効化'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('削除', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        // スタッフ追加ボタン
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final shiftTimeProvider = context.read<ShiftTimeProvider>();
                final staffProvider = context.read<StaffProvider>();
                showDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (dialogContext) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
                      ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
                    ],
                    child: const StaffEditDialog(),
                  ),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('スタッフを追加'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action, Staff staff) {
    final staffProvider = context.read<StaffProvider>();

    switch (action) {
      case 'edit':
        final shiftTimeProvider = context.read<ShiftTimeProvider>();
        final localStaffProvider = context.read<StaffProvider>();
        showDialog(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) => MultiProvider(
            providers: [
              ChangeNotifierProvider<ShiftTimeProvider>.value(value: shiftTimeProvider),
              ChangeNotifierProvider<StaffProvider>.value(value: localStaffProvider),
            ],
            child: StaffEditDialog(existingStaff: staff),
          ),
        );
        break;
      case 'toggle':
        staffProvider.toggleStaffStatus(staff.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              staff.isActive
                  ? '${staff.name}を有効化しました'
                  : '${staff.name}を無効化しました',
            ),
          ),
        );
        break;
      case 'delete':
        _showDeleteStaffDialog(staff);
        break;
    }
  }

  /// スタッフ削除ダイアログ
  void _showDeleteStaffDialog(Staff staff) {
    // Provider を引き継ぐために、現在のスコープから Provider を取得
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final constraintRequestProvider = Provider.of<ConstraintRequestProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<StaffProvider>.value(value: staffProvider),
          ChangeNotifierProvider<ConstraintRequestProvider>.value(value: constraintRequestProvider),
        ],
        child: _DeleteStaffDialog(staff: staff),
      ),
    );
  }
}

/// スタッフ削除確認ダイアログ（StatefulWidget）
class _DeleteStaffDialog extends StatefulWidget {
  final Staff staff;

  const _DeleteStaffDialog({required this.staff});

  @override
  State<_DeleteStaffDialog> createState() => _DeleteStaffDialogState();
}

class _DeleteStaffDialogState extends State<_DeleteStaffDialog> {
  @override
  Widget build(BuildContext context) {
    final hasAccount = widget.staff.userId != null;

    return AlertDialog(
      title: const Text('削除確認'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${widget.staff.name}」を削除しますか？'),
            const SizedBox(height: 16),

            // 紐付け済みスタッフの場合は警告を表示
            if (hasAccount) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '以下のデータが削除されます：',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• ログイン情報（メールアドレス・パスワード）\n'
                            '• 休み希望の申請データ\n'
                            '• スタッフ登録データ',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'このスタッフはアプリにログインできなくなります。',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          onPressed: () => _performDelete(context),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('削除'),
        ),
      ],
    );
  }

  /// 削除処理を実行
  Future<void> _performDelete(BuildContext context) async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final staffProvider = Provider.of<StaffProvider>(context, listen: false);

      if (widget.staff.userId != null) {
        // 紐付け済みスタッフの場合：アカウントごと削除
        final constraintRequestProvider = Provider.of<ConstraintRequestProvider>(context, listen: false);
        final authService = AuthService();

        await staffProvider.deleteStaffWithAccount(
          widget.staff.id,
          deleteRequestsByStaffId: constraintRequestProvider.deleteRequestsByStaffId,
          deleteStaffAccount: authService.deleteStaffAccount,
        );
      } else {
        // 紐付けなしスタッフの場合：スタッフデータのみ削除
        await staffProvider.deleteStaff(widget.staff.id);
      }

      if (!mounted) return;

      // ローディングを閉じる
      Navigator.pop(context);
      // 削除ダイアログを閉じる
      Navigator.pop(context);

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.staff.name}を削除しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // ローディングを閉じる
      try {
        Navigator.pop(context);
      } catch (_) {}

      // エラーメッセージ
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('エラー'),
          content: Text('削除に失敗しました: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }
}