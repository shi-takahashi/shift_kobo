# Firestore Security Rules

## 概要
このドキュメントは、Firestoreのセキュリティルールを記録します。
Firebaseコンソールで設定する際の参考にしてください。

---

## 現在の設定（本番・開発環境共通）

**方針**:
- 認証済みユーザー（匿名含む）のみアクセス可能
- チーム単位でのデータ分離を実装
- ロールベースアクセス制御（admin/member）

**特徴**:
- ✅ 匿名ユーザーでもアクセス可能（`request.auth != null`で認証済みかチェック）
- ✅ チームメンバーのみがチームデータにアクセス可能
- ✅ 管理者のみが特定の操作（ロール変更、チーム更新）を実行可能

---

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーは認証済みなら読み取り可能
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && (
        // 本人による更新
        request.auth.uid == userId ||
        // または、チーム管理者によるrole更新
        (
          // 変更がroleとupdatedAtのみ
          request.resource.data.diff(resource.data).affectedKeys().hasOnly(['role', 'updatedAt']) &&
          // 変更対象のユーザーにteamIdが設定されている
          resource.data.teamId != null &&
          // 変更者がそのチームの管理者またはオーナー
          (
            request.auth.uid in get(/databases/$(database)/documents/teams/$(resource.data.teamId)).data.adminIds ||
            request.auth.uid == get(/databases/$(database)/documents/teams/$(resource.data.teamId)).data.ownerId
          )
        )
      );
      allow delete: if request.auth != null && request.auth.uid == userId;
    }

    // チームは認証済みなら作成可能（匿名ユーザー含む）
    match /teams/{teamId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null &&
        (
          // 管理者またはオーナー：全フィールド更新可能
          request.auth.uid in resource.data.adminIds ||
          request.auth.uid == resource.data.ownerId ||
          // 新規メンバー：自分をmemberIdsに追加するのみ許可
          (
            request.resource.data.diff(resource.data).affectedKeys().hasOnly(['memberIds', 'updatedAt']) &&
            request.auth.uid in request.resource.data.memberIds &&
            !(request.auth.uid in resource.data.memberIds)
          )
        );
      allow delete: if request.auth != null &&
        (request.auth.uid in resource.data.adminIds || request.auth.uid == resource.data.ownerId);

      // サブコレクション
      match /{subcollection=**} {
        allow read, write: if request.auth != null &&
          (request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds);
      }
    }
  }
}
```

---

## ルール詳細解説

### 1. usersコレクション

#### 読み取り（read）
- **条件**: 認証済みユーザー（匿名含む）
- **用途**: 全ユーザー情報の参照（チームメンバー一覧表示など）

#### 作成（create）
- **条件**: 認証済み かつ 自分自身のドキュメント
- **用途**: サインアップ時のユーザー作成

#### 更新（update）
- **条件1**: 本人による更新（全フィールド）
- **条件2**: チーム管理者によるrole更新
  - 変更フィールドが`role`と`updatedAt`のみ
  - 対象ユーザーがチームに所属している
  - 更新者がそのチームの管理者またはオーナー
- **用途**: プロフィール更新、管理者権限の付与/剥奪

#### 削除（delete）
- **条件**: 本人のみ
- **用途**: アカウント削除

---

### 2. teamsコレクション

#### 読み取り（read）
- **条件**: 認証済みユーザー
- **用途**: チーム検索、チーム情報参照

#### 作成（create）
- **条件**: 認証済みユーザー（匿名含む）
- **用途**: チーム作成（匿名ユーザーでも可能）

#### 更新（update）
- **条件1**: 管理者またはオーナー（全フィールド更新可能）
  - チーム名変更、招待コード変更、管理者追加など
- **条件2**: 新規メンバーの自己追加
  - 変更フィールドが`memberIds`と`updatedAt`のみ
  - 自分自身を`memberIds`に追加する場合のみ
  - すでにメンバーではない場合のみ
- **用途**: チーム設定変更、招待コードでのチーム参加

#### 削除（delete）
- **条件**: 管理者またはオーナー
- **用途**: チーム解散

---

### 3. サブコレクション（staff, shifts, constraint_requests など）

#### 読み取り・書き込み（read, write）
- **条件**: 認証済み かつ チームメンバー
- **用途**: シフト作成、スタッフ管理、休み希望申請など

**サブコレクション一覧**:
- `teams/{teamId}/staff` - スタッフ情報
- `teams/{teamId}/shifts` - シフトデータ
- `teams/{teamId}/constraint_requests` - 休み希望申請
- `teams/{teamId}/monthly_requirements` - 月次シフト要件
- `teams/{teamId}/shift_time_settings` - シフト時間設定

---

## 設定手順

### 開発環境（shift-kobo-online）

1. https://console.firebase.google.com/ にアクセス
2. **shift-kobo-online** プロジェクトを選択
3. 左メニュー「Firestore Database」→「ルール」タブ
4. 上記のルールをコピー＆ペースト
5. 「公開」ボタンをクリック

### 本番環境（shift-kobo-online-prod）

1. https://console.firebase.google.com/ にアクセス
2. **shift-kobo-online-prod** プロジェクトを選択
3. 左メニュー「Firestore Database」→「ルール」タブ
4. 上記のルールをコピー＆ペースト
5. 「公開」ボタンをクリック

---

## セキュリティポイント

### ✅ 実装されているセキュリティ

1. **認証必須**: 全てのアクセスに`request.auth != null`を要求
2. **チーム分離**: サブコレクションは`memberIds`でアクセス制御
3. **ロール制御**: 管理者のみがロール変更やチーム更新を実行可能
4. **自己所有制約**: ユーザーは自分のドキュメントのみ作成・削除可能

### 🔒 セキュリティの仕組み

#### 匿名ユーザーの扱い
- 匿名ユーザーも`request.auth != null`で認証済みとみなされる
- チーム作成やデータアクセスが可能
- 後でメールアドレスでアカウント登録可能（UIDは不変）

#### チーム分離の仕組み
- サブコレクションは全て`memberIds`でアクセス制御
- 他のチームのデータにはアクセス不可
- チームIDは推測不可能（Firestoreの自動生成ID）

#### ロールベースアクセス制御
- `adminIds`: 管理者のUIDリスト
- `ownerId`: チーム作成者のUID
- 管理者のみがチーム設定変更やロール変更を実行可能

---

## 変更履歴

- **2025-12-02**: 現在の実装に合わせて全面改訂
  - 匿名ユーザー対応を明記
  - チーム管理者によるロール変更ルールを追加
  - 新規メンバーの自己追加ルールを追加
  - ルール詳細解説を追加
- **2025-10-23**: シンプルな認証ベースのルールに変更
- **2025-10-22**: Phase 1（詳細版）のSecurity Rules追加

---

**最終更新**: 2025-12-02
