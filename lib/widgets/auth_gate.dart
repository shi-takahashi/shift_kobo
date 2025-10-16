import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/team/team_creation_screen.dart';
import '../services/auth_service.dart';

/// 認証状態を監視し、適切な画面を表示
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 読み込み中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ログイン済み
        if (snapshot.hasData && snapshot.data != null) {
          // チーム所属チェック
          return FutureBuilder(
            future: AuthService().getUser(snapshot.data!.uid),
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
                // チーム未所属の場合はチーム作成画面へ
                return TeamCreationScreen(userId: snapshot.data!.uid);
              }

              // チーム所属済みの場合はホーム画面へ
              return const HomeScreen();
            },
          );
        }

        // 未ログイン
        return const LoginScreen();
      },
    );
  }
}
