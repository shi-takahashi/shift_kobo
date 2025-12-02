# シフト工房 システム設計書

最終更新: 2025-12-02

## 目次
1. [システム概要](#システム概要)
2. [技術スタック](#技術スタック)
3. [アーキテクチャ](#アーキテクチャ)
4. [ディレクトリ構成](#ディレクトリ構成)
5. [データモデル](#データモデル)
6. [状態管理](#状態管理)
7. [Firebase構成](#firebase構成)
8. [主要機能と処理フロー](#主要機能と処理フロー)
9. [ソースコード読解のポイント](#ソースコード読解のポイント)

---

## システム概要

### アプリケーションの目的
**シフト工房**は、管理者のシフト作成を支援するFlutterアプリケーションです。

### 主要機能
- **自動シフト割り当て**: スタッフの制約条件を考慮した公平なシフト自動生成
- **手動編集**: 自動生成されたシフトの調整機能
- **チーム管理**: 複数ユーザーでのデータ共有（オンライン版）
- **休み希望承認フロー**: スタッフが休み希望を申請→管理者が承認
- **シフト表エクスポート**: Excel/画像形式での出力

### プラットフォーム
- **Android版**: Google Play配信（AdMob広告あり）
- **Web版**: Firebase Hosting（広告なし、iOSユーザー向け）
- **iOS版**: 将来対応予定

---

## 技術スタック

### フロントエンド
| 技術 | バージョン | 用途 |
|-----|---------|------|
| Flutter | 3.24.3 | UIフレームワーク |
| Dart | Stable | プログラミング言語 |
| Provider | 6.1.2 | 状態管理 |
| table_calendar | 3.2.0 | カレンダーUI |

### バックエンド・インフラ
| 技術 | 用途 |
|-----|------|
| Firebase Authentication | ユーザー認証（Email/Password、匿名認証） |
| Cloud Firestore | NoSQLデータベース |
| Cloud Functions | サーバーサイド処理（チーム解散、アカウント削除） |
| Firebase Hosting | Web版ホスティング |
| Firebase Messaging (FCM) | Push通知（実装予定） |

### ローカルストレージ
| 技術 | 用途 |
|-----|------|
| Hive | ローカルKVS（オフライン版の名残、データ移行時に使用） |
| Firestore Offline Cache | オンライン版のオフライン対応 |

### その他
| 技術 | 用途 |
|-----|------|
| AdMob | Android版の収益化（バナー、インタースティシャル） |
| Excel | シフト表エクスポート |
| build_runner | コード生成（Hive Adapter） |

---

## アーキテクチャ

### 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Application                     │
│  ┌──────────────────────────────────────────────────┐  │
│  │              UI Layer (Screens)                   │  │
│  │  - Calendar, Staff List, Settings, My Page, etc. │  │
│  └────────────┬─────────────────────────────────────┘  │
│               │                                          │
│  ┌────────────▼─────────────────────────────────────┐  │
│  │         State Management (Provider)               │  │
│  │  - StaffProvider, ShiftProvider, etc.            │  │
│  └────────────┬─────────────────────────────────────┘  │
│               │                                          │
│  ┌────────────▼─────────────────────────────────────┐  │
│  │              Service Layer                        │  │
│  │  - AuthService, ShiftAssignmentService, etc.     │  │
│  └────────────┬─────────────────────────────────────┘  │
│               │                                          │
│  ┌────────────▼─────────────────────────────────────┐  │
│  │               Data Layer                          │  │
│  │  - Model Classes (Staff, Shift, Team, etc.)      │  │
│  └────────────┬─────────────────────────────────────┘  │
└───────────────┼──────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────┐
│                     Firebase Backend                      │
│  ┌────────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │ Authentication │  │  Firestore  │  │  Functions   │  │
│  │  (Email/Anon)  │  │  (NoSQL DB) │  │  (Node.js)   │  │
│  └────────────────┘  └─────────────┘  └──────────────┘  │
│  ┌────────────────┐  ┌─────────────┐                     │
│  │    Hosting     │  │  Messaging  │                     │
│  │   (Web版)      │  │    (FCM)    │                     │
│  └────────────────┘  └─────────────┘                     │
└──────────────────────────────────────────────────────────┘
```

### レイヤー構成

#### 1. UI Layer (Screens)
- **役割**: ユーザーインターフェース、画面表示
- **場所**: `lib/screens/`
- **特徴**:
  - StatefulWidget/StatelessWidgetで実装
  - Providerでデータを購読
  - ビジネスロジックは持たない（Providerに委譲）

#### 2. State Management (Provider)
- **役割**: 状態管理、ビジネスロジック
- **場所**: `lib/providers/`
- **特徴**:
  - ChangeNotifierを継承
  - Firestoreとリアルタイム同期（StreamSubscription）
  - UIに状態変更を通知（notifyListeners）

#### 3. Service Layer
- **役割**: 横断的な処理、複雑なビジネスロジック
- **場所**: `lib/services/`
- **特徴**:
  - 認証（AuthService）
  - シフト自動割り当て（ShiftAssignmentService）
  - データ移行（MigrationService）
  - 広告（AdService）

#### 4. Data Layer (Models)
- **役割**: データモデル定義
- **場所**: `lib/models/`
- **特徴**:
  - Firestoreとの相互変換メソッド（toFirestore/fromFirestore）
  - Hiveアダプター（オフライン版の名残）
  - immutableなデータクラス

---

## ディレクトリ構成

```
shift_kobo/
├── lib/
│   ├── main.dart                        # アプリエントリーポイント
│   │
│   ├── models/                          # データモデル
│   │   ├── app_user.dart                # アプリユーザー（認証情報）
│   │   ├── team.dart                    # チーム
│   │   ├── staff.dart                   # スタッフ
│   │   ├── shift.dart                   # シフト
│   │   ├── constraint_request.dart      # 休み希望申請
│   │   ├── shift_constraint.dart        # シフト制約条件
│   │   ├── shift_time_setting.dart      # シフト時間設定
│   │   └── *.g.dart                     # 自動生成ファイル（Hive）
│   │
│   ├── providers/                       # 状態管理（Provider）
│   │   ├── staff_provider.dart          # スタッフ管理
│   │   ├── shift_provider.dart          # シフト管理
│   │   ├── shift_time_provider.dart     # シフト時間設定
│   │   ├── constraint_request_provider.dart # 休み希望申請
│   │   └── monthly_requirements_provider.dart # 月次シフト要件
│   │
│   ├── services/                        # サービス層
│   │   ├── auth_service.dart            # 認証処理
│   │   ├── shift_assignment_service.dart # シフト自動割り当て
│   │   ├── ad_service.dart              # AdMob広告
│   │   ├── migration_service.dart       # Hive→Firestore移行
│   │   ├── notification_service.dart    # Push通知（実装予定）
│   │   └── invitation_service.dart      # チーム招待
│   │
│   ├── screens/                         # 画面
│   │   ├── auth/                        # 認証関連画面
│   │   │   ├── welcome_screen.dart      # ウェルカム画面
│   │   │   ├── role_selection_screen.dart # 役割選択
│   │   │   ├── login_screen.dart        # ログイン
│   │   │   ├── signup_screen.dart       # 新規登録
│   │   │   └── register_account_screen.dart # アカウント登録
│   │   │
│   │   ├── team/                        # チーム関連画面
│   │   │   ├── team_creation_screen.dart # チーム作成
│   │   │   ├── join_team_screen.dart    # チーム参加
│   │   │   └── team_invite_screen.dart  # チーム招待
│   │   │
│   │   ├── approval/                    # 承認関連画面
│   │   │   └── constraint_approval_screen.dart # 休み希望承認
│   │   │
│   │   ├── migration/                   # データ移行画面
│   │   │   └── migration_onboarding_screen.dart
│   │   │
│   │   ├── calendar_screen.dart         # カレンダー（メイン画面）
│   │   ├── staff_list_screen.dart       # スタッフ一覧
│   │   ├── my_page_screen.dart          # マイページ（休み希望申請）
│   │   ├── settings_screen.dart         # 設定
│   │   ├── help_screen.dart             # ヘルプ
│   │   ├── home_screen.dart             # ホーム（ナビゲーション）
│   │   └── export_screen.dart           # エクスポート
│   │
│   ├── widgets/                         # 共通ウィジェット
│   │   ├── auth_gate.dart               # 認証ゲート（ルーティング）
│   │   └── banner_ad_widget.dart        # バナー広告
│   │
│   ├── utils/                           # ユーティリティ
│   │   ├── japanese_calendar_utils.dart # 日本の祝日判定
│   │   └── test_data_helper.dart        # テストデータ生成
│   │
│   ├── firebase_options.dart            # Firebase設定（開発環境）
│   └── firebase_options_prod.dart       # Firebase設定（本番環境）
│
├── functions/                           # Cloud Functions
│   ├── index.js                         # エントリーポイント
│   └── package.json                     # Node.js依存関係
│
├── web/                                 # Web版設定
│   ├── index.html
│   └── manifest.json                    # PWA設定
│
├── android/                             # Android固有設定
├── ios/                                 # iOS固有設定
│
├── docs/                                # ドキュメント
│   └── privacy-policy.html              # プライバシーポリシー
│
├── pubspec.yaml                         # Flutter依存関係
├── firebase.json                        # Firebase設定
├── .firebaserc                          # Firebaseプロジェクト選択
│
└── *.md                                 # プロジェクトドキュメント
    ├── CLAUDE.md                        # 開発進捗サマリー
    ├── SYSTEM_DESIGN.md                 # このファイル
    ├── ACCOUNT_DELETION_SPEC.md         # アカウント削除仕様
    ├── APPROVAL_FLOW_SPEC.md            # 承認フロー仕様
    └── README-online.md                 # オンライン化詳細計画
```

---

## データモデル

### Firestoreデータ構造

```
firestore/
├── users/{userId}                       # ユーザー情報
│   ├── uid: String                      # Firebase Auth UID
│   ├── email: String?                   # メールアドレス（匿名はnull）
│   ├── displayName: String              # 表示名
│   ├── role: String                     # "admin" | "member"
│   ├── teamId: String?                  # 所属チームID
│   ├── fcmToken: String?                # Push通知トークン
│   ├── notificationSettings: Map        # 通知設定
│   ├── createdAt: Timestamp
│   └── updatedAt: Timestamp
│
├── teams/{teamId}                       # チーム情報
│   ├── name: String                     # チーム名
│   ├── ownerId: String                  # オーナーのuid
│   ├── adminIds: List<String>           # 管理者のuidリスト
│   ├── memberIds: List<String>          # スタッフのuidリスト
│   ├── inviteCode: String               # 招待コード（8文字）
│   ├── shiftDeadline: Timestamp?        # 休み希望締め日
│   ├── createdAt: Timestamp
│   └── updatedAt: Timestamp
│   │
│   ├── staff/{staffId}                  # スタッフ（サブコレクション）
│   │   ├── name: String                 # スタッフ名
│   │   ├── email: String?               # メールアドレス
│   │   ├── phoneNumber: String?         # 電話番号
│   │   ├── maxShiftsPerMonth: Int       # 月間最大シフト数
│   │   ├── preferredDaysOff: List<Int>  # 希望曜日休み
│   │   ├── unavailableShiftTypes: List  # 対応不可シフト種別
│   │   ├── specificDaysOff: List        # 固定休み日付
│   │   ├── isActive: Boolean            # 有効/無効
│   │   ├── userId: String?              # 紐付きユーザーID
│   │   ├── createdAt: Timestamp
│   │   └── updatedAt: Timestamp
│   │
│   ├── shifts/{shiftId}                 # シフト（サブコレクション）
│   │   ├── staffId: String              # 担当スタッフID
│   │   ├── date: Timestamp              # シフト日時
│   │   ├── shiftTypeName: String        # シフト種別名
│   │   ├── startTime: Timestamp         # 開始時刻
│   │   ├── endTime: Timestamp           # 終了時刻
│   │   ├── createdAt: Timestamp
│   │   └── updatedAt: Timestamp
│   │
│   ├── constraint_requests/{requestId}  # 休み希望申請
│   │   ├── staffId: String              # 申請スタッフID
│   │   ├── userId: String               # 申請ユーザーID
│   │   ├── date: Timestamp              # 休み希望日
│   │   ├── shiftTypeName: String?       # シフト種別（nullは終日）
│   │   ├── reason: String?              # 理由
│   │   ├── status: String               # "pending" | "approved" | "rejected"
│   │   ├── reviewedBy: String?          # 承認/却下した管理者ID
│   │   ├── reviewedAt: Timestamp?       # 承認/却下日時
│   │   ├── createdAt: Timestamp
│   │   └── updatedAt: Timestamp
│   │
│   ├── monthly_requirements/{monthId}   # 月次シフト要件
│   │   ├── month: String                # "YYYY-MM"
│   │   ├── dailyRequirements: Map       # {"YYYY-MM-DD": {"早番": 2, ...}}
│   │   ├── createdAt: Timestamp
│   │   └── updatedAt: Timestamp
│   │
│   └── shift_time_settings/{settingId}  # シフト時間設定
│       ├── shiftTypeName: String        # シフト種別の内部名
│       ├── displayName: String          # 表示名
│       ├── startTime: String            # "HH:mm"
│       ├── endTime: String              # "HH:mm"
│       ├── color: String                # 色（#RRGGBB）
│       ├── displayOrder: Int            # 表示順序
│       ├── createdAt: Timestamp
│       └── updatedAt: Timestamp
```

### 主要モデルクラス

#### AppUser
```dart
class AppUser {
  final String uid;              // Firebase Auth UID
  final String? email;           // メールアドレス（匿名はnull）
  final String displayName;      // 表示名
  final UserRole role;           // admin | member
  final String? teamId;          // 所属チームID
  final String? fcmToken;        // FCMトークン

  // Firestore変換
  factory AppUser.fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore();
}
```

#### Team
```dart
class Team {
  final String id;               // チームID
  final String name;             // チーム名
  final String ownerId;          // オーナーID
  final List<String> adminIds;   // 管理者IDリスト
  final List<String> memberIds;  // スタッフIDリスト
  final String inviteCode;       // 招待コード（8文字）

  bool isAdmin(String uid);      // 管理者判定
  bool isMember(String uid);     // スタッフ判定
}
```

#### Staff
```dart
class Staff {
  final String id;                       // スタッフID
  final String name;                     // スタッフ名
  final String? email;                   // メールアドレス
  final int maxShiftsPerMonth;           // 月間最大シフト数
  final List<int> preferredDaysOff;      // 希望曜日休み
  final List<String> unavailableShiftTypes; // 対応不可シフト
  final bool isActive;                   // 有効フラグ
  final String? userId;                  // 紐付きユーザーID
}
```

#### Shift
```dart
class Shift {
  final String id;               // シフトID
  final String staffId;          // 担当スタッフID
  final DateTime date;           // シフト日時
  final String shiftTypeName;    // シフト種別名
  final DateTime startTime;      // 開始時刻
  final DateTime endTime;        // 終了時刻
}
```

#### ConstraintRequest
```dart
class ConstraintRequest {
  final String id;               // リクエストID
  final String staffId;          // 申請スタッフID
  final String userId;           // 申請ユーザーID
  final DateTime date;           // 休み希望日
  final String? shiftTypeName;   // シフト種別（nullは終日）
  final RequestStatus status;    // pending | approved | rejected
  final String? reviewedBy;      // 承認/却下した管理者ID
}
```

---

## 状態管理

### Providerパターン

アプリ全体で**Provider**パッケージを使用した状態管理を採用。

#### Provider一覧

| Provider | 役割 | データソース |
|---------|------|------------|
| **StaffProvider** | スタッフ管理 | `teams/{teamId}/staff/` |
| **ShiftProvider** | シフト管理 | `teams/{teamId}/shifts/` |
| **ShiftTimeProvider** | シフト時間設定 | `teams/{teamId}/shift_time_settings/` |
| **ConstraintRequestProvider** | 休み希望申請 | `teams/{teamId}/constraint_requests/` |
| **MonthlyRequirementsProvider** | 月次シフト要件 | `teams/{teamId}/monthly_requirements/` |

#### Providerの基本構造

```dart
class StaffProvider extends ChangeNotifier {
  final String? teamId;                    // チームID
  final FirebaseFirestore _firestore;      // Firestoreインスタンス
  List<Staff> _staffList = [];             // ローカルキャッシュ
  StreamSubscription? _staffSubscription;  // リアルタイム購読

  List<Staff> get staffList => _staffList; // ゲッター

  // コンストラクタ: リアルタイム購読開始
  StaffProvider({this.teamId}) {
    if (teamId != null) {
      _subscribeToStaff();
    }
  }

  // Firestoreからリアルタイム購読
  void _subscribeToStaff() {
    _staffSubscription = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .snapshots()
        .listen((snapshot) {
      _staffList = snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      notifyListeners(); // UIに通知
    });
  }

  // CRUD操作
  Future<void> addStaff(Staff staff) async { ... }
  Future<void> updateStaff(Staff staff) async { ... }
  Future<void> deleteStaff(String staffId) async { ... }

  // クリーンアップ
  @override
  void dispose() {
    _staffSubscription?.cancel();
    super.dispose();
  }
}
```

#### Providerの利用（画面側）

```dart
// Providerの提供
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => StaffProvider(teamId: teamId)),
    ChangeNotifierProvider(create: (_) => ShiftProvider(teamId: teamId)),
  ],
  child: MyApp(),
)

// Providerの購読（Widget内）
final staffProvider = context.watch<StaffProvider>(); // リアルタイム更新
final staffList = staffProvider.staffList;

// Providerのメソッド呼び出し
context.read<StaffProvider>().addStaff(newStaff); // 読み取り専用
```

---

## Firebase構成

### 環境分離

| 環境 | プロジェクトID | 用途 | ビルド方法 |
|-----|--------------|------|----------|
| **開発環境** | `shift-kobo-online` | 開発・テスト | デフォルト |
| **本番環境** | `shift-kobo-prod` | リリース版 | `--dart-define=FIREBASE_ENV=prod` |

```bash
# 開発環境（デフォルト）
flutter run

# 本番環境
flutter build apk --release --dart-define=FIREBASE_ENV=prod
```

### Firebase機能の使い分け

#### 1. Authentication
- **Email/Password**: 通常のアカウント登録
- **匿名認証**: ワンタップで開始（後でEmail登録可能）
- **アカウントアップグレード**: 匿名→Email変換（UIDは不変）

```dart
// 匿名ログイン
await FirebaseAuth.instance.signInAnonymously();

// アカウントアップグレード（UIDは変わらない）
final credential = EmailAuthProvider.credential(email: email, password: password);
await currentUser.linkWithCredential(credential);
```

#### 2. Firestore
- **リアルタイム同期**: StreamSubscriptionで自動更新
- **オフライン対応**: キャッシュ有効化（persistenceEnabled: true）
- **Security Rules**: ロールベースアクセス制御（admin/member）

```dart
// Firestoreの初期化（オフラインキャッシュ有効化）
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

#### 3. Cloud Functions
- **チーム解散**: チーム全体のデータ削除（GDPR対応）
- **スタッフアカウント削除**: Admin SDK使用（クライアントからは削除不可）

```javascript
// functions/index.js
exports.deleteTeamAndAllAccounts = onCall(async (request) => {
  // チーム全体を削除
  // 全メンバーのAuthenticationを削除（GDPR対応）
});
```

#### 4. Firebase Hosting（Web版）
- **URL**: `https://shift-kobo-online.web.app`
- **デプロイ**: `firebase deploy --only hosting`

---

## 主要機能と処理フロー

### 1. 認証フロー

```
┌─────────────────┐
│ アプリ起動      │
└────────┬────────┘
         │
    ┌────▼─────┐
    │AuthGate  │ ← StreamBuilder(authStateChanges)
    └────┬─────┘
         │
    ┌────▼──────────────────┐
    │ ログイン状態？        │
    └────┬──────────────────┘
         │
    ┌────▼────┐         ┌─────────────────┐
    │ YES     │         │ NO               │
    └────┬────┘         └────┬─────────────┘
         │                   │
    ┌────▼─────────┐    ┌───▼──────────────┐
    │ チーム所属？  │    │ 役割選択画面     │
    └────┬─────────┘    │ - 管理者         │
         │              │ - スタッフ       │
    ┌────▼────┐         │ - 匿名ログイン   │
    │ YES     │         └──────────────────┘
    └────┬────┘
         │
    ┌────▼──────────┐
    │ HomeScreen    │
    │ (カレンダー)   │
    └───────────────┘
```

### 2. シフト自動割り当てフロー

```
┌─────────────────────────────┐
│ 自動割り当てボタン押下       │
└────────┬────────────────────┘
         │
    ┌────▼────────────────────┐
    │ ShiftAssignmentService  │
    │ .autoAssignShifts()     │
    └────────┬────────────────┘
             │
    ┌────────▼────────────────────────┐
    │ 1. 有効なスタッフ取得             │
    │    - isActive = true             │
    │    - maxShiftsPerMonth > 0       │
    └────────┬────────────────────────┘
             │
    ┌────────▼────────────────────────┐
    │ 2. 制約条件を考慮して割り当て     │
    │    - 希望休み                    │
    │    - 対応不可シフト種別           │
    │    - 固定休み日                  │
    │    - 月間最大シフト数             │
    │    - 連続勤務制限                │
    └────────┬────────────────────────┘
             │
    ┌────────▼────────────────────────┐
    │ 3. 公平性を保つため              │
    │    - シフト回数の少ないスタッフ優先│
    │    - ランダム性を持たせる         │
    └────────┬────────────────────────┘
             │
    ┌────────▼────────────────────────┐
    │ 4. Firestoreに保存               │
    │    - ShiftProvider経由           │
    └─────────────────────────────────┘
```

### 3. 休み希望承認フロー

```
[スタッフ側]                         [管理者側]
    │                                    │
    ├─ 1. 休み希望申請                   │
    │   (My Page)                        │
    │                                    │
    ├─ 2. Firestore保存                 │
    │   constraint_requests/             │
    │   status: pending                  │
    │                                    │
    │                              ┌─────▼─────────┐
    │                              │ 3. 申請一覧表示 │
    │                              │   (承認画面)    │
    │                              └─────┬─────────┘
    │                                    │
    │                              ┌─────▼─────────┐
    │                              │ 4. 承認/却下   │
    │                              └─────┬─────────┘
    │                                    │
    │                              ┌─────▼─────────┐
    │                              │ 5. Firestore更新│
    │                              │ status: approved│
    │◄─────────────────────────────┤ or rejected    │
    │                              └────────────────┘
    │
    ├─ 6. リアルタイム更新
    │   (StreamBuilder)
    │
    ├─ 7. Push通知受信
        （実装予定）
```

### 4. チーム作成・参加フロー

```
[管理者]                              [スタッフ]
    │                                     │
    ├─ 1. チーム作成                       │
    │   - チーム名入力                     │
    │   - Firestore保存                   │
    │   - 招待コード自動生成（8文字）       │
    │                                     │
    ├─ 2. 招待コード共有                  │
    │   (LINEなど)                        │
    │                                     │
    │                               ┌─────▼─────────┐
    │                               │ 3. 招待コード入力│
    │                               │   (参加画面)     │
    │                               └─────┬─────────┘
    │                                     │
    │                               ┌─────▼─────────┐
    │                               │ 4. チーム参加   │
    │                               │ - users更新     │
    │                               │ - teams更新     │
    │◄──────────────────────────────┤ - 自動紐付け    │
    │                               └────────────────┘
    │
    ├─ 5. リアルタイム更新
        (StreamBuilder)
```

---

## ソースコード読解のポイント

### 1. エントリーポイント

**ファイル**: `lib/main.dart`

```dart
void main() async {
  // 1. Hive初期化（オフライン版の名残）
  await Hive.initFlutter();

  // 2. AdMob初期化（Web版では無効）
  if (!kIsWeb) {
    await AdService.initialize();
  }

  // 3. Firebase初期化（環境分離）
  await Firebase.initializeApp(
    options: firebaseEnv == 'prod'
      ? prod_options.DefaultFirebaseOptions.currentPlatform
      : dev_options.DefaultFirebaseOptions.currentPlatform,
  );

  // 4. アプリ起動
  runApp(const MyApp());
}
```

### 2. ルーティング（AuthGate）

**ファイル**: `lib/widgets/auth_gate.dart`

```dart
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // ログイン済み
          return StreamBuilder<AppUser?>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots()
                .map((doc) => AppUser.fromFirestore(doc)),
            builder: (context, userSnapshot) {
              final appUser = userSnapshot.data;

              if (appUser?.teamId != null) {
                // チーム所属済み → ホーム画面
                return HomeScreen(appUser: appUser);
              } else {
                // チーム未所属 → チーム作成/参加画面
                return JoinTeamScreen(userId: snapshot.data!.uid);
              }
            },
          );
        } else {
          // 未ログイン → 役割選択画面
          return const RoleSelectionScreen();
        }
      },
    );
  }
}
```

### 3. Provider初期化（HomeScreen）

**ファイル**: `lib/screens/home_screen.dart`

```dart
class HomeScreen extends StatelessWidget {
  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // teamIdを使ってProviderを初期化
        ChangeNotifierProvider(
          create: (_) => StaffProvider(teamId: appUser.teamId),
        ),
        ChangeNotifierProvider(
          create: (_) => ShiftProvider(teamId: appUser.teamId),
        ),
        // ...他のProvider
      ],
      child: _HomeScreenContent(appUser: appUser),
    );
  }
}
```

### 4. Firestoreリアルタイム同期

**ファイル**: `lib/providers/staff_provider.dart`

```dart
void _subscribeToStaff() {
  _staffSubscription = _firestore
      .collection('teams')
      .doc(teamId)
      .collection('staff')
      .snapshots()              // ← リアルタイムストリーム
      .listen((snapshot) {      // ← データ変更時に発火
    _staffList = snapshot.docs
        .map((doc) => Staff.fromFirestore(doc))
        .toList();
    notifyListeners();          // ← UIに通知
  });
}
```

### 5. Web版とアプリ版の分岐

**パターン1: AdMob無効化**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// AdMobの初期化（Web版では無効）
if (!kIsWeb) {
  await AdService.initialize();
}
```

**パターン2: Push通知無効化**
```dart
// FCMの初期化（Web版では無効）
if (!kIsWeb) {
  await FirebaseMessaging.instance.requestPermission();
}
```

**パターン3: バナー広告表示**
```dart
// Web版ではバナー広告を非表示
if (!kIsWeb) {
  BannerAdWidget();
}
```

### 6. エラーハンドリング

```dart
try {
  await _firestore.collection('users').doc(userId).set(data);
} on FirebaseException catch (e) {
  // Firebase固有エラー
  if (e.code == 'permission-denied') {
    throw '権限がありません';
  }
  throw 'エラー: ${e.message}';
} catch (e) {
  // その他のエラー
  throw '予期しないエラー: $e';
}
```

### 7. Cloud Functions呼び出し

**ファイル**: `lib/services/auth_service.dart`

```dart
Future<void> deleteTeamAndAccount(String teamId) async {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'deleteTeamAndAllAccounts',
  );

  final result = await callable.call({
    'teamId': teamId,
  });

  print('結果: ${result.data}');
}
```

---

## よくある開発タスクの実装パターン

### 新しい画面を追加する

1. `lib/screens/` に画面ファイル作成
2. `HomeScreen` または `AuthGate` でルーティング追加
3. 必要に応じてProviderを購読

```dart
// 新しい画面
class NewScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomeProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('新しい画面')),
      body: ListView.builder(
        itemCount: provider.items.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(provider.items[index].name));
        },
      ),
    );
  }
}
```

### 新しいProviderを追加する

1. `lib/providers/` にProviderファイル作成
2. `ChangeNotifier` を継承
3. Firestoreのリアルタイム購読を実装
4. `HomeScreen` でProvider提供

```dart
class NewProvider extends ChangeNotifier {
  final String? teamId;
  List<Item> _items = [];
  StreamSubscription? _subscription;

