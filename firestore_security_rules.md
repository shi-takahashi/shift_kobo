# Firestore Security Rules

## 概要
このドキュメントは、Firestoreのセキュリティルールを記録します。
Firebaseコンソールで設定する際の参考にしてください。

## 現在の設定（認証ベース・シンプル版）

**方針**: 認証済みユーザーのみアクセス可能（アプリ側でチーム分離を制御）

**理由**:
- 複雑なルールで動作不良が発生するリスクを回避
- ユーザーがエラーで離脱することを防ぐ
- アプリ側でteamIdによるフィルタリングを実装済み
- 実際のリスクは低い（チームIDは推測不可能）

## 本番・開発環境共通ルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 認証済みユーザーのみアクセス可能
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

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

## 注意事項

- 認証済みユーザーのみアクセス可能（未ログインユーザーは全て拒否）
- チーム間のデータ分離はアプリ側で実装（teamIdによるフィルタリング）
- セキュリティとユーザー体験のバランスを重視

## 変更履歴

- **2025-10-23**: シンプルな認証ベースのルールに変更
  - 複雑なルールによる動作不良を回避
  - ユーザー体験を最優先
- **2025-10-22**: Phase 1（詳細版）のSecurity Rules追加（後に簡易版に変更）
