# Web版デプロイ手順

## 📌 環境について

- **開発環境**: https://shift-kobo-online.web.app
- **本番環境**: https://shift-kobo-online-prod.web.app

---

## 🚀 デプロイ手順

### 開発環境（テスト用）にデプロイ

```bash
# 1. Web版をビルド（開発環境用）
flutter build web --release

# 2. 開発環境にデプロイ
firebase deploy --only hosting
```

デプロイ完了後、以下のURLにアクセス:
- https://shift-kobo-online.web.app

**接続先**: 開発環境のFirebaseプロジェクト（shift-kobo-online）

---

### 本番環境にデプロイ

```bash
# 1. 本番環境に切り替え
firebase use shift-kobo-online-prod

# 2. Web版をビルド（本番環境用）
flutter build web --release --dart-define=FIREBASE_ENV=prod

# 3. 本番環境にデプロイ
firebase deploy --only hosting

# 4. 開発環境に戻す（重要！）
firebase use shift-kobo-online
```

デプロイ完了後、以下のURLにアクセス:
- https://shift-kobo-online-prod.web.app

**接続先**: 本番環境のFirebaseプロジェクト（shift-kobo-online-prod）

**⚠️ 重要**:
- 本番環境ビルドでは `--dart-define=FIREBASE_ENV=prod` を必ず指定してください
- 本番環境へのデプロイ後は、必ず開発環境に戻してください

---

## 🔧 環境確認・切り替え

### 現在の環境を確認

```bash
firebase use
```

出力例:
```
Active Project: shift-kobo-online (current)
```

### 環境を切り替え

```bash
# 開発環境に切り替え
firebase use shift-kobo-online

# 本番環境に切り替え
firebase use shift-kobo-online-prod
```

### プロジェクト一覧を表示

```bash
firebase projects:list
```

---

## 🛠️ トラブルシューティング

### ビルドエラーが出る場合

```bash
flutter clean
flutter pub get
flutter build web --release
```

### デプロイに失敗する場合

```bash
# Firebase CLIに再ログイン
firebase logout
firebase login

# 再度デプロイ
firebase deploy --only hosting
```

### どの環境にデプロイしたか忘れた場合

```bash
# デプロイ履歴を確認
firebase hosting:channel:list
```

---

## 📝 デプロイの流れ（推奨）

1. **開発・修正**: コードを修正
2. **開発環境テスト**: 開発環境にデプロイして動作確認
3. **本番環境デプロイ**: 問題なければ本番環境にデプロイ
4. **環境を戻す**: 開発環境に切り替えを忘れずに

---

## ⚡ クイックリファレンス

| 操作 | コマンド |
|------|----------|
| 開発環境にデプロイ | `flutter build web --release && firebase deploy --only hosting` |
| 本番環境にデプロイ | `firebase use shift-kobo-online-prod && flutter build web --release --dart-define=FIREBASE_ENV=prod && firebase deploy --only hosting && firebase use shift-kobo-online` |
| 現在の環境確認 | `firebase use` |
| 開発環境に切り替え | `firebase use shift-kobo-online` |
| 本番環境に切り替え | `firebase use shift-kobo-online-prod` |

---

## 💡 環境の違い

| 項目 | 開発環境 | 本番環境 |
|------|----------|----------|
| Firebase Project | shift-kobo-online | shift-kobo-online-prod |
| Hosting URL | https://shift-kobo-online.web.app | https://shift-kobo-online-prod.web.app |
| ビルドコマンド | `flutter build web --release` | `flutter build web --release --dart-define=FIREBASE_ENV=prod` |
| 用途 | テスト・開発 | 本番リリース |
| データ | テストデータ | 本番データ |

---

## 🗑️ Web版を無効化する（iOS版リリース後）

iOS版アプリをリリースした後、Web版を終了する場合の手順です。

### 本番環境のWeb版を無効化

```bash
# 1. 本番環境に切り替え
firebase use shift-kobo-online-prod

# 2. Hostingを無効化
firebase hosting:disable

# 3. 開発環境に戻す
firebase use shift-kobo-online
```

実行後、https://shift-kobo-online-prod.web.app にアクセスすると404エラーになります。

### 開発環境のWeb版も無効化する場合

```bash
# 開発環境のHostingを無効化
firebase hosting:disable
```

### 注意事項

- **無効化は取り消し可能**: 再度デプロイすれば復活します
- **完全削除はできません**: Firebase Hostingの仕様上、サイト自体は残ります
- **段階的な移行**: まずメンテナンスページをデプロイ → iOS版リリース → 無効化、という流れも可能