  List<Item> get items => _items;

  NewProvider({this.teamId}) {
    _subscribe();
  }

  void _subscribe() {
    _subscription = FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
      _items = snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### Firestoreに新しいコレクションを追加する

1. `lib/models/` にモデルクラス作成
2. `fromFirestore` / `toFirestore` メソッド実装
3. Providerでリアルタイム購読
4. Security Rules更新（`firestore.rules`）

```dart
// モデルクラス
class Item {
  final String id;
  final String name;

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
```

---

## セキュリティとプライバシー

### Firestore Security Rules

**ファイル**: `firestore.rules`

- **users**: 自分のドキュメントのみ読み書き可能
- **teams**: チームメンバーのみ読み取り可能、管理者のみ書き込み可能
- **staff, shifts**: チームメンバーのみアクセス可能
- **constraint_requests**: 申請者と管理者のみアクセス可能

詳細は `firestore_security_rules.md` を参照。

### プライバシーポリシー

**ファイル**: `docs/privacy-policy.html`

- GDPR対応
- 収集データ: メールアドレス、表示名、シフトデータ
- 削除権: アカウント削除機能提供

---

## デバッグとトラブルシューティング

### ログ出力の見方

```dart
// デバッグログ
print('デバッグ: $value');

// Firebaseログ
debugPrint('✅ 成功: $message');
debugPrint('❌ エラー: $error');
debugPrint('⚠️ 警告: $warning');
```

### よくあるエラーと対処法

| エラー | 原因 | 対処法 |
|-------|-----|-------|
| `permission-denied` | Security Rulesで拒否 | ログイン状態、ロール、teamId確認 |
| `requires-recent-login` | 再認証が必要 | パスワード再入力で再認証 |
| `email-already-in-use` | メールアドレス重複 | 別のメールアドレス使用 |
| Provider未初期化 | teamIdがnull | AuthGateでチーム所属確認 |

---

## 今後の拡張予定

1. **Push通知実装**（FCM）
2. **一括承認機能**
3. **自動承認設定**
4. **祝日勤務不可設定**
5. **締め日機能**
6. **SNS連携**（Google Sign In、Apple Sign In）

---

## 関連ドキュメント

- **CLAUDE.md**: 開発進捗サマリー
- **ACCOUNT_DELETION_SPEC.md**: アカウント削除機能仕様
- **APPROVAL_FLOW_SPEC.md**: 休み希望承認フロー仕様
- **README-online.md**: オンライン化詳細計画
- **WEB_DEPLOY.md**: Web版デプロイ手順
- **firestore_security_rules.md**: Security Rules仕様

---

**最終更新**: 2025-12-02
**ドキュメント作成者**: Claude Code
