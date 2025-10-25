import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_screen.dart';
import 'help_screen.dart';
import 'my_page_screen.dart';
import 'staff_list_screen.dart';
import 'settings_screen.dart';
import '../models/app_user.dart';
import '../models/announcement.dart';
import '../widgets/auto_assignment_dialog.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/announcement_dialog.dart';
import '../services/announcement_service.dart';
import '../services/notification_service.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/constraint_request_provider.dart';

class HomeScreen extends StatefulWidget {
  final AppUser appUser;
  final bool showWelcomeDialog;

  const HomeScreen({
    super.key,
    required this.appUser,
    this.showWelcomeDialog = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasShownFirstTimeHelp = false;
  bool _hasCheckedInitialTab = false; // 初期タブ選択チェック済みフラグ
  final AnnouncementService _announcementService = AnnouncementService();

  /// 権限に応じてタブ画面を取得
  List<Widget> get _screens {
    if (widget.appUser.isAdmin) {
      // 管理者: マイページ、シフト、スタッフ、設定
      return [
        MyPageScreen(appUser: widget.appUser),
        CalendarScreen(appUser: widget.appUser),
        StaffListScreen(appUser: widget.appUser),
        SettingsScreen(appUser: widget.appUser),
      ];
    } else {
      // スタッフ: マイページ、シフト、設定
      return [
        MyPageScreen(appUser: widget.appUser),
        CalendarScreen(appUser: widget.appUser),
        SettingsScreen(appUser: widget.appUser),
      ];
    }
  }

  /// 権限に応じてタブタイトルを取得
  List<String> get _titles {
    if (widget.appUser.isAdmin) {
      return ['マイページ', 'シフト', 'スタッフ', 'その他'];
    } else {
      return ['マイページ', 'シフト', 'その他'];
    }
  }

  /// 権限に応じてナビゲーション項目を取得
  List<NavigationDestination> _navigationDestinations(int pendingCount) {
    if (widget.appUser.isAdmin) {
      return [
        const NavigationDestination(
          icon: Icon(Icons.person, size: 22),
          label: 'マイページ',
        ),
        const NavigationDestination(
          icon: Icon(Icons.calendar_month, size: 22),
          label: 'シフト',
        ),
        NavigationDestination(
          icon: Badge(
            label: Text('$pendingCount'),
            isLabelVisible: pendingCount > 0,
            child: const Icon(Icons.people, size: 22),
          ),
          label: 'スタッフ',
        ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz, size: 22),
          label: 'その他',
        ),
      ];
    } else {
      return const [
        NavigationDestination(
          icon: Icon(Icons.person, size: 22),
          label: 'マイページ',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month, size: 22),
          label: 'シフト',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz, size: 22),
          label: 'その他',
        ),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirstTimeHelp();
    _initializeFCM();
  }

  /// FCM初期化（アプリ版のみ、初回のみ）
  Future<void> _initializeFCM() async {
    if (kIsWeb) return;

    try {
      // 既に初期化済みかチェック
      final prefs = await SharedPreferences.getInstance();
      final hasInitializedFCM = prefs.getBool('has_initialized_fcm') ?? false;

      if (!hasInitializedFCM) {
        // ログイン成功後、画面が表示された後に通知許可を求める
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await NotificationService.initialize();
          await prefs.setBool('has_initialized_fcm', true);
        });
      }
    } catch (e) {
      debugPrint('⚠️ FCM初期化エラー: $e');
    }
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

