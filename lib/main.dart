import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart'; // 一時的にコメントアウト

import 'models/staff.dart';
import 'models/shift.dart';
import 'models/shift_constraint.dart';
import 'models/shift_time_setting.dart';
import 'providers/staff_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/shift_time_provider.dart';
import 'screens/home_screen.dart';
import 'utils/test_data_helper.dart';

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
  
  // テスト用データの初期化（初回のみ）
  await TestDataHelper.initializeTestData();
  
  // MobileAds.instance.initialize(); // 一時的にコメントアウト
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => ShiftTimeProvider()..initialize()),
      ],
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
        home: const HomeScreen(),
      ),
    );
  }
}