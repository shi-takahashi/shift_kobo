# Web版デプロイ手順

## 📌 環境について

- **開発環境**: https://shift-kobo-online.web.app
- **本番環境**: https://shift-kobo-online-prod.web.app

---

## 🌐 URL構成

本番環境のURL構成：

- **/** → ランディングページ（アプリ紹介）
- **/web/** → Webアプリ本体
- **/app** → Cloud Function（振り分け）
  - Android → Google Play Store
  - iOS/その他 → /web/ へリダイレクト
- **/privacy-policy.html** → プライバシーポリシー
- **/account-deletion.html** → アカウント削除方法

**ストアの掲載情報**: `https://shift-kobo-online-prod.web.app` を登録

---

## 🚀 デプロイ手順

### 開発環境（テスト用）にデプロイ

```bash
# 1. Web版をビルド（開発環境用、Service Worker無効）
flutter build web --release --pwa-strategy=none

# 2. hosting_rootにコピー
rm -rf hosting_root/web
cp -r build/web hosting_root/web

# 3. 開発環境にデプロイ
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

# 2. Web版をビルド（本番環境用、Service Worker無効、base-href指定）
flutter build web --release --dart-define=FIREBASE_ENV=prod --pwa-strategy=none --base-href /web/

# 3. hosting_rootにコピー
rm -rf hosting_root/web
cp -r build/web hosting_root/web

# 4. 本番環境にデプロイ
firebase deploy --only hosting

# 5. 開発環境に戻す（重要！）
firebase use shift-kobo-online
```

デプロイ完了後、以下のURLにアクセス:
- https://shift-kobo-online-prod.web.app (ランディングページ)
- https://shift-kobo-online-prod.web.app/web/ (Webアプリ)

**接続先**: 本番環境のFirebaseプロジェクト（shift-kobo-online-prod）

**⚠️ 重要**:
- 本番環境ビルドでは `--dart-define=FIREBASE_ENV=prod` を必ず指定してください
- 本番環境ビルドでは `--base-href /web/` を必ず指定してください
- 本番環境へのデプロイ後は、必ず開発環境に戻してください

---

## 📂 hosting_root構成

```
hosting_root/
├── index.html                  # ランディングページ
├── privacy-policy.html         # プライバシーポリシー
├── account-deletion.html       # アカウント削除方法
└── web/                        # Webアプリ本体
    ├── index.html
    ├── main.dart.js
    ├── flutter.js
    └── ...
```

**注意**: `hosting_root/`は手動管理です。ビルド後に`build/web`を`hosting_root/web/`にコピーする必要があります。

---

## 🔄 静的ページの更新

プライバシーポリシーやアカウント削除方法を更新する場合：

```bash
# docsディレクトリのファイルを編集後、hosting_rootにコピー
cp docs/privacy-policy.html hosting_root/privacy-policy.html
cp docs/account-deletion.html hosting_root/account-deletion.html

# デプロイ
firebase deploy --only hosting
```

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
flutter build web --release --dart-define=FIREBASE_ENV=prod --base-href /web/
```

### デプロイに失敗する場合

```bash
# Firebase CLIに再ログイン
firebase logout
firebase login

# 再度デプロイ
firebase deploy --only hosting
```

### Webアプリが表示されない場合

1. ブラウザのキャッシュをクリア（Cmd+Shift+R または Ctrl+Shift+R）
2. シークレットモードで確認
3. `--base-href /web/` を指定してビルドし直す

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
| 開発環境にデプロイ | `flutter build web --release --pwa-strategy=none && rm -rf hosting_root/web && cp -r build/web hosting_root/web && firebase deploy --only hosting` |
| 本番環境にデプロイ | `firebase use shift-kobo-online-prod && flutter build web --release --dart-define=FIREBASE_ENV=prod --pwa-strategy=none --base-href /web/ && rm -rf hosting_root/web && cp -r build/web hosting_root/web && firebase deploy --only hosting && firebase use shift-kobo-online` |
| 現在の環境確認 | `firebase use` |
| 開発環境に切り替え | `firebase use shift-kobo-online` |
| 本番環境に切り替え | `firebase use shift-kobo-online-prod` |

---

## 💡 環境の違い

| 項目 | 開発環境 | 本番環境 |
|------|----------|----------|
| Firebase Project | shift-kobo-online | shift-kobo-online-prod |
| Hosting URL | https://shift-kobo-online.web.app | https://shift-kobo-online-prod.web.app |
| ビルドコマンド | `flutter build web --release --pwa-strategy=none` | `flutter build web --release --dart-define=FIREBASE_ENV=prod --pwa-strategy=none --base-href /web/` |
| 用途 | テスト・開発 | 本番リリース |
| データ | テストデータ | 本番データ |
| URL構成 | / → Webアプリ | / → ランディングページ<br>/web/ → Webアプリ |

---

## 🔐 セキュリティとAPI制限

### Google API キー公開警告について

Web版デプロイ後、Googleから「APIキーが一般公開されています」という警告メールが届くことがありますが、**これは正常な動作です**。

#### なぜ警告が来るのか
- Firebase Web APIキーはブラウザで実行されるため、必然的に公開されます
- ビルドされた`build/web`内のJavaScriptにも含まれており、隠すことは不可能です
- GoogleがGitHub等でAPIキーを検出すると自動的に警告メールを送信します

#### 安全性について
- **Firebase Web APIキーは公開前提の設計です**（Firebase公式も明言）
- APIキーは単なるプロジェクト識別子であり、それ自体はセキュリティリスクではありません
- 実際のセキュリティは以下で担保されています：
  - **Firestore Security Rules**（データアクセス制限）
  - **Firebase Authentication**（認証）
  - **API制限**（オプション）

#### 対応方法

**基本的には無視してOK**ですが、警告を止めたい場合は以下の手順でAPI制限を設定できます：

```bash
# Google Cloud Consoleにアクセス
# https://console.cloud.google.com/

# 1. 該当プロジェクト（shift-kobo-online-prod）を選択
# 2. 「APIとサービス」→「認証情報」
# 3. 該当のAPIキー（AIzaSy...）をクリック
# 4. 「アプリケーションの制限」で「HTTPリファラー」を選択
# 5. 「ウェブサイトの制限」に以下を追加：
#    - https://shift-kobo-online-prod.web.app/*
#    - https://shift-kobo-online-prod.firebaseapp.com/*
# 6. 保存
```

**注意**：
- API制限はオプションです（設定しなくても問題ありません）
- 制限を設定すると、指定したドメイン以外からのアクセスが拒否されます
- 開発環境（localhost）でテストする場合は、`http://localhost/*`も追加してください

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