  /// お知らせをチェックして表示
  Future<void> _checkAnnouncements() async {
    print('📢 _checkAnnouncements() 呼び出し開始');
    if (!mounted) {
      print('📢 mounted=false のため中断');
      return;
    }

    try {
      // 未読のお知らせを取得
      print('📢 未読お知らせ取得開始...');
      final announcements = await _announcementService.getUnreadAnnouncements(widget.appUser.uid);

      print('📢 取得結果: ${announcements.length}件');

      if (!mounted || announcements.isEmpty) {
        print('📢 表示するお知らせなし（mounted=$mounted, 件数=${announcements.length}）');
        return;
      }

      // 最新のお知らせのみ表示（複数ある場合は最新1件のみ）
      final latestAnnouncement = announcements.first;
      print('📢 お知らせダイアログ表示: ${latestAnnouncement.title}');

      // ダイアログ表示
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AnnouncementDialog(
          announcement: latestAnnouncement,
          onClose: () {
            Navigator.of(context).pop();
          },
        ),
      );

      // 既読マーク
      print('📢 既読マーク実行');
      await _announcementService.markAsRead(widget.appUser.uid, latestAnnouncement.id);
    } catch (e) {
      print('⚠️ お知らせチェックエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamId = widget.appUser.teamId!;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StaffProvider(teamId: teamId)),
        ChangeNotifierProvider(create: (_) => ShiftProvider(teamId: teamId)),
        ChangeNotifierProvider(create: (_) => ShiftTimeProvider(teamId: teamId)),
        ChangeNotifierProvider(create: (_) => MonthlyRequirementsProvider(teamId: teamId)),
        ChangeNotifierProvider(create: (_) => ConstraintRequestProvider(teamId: teamId)),
      ],
      child: Consumer<ConstraintRequestProvider>(
        builder: (context, requestProvider, child) {
          return Consumer4<StaffProvider, ShiftProvider, ShiftTimeProvider, MonthlyRequirementsProvider>(
            builder: (context, staffProvider, shiftProvider, shiftTimeProvider, monthlyProvider, child) {
              // すべてのProviderのデータロード完了を待つ
              final isLoading = staffProvider.isLoading ||
                  shiftProvider.isLoading ||
                  shiftTimeProvider.isLoading ||
                  monthlyProvider.isLoading ||
                  requestProvider.isLoading;

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

          // 初期タブ選択（管理者でスタッフ情報がない場合はシフトタブへ）
          if (!_hasCheckedInitialTab) {
            _hasCheckedInitialTab = true;
            if (widget.appUser.isAdmin) {
              // 管理者の場合、スタッフ情報があるか確認
              final myUid = widget.appUser.uid;
              final myStaff = staffProvider.staff
                  .where((staff) =>
                      (staff.userId != null && staff.userId == myUid) ||
                      (staff.email != null && staff.email!.toLowerCase() == widget.appUser.email.toLowerCase()))
                  .firstOrNull;

              // スタッフ情報がない場合はシフトタブ(index: 1)を初期選択
              if (myStaff == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedIndex = 1; // シフトタブ
                    });
                  }
                });
              }
            }

            // データロード完了後、お知らせをチェック
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAnnouncements();
            });
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
        destinations: _navigationDestinations(requestProvider.pendingRequests.length),
        ),
        floatingActionButton: _buildFloatingActionButton(),
          );
            },
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
    // 初回起動時は簡易的なウェルカムダイアログを表示
    if (isFirstTime) {
      showDialog(
        context: context,
        barrierDismissible: false, // 初回時は背景タップで閉じない
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.waving_hand,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('ようこそ！'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'シフト工房へようこそ！\n基本的な使い方をご説明します。',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('1. スタッフ管理でスタッフを登録'),
                const SizedBox(height: 8),
                const Text('2. カレンダーでシフトを自動作成'),
                const SizedBox(height: 8),
                const Text('3. 必要に応じて手動で調整'),
                const SizedBox(height: 8),
                const Text('4. 完成したシフト表を共有'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 ヒント：右上の？ボタンや「その他」タブからいつでも詳しいヘルプを見られます。',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markFirstTimeHelpSeen();
              },
              child: const Text('始める'),
            ),
          ],
        ),
      );
    } else {
      // 右上の？アイコンからは詳細なヘルプ画面へ遷移
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HelpScreen()),
      );
    }
  }
}