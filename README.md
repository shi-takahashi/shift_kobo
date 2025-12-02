# シフト工房

スタッフのシフトを自動で作成・管理するFlutterアプリケーション

---

## 📱 概要

**シフト工房**は、管理者のシフト作成を支援するアプリです。スタッフの制約条件を考慮した公平なシフト自動生成と、チームでのオンライン共有機能を提供します。

### 主要機能
- ✅ **シフト自動割り当て**: 制約条件を考慮した公平な自動生成
- ✅ **手動編集**: 自動生成されたシフトの調整
- ✅ **チーム管理**: 複数ユーザーでのデータ共有
- ✅ **休み希望承認フロー**: スタッフが申請→管理者が承認
- ✅ **Push通知**: 申請・承認の通知（アプリ版限定）
- ✅ **シフト表エクスポート**: Excel/画像形式での出力

### 技術スタック
- **Frontend**: Flutter 3.24.3, Dart
- **Backend**: Firebase (Authentication, Firestore, Functions, Hosting, Messaging)
- **状態管理**: Provider
- **収益化**: AdMob（Android版）

### プラットフォーム
- **Android版**: Google Play配信（AdMob広告あり）
- **Web版**: Firebase Hosting（広告なし、iOSユーザー向け）
- **iOS版**: 将来対応予定

---

## 📚 ドキュメント

### 開発・運用ドキュメント

| ドキュメント | 用途 |
|------------|------|
| **[CLAUDE.md](CLAUDE.md)** | 開発進捗サマリー（最重要、まずここを読む） |
| **[SYSTEM_DESIGN.md](SYSTEM_DESIGN.md)** | システム設計書（アーキテクチャ、技術仕様） |
| **[WEB_DEPLOY.md](WEB_DEPLOY.md)** | Web版デプロイ手順（開発/本番環境） |
| **[firestore_security_rules.md](firestore_security_rules.md)** | Firestore Security Rules仕様 |
| **[ANNOUNCEMENT_GUIDE.md](ANNOUNCEMENT_GUIDE.md)** | お知らせ機能の運用マニュアル |

---

## 🚀 開発環境セットアップ

### 必要な環境
- Flutter 3.24.3以上
- Dart Stable
- Firebase CLI
- Android Studio / Xcode（プラットフォームに応じて）

### セットアップ手順

```bash
# 1. リポジトリクローン
git clone <repository-url>
cd shift_kobo

# 2. 依存関係インストール
flutter pub get

# 3. モデル生成（Hive Adapter）
flutter pub run build_runner build --delete-conflicting-outputs

# 4. 実行
flutter run                      # Android/iOS
flutter run -d chrome            # Web版（開発）
```

---

## 🛠️ よく使うコマンド

### 実行・ビルド

```bash
# アプリ版実行（開発環境）
flutter run

# Web版実行（開発環境）
flutter run -d chrome

# Android版ビルド（本番環境）
flutter build apk --release --dart-define=FIREBASE_ENV=prod

# Web版ビルド（本番環境）
flutter build web --release --dart-define=FIREBASE_ENV=prod --pwa-strategy=none --base-href /web/
```

### Web版デプロイ

```bash
# 開発環境にデプロイ
flutter build web --release --pwa-strategy=none
rm -rf hosting_root/web && cp -r build/web hosting_root/web
firebase deploy --only hosting

# 本番環境にデプロイ
firebase use shift-kobo-online-prod
flutter build web --release --dart-define=FIREBASE_ENV=prod --pwa-strategy=none --base-href /web/
rm -rf hosting_root/web && cp -r build/web hosting_root/web
firebase deploy --only hosting
firebase use shift-kobo-online  # 開発環境に戻す
```

詳細は **[WEB_DEPLOY.md](WEB_DEPLOY.md)** を参照。

### その他

```bash
# コード解析
flutter analyze

# クリーンビルド
flutter clean
flutter pub get

# モデル再生成
flutter pub run build_runner build --delete-conflicting-outputs

# Firebase環境確認
firebase use

# Firebase環境切り替え
firebase use shift-kobo-online        # 開発環境
firebase use shift-kobo-online-prod   # 本番環境
```

---

## 📂 ディレクトリ構成

```
shift_kobo/
├── lib/
│   ├── main.dart                    # エントリーポイント
│   ├── models/                      # データモデル
│   ├── providers/                   # 状態管理（Provider）
│   ├── services/                    # サービス層
│   ├── screens/                     # 画面
│   ├── widgets/                     # 共通ウィジェット
│   └── utils/                       # ユーティリティ
├── functions/                       # Cloud Functions
├── web/                             # Web版設定
├── android/                         # Android固有設定
├── ios/                             # iOS固有設定
├── docs/                            # ドキュメント
└── hosting_root/                    # Firebase Hosting用
```

詳細は **[SYSTEM_DESIGN.md](SYSTEM_DESIGN.md)** を参照。

---

## 🔐 環境管理

### Firebase環境

| 環境 | プロジェクトID | 用途 |
|-----|---------------|------|
| **開発環境** | `shift-kobo-online` | テスト・開発 |
| **本番環境** | `shift-kobo-online-prod` | 本番リリース |

### ビルド時の環境指定

```bash
# 開発環境（デフォルト）
flutter run

# 本番環境
flutter build apk --release --dart-define=FIREBASE_ENV=prod
```

---

## 📖 プライバシーポリシー

- **開発環境**: https://shift-kobo-online.web.app/privacy-policy.html
- **本番環境**: https://shift-kobo-online-prod.web.app/privacy-policy.html

---

## 📝 ライセンス

Private（個人開発プロジェクト）

---

## 🔗 関連リンク

- **Firebase Console（開発）**: https://console.firebase.google.com/project/shift-kobo-online
- **Firebase Console（本番）**: https://console.firebase.google.com/project/shift-kobo-online-prod
- **Web版（開発）**: https://shift-kobo-online.web.app
- **Web版（本番）**: https://shift-kobo-online-prod.web.app/web/

---

**最終更新**: 2025-12-02
