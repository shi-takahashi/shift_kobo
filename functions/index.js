const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * アプリリダイレクト：User-Agentで判定
 *  - Android → Google Play
 *  - iPhone/iPad → App Store
 *  - その他（PC等） → Webアプリ
 * ※302（一時）リダイレクト：将来の振り先変更がキャッシュで固定されないように
 */
exports.appRedirect = onRequest(
    {
      region: "asia-northeast1",
    },
    (req, res) => {
      const userAgent = (req.headers["user-agent"] || "").toLowerCase();

      if (userAgent.includes("android")) {
        // Android → Google Play
        console.log("🤖 Android User-Agent検出 → Google Play");
        res.redirect(302, "https://play.google.com/store/apps/details?id=io.github.shitakahashi.shiftkobo");
      } else if (
        userAgent.includes("iphone") ||
        userAgent.includes("ipad") ||
        userAgent.includes("ipod")
      ) {
        // iPhone/iPad → App Store
        console.log("🍎 iOS User-Agent検出 → App Store");
        res.redirect(302, "https://apps.apple.com/app/id6775868548");
      } else {
        // その他（PC等） → Webアプリ
        console.log("🖥️ その他 User-Agent検出 → Webアプリ");
        res.redirect(302, "https://shift-kobo-online-prod.web.app/web/");
      }
    },
);

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
    await deleteSubcollection(teamId, "constraint_requests");
    await deleteSubcollection(teamId, "monthly_requirements");
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

/**
 * 休み希望申請作成時のトリガー
 * 管理者にPush通知を送信
 */
exports.onConstraintRequestCreated = onDocumentCreated(
    {
      document: "teams/{teamId}/constraint_requests/{requestId}",
      database: "(default)",
      region: "asia-northeast1",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        console.log("⚠️ スナップショットがありません");
        return;
      }

      const requestData = snapshot.data();
      const teamId = event.params.teamId;
      const requestId = event.params.requestId;

      console.log(`📬 申請作成トリガー: ${teamId}/${requestId}`);

      try {
        // 1. 申請者のスタッフ情報を取得
        const staffDoc = await admin.firestore()
            .collection("teams")
            .doc(teamId)
            .collection("staff")
            .doc(requestData.staffId)
            .get();

        const staffName = staffDoc.exists ? staffDoc.data().name : "不明なスタッフ";

        // 2. requestTypeに応じた通知タイトル・メッセージを生成
        const requestType = requestData.requestType;
        const isDelete = requestData.isDelete || false;

        let title = "";
        let body = "";

        if (requestType === "specificDay") {
          title = isDelete ? "休み希望の取り消し" : "新しい休み希望申請";
          body = isDelete ?
            `${staffName}さんが休み希望を取り消しました` :
            `${staffName}さんが休み希望を申請しました`;
        } else if (requestType === "weekday") {
          title = isDelete ? "曜日休みの取り消し" : "新しい曜日休み申請";
          body = isDelete ?
            `${staffName}さんが曜日休みを取り消しました` :
            `${staffName}さんが曜日休みを申請しました`;
        } else if (requestType === "shiftType") {
          title = isDelete ? "勤務不可シフトの取り消し" : "新しい勤務不可シフト申請";
          body = isDelete ?
            `${staffName}さんが勤務不可シフトを取り消しました` :
            `${staffName}さんが勤務不可シフトを申請しました`;
        } else if (requestType === "maxShiftsPerMonth") {
          title = "月間最大シフト数の変更申請";
          body = `${staffName}さんが月間最大シフト数の変更を申請しました`;
        } else if (requestType === "preferredDate") {
          title = isDelete ? "勤務希望日の取り消し" : "新しい勤務希望日申請";
          body = isDelete ?
            `${staffName}さんが勤務希望日を取り消しました` :
            `${staffName}さんが勤務希望日を申請しました`;
        } else {
          console.log(`⚠️ 不明なrequestType: ${requestType}`);
          return;
        }

        // 3. チームの管理者を取得
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("teamId", "==", teamId)
            .where("role", "==", "admin")
            .get();

        if (usersSnapshot.empty) {
          console.log("⚠️ 管理者が見つかりません");
          return;
        }

        // 4. 各管理者にPush通知を送信
        const notifications = [];
        for (const userDoc of usersSnapshot.docs) {
          const userData = userDoc.data();

          // 通知設定を確認
          const settings = userData.notificationSettings || {};
          if (settings.requestCreated === false) {
            console.log(`⏭️ 通知スキップ（設定OFF）: ${userDoc.id}`);
            continue;
          }

          // FCMトークンがない場合はスキップ
          if (!userData.fcmToken) {
            console.log(`⏭️ FCMトークンなし: ${userDoc.id}`);
            continue;
          }

          // Push通知を送信
          const message = {
            token: userData.fcmToken,
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: "request_created",
              teamId: teamId,
              requestId: requestId,
              staffId: requestData.staffId,
              requestType: requestType,
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  badge: 1,
                  sound: "default",
                },
              },
            },
          };

          notifications.push(
              admin.messaging().send(message)
                  .then(() => {
                    console.log(`✅ Push通知送信成功: ${userDoc.id}`);
                  })
                  .catch((error) => {
                    console.error(`❌ Push通知送信失敗: ${userDoc.id}`, error);
                    // FCMトークンが無効な場合は削除
                    if (error.code === "messaging/invalid-registration-token" ||
                        error.code === "messaging/registration-token-not-registered") {
                      return admin.firestore()
                          .collection("users")
                          .doc(userDoc.id)
                          .update({fcmToken: admin.firestore.FieldValue.delete()});
                    }
                  }),
          );
        }

        await Promise.all(notifications);
        console.log(`✅ 申請通知処理完了: ${notifications.length}件`);
      } catch (error) {
        console.error(`❌ 申請通知処理エラー`, error);
      }
    });

