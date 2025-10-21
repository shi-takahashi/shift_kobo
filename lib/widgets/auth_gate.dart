import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/staff.dart';
import '../models/shift.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/home_screen.dart';
import '../screens/team/team_creation_screen.dart';
import '../screens/team/join_team_screen.dart';
import '../screens/migration/migration_onboarding_screen.dart';
import '../services/auth_service.dart';

/// 認証状態を監視し、適切な画面を表示
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// 既存のHiveデータが存在するかチェック（オフライン版からのアップデート判定）
  Future<bool> _hasExistingData() async {
    try {
      // Hiveボックスが存在するかチェック
      final staffBoxExists = await Hive.boxExists('staff');
      final shiftsBoxExists = await Hive.boxExists('shifts');

      if (!staffBoxExists && !shiftsBoxExists) {
        return false;
      }

      // ボックスを開いてデータが存在するか確認
      // main.dartで型付きボックスとして開いているため、型付きで取得
      if (staffBoxExists) {
        final staffBox = Hive.box<Staff>('staff');
        if (staffBox.isNotEmpty) return true;
      }

      if (shiftsBoxExists) {
        final shiftsBox = Hive.box<Shift>('shifts');
        if (shiftsBox.isNotEmpty) return true;
      }

      return false;
    } catch (e) {
      // エラー時は既存データなしとして扱う
      debugPrint('既存データチェックエラー: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasExistingData(),
      builder: (context, dataSnapshot) {
        if (dataSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasExistingData = dataSnapshot.data ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            // 読み込み中
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // 既存データがあり、未ログインの場合 → オンボーディング画面
            if (hasExistingData &&
                (!authSnapshot.hasData || authSnapshot.data == null)) {
              return const MigrationOnboardingScreen();
            }

            // ログイン済み
            if (authSnapshot.hasData && authSnapshot.data != null) {
              // チーム所属チェック
              return FutureBuilder(
                future: AuthService().getUser(authSnapshot.data!.uid),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final appUser = userSnapshot.data;
                  if (appUser?.teamId == null) {
                    // チーム未所属の場合
                    if (hasExistingData) {
                      // 既存データがある場合はチーム作成画面へ（データ移行フラグ付き）
                      return TeamCreationScreen(
                        userId: authSnapshot.data!.uid,
                        shouldMigrateData: true,
                      );
                    } else {
                      // 既存データがない場合はチーム参加画面へ
                      return JoinTeamScreen(
                        userId: authSnapshot.data!.uid,
                      );
                    }
                  }

                  // チーム所属済みの場合はホーム画面へ（AppUser全体を渡す）
                  return HomeScreen(appUser: appUser!);
                },
              );
            }

            // 既存データなし、未ログインの場合 → ウェルカム画面（新規ユーザー向け）
            return const WelcomeScreen();
          },
        );
      },
    );
  }
}
