import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart'; // 一時的にコメントアウト

import 'models/staff.dart';
import 'models/shift.dart';
import 'models/shift_constraint.dart';
import 'providers/staff_provider.dart';
import 'providers/shift_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(StaffAdapter());
  Hive.registerAdapter(ShiftAdapter());
  Hive.registerAdapter(ShiftConstraintAdapter());
  
  await Hive.openBox<Staff>('staff');
  await Hive.openBox<Shift>('shifts');
  await Hive.openBox<ShiftConstraint>('constraints');
  
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
      ],
      child: MaterialApp(
        title: 'シフト工房',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}