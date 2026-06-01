import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shift_kobo/utils/test_data_helper.dart';

import 'firebase_options.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
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
  }

  await Hive.initFlutter();
  Hive.registerAdapter(StaffAdapter());
  Hive.registerAdapter(ShiftAdapter());
  Hive.registerAdapter(ShiftConstraintAdapter());
  Hive.registerAdapter(ShiftTypeAdapter());
  Hive.registerAdapter(ShiftTimeSettingAdapter());

  await Hive.openBox<Staff>('staff');
  await Hive.openBox<Shift>('shifts');
  await Hive.openBox<ShiftConstraint>('constraints');
  await Hive.openBox<ShiftTimeSetting>('shift_time_settings');

  // テスト用データの初期化（初回のみ）
  // TODO: Providerの改修（Firestore対応）が完了したら削除
  if (!kIsWeb) {
    await TestDataHelper.initializeTestData(); // データ移行テスト用に有効化
  }

  // AdMobの初期化（Web版では無効）
  if (!kIsWeb) {
    await AdService.initialize();
  }

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

    // Analytics: アプリ起動イベント
    await AnalyticsService.logAppOpen();

    // 認証状態の追跡（根本原因調査用）
    await _initAuthMonitoring();

    // FCMの初期化は行わない（ログイン後に初期化する）
  } catch (e) {
    debugPrint('❌ Firebase初期化エラー: $e');
  }

  runApp(const MyApp());
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
