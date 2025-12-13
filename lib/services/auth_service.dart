import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/app_user.dart';
import '../models/team.dart';
import 'analytics_service.dart';
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
      print('🔵 [SignUp] サインアップ開始: $email');

      // Firebase Authでユーザー作成
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      print('✅ [SignUp] Authenticationユーザー作成成功: ${user.uid}');

      // 表示名を設定
      await user.updateDisplayName(displayName);
      print('✅ [SignUp] 表示名設定成功: $displayName');

      // 認証トークンを確実に取得（Firestoreアクセス前に必須）
      // これにより request.auth が確実に有効になる
      await user.reload();
      final token = await user.getIdToken(true); // 強制リフレッシュ
      print('✅ [SignUp] 認証トークン取得成功: ${token?.substring(0, 20)}...');

      // トークンが有効になるまで待機（Firestore Security Rulesでのアクセス許可に必要）
      await Future.delayed(const Duration(milliseconds: 500));

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

      print('✅ [SignUp] Firestoreユーザー情報保存成功');

      // Analytics: ユーザーIDを設定
      await AnalyticsService.setUserId(user.uid);

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ [SignUp] Firebase認証エラー: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ [SignUp] 予期しないエラー: $e');
      rethrow;
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
      final user = userCredential.user;

      // Analytics: ユーザーIDを設定
      if (user != null) {
        await AnalyticsService.setUserId(user.uid);
      }

      return user;
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

    // Analytics: ユーザーIDをクリア
    await AnalyticsService.setUserId(null);

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

  /// ユーザー情報をリアルタイムで監視
  Stream<AppUser?> getUserStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  /// 8文字のランダム招待コード生成（重複チェック付き）
  /// 紛らわしい文字を除外: 0/O, 1/I/L, 2/Z, 5/S, 8/B
  Future<String> _generateUniqueInviteCode() async {
    // 認証状態を確認
    final currentUser = _auth.currentUser;
    print('🔍 [招待コード生成] 認証状態: ${currentUser != null ? "ログイン中 (${currentUser.uid})" : "未ログイン"}');

    if (currentUser == null) {
      throw '認証エラー: ログインしていません';
    }

    const chars = 'ACDEFGHJKMNPQRTUVWXY34679';
    final random = Random();

    // 最大10回まで重複チェック
    for (var i = 0; i < 10; i++) {
      // 8文字のランダムコード生成
      final code = List.generate(
        8,
        (_) => chars[random.nextInt(chars.length)],
      ).join();

      print('🔍 [招待コード生成] 重複チェック実行: $code');

      // Firestoreで重複チェック
      try {
        final existingTeam = await _firestore
            .collection('teams')
            .where('inviteCode', isEqualTo: code)
            .limit(1)
            .get();

        if (existingTeam.docs.isEmpty) {
          print('✅ [招待コード生成] 成功: $code');
          return code; // 重複なし
        }

        print('⚠️ [招待コード生成] 重複あり: $code, 再試行...');
      } catch (e) {
        print('❌ [招待コード生成] Firestoreクエリエラー: $e');
        rethrow;
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
      print('🔵 [CreateTeam] チーム作成開始: $teamName');

      // 認証状態を確認（request.auth != null を保証）
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ [CreateTeam] 認証エラー: ログインしていません');
        throw '認証エラー: ログインしていません。もう一度ログインしてください。';
      }

      // 認証トークンを確認（request.auth が有効であることを保証）
      try {
        final token = await currentUser.getIdToken(false);
        if (token == null || token.isEmpty) {
          print('❌ [CreateTeam] 認証トークンが無効です。リフレッシュを試みます。');
          await currentUser.getIdToken(true); // 強制リフレッシュ
          await Future.delayed(const Duration(milliseconds: 100));
        }
        print('✅ [CreateTeam] 認証トークン確認成功');
      } catch (e) {
        print('❌ [CreateTeam] 認証トークン取得エラー: $e');
        throw '認証エラー: トークンの取得に失敗しました。もう一度ログインしてください。';
      }

      // 既にチームに所属していないかチェック
      final userDoc = await _firestore.collection('users').doc(ownerId).get();
      if (userDoc.exists) {
        final existingTeamId = userDoc.data()?['teamId'];
        if (existingTeamId != null) {
          throw '既にチームに所属しています。新しいチームを作成するには、現在のチームから退出してください。';
        }
      }

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
      print('✅ [CreateTeam] チームドキュメント作成成功: ${teamRef.id}');

      // ユーザーにチームIDを設定
      await _firestore.collection('users').doc(ownerId).update({
        'teamId': teamRef.id,
        'updatedAt': Timestamp.now(),
      });
      print('✅ [CreateTeam] ユーザーのteamId更新成功');

      print('✅ [CreateTeam] チーム作成完了: ${team.name} (${team.id})');
      return team;
    } catch (e) {
      print('❌ [CreateTeam] チーム作成エラー: $e');
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

  /// チーム名を変更
  Future<void> updateTeamName({
    required String teamId,
    required String newName,
  }) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ チーム名変更成功: $newName');
    } catch (e) {
      throw '❌ チーム名の変更に失敗しました: $e';
    }
  }

  /// チーム休み設定を更新
  Future<void> updateTeamHolidays({
    required String teamId,
    required List<int> teamDaysOff,
    required List<String> teamSpecificDaysOff,
    required bool teamHolidaysOff,
  }) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'teamDaysOff': teamDaysOff,
        'teamSpecificDaysOff': teamSpecificDaysOff,
        'teamHolidaysOff': teamHolidaysOff,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ チーム休み設定更新成功');
    } catch (e) {
      throw '❌ チーム休み設定の更新に失敗しました: $e';
    }
  }

  /// 招待コードでチームに参加
  Future<Team> joinTeamByCode({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      // 既にチームに所属していないかチェック
      final existingUserDoc = await _firestore.collection('users').doc(userId).get();
      final userEmail = existingUserDoc.data()?['email'] as String?;

      if (existingUserDoc.exists) {
        final existingTeamId = existingUserDoc.data()?['teamId'];
        if (existingTeamId != null) {
          throw '既にチームに所属しています。新しいチームに参加するには、現在のチームから退出してください。';
        }
      }

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

      // 認証トークンを強制更新し、Firestoreにアクセスできることを確認
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        await currentUser.getIdToken(true); // 強制リフレッシュ
        print('✅ [joinTeamByCode] 認証トークン更新完了');

        // teamIdが反映されたか確認（リトライ付き、最大5回）
        bool tokenReflected = false;
        for (var i = 0; i < 5; i++) {
          try {
            // usersドキュメントを読み取ってteamIdが反映されているか確認
            final userDoc = await _firestore.collection('users').doc(userId).get();
            final userTeamId = userDoc.data()?['teamId'];
            if (userTeamId == teamId) {
              print('✅ [joinTeamByCode] teamId反映確認成功（${i + 1}回目）');
              tokenReflected = true;
              break;
            }
          } catch (e) {
            print('⚠️ [joinTeamByCode] teamId反映確認失敗（${i + 1}回目）: $e');
          }

          if (i < 4) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        if (!tokenReflected) {
          print('⚠️ [joinTeamByCode] teamIdの反映確認に失敗しましたが、処理を続行します');
        }
      }

      // 3. teamsコレクションのmemberIdsに追加
      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. ユーザーのメールアドレスでスタッフとの自動紐付けを試行
      final email = userEmail;
      if (email != null && email.isNotEmpty) {
        await _autoLinkStaffByEmail(
          teamId: teamId,
          userId: userId,
          email: email,
        );
      }

      // 5. 参加したTeamオブジェクトを返す
      print('✅ [joinTeamByCode] チーム参加成功: $teamId');
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
      // usersコレクションから、teamIdが一致しroleがadminのユーザー数をカウント
      final snapshot = await _firestore
          .collection('users')
          .where('teamId', isEqualTo: teamId)
          .where('role', isEqualTo: 'admin')
          .get();

      return snapshot.docs.length;
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

  /// 匿名ログイン + デフォルトチーム自動作成
  Future<User?> signInAnonymously() async {
    try {
      print('🔵 [SignInAnonymously] 匿名ログイン開始');

      // Firebase匿名認証
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user == null) return null;

      print('✅ [SignInAnonymously] 匿名ユーザー作成成功: ${user.uid}');

      // 認証トークンを確実に取得
      await user.reload();
      final token = await user.getIdToken(true);
      print('✅ [SignInAnonymously] 認証トークン取得成功');

      // トークンが有効になるまで少し待機
      await Future.delayed(const Duration(milliseconds: 200));

      // デフォルトチーム「マイワークスペース」を作成（名前は空文字）
      final team = await _createDefaultTeam(user.uid);
      print('✅ [SignInAnonymously] デフォルトチーム作成成功: ${team.id}');

      // AppUserをFirestoreに保存（email: null, teamId: デフォルトチームID）
      final appUser = AppUser(
        uid: user.uid,
        email: null,  // 匿名なのでnull
        displayName: 'ゲスト',
        role: UserRole.admin,
        teamId: team.id,  // デフォルトチームに所属
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(appUser.toFirestore());

      print('✅ [SignInAnonymously] Firestoreユーザー情報保存成功');

      // 書き込みが確実に反映されるまで確認（AuthGateのStreamBuilderが反応する前に）
      await _firestore.collection('users').doc(user.uid).get();
      print('✅ [SignInAnonymously] ユーザードキュメント読み取り確認完了');

      // Analytics: ユーザーIDを設定
      await AnalyticsService.setUserId(user.uid);

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ [SignInAnonymously] Firebase認証エラー: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ [SignInAnonymously] 予期しないエラー: $e');
      rethrow;
    }
  }

  /// デフォルトチームを作成
  Future<Team> _createDefaultTeam(String ownerId) async {
    final team = Team(
      id: '',
      name: '',  // 空文字（アカウント登録時に入力）
      ownerId: ownerId,
      adminIds: [ownerId],
      memberIds: [ownerId],
      inviteCode: await _generateUniqueInviteCode(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('teams').add(team.toFirestore());
    print('✅ [_createDefaultTeam] デフォルトチーム作成: ${docRef.id}');
    return team.copyWith(id: docRef.id);
  }

  /// 匿名ユーザーをメールアドレスでアップグレード
  /// ★UIDは変わらない = データは完全に引き継がれる★
  Future<User?> upgradeAnonymousToEmail({
    required String email,
    required String password,
    required String teamName,
  }) async {
    final user = _auth.currentUser;

    // 匿名ユーザーかチェック
    if (user == null || !user.isAnonymous) {
      throw '匿名ユーザーではありません';
    }

    print('🔄 [Upgrade] 匿名 → メール登録');
    print('🔄 [Upgrade] 現在のUID: ${user.uid}（変わりません）');

    // メールアドレスを紐付け（★重要: UIDは変わらない★）
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    try {
      await user.linkWithCredential(credential);
      print('✅ [Upgrade] linkWithCredential成功');

      // 認証トークンを強制更新（Security Rulesで request.auth.token.email が必要な場合）
      await user.reload();
      final token = await user.getIdToken(true); // 強制リフレッシュ
      print('✅ [Upgrade] 認証トークン更新成功');

      // トークンが反映されるまで少し待機
      await Future.delayed(const Duration(milliseconds: 200));

      // displayNameを自動設定（@より前）
      final displayName = email.split('@')[0];
      await user.updateDisplayName(displayName);

      // Firestoreのusersドキュメントを更新
      await _firestore.collection('users').doc(user.uid).update({
        'email': email,
        'displayName': displayName,  // 自動設定
        'updatedAt': Timestamp.now(),
      });

      // チーム名を更新（空文字 → 入力値）
      final appUser = await getUser(user.uid);
      if (appUser?.teamId != null) {
        await _firestore.collection('teams').doc(appUser!.teamId).update({
          'name': teamName,
          'updatedAt': Timestamp.now(),
        });
        print('✅ [Upgrade] チーム名更新: $teamName');

        // メールアドレスでスタッフとの自動紐付けを試行
        await _autoLinkStaffByEmail(
          teamId: appUser.teamId!,
          userId: user.uid,
          email: email,
        );
      }

      print('✅ [Upgrade] 完了！UID: ${user.uid}（データはそのまま）');

      // Analytics: ユーザーIDを再設定（念のため）
      await AnalyticsService.setUserId(user.uid);

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'このメールアドレスは既に使用されています';
      }
      throw _handleAuthException(e);
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
      case 'requires-recent-login':
        return '最近ログインしていないため、この操作を実行できません';
      default:
        return '❌ 認証エラー: ${e.message}';
    }
  }
}
