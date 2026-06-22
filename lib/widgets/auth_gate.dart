import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/team/join_team_screen.dart';

/// 認証状態を監視し、適切な画面を表示
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
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
              // 最初のデータが届くまで（waiting）だけローディング。
              // ⚠️ ここで !hasData を条件に入れてはいけない:
              //   ドキュメントが存在しない場合 .map() は null を emit するが、
              //   AsyncSnapshot.hasData は (data != null) なので null だと false になり、
              //   !hasData が永久に true → アカウント削除後にローディングで固まる（過去のデグレ）。
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                debugPrint('🔄 [AuthGate] usersドキュメント読み込み中...');
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // 読み取りエラー時は有効なユーザーを誤って弾かないようローディング維持（自動リトライを待つ）。
              // ※ Auth自体が無効化されればauthStateChangesがnullを発火し、外側で未ログイン処理される。
              if (userSnapshot.hasError) {
                debugPrint('⚠️ [AuthGate] usersドキュメント読み取りエラー: ${userSnapshot.error}');
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // ここに来た時点で最初のemissionは届いている（null = ドキュメント無し も含む）。
              final appUser = userSnapshot.data;

              // usersドキュメントが存在しない場合（アカウント削除直後など）
              // ※ Authentication削除が進行中の可能性があるため、signOut()を呼ばずに直接遷移
              // ※ authStateChangesが発火すれば自動的に未ログイン状態として再処理される
              if (appUser == null) {
                debugPrint('📍 [AuthGate] → RoleSelectionScreen (appUser=null、削除直後?)');
                return const RoleSelectionScreen();
              }

              if (appUser.teamId == null) {
                // チーム未所属の場合はチーム参加画面へ
                debugPrint('📍 [AuthGate] チーム未所属: uid=$uid → JoinTeamScreen');
                return JoinTeamScreen(
                  userId: authSnapshot.data!.uid,
                );
              }

              // チーム所属済みの場合はホーム画面へ（AppUser全体を渡す）
              debugPrint('📍 [AuthGate] → HomeScreen (teamId=${appUser.teamId})');
              return HomeScreen(appUser: appUser);
            },
          );
        }

        // 未ログインの場合 → 役割選択画面（新規ユーザー向け）
        debugPrint('📍 [AuthGate] → RoleSelectionScreen (未ログイン)');
        return const RoleSelectionScreen();
      },
    );
  }
}
