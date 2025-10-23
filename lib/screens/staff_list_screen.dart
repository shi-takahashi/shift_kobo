import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/constraint_request_provider.dart';
import '../models/staff.dart';
import '../models/app_user.dart';
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('削除確認'),
            content: Text('${staff.name}を削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  staffProvider.deleteStaff(staff.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${staff.name}を削除しました')),
                  );
                },
                child: const Text('削除'),
              ),
            ],
          ),
        );
        break;
    }
  }
}