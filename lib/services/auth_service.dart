import 'dart:math';
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

  /// 8文字のランダム招待コード生成（重複チェック付き）
  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();

    // 最大10回まで重複チェック
    for (var i = 0; i < 10; i++) {
      // 8文字のランダムコード生成
      final code = List.generate(
        8,
        (_) => chars[random.nextInt(chars.length)],
      ).join();

      // Firestoreで重複チェック
      final existingTeam = await _firestore
          .collection('teams')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existingTeam.docs.isEmpty) {
        return code; // 重複なし
      }
    }

    // 10回試行しても重複した場合（極めて稀）
    throw '招待コードの生成に失敗しました。もう一度お試しください。';
  }

  /// チーム作成
  Future<Team> createTeam({
    required String teamName,
    required String ownerId,
  }) async {
    try {
      // 招待コード生成（重複チェック付き）
      final inviteCode = await _generateUniqueInviteCode();

      // チーム作成
      final teamRef = _firestore.collection('teams').doc();
      final team = Team(
        id: teamRef.id,
        name: teamName,
        ownerId: ownerId,
        adminIds: [ownerId],   // 作成者を管理者に
        memberIds: [ownerId],  // 作成者をスタッフに
        inviteCode: inviteCode, // 招待コード
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

  /// 招待コードでチームに参加
  Future<Team> joinTeamByCode({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      // 1. 招待コードでteamsコレクションを検索
      final inviteCodeUpper = inviteCode.toUpperCase();

      final teamsQuery = await _firestore
          .collection('teams')
          .where('inviteCode', isEqualTo: inviteCodeUpper)
          .limit(1)
          .get();

      if (teamsQuery.docs.isEmpty) {
        throw '招待コードが見つかりません';
      }

      final teamDoc = teamsQuery.docs.first;
      final teamId = teamDoc.id;

      // 2. usersコレクションのteamIdを更新（スタッフとして参加）
      await _firestore.collection('users').doc(userId).update({
        'teamId': teamId,
        'role': 'member', // スタッフとして参加
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. teamsコレクションのmemberIdsに追加
      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. ユーザーのメールアドレスでスタッフとの自動紐付けを試行
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final email = userDoc.data()?['email'] as String?;
      if (email != null && email.isNotEmpty) {
        await _autoLinkStaffByEmail(
          teamId: teamId,
          userId: userId,
          email: email,
        );
      }

      // 5. 参加したTeamオブジェクトを返す
      return Team.fromFirestore(teamDoc);
    } catch (e) {
      if (e.toString().contains('招待コードが見つかりません')) {
        throw e; // カスタムエラーメッセージはそのまま投げる
      }
      throw '❌ チーム参加に失敗しました: $e';
    }
  }

  /// メールアドレスでスタッフと自動紐付け
  Future<void> _autoLinkStaffByEmail({
    required String teamId,
    required String userId,
    required String email,
  }) async {
    try {
      // メールアドレスが一致する未紐付けスタッフを検索
      final staffQuery = await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .where('email', isEqualTo: email)
          .where('userId', isNull: true)
          .limit(1)
          .get();

      if (staffQuery.docs.isNotEmpty) {
        // 一致するスタッフが見つかった場合、userIdを設定
        final staffDoc = staffQuery.docs.first;
        await _firestore
            .collection('teams')
            .doc(teamId)
            .collection('staff')
            .doc(staffDoc.id)
            .update({
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ スタッフ自動紐付け成功: ${staffDoc.data()['name']} <-> $email');
      } else {
        print('ℹ️ スタッフ自動紐付けスキップ: メールアドレス $email に一致する未紐付けスタッフが見つかりません');
      }
    } catch (e) {
      // 紐付け失敗してもチーム参加は成功扱い（エラーを投げない）
      print('⚠️ スタッフ自動紐付けエラー: $e');
    }
  }

  /// チーム内の管理者数を取得
  Future<int> getAdminCount(String teamId) async {
    try {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) return 0;

      final adminIds = teamDoc.data()?['adminIds'] as List<dynamic>?;
      return adminIds?.length ?? 0;
    } catch (e) {
      throw '❌ 管理者数の取得に失敗しました: $e';
    }
  }

  /// ユーザーのロールを変更
  Future<void> updateUserRole({
    required String userId,
    required String teamId,
    required UserRole newRole,
  }) async {
    try {
      // usersコレクションのroleを更新
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // teamsコレクションのadminIds配列を更新
      if (newRole == UserRole.admin) {
        // 管理者に昇格 → adminIdsに追加
        await _firestore.collection('teams').doc(teamId).update({
          'adminIds': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // スタッフに降格 → adminIdsから削除
        await _firestore.collection('teams').doc(teamId).update({
          'adminIds': FieldValue.arrayRemove([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw '❌ ロール変更に失敗しました: $e';
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
