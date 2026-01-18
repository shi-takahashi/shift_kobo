import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_user.dart';
import '../models/staff.dart';
import '../models/shift.dart';
import '../screens/auth/role_selection_screen.dart';
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

  /// ユーザー情報を取得（リトライ機能付き）
  ///
  /// 新規登録直後はFirestoreへの書き込みや認証トークンの同期に時間がかかる場合があるため、
  /// nullまたはエラーの場合は500ms待ってから再度取得を試みる（最大5回）。
  /// それでもnullの場合は削除されたユーザーと判断する。
  Future<dynamic> _getUserWithRetry(String uid) async {
    final authService = AuthService();
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 500);

    for (var i = 0; i < maxRetries; i++) {
      try {
        final appUser = await authService.getUser(uid);

        if (appUser != null) {
          if (i > 0) {
            debugPrint('✅ [AuthGate] usersドキュメント取得成功（${i + 1}回目）');
          }
          return appUser;
        }

        debugPrint('⚠️ [AuthGate] usersドキュメント取得失敗（${i + 1}回目）: appUser == null');
      } catch (e) {
        debugPrint('⚠️ [AuthGate] usersドキュメント取得エラー（${i + 1}回目）: $e');
      }

      // 最後の試行以外は待機してリトライ
      if (i < maxRetries - 1) {
        debugPrint('⏳ [AuthGate] ${retryDelay.inMilliseconds}ms後にリトライします...');
        await Future.delayed(retryDelay);
      }
    }

    debugPrint('❌ [AuthGate] usersドキュメント取得失敗（$maxRetries回試行）。削除されたユーザーと判断します。');
    return null;
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
              debugPrint('🔄 [AuthGate] authStateChanges: waiting...');
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // 認証状態をログ
            final user = authSnapshot.data;
            debugPrint('📍 [AuthGate] authStateChanges: user=${user?.uid ?? "null"}, hasData=${authSnapshot.hasData}');

            // 既存データがあり、未ログインの場合 → オンボーディング画面
            if (hasExistingData &&
                (!authSnapshot.hasData || authSnapshot.data == null)) {
              debugPrint('📍 [AuthGate] → MigrationOnboardingScreen (hasExistingData=$hasExistingData, user=null)');
              return const MigrationOnboardingScreen();
            }

            // ログイン済み
            if (authSnapshot.hasData && authSnapshot.data != null) {
              final uid = authSnapshot.data!.uid;
              debugPrint('📍 [AuthGate] ログイン済み: uid=$uid');
              // チーム所属チェック（リアルタイム監視）
              return StreamBuilder<AppUser?>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots()
                    .map((doc) {
                  if (!doc.exists) {
                    debugPrint('⚠️ [AuthGate] usersドキュメント存在せず: uid=$uid');
                    return null;
                  }
                  return AppUser.fromFirestore(doc);
                }),
                builder: (context, userSnapshot) {
                  // 初回読み込み中、またはデータ待ちの場合はローディング
                  if (userSnapshot.connectionState == ConnectionState.waiting ||
                      !userSnapshot.hasData) {
                    debugPrint('🔄 [AuthGate] usersドキュメント読み込み中...');
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final appUser = userSnapshot.data;

                  // usersドキュメントが存在しない場合（アカウント削除直後など）
                  // ※ Authentication削除が進行中の可能性があるため、signOut()を呼ばずに直接遷移
                  // ※ authStateChangesが発火すれば自動的に未ログイン状態として再処理される
                  if (appUser == null) {
                    debugPrint('📍 [AuthGate] → RoleSelectionScreen (appUser=null、削除直後?)');
                    return const RoleSelectionScreen();
                  }

                  if (appUser.teamId == null) {
                    debugPrint('📍 [AuthGate] チーム未所属: uid=$uid');
                    // チーム未所属の場合
                    if (hasExistingData) {
                      // 既存データがある場合はチーム作成画面へ（データ移行フラグ付き）
                      debugPrint('📍 [AuthGate] → TeamCreationScreen (shouldMigrateData=true)');
                      return TeamCreationScreen(
                        userId: authSnapshot.data!.uid,
                        shouldMigrateData: true,
                      );
                    } else {
                      // 既存データがない場合はチーム参加画面へ
                      debugPrint('📍 [AuthGate] → JoinTeamScreen');
                      return JoinTeamScreen(
                        userId: authSnapshot.data!.uid,
                      );
                    }
                  }

                  // チーム所属済みの場合はホーム画面へ（AppUser全体を渡す）
                  debugPrint('📍 [AuthGate] → HomeScreen (teamId=${appUser.teamId})');
                  return HomeScreen(appUser: appUser);
                },
              );
            }

            // 既存データなし、未ログインの場合 → 役割選択画面（新規ユーザー向け）
            debugPrint('📍 [AuthGate] → RoleSelectionScreen (未ログイン、既存データなし)');
            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}
