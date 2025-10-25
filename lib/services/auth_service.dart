import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/app_user.dart';
import '../models/team.dart';
import 'notification_service.dart';

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
    // FCMトークンを削除（アプリ版のみ）
    if (!kIsWeb) {
      try {
        await NotificationService.deleteFcmToken();
      } catch (e) {
        // エラーは無視してログアウト処理を継続
        print('⚠️ FCMトークン削除エラー（無視）: $e');
      }
    }

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
  /// 紛らわしい文字を除外: 0/O, 1/I/L, 2/Z, 5/S, 8/B
  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ACDEFGHJKMNPQRTUVWXY34679';
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
      // set(merge: true)を使用して、ドキュメントが存在しない場合でも作成する
      await _firestore.collection('users').doc(userId).set({
        'teamId': teamId,
        'role': 'member', // スタッフとして参加
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

      // 5. usersドキュメントが正しく更新されたことを確認（書き込み完了待ち）
      await Future.delayed(const Duration(milliseconds: 500));
      final updatedUserDoc = await _firestore.collection('users').doc(userId).get();
      final updatedTeamId = updatedUserDoc.data()?['teamId'];
      print('✅ [joinTeamByCode] teamId更新確認: $updatedTeamId');

      // 6. 参加したTeamオブジェクトを返す
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
      // メールアドレスが一致するスタッフを検索（全件取得してアプリ側でフィルタ）
      final staffQuery = await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .where('email', isEqualTo: email)
          .get();

      // userIdが未設定のスタッフを探す
      final unmatchedStaff = staffQuery.docs.where((doc) {
        final data = doc.data();
        return data['userId'] == null || !(data.containsKey('userId'));
      }).toList();

      if (unmatchedStaff.isNotEmpty) {
        // 一致するスタッフが見つかった場合、userIdを設定
        final staffDoc = unmatchedStaff.first;
        await _firestore
            .collection('teams')
            .doc(teamId)
            .collection('staff')
            .doc(staffDoc.id)
            .update({
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ スタッフ自動紐付け成功: ${staffDoc.data()['name']} <-> $email (userId: $userId)');
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

  /// パスワードで再認証
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw '❌ ログインしていません';
      }

      final email = user.email;
      if (email == null) {
        throw '❌ メールアドレスが取得できません';
      }

      // EmailAuthProviderで再認証
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      print('✅ 再認証成功');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw '❌ 再認証に失敗しました: $e';
    }
  }

  /// アカウント削除（Firebase Authentication + Firestore users/）
  ///
  /// 注意: この関数は以下のみを削除します：
  /// - Firebase Authentication アカウント
  /// - Firestore users/{userId} ドキュメント
  ///
  /// 以下は呼び出し側で削除してください：
  /// - constraint_requests/ サブコレクション（ConstraintRequestProvider.deleteRequestsByStaffId()）
  /// - Staff.userId（StaffProvider.unlinkStaffUser()）
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw '❌ ログインしていません';
      }

      final userId = user.uid;

      // 1. Firestoreのusersドキュメント削除
      await _firestore.collection('users').doc(userId).delete();
      print('✅ usersドキュメント削除成功: $userId');

      // 2. Firebase Authenticationのアカウント削除
      await user.delete();
      print('✅ Authenticationアカウント削除成功: $userId');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // 再認証が必要（このエラーは呼び出し側で処理）
        rethrow;
      } else {
        throw '❌ アカウント削除に失敗しました: ${_handleAuthException(e)}';
      }
    } catch (e) {
      throw '❌ アカウント削除に失敗しました: $e';
    }
  }

  /// スタッフアカウント削除（管理者専用）
  ///
  /// 管理者が指定したスタッフのAuthenticationアカウントを削除します。
  ///
  /// Cloud Functionsを使用して、以下を削除します：
  /// - 指定されたスタッフのAuthentication（Admin SDK使用）
  ///
  /// 注意: この関数は以下のみを削除します：
  /// - Firebase Authentication アカウント
  ///
  /// 以下は呼び出し側で削除してください：
  /// - constraint_requests/ サブコレクション（ConstraintRequestProvider.deleteRequestsByStaffId()）
  /// - users/{userId} ドキュメント
  /// - staffs/{staffId} ドキュメント（StaffProvider.deleteStaff()）
  Future<void> deleteStaffAccount(String userId) async {
    try {
      print('🗑️ スタッフアカウント削除開始（Cloud Functions使用）: $userId');

      // Cloud Functionsを呼び出してスタッフのAuthenticationを削除
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteStaffAccount',
      );

      final result = await callable.call({
        'userId': userId,
      });

      final data = result.data as Map<String, dynamic>;
      print('✅ スタッフアカウント削除完了: ${data['message']}');
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw '❌ 認証が必要です';
      } else if (e.code == 'permission-denied') {
        throw '❌ 権限がありません: ${e.message}';
      } else if (e.code == 'invalid-argument') {
        throw '❌ 無効なパラメータです: ${e.message}';
      } else if (e.code == 'not-found') {
        throw '❌ ユーザーが見つかりません: ${e.message}';
      } else {
        throw '❌ スタッフアカウント削除に失敗しました: ${e.message}';
      }
    } catch (e) {
      throw '❌ スタッフアカウント削除に失敗しました: $e';
    }
  }

  /// チーム解散とアカウント削除（唯一の管理者専用）
  ///
  /// 唯一の管理者がアカウント削除する場合、チーム全体を解散します。
  ///
  /// Cloud Functionsを使用して、以下を削除します：
  /// - チームの全サブコレクション（staff, shifts, constraintRequests, settings, shift_time_settings）
  /// - チームドキュメント
  /// - チームメンバー全員のusersドキュメント
  /// - チームメンバー全員のAuthentication（Admin SDK使用）
  ///
  /// GDPR対応：
  /// - 個人情報保護のため、全メンバーのAuthenticationアカウントを削除します
  /// - Admin SDKを使用して、他のメンバーのAuthenticationも削除します
  Future<void> deleteTeamAndAccount(String teamId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw '❌ ログインしていません';
      }

      print('🗑️ チーム解散開始（Cloud Functions使用）: $teamId');

      // Cloud Functionsを呼び出してチーム全体を削除
      // サーバー側で全メンバーのAuthenticationを削除
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteTeamAndAllAccounts',
      );

      final result = await callable.call({
        'teamId': teamId,
      });

      final data = result.data as Map<String, dynamic>;
      print('✅ チーム解散完了: ${data['message']} (削除ユーザー数: ${data['deletedUsers']})');
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw '❌ 認証が必要です';
      } else if (e.code == 'permission-denied') {
        throw '❌ 権限がありません: ${e.message}';
      } else if (e.code == 'invalid-argument') {
        throw '❌ 無効なパラメータです: ${e.message}';
      } else {
        throw '❌ チーム解散に失敗しました: ${e.message}';
      }
    } catch (e) {
      throw '❌ チーム解散に失敗しました: $e';
    }
  }

  /// サブコレクションを削除
  Future<void> _deleteSubcollection(String teamId, String subcollection) async {
    final snapshot = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection(subcollection)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    print('✅ サブコレクション削除成功: $subcollection (${snapshot.docs.length}件)');
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
      case 'requires-recent-login':
        return '最近ログインしていないため、この操作を実行できません';
      default:
        return '❌ 認証エラー: ${e.message}';
    }
  }
}
