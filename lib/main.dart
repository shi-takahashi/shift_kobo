import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shift_kobo/utils/test_data_helper.dart';

import 'firebase_options.dart';
import 'models/shift.dart';
import 'models/shift_constraint.dart';
import 'models/shift_time_setting.dart';
import 'models/staff.dart';
import 'services/ad_service.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // if (!kIsWeb) {
  //   await TestDataHelper.initializeTestData(); // データ移行テスト用に有効化
  // }

  // AdMobの初期化（Web版では無効）
  if (!kIsWeb) {
    await AdService.initialize();
  }

  // Firebaseの初期化
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firestoreのキャッシュ設定（オフライン対応）
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    debugPrint('✅ Firebase初期化成功');

    // FCMの初期化は行わない（ログイン後に初期化する）
  } catch (e) {
    debugPrint('❌ Firebase初期化エラー: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
