# Firestore Security Rules

## 概要
このドキュメントは、Firestoreのセキュリティルールを記録します。
Firebaseコンソールで設定する際の参考にしてください。

## 現在の設定（Phase 1: 簡易版）

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ヘルパー関数：チームスタッフかどうか
    function isTeamMember(teamId) {
      return request.auth != null &&
             request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
    }

    // ヘルパー関数：チーム管理者かどうか
    function isTeamAdmin(teamId) {
      return request.auth != null &&
             request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
    }

    // ユーザーコレクション
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // チームコレクション
    match /teams/{teamId} {
      allow read: if isTeamMember(teamId);
      allow write: if isTeamAdmin(teamId);

      // スタッフサブコレクション
      match /staff/{staffId} {
        allow read: if isTeamMember(teamId);
        allow write: if isTeamAdmin(teamId);
      }

      // シフトサブコレクション
      match /shifts/{shiftId} {
        allow read: if isTeamMember(teamId);
        allow write: if isTeamAdmin(teamId);
      }

      // 設定サブコレクション
      match /settings/{settingId} {
        allow read: if isTeamMember(teamId);
        allow write: if isTeamAdmin(teamId);
      }

      // 月間必要人数サブコレクション
      match /monthly_requirements/{requirementId} {
        allow read: if isTeamMember(teamId);
        allow write: if isTeamAdmin(teamId);
      }

      // 休み希望承認リクエストサブコレクション（Phase 1: 簡易版）
      match /constraint_requests/{requestId} {
        // 全員が閲覧可能（管理者：全件、スタッフ：自分の申請のみはアプリ側で制御）
        allow read: if isTeamMember(teamId);

        // 申請作成：スタッフ自身のみ
        allow create: if isTeamMember(teamId) &&
                         request.resource.data.userId == request.auth.uid;

        // 申請更新：管理者のみ（承認・却下操作）
        allow update: if isTeamAdmin(teamId);

        // 申請削除：本人または管理者
        allow delete: if (resource.data.userId == request.auth.uid) ||
                         isTeamAdmin(teamId);
      }
    }
  }
}
```

## 将来の拡張予定（Phase 6: 締め日制御）

```javascript
// 休み希望承認リクエストサブコレクション（将来版：締め日制御あり）
match /constraint_requests/{requestId} {
  // 全員が閲覧可能
  allow read: if isTeamMember(teamId);

  // 申請作成：スタッフ自身のみ（締め日前のみ）
  allow create: if isTeamMember(teamId) &&
                   request.resource.data.userId == request.auth.uid &&
                   request.time < get(/databases/$(database)/documents/teams/$(teamId)).data.shiftDeadline;

  // 申請更新：管理者のみ（承認・却下操作）
  allow update: if isTeamAdmin(teamId) &&
                   request.resource.data.keys().hasAny(['status', 'approvedBy', 'approvedAt', 'rejectedReason']);

  // 申請削除：本人または管理者
  allow delete: if (resource.data.userId == request.auth.uid) ||
                   isTeamAdmin(teamId);
}
```

## 設定手順

1. Firebaseコンソールを開く
2. プロジェクトを選択
3. 左メニューから「Firestore Database」→「ルール」を選択
4. 上記のルールをコピー＆ペースト
5. 「公開」ボタンをクリック

## 注意事項

- **Phase 1では簡易版のルールを使用**しています
- 締め日制御（shiftDeadlineフィールド）は将来のフェーズで追加します
- アプリ側で適切なフィルタリングを行うことで、セキュリティを補完しています

## 変更履歴

- **2025-10-22**: Phase 1（簡易版）のSecurity Rules追加
  - constraint_requestsコレクション用のルール追加
  - 基本的な読み書き権限のみ設定
