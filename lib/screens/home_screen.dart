import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_screen.dart';
import 'staff_list_screen.dart';
import 'settings_screen.dart';
import '../widgets/auto_assignment_dialog.dart';
import '../widgets/banner_ad_widget.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/monthly_requirements_provider.dart';

class HomeScreen extends StatefulWidget {
  final String teamId;
  final bool showWelcomeDialog;

  const HomeScreen({
    super.key,
    required this.teamId,
    this.showWelcomeDialog = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasShownFirstTimeHelp = false;

  final List<Widget> _screens = [
    const CalendarScreen(),
    const StaffListScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = [
    'シフト表',
    'スタッフ管理',
    '設定',
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstTimeHelp();
  }

  /// 初回起動チェック及び自動ヘルプ表示
  Future<void> _checkFirstTimeHelp() async {
    // チーム作成直後の場合は、必ずウェルカムダイアログを表示
    if (widget.showWelcomeDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasShownFirstTimeHelp) {
          _hasShownFirstTimeHelp = true;
          _showHelpDialog(isFirstTime: true);
        }
      });
      return;
    }

    // 通常の初回起動チェック（チーム作成を経由していない場合）
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHelp = prefs.getBool('has_seen_first_time_help') ?? false;

    if (!hasSeenHelp && mounted) {
      // 画面描画完了後にヘルプを表示
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasShownFirstTimeHelp) {
          _hasShownFirstTimeHelp = true;
          _showHelpDialog(isFirstTime: true);
        }
      });
    }
  }

  /// 初回起動フラグを保存
  Future<void> _markFirstTimeHelpSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_first_time_help', true);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StaffProvider(teamId: widget.teamId)),
        ChangeNotifierProvider(create: (_) => ShiftProvider(teamId: widget.teamId)),
        ChangeNotifierProvider(create: (_) => ShiftTimeProvider(teamId: widget.teamId)),
        ChangeNotifierProvider(create: (_) => MonthlyRequirementsProvider(teamId: widget.teamId)),
      ],
      child: Consumer4<StaffProvider, ShiftProvider, ShiftTimeProvider, MonthlyRequirementsProvider>(
        builder: (context, staffProvider, shiftProvider, shiftTimeProvider, monthlyProvider, child) {
          // すべてのProviderのデータロード完了を待つ
          final isLoading = staffProvider.isLoading ||
              shiftProvider.isLoading ||
              shiftTimeProvider.isLoading ||
              monthlyProvider.isLoading;

          if (isLoading) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'データを読み込み中...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: Text(_titles[_selectedIndex], style: const TextStyle(fontSize: 18)),
              toolbarHeight: 48, // デフォルト56 → 48に縮小
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 22),
              onPressed: () {
                _showHelpDialog(isFirstTime: false);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _screens[_selectedIndex],
            ),
            // バナー広告
            const BannerAdWidget(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
        height: 65, // デフォルト80 → 65に縮小
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.calendar_month, size: 22),
            label: 'シフト',
          ),
          NavigationDestination(
            icon: Icon(Icons.people, size: 22),
            label: 'スタッフ',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings, size: 22),
            label: '設定',
          ),
        ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
          );
        },
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return null;
  }

  void _showAutoGenerateDialog() {
    showDialog<bool>(
      context: context,
      builder: (context) => AutoAssignmentDialog(
        selectedMonth: DateTime.now(),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {});
      }
    });
  }

  void _showHelpDialog({required bool isFirstTime}) {
    showDialog(
      context: context,
      barrierDismissible: !isFirstTime, // 初回時は背景タップで閉じない
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isFirstTime ? Icons.waving_hand : Icons.help_outline,
              color: isFirstTime ? Colors.orange : null,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(isFirstTime ? 'ようこそ！' : '使い方'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFirstTime) ...[
                const Text(
                  'シフト工房へようこそ！\n基本的な使い方をご説明します。',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              const Text('1. スタッフ管理でスタッフを登録'),
              const SizedBox(height: 8),
              const Text('2. カレンダーでシフトを自動作成'),
              const SizedBox(height: 8),
              const Text('3. 必要に応じて手動で調整'),
              const SizedBox(height: 8),
              const Text('4. 完成したシフト表を共有'),
              if (isFirstTime) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 ヒント：右上の？ボタンでいつでもこのヘルプを表示できます。',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isFirstTime) {
                _markFirstTimeHelpSeen();
              }
            },
            child: Text(isFirstTime ? '始める' : '閉じる'),
          ),
        ],
      ),
    );
  }
}