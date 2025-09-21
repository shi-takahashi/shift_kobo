import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/staff_provider.dart';
import '../models/staff.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
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
        Expanded(
          child: Consumer<StaffProvider>(
            builder: (context, staffProvider, child) {
              final staffList = _searchQuery.isEmpty
                  ? staffProvider.staffList
                  : staffProvider.searchStaff(_searchQuery);

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

              return ListView.builder(
                itemCount: staffList.length,
                itemBuilder: (context, index) {
                  final staff = staffList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: staff.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        child: Text(
                          staff.name.substring(0, 1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        staff.name,
                        style: TextStyle(
                          decoration: staff.isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (staff.phoneNumber != null)
                            Text('📞 ${staff.phoneNumber}'),
                          Text('月間最大シフト: ${staff.maxShiftsPerMonth}回'),
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
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action, Staff staff) {
    final staffProvider = context.read<StaffProvider>();

    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('編集機能は準備中です')),
        );
        break;
      case 'toggle':
        staffProvider.toggleStaffStatus(staff.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              staff.isActive
                  ? '${staff.name}を無効化しました'
                  : '${staff.name}を有効化しました',
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