/**
 * 休み希望申請更新時のトリガー
 * スタッフにPush通知を送信（承認/却下）
 */
exports.onConstraintRequestUpdated = onDocumentUpdated(
    {
      document: "teams/{teamId}/constraint_requests/{requestId}",
      database: "(default)",
      region: "asia-northeast1",
    },
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const teamId = event.params.teamId;
      const requestId = event.params.requestId;

      // statusが変更されていない場合はスキップ
      if (beforeData.status === afterData.status) {
        console.log(`⏭️ statusが変更されていないためスキップ`);
        return;
      }

      // 承認または却下の場合のみ通知
      if (afterData.status !== "approved" && afterData.status !== "rejected") {
        console.log(`⏭️ status=${afterData.status} のため通知スキップ`);
        return;
      }

      console.log(`📬 申請更新トリガー: ${teamId}/${requestId}, status=${afterData.status}`);

      try {
        // 1. 申請者のユーザー情報を取得
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("teamId", "==", teamId)
            .get();

        // staffIdと紐づくユーザーを探す
        let targetUser = null;
        for (const userDoc of usersSnapshot.docs) {
          const staffSnapshot = await admin.firestore()
              .collection("teams")
              .doc(teamId)
              .collection("staff")
              .where("email", "==", userDoc.data().email)
              .get();

          if (!staffSnapshot.empty && staffSnapshot.docs[0].id === afterData.staffId) {
            targetUser = {id: userDoc.id, data: userDoc.data()};
            break;
          }
        }

        if (!targetUser) {
          console.log(`⚠️ 申請者のユーザーが見つかりません: staffId=${afterData.staffId}`);
          return;
        }

        // 2. 通知設定を確認
        const settings = targetUser.data.notificationSettings || {};
        const notificationType = afterData.status === "approved" ? "requestApproved" : "requestRejected";

        if (settings[notificationType] === false) {
          console.log(`⏭️ 通知スキップ（設定OFF）: ${targetUser.id}`);
          return;
        }

        // 3. FCMトークンがない場合はスキップ
        if (!targetUser.data.fcmToken) {
          console.log(`⏭️ FCMトークンなし: ${targetUser.id}`);
          return;
        }

        // 4. requestTypeに応じた通知メッセージを生成
        const isApproved = afterData.status === "approved";
        const requestType = afterData.requestType;
        const isDelete = afterData.isDelete || false;

        let title = "";
        let body = "";

        if (isApproved) {
          // 承認通知
          if (requestType === "specificDay") {
            title = isDelete ? "休み希望の取り消しが承認されました" : "休み希望が承認されました";
            body = isDelete ?
              "申請した休み希望の取り消しが承認されました" :
              "申請した休み希望が承認されました";
          } else if (requestType === "weekday") {
            title = isDelete ? "曜日休みの取り消しが承認されました" : "曜日休みが承認されました";
            body = isDelete ?
              "申請した曜日休みの取り消しが承認されました" :
              "申請した曜日休みが承認されました";
          } else if (requestType === "shiftType") {
            title = isDelete ? "勤務不可シフトの取り消しが承認されました" : "勤務不可シフトが承認されました";
            body = isDelete ?
              "申請した勤務不可シフトの取り消しが承認されました" :
              "申請した勤務不可シフトが承認されました";
          } else if (requestType === "maxShiftsPerMonth") {
            title = "月間最大シフト数の変更が承認されました";
            body = "申請した月間最大シフト数の変更が承認されました";
          } else if (requestType === "preferredDate") {
            title = isDelete ? "勤務希望日の取り消しが承認されました" : "勤務希望日が承認されました";
            body = isDelete ?
              "申請した勤務希望日の取り消しが承認されました" :
              "申請した勤務希望日が承認されました";
          } else {
            title = "申請が承認されました";
            body = "申請が承認されました";
          }
        } else {
          // 却下通知
          if (requestType === "specificDay") {
            title = isDelete ? "休み希望の取り消しが却下されました" : "休み希望が却下されました";
            body = "申請が却下されました。詳細はアプリで確認してください";
          } else if (requestType === "weekday") {
            title = isDelete ? "曜日休みの取り消しが却下されました" : "曜日休みが却下されました";
            body = "申請が却下されました。詳細はアプリで確認してください";
          } else if (requestType === "shiftType") {
            title = isDelete ? "勤務不可シフトの取り消しが却下されました" : "勤務不可シフトが却下されました";
            body = "申請が却下されました。詳細はアプリで確認してください";
          } else if (requestType === "maxShiftsPerMonth") {
            title = "月間最大シフト数の変更が却下されました";
            body = "申請が却下されました。詳細はアプリで確認してください";
          } else if (requestType === "preferredDate") {
            title = isDelete ? "勤務希望日の取り消しが却下されました" : "勤務希望日が却下されました";
            body = "申請が却下されました。詳細はアプリで確認してください";
          } else {
            title = "申請が却下されました";
            body = "申請が却下されました。詳細はアプリで確認してください";
          }
        }

        // 5. Push通知を送信
        const message = {
          token: targetUser.data.fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: isApproved ? "request_approved" : "request_rejected",
            teamId: teamId,
            requestId: requestId,
            staffId: afterData.staffId,
            requestType: requestType,
          },
          android: {
            priority: "high",
          },
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: "default",
              },
            },
          },
        };

        await admin.messaging().send(message);
        console.log(`✅ Push通知送信成功: ${targetUser.id}`);
      } catch (error) {
        console.error(`❌ 承認/却下通知処理エラー`, error);

        // FCMトークンが無効な場合は削除
        if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          // targetUserが見つかっている場合のみ削除
          if (error.message && error.message.includes("targetUser")) {
            return;
          }
          // 実際にはtargetUser.idを使用して削除する必要があるが、
          // エラーハンドリングのスコープ外のため、ログのみ
          console.log(`⚠️ 無効なFCMトークンを検出しました`);
        }
      }
    });
