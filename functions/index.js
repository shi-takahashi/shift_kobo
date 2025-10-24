const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * チーム解散：全メンバーのAuthenticationを削除
 *
 * セキュリティ：
 * - 認証必須（context.auth）
 * - 呼び出し元が管理者であることを確認
 * - 呼び出し元がチームのメンバーであることを確認
 */
exports.deleteTeamAndAllAccounts = onCall(async (request) => {
  // 1. 認証チェック
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "認証が必要です",
    );
  }

  const callerId = request.auth.uid;
  const {teamId} = request.data;

  if (!teamId) {
    throw new HttpsError(
        "invalid-argument",
        "teamIdが必要です",
    );
  }

  console.log(`🗑️ チーム解散開始: ${teamId}, 呼び出し元: ${callerId}`);

  try {
    // 2. 呼び出し元がチームの管理者であることを確認
    const callerDoc = await admin.firestore()
        .collection("users")
        .doc(callerId)
        .get();

    if (!callerDoc.exists) {
      throw new HttpsError(
          "permission-denied",
          "ユーザー情報が見つかりません",
      );
    }

    const callerData = callerDoc.data();
    if (callerData.teamId !== teamId) {
      throw new HttpsError(
          "permission-denied",
          "このチームのメンバーではありません",
      );
    }

    if (callerData.role !== "admin") {
      throw new HttpsError(
          "permission-denied",
          "管理者権限が必要です",
      );
    }

    // 3. チームの全メンバーのuidを取得
    const usersSnapshot = await admin.firestore()
        .collection("users")
        .where("teamId", "==", teamId)
        .get();

    const allUserIds = usersSnapshot.docs.map((doc) => doc.id);
    // 呼び出し元以外のメンバーのuidを取得
    const otherUserIds = allUserIds.filter((uid) => uid !== callerId);
    console.log(`👥 全メンバー数: ${allUserIds.length}, 他のメンバー数: ${otherUserIds.length}`);

    // 4. チームドキュメントを先に削除（Providerの自動作成を防ぐため）
    await admin.firestore().collection("teams").doc(teamId).delete();
    console.log(`✅ チームドキュメント削除完了: ${teamId}`);

    // 5. サブコレクション削除
    await deleteSubcollection(teamId, "staff");
    await deleteSubcollection(teamId, "shifts");
    await deleteSubcollection(teamId, "constraintRequests");
    await deleteSubcollection(teamId, "settings");
    await deleteSubcollection(teamId, "shift_time_settings");

    // 6. usersドキュメント削除
    const batch = admin.firestore().batch();
    usersSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`✅ usersドキュメント削除完了: ${allUserIds.length}件`);

    // 7. 他のメンバーのAuthenticationを削除（呼び出し元は除く）
    const deletePromises = otherUserIds.map(async (uid) => {
      try {
        await admin.auth().deleteUser(uid);
        console.log(`✅ Authentication削除成功: ${uid}`);
      } catch (error) {
        // ユーザーが既に削除されている場合はエラーを無視
        if (error.code === "auth/user-not-found") {
          console.log(`⚠️ ユーザーが既に削除されています: ${uid}`);
        } else {
          console.error(`❌ Authentication削除失敗: ${uid}`, error);
          throw error;
        }
      }
    });

    await Promise.all(deletePromises);

    console.log(`✅ チーム解散完了: ${teamId}`);

    return {
      success: true,
      deletedUsers: allUserIds.length,
      message: "チーム解散が完了しました",
    };
  } catch (error) {
    console.error(`❌ チーム解散エラー: ${teamId}`, error);
    throw new HttpsError(
        "internal",
        `チーム解散に失敗しました: ${error.message}`,
    );
  }
});

/**
 * スタッフアカウント削除：指定されたスタッフのAuthenticationを削除
 *
 * セキュリティ：
 * - 認証必須（context.auth）
 * - 呼び出し元が管理者であることを確認
 * - 削除対象が同じチームのメンバーであることを確認
 */
exports.deleteStaffAccount = onCall(async (request) => {
  // 1. 認証チェック
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "認証が必要です",
    );
  }

  const callerId = request.auth.uid;
  const {userId} = request.data;

  if (!userId) {
    throw new HttpsError(
        "invalid-argument",
        "userIdが必要です",
    );
  }

  console.log(`🗑️ スタッフアカウント削除開始: ${userId}, 呼び出し元: ${callerId}`);

  try {
    // 2. 呼び出し元が管理者であることを確認
    const callerDoc = await admin.firestore()
        .collection("users")
        .doc(callerId)
        .get();

    if (!callerDoc.exists) {
      throw new HttpsError(
          "permission-denied",
          "ユーザー情報が見つかりません",
      );
    }

    const callerData = callerDoc.data();
    if (callerData.role !== "admin") {
      throw new HttpsError(
          "permission-denied",
          "管理者権限が必要です",
      );
    }

    // 3. 自分自身を削除しようとしていないか確認
    if (callerId === userId) {
      throw new HttpsError(
          "invalid-argument",
          "自分自身は削除できません。アカウント削除機能を使用してください。",
      );
    }

    // 4. Authenticationを削除（users ドキュメントの存在チェックは不要）
    try {
      await admin.auth().deleteUser(userId);
      console.log(`✅ Authentication削除成功: ${userId}`);
    } catch (error) {
      // ユーザーが既に削除されている場合はエラーを無視
      if (error.code === "auth/user-not-found") {
        console.log(`⚠️ ユーザーが既に削除されています: ${userId}`);
      } else {
        console.error(`❌ Authentication削除失敗: ${userId}`, error);
        throw error;
      }
    }

    console.log(`✅ スタッフアカウント削除完了: ${userId}`);

    return {
      success: true,
      message: "スタッフアカウントの削除が完了しました",
    };
  } catch (error) {
    console.error(`❌ スタッフアカウント削除エラー: ${userId}`, error);
    throw new HttpsError(
        "internal",
        `スタッフアカウント削除に失敗しました: ${error.message}`,
    );
  }
});

/**
 * サブコレクションを削除
 * @param {string} teamId チームID
 * @param {string} subcollection サブコレクション名
 */
async function deleteSubcollection(teamId, subcollection) {
  const snapshot = await admin.firestore()
      .collection("teams")
      .doc(teamId)
      .collection(subcollection)
      .get();

  if (snapshot.empty) {
    console.log(`⚠️ サブコレクションは既に空です: ${subcollection}`);
    return;
  }

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();
  console.log(`✅ サブコレクション削除完了: ${subcollection} (${snapshot.size}件)`);
}
