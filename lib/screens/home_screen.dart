import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../providers/constraint_request_provider.dart';
import '../providers/monthly_requirements_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';
import '../providers/staff_provider.dart';
import '../services/announcement_service.dart';
import '../services/notification_service.dart';
import '../widgets/announcement_dialog.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/welcome_dialog.dart';
import 'calendar_screen.dart';
import 'help_screen.dart';
import 'my_page_screen.dart';
import 'settings_screen.dart';
import 'staff_list_screen.dart';
import 'team_settings_screen.dart';

/// ホーム画面のタブ
enum HomeTab {
  myPage, // マイページ
  shift, // シフト
  staff, // スタッフ（管理者のみ）
  teamSettings, // チーム設定（管理者のみ）
  settings, // その他
}

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
  // UI定数
  static const double _appBarHeight = 48.0;
  static const double _navigationBarHeight = 65.0;
  static const double _iconSize = 22.0;

  HomeTab _selectedTab = HomeTab.shift; // デフォルトはシフトタブ
  bool _hasShownFirstTimeHelp = false;
  bool _hasCheckedInitialTab = false; // 初期タブ選択チェック済みフラグ
  final AnnouncementService _announcementService = AnnouncementService();

  /// 表示可能なタブのリストを取得
  List<HomeTab> get _availableTabs {
    final tabs = <HomeTab>[];

    // 匿名ユーザーはマイページを非表示
    if (widget.appUser.email != null) {
      tabs.add(HomeTab.myPage);
    }

    tabs.add(HomeTab.shift);

    // 管理者のみスタッフタブを表示
    if (widget.appUser.isAdmin) {
      tabs.add(HomeTab.staff);
    }

    // 管理者のみチーム設定タブを表示
    if (widget.appUser.isAdmin) {
      tabs.add(HomeTab.teamSettings);
    }

    tabs.add(HomeTab.settings);

    return tabs;
  }

  /// 選択中のタブのインデックスを取得
  int get _selectedIndex {
    final tabs = _availableTabs;
    final index = tabs.indexOf(_selectedTab);
    return index >= 0 ? index : 0;
  }

  /// タブに対応する画面を取得
  Widget _getScreen(HomeTab tab) {
    switch (tab) {
      case HomeTab.myPage:
        return MyPageScreen(appUser: widget.appUser);
      case HomeTab.shift:
        return CalendarScreen(appUser: widget.appUser);
      case HomeTab.staff:
        return StaffListScreen(appUser: widget.appUser);
      case HomeTab.teamSettings:
        return const TeamSettingsScreen();
      case HomeTab.settings:
        return SettingsScreen(appUser: widget.appUser);
    }
  }

  /// タブに対応するタイトルを取得
  String _getTitle(HomeTab tab) {
    switch (tab) {
      case HomeTab.myPage:
        return 'マイページ';
      case HomeTab.shift:
        return 'シフト';
      case HomeTab.staff:
        return 'スタッフ';
      case HomeTab.teamSettings:
        return 'チーム設定';
      case HomeTab.settings:
        return 'その他';
    }
  }

  /// タブに対応するナビゲーション項目を取得
  NavigationDestination _getNavigationDestination(HomeTab tab, int pendingCount) {
    switch (tab) {
      case HomeTab.myPage:
        return const NavigationDestination(
          icon: Icon(Icons.person, size: _iconSize),
          label: 'マイページ',
        );
      case HomeTab.shift:
        return const NavigationDestination(
          icon: Icon(Icons.calendar_month, size: _iconSize),
          label: 'シフト',
        );
      case HomeTab.staff:
        return NavigationDestination(
          icon: Badge(
            label: Text('$pendingCount'),
            isLabelVisible: pendingCount > 0,
            child: const Icon(Icons.people, size: _iconSize),
          ),
          label: 'スタッフ',
        );
      case HomeTab.teamSettings:
        return const NavigationDestination(
          icon: Icon(Icons.settings, size: _iconSize),
          label: 'チーム',
        );
      case HomeTab.settings:
        return const NavigationDestination(
          icon: Icon(Icons.more_horiz, size: _iconSize),
          label: 'その他',
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirstTimeHelp();
    _syncFCMTokenOnStartup();
  }

  /// アプリ起動時にFCMトークンを同期（ウェルカムダイアログなしの場合）
  Future<void> _syncFCMTokenOnStartup() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final hasRequestedPermission = prefs.getBool('has_requested_fcm_permission') ?? false;

    // 既に許可ダイアログを表示済みの場合のみトークン同期
    if (hasRequestedPermission) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await NotificationService.syncToken();
      });
    }
  }

  /// FCM初期化（アプリ版のみ）
  /// ようこそダイアログの後、または毎回起動時に呼び出される
  Future<void> _initializeFCM() async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequestedPermission = prefs.getBool('has_requested_fcm_permission') ?? false;

      if (!hasRequestedPermission && mounted) {
        // 初回のみ通知許可ダイアログを表示
        await NotificationService.requestPermission();
        await prefs.setBool('has_requested_fcm_permission', true);
      }

      // 毎回、許可状態をチェックしてトークンを同期
      await NotificationService.syncToken();
    } catch (e) {
      debugPrint('⚠️ FCM初期化エラー: $e');
    }
  }

  /// 初回起動チェック及び自動ヘルプ表示
  Future<void> _checkFirstTimeHelp() async {
    // ウェルカムダイアログを表示するか判定
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHelp = prefs.getBool('has_seen_first_time_help') ?? false;
    final shouldShowWelcome = widget.showWelcomeDialog || !hasSeenHelp;

    if (!mounted) return;

    // 画面描画完了後に処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _hasShownFirstTimeHelp) return;

      // ウェルカムダイアログ表示（必要な場合のみ）
      if (shouldShowWelcome) {
        _hasShownFirstTimeHelp = true;
        await _showHelpDialog(isFirstTime: true);
      }

      // FCM初期化（常に実行）
      await _initializeFCM();
    });
  }

  /// 初回起動フラグを保存
  Future<void> _markFirstTimeHelpSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_first_time_help', true);
  }

  /// お知らせをチェックして表示
  Future<void> _checkAnnouncements() async {
    if (!mounted) {
      return;
    }

    try {
      // 未読のお知らせを取得
      final announcements = await _announcementService.getUnreadAnnouncements(widget.appUser.uid);

      if (!mounted || announcements.isEmpty) {
        return;
      }

      // 最新のお知らせのみ表示（複数ある場合は最新1件のみ）
      final latestAnnouncement = announcements.first;

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
      await _announcementService.markAsRead(widget.appUser.uid, latestAnnouncement.id);
    } catch (e) {
      // エラーは無視
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
      child: Consumer5<StaffProvider, ShiftProvider, ShiftTimeProvider, MonthlyRequirementsProvider, ConstraintRequestProvider>(
        builder: (context, staffProvider, shiftProvider, shiftTimeProvider, monthlyProvider, requestProvider, child) {
          // すべてのProviderのデータロード完了を待つ
          final isLoading =
              staffProvider.isLoading || shiftProvider.isLoading || shiftTimeProvider.isLoading || monthlyProvider.isLoading || requestProvider.isLoading;

          if (isLoading) {
            return _buildLoadingScreen(context);
          }

          // データロード完了後の初期化処理（初回のみ）
          if (!_hasCheckedInitialTab) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleInitialTabSelection(staffProvider);
            });
          }

          final availableTabs = _availableTabs;
          final pendingCount = requestProvider.pendingRequests.length;

          return Scaffold(
            appBar: _buildAppBar(context),
            body: _buildBody(),
            bottomNavigationBar: _buildBottomNavigationBar(availableTabs, pendingCount),
            floatingActionButton: _buildFloatingActionButton(),
          );
        },
      ),
    );
  }

  /// ローディング画面
  Widget _buildLoadingScreen(BuildContext context) {
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

  /// 初期タブ選択処理（データロード完了後に一度だけ実行）
  void _handleInitialTabSelection(StaffProvider staffProvider) {
    _hasCheckedInitialTab = true;

    // デフォルトはシフトタブ
    HomeTab initialTab = HomeTab.shift;

    // 登録済みユーザーかつ管理者の場合、スタッフ情報があればマイページを初期選択
    if (widget.appUser.email != null && widget.appUser.isAdmin) {
      final myUid = widget.appUser.uid;
      final myEmail = widget.appUser.email?.toLowerCase();
      final myStaff = staffProvider.staff
          .where((staff) =>
              (staff.userId != null && staff.userId == myUid) || (myEmail != null && staff.email != null && staff.email!.toLowerCase() == myEmail))
          .firstOrNull;

      // スタッフ情報があればマイページを初期選択
      if (myStaff != null) {
        initialTab = HomeTab.myPage;
      }
    } else if (widget.appUser.email != null && !widget.appUser.isAdmin) {
      // スタッフの場合はマイページを初期選択
      initialTab = HomeTab.myPage;
    }

    // 初期タブが利用可能か確認（匿名ユーザーの場合myPageは利用不可）
    if (_availableTabs.contains(initialTab)) {
      if (mounted) {
        setState(() {
          _selectedTab = initialTab;
        });
      }
    }

    // データロード完了後、お知らせをチェック
    _checkAnnouncements();
  }

  /// AppBarを構築
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(_getTitle(_selectedTab), style: const TextStyle(fontSize: 18)),
      toolbarHeight: _appBarHeight, // デフォルト56 → 48に縮小
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, size: _iconSize),
          onPressed: () {
            _showHelpDialog(isFirstTime: false);
          },
        ),
      ],
    );
  }

  /// Bodyを構築
  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: _getScreen(_selectedTab),
        ),
        // バナー広告
        const BannerAdWidget(),
      ],
    );
  }

  /// BottomNavigationBarを構築
  Widget _buildBottomNavigationBar(List<HomeTab> availableTabs, int pendingCount) {
    return NavigationBar(
      height: _navigationBarHeight, // デフォルト80 → 65に縮小
      onDestinationSelected: (int index) {
        if (index >= 0 && index < availableTabs.length) {
          setState(() {
            _selectedTab = availableTabs[index];
          });
        }
      },
      selectedIndex: _selectedIndex,
      destinations: availableTabs.map((tab) => _getNavigationDestination(tab, pendingCount)).toList(),
    );
  }

  Widget? _buildFloatingActionButton() {
    return null;
  }

  Future<void> _showHelpDialog({required bool isFirstTime}) async {
    if (isFirstTime) {
      // 初回起動時は簡易的なウェルカムダイアログを表示
      await showDialog(
        context: context,
        barrierDismissible: false, // 初回時は背景タップで閉じない
        builder: (context) => WelcomeDialog(
          appUser: widget.appUser,
          onStart: () {
            Navigator.pop(context);
            _markFirstTimeHelpSeen();
          },
        ),
      );
    } else {
      // 右上の？アイコンからは詳細なヘルプ画面へ遷移
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HelpScreen()),
      );
    }
  }
}
