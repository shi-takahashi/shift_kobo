import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
import 'models/consecutive_days_off_rule.dart';
import 'models/shift.dart';
import 'models/shift_constraint.dart';
import 'models/shift_time_setting.dart';
import 'models/staff.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'widgets/auth_gate.dart';

// ビルド時に環境を指定: --dart-define=FIREBASE_ENV=prod
const firebaseEnv = String.fromEnvironment('FIREBASE_ENV', defaultValue: 'dev');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // エッジ・ツー・エッジ対応（Android 15 / SDK 35対応）
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );
    // アプリ全体を縦向きに固定する。
    // 横向きはシフト表（ExportScreen）でのみ一時的に許可し、離脱時に縦へ戻す。
    // これにより縦向き専用設計の各画面が横向きで描画されてRenderFlexオーバーフロー
    // （黄黒のシマ）が出るのを防ぐ。
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await Hive.initFlutter();
  Hive.registerAdapter(ConsecutiveDaysOffRuleAdapter());
  Hive.registerAdapter(StaffAdapter());
  Hive.registerAdapter(ShiftAdapter());
  Hive.registerAdapter(ShiftConstraintAdapter());
  Hive.registerAdapter(ShiftTypeAdapter());
  Hive.registerAdapter(ShiftTimeSettingAdapter());

  await Hive.openBox<Staff>('staff');
  await Hive.openBox<Shift>('shifts');
  await Hive.openBox<ShiftConstraint>('constraints');
  await Hive.openBox<ShiftTimeSetting>('shift_time_settings');

  // AdMobの初期化はrunApp後に行う（下記）。
  // iOSのATT許可ダイアログはアプリがアクティブでないと出ないため、
  // 最初のフレーム後にATT→広告初期化の順で実行する。

  // Firebaseの初期化
  try {
    // 環境に応じてFirebase設定を切り替え
    final firebaseOptions = firebaseEnv == 'prod' ? prod_options.DefaultFirebaseOptions.currentPlatform : dev_options.DefaultFirebaseOptions.currentPlatform;

    debugPrint('🔥 Firebase環境: $firebaseEnv');

    await Firebase.initializeApp(
      options: firebaseOptions,
    );

    // Firestoreのキャッシュ設定（オフライン対応）
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    debugPrint('✅ Firebase初期化成功');

    // 再インストール時のみ「まっさら」な状態から始める（iOS限定）。
    // ※ runApp前・認証監視前に実行し、復元された残存セッションを先に解消しておく。
    await _resetAuthOnFreshInstall();

    // Analytics: アプリ起動イベント
    await AnalyticsService.logAppOpen();

    // 認証状態の追跡（根本原因調査用）
    await _initAuthMonitoring();

    // FCMの初期化は行わない（ログイン後に初期化する）
  } catch (e) {
    debugPrint('❌ Firebase初期化エラー: $e');
  }

  runApp(const MyApp());

  // 最初のフレーム描画後にATT許可→AdMob初期化（Web版では無効）。
  // この順序によりiOSで許可ダイアログが正しく表示され、許可確定後に広告SDKを初期化できる。
  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AdService.requestTrackingAuthorization();
      await AdService.initialize();
    });
  }
}

