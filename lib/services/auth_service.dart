import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/team.dart';

/// 認証サービス
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 現在のFirebase Authユーザー
  User? get currentUser => _auth.currentUser;

  /// 認証状態の監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// サインアップ（新規登録）
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Firebase Authでユーザー作成
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // 表示名を設定
      await user.updateDisplayName(displayName);

      // Firestoreにユーザー情報を保存（初期はチーム未所属）
      final appUser = AppUser(
        uid: user.uid,
        email: email,
        displayName: displayName,
        role: UserRole.admin, // 最初のユーザーは管理者
        teamId: null,         // チーム未所属
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(appUser.toFirestore());

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ログイン
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// ユーザー情報を取得
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      throw '❌ ユーザー情報の取得に失敗しました: $e';
    }
  }

  /// チーム作成
  Future<Team> createTeam({
    required String teamName,
    required String ownerId,
  }) async {
    try {
      // チーム作成
      final teamRef = _firestore.collection('teams').doc();
      final team = Team(
        id: teamRef.id,
        name: teamName,
        ownerId: ownerId,
        adminIds: [ownerId],   // 作成者を管理者に
        memberIds: [ownerId],  // 作成者をメンバーに
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await teamRef.set(team.toFirestore());

      // ユーザーにチームIDを設定
      await _firestore.collection('users').doc(ownerId).update({
        'teamId': teamRef.id,
        'updatedAt': Timestamp.now(),
      });

      return team;
    } catch (e) {
      throw '❌ チーム作成に失敗しました: $e';
    }
  }

  /// チーム情報を取得
  Future<Team?> getTeam(String teamId) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (!doc.exists) return null;
      return Team.fromFirestore(doc);
    } catch (e) {
      throw '❌ チーム情報の取得に失敗しました: $e';
    }
  }

  /// 認証エラーの処理
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'operation-not-allowed':
        return 'この操作は許可されていません';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上）';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'user-not-found':
        return 'ユーザーが見つかりません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが間違っています';
      default:
        return '❌ 認証エラー: ${e.message}';
    }
  }
}