/// iOSで「再インストール時のみ」セッションを破棄し、まっさらな状態から始められるようにする。
///
/// ■ 根本原因
/// iOSのKeychainはアプリ削除後もFirebase Authのセッションを保持し、再インストール時に
/// 自動復元してしまう（Androidは削除でセッションごと消えるので元から問題なし）。
///
/// ■ 2つの目印を使い分ける
/// - フラグ F（SharedPreferences = NSUserDefaults）: アンインストールで「消える」。
///   → 「このインストールで初回起動か」を表す。
/// - マーカー K（flutter_secure_storage = Keychain）: アンインストールでも「残る」。
///   → 「この端末で“新アプリ”が一度でも動いたことがあるか」を表す。
///
/// ■ 判定（iOSのみ。signOutするのは下表の1ケースだけ）
///   | F     | K     | 状況                                   | 動作            |
///   |-------|-------|----------------------------------------|-----------------|
///   | あり  | -     | 通常起動 / アップデート                | 何もしない      |
///   | なし  | なし  | 既存ユーザーの乗り換え or 完全新規     | 据え置き（救済） |
///   | なし  | あり  | 新アプリ使用後にアンインストール→再導入 | signOut（リセット）|
///
/// これにより:
/// - 既存ユーザーがアップデート/乗り換えしてもサインアウトされない（F無し・K無し＝据え置き）。
/// - 新アプリを一度使えばKが残るので、以後の再インストールは確実にまっさらになる。
/// - 例外時は据え置き（誤signOutしないことを最優先）。
Future<void> _resetAuthOnFreshInstall() async {
  // iOS限定。Androidは元から再インストールでセッションが消える。Webは再インストール概念なし。
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

  const installedKey = 'has_installed_before_v1'; // フラグ F（SharedPreferences）
  const reinstallMarkerKey = 'reinstall_marker_v1'; // マーカー K（Keychain）
  const secureStorage = FlutterSecureStorage();

  try {
    final prefs = await SharedPreferences.getInstance();

    // F あり = アップデート or 2回目以降の起動 → 絶対に何もしない（signOutしない）。
    if (prefs.getBool(installedKey) == true) {
      return;
    }

    // ここに来る = このインストールでの初回起動。
    // K（Keychain）が残っているかで「過去に新アプリが動いた端末か」を判定する。
    final hadMarker = await secureStorage.read(key: reinstallMarkerKey) != null;

    if (hadMarker) {
      // K あり・F なし = 新アプリ使用後にアンインストール→再インストール＝本当の再インストール。
      // 復元された残存セッションをsignOutしてまっさらにする。
      // currentUserは復元完了前だとnullになるため、authStateChanges().firstで復元を待つ。
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user != null) {
        debugPrint(
            '🧹 再インストール検知: 残存セッションをsignOut (uid=${user.uid}, anonymous=${user.isAnonymous})');
        await FirebaseAuth.instance.signOut();
      }
    } else {
      // K なし・F なし = 既存ユーザーの初回 or 完全新規。
      // ここでは絶対にsignOutしない（既存ユーザーの乗り換えを壊さない＝救済）。
      debugPrint('🛟 初回起動（既存ユーザー乗り換え or 新規）: 据え置き＋マーカー設定');
    }

    // 以後の再インストールを検知できるよう、Kを必ず立てる（Keychainなので削除後も残る）。
    await secureStorage.write(key: reinstallMarkerKey, value: '1');
    // Fを立てる。次回以降の起動は冒頭のreturnで早期終了する。
    await prefs.setBool(installedKey, true);
  } catch (e) {
    // F/Kとも立てない（次回起動で再試行）。誤ってsignOutしないことを最優先。
    debugPrint('⚠️ 再インストール判定処理でエラー（据え置きで継続）: $e');
  }
}

/// 認証状態の監視を初期化（根本原因調査用）
Future<void> _initAuthMonitoring() async {
  final auth = FirebaseAuth.instance;

  // 1. 起動時の認証状態をログ
  // 注意: auth.currentUser は認証状態の復元完了前だとnullになる
  // authStateChanges().first で復元完了を待ってから取得する
  final currentUser = await auth.authStateChanges().first;
  await AnalyticsService.logAuthStateOnStartup(currentUser);

  // 2. 認証状態の変化を監視
  auth.authStateChanges().listen((user) {
    AnalyticsService.logAuthStateChanged(
      isSignedIn: user != null,
      uid: user?.uid,
      isAnonymous: user?.isAnonymous,
    );
  });

  // 3. IDトークンの変化を監視（トークン更新を検知）
  auth.idTokenChanges().listen((user) async {
    if (user != null) {
      try {
        // トークンが実際に取得できるか確認
        final token = await user.getIdToken();
        if (token != null) {
          await AnalyticsService.logIdTokenRefreshed(user.uid);
        }
      } catch (e) {
        await AnalyticsService.logIdTokenError(e.toString());
      }
    }
  });

  debugPrint('✅ 認証状態監視を開始しました');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'シフト工房',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ja', 'JP'),
        ],
        locale: const Locale('ja', 'JP'),
        home: const AuthGate(), // 認証状態に応じて画面を切り替え
      ),
    );
  }
}
