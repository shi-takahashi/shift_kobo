# シフト工房 オンライン化 開発計画

## 📋 実装方針サマリー（2025-10-15決定）

### 主要決定事項
- ✅ **完全オンライン化**: Hive完全削除、Firestoreのみ使用
- ✅ **オフライン対応**: Firestoreのキャッシュ機能のみ（`persistenceEnabled: true`）
- ✅ **認証**: Firebase Authentication（Email/Password）
- ✅ **データ移行**: 既存バックアップJSON → Firestoreサブコレクション
- ✅ **自動生成**: クライアント実行（既存アルゴリズム維持）
- ✅ **広告**: Android版はAdMob（メイン収益源）、Web版はAdSense（赤字覚悟）
- ✅ **開発期間**: 7週間（Android版）+ 2週間（Web版）
- ✅ **プラットフォーム戦略**:
  - Android版アプリ（管理者+メンバー全員）→ メイン
  - Web版（iOSユーザー救済）→ 暫定
  - iOS版アプリ（採算ライン到達後）→ Web版クローズ

### 技術スタック
```
Firebase Core 3.3.0
├─ Firebase Auth 5.1.4 (Email/Password認証)
├─ Cloud Firestore 5.2.1 (データベース + オフラインキャッシュ)
└─ Firebase Messaging 15.0.4 (Push通知基盤)

削除予定
├─ Hive
└─ Hive Flutter
```

### 実装可能性
**✅ 実装可能** - 主な理由:
1. 既存バックアップ構造が完璧（toJson/fromJson完備）
2. Provider構造は維持、データソースのみ変更
3. 既存モデルがそのまま使える
4. Firebase無料枠で小規模チーム対応可能

---

## 1. 開発目的
- 既存オフライン版（管理者専用）を**完全オンライン化**
- 管理者・メンバーの権限分離
- チーム単位でのシフト共有
- 休み希望入力・締め日管理
- 年内リリースを目標
- **決定事項**: Hive完全削除、Firestoreのみ使用（キャッシュ機能でオフライン対応）

## 2. ユーザー権限設計

| 種別 | 権限 |
|------|------|
| 管理者 | シフト作成・編集・削除、休み希望確認・承認、チーム管理、締め日設定 |
| メンバー | シフト閲覧、休み希望入力（締め日まで） |

権限による画面・操作制御：
- ログイン時にユーザーロール判定（Firebase Authentication + Firestore）
- 管理者：全操作可能
- メンバー：シフト閲覧＋自分の休み希望のみ入力、締め日後は入力不可
- UI上でも権限に応じて表示切替・入力非活性化

## 3. 休み希望・締め日ルール
- シフト単位または月単位で締め日を設定
- メンバーは締め日まで休み希望を入力可能
- 締め日後は管理者のみ編集可能
- Firestoreで締め日管理、アプリ側で入力制御

## 4. Firestore構造設計（詳細版）

### 4.1 コレクション構造

```
users/{userId}
  - uid: string (Firebase Auth UID)
  - email: string
  - displayName: string
  - role: "admin" | "member"
  - teamId: string (所属チームID)
  - createdAt: timestamp
  - updatedAt: timestamp

teams/{teamId}
  - name: string (チーム名)
  - ownerId: string (作成者のuserId)
  - adminIds: string[] (管理者のuidリスト)
  - memberIds: string[] (メンバーのuidリスト)
  - shiftDeadline: timestamp (休み希望締め日)
  - createdAt: timestamp
  - updatedAt: timestamp

  /staff/{staffId}  (サブコレクション)
    - id: string (既存のstaffId維持)
    - userId: string | null (ユーザーと紐づけ、未登録ならnull)
    - name: string
    - phoneNumber: string
    - email: string
    - maxShiftsPerMonth: int
    - isActive: bool
    - preferredDaysOff: int[] (曜日: 1-7)
    - unavailableShiftTypes: string[]
    - specificDaysOff: string[] (ISO8601日付)
    - createdAt: timestamp
    - updatedAt: timestamp

  /shifts/{shiftId}  (サブコレクション)
    - id: string
    - date: timestamp
    - staffId: string
    - shiftType: string
    - startTime: timestamp
    - endTime: timestamp
    - note: string
    - createdAt: timestamp
    - updatedAt: timestamp

  /constraints/{constraintId}  (サブコレクション)
    - id: string
    - staffId: string
    - date: timestamp
    - isAvailable: bool
    - reason: string
    - createdAt: timestamp
    - updatedAt: timestamp

  /shift_time_settings/{settingId}  (サブコレクション)
    - shiftType: int (enum index)
    - customName: string
    - startTime: string ("HH:mm")
    - endTime: string ("HH:mm")
    - isActive: bool

  /shift_requirements/{shiftType}  (サブコレクション)
    - shiftType: string
    - requiredCount: int (1日あたり必要人数)
```

### 4.2 既存バックアップからの移行マッピング

| 既存 (Hive) | 移行先 (Firestore) |
|-------------|-------------------|
| staff Box | teams/{teamId}/staff |
| shifts Box | teams/{teamId}/shifts |
| constraints Box | teams/{teamId}/constraints |
| shift_time_settings Box | teams/{teamId}/shift_time_settings |
| SharedPreferences (shift_requirement_*) | teams/{teamId}/shift_requirements |

### 4.3 Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ユーザー情報
    match /users/{userId} {
      allow read: if request.auth.uid == userId
                  || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow write: if request.auth.uid == userId;
    }

    // チーム情報
    match /teams/{teamId} {
      allow read: if request.auth.uid in resource.data.adminIds
                  || request.auth.uid in resource.data.memberIds;
      allow write: if request.auth.uid in resource.data.adminIds;

      // スタッフ情報（チームメンバー全員が閲覧、管理者のみ編集）
      match /staff/{staffId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
        allow write: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
      }

      // シフト情報（チームメンバー全員が閲覧、管理者のみ編集）
      match /shifts/{shiftId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
        allow write: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
      }

      // 休み希望（自分のものは編集可、締め日後は管理者のみ）
      match /constraints/{constraintId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
        allow create, update: if (request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds
                                  && request.resource.data.staffId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.staffId
                                  && request.time < get(/databases/$(database)/documents/teams/$(teamId)).data.shiftDeadline)
                                  || request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
        allow delete: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
      }

      // シフト時間設定・月間シフト設定（管理者のみ編集）
      match /shift_time_settings/{settingId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
        allow write: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
      }

      match /shift_requirements/{requirementId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
        allow write: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
      }
    }
  }
}
```

## 5. 年内リリース向け機能整理

### 必須機能
- 管理者・メンバー権限によるログイン
- 管理者：シフト作成・編集・削除
- メンバー：シフト閲覧、休み希望入力（締め日まで）
- 締め日制御（休み希望入力期限）
- オフライン版からFirebaseへのデータ移行
- 基本UI（権限に応じた画面切替）

### Push通知
- 送信仕組みのみ準備（Firebase Cloud Messaging）
- リリース段階では通知送信は後回し

### 後回し機能（リリース後追加）
- 実際のシフト変更通知
- チーム招待・管理機能
- 広告収益・有料版
- 高度なUI改善・添付ファイル拡張

## 6. 開発ロードマップ（1人開発想定・7週間）

| 週 | フェーズ | タスク詳細 | 重要度 |
|----|---------|-----------|--------|
| **1週目** | Firebase基盤 | ・Firebase初期設定（コンソール・Android/iOS設定）<br>・Firebase Auth実装（Email/Password）<br>・ログイン/サインアップ画面作成<br>・チーム作成画面<br>・Firestore基本接続確認 | ⭐⭐⭐ |
| **2週目** | データ移行 | ・MigrationService作成<br>・データ移行画面実装<br>・バックアップファイル→Firestore移行機能<br>・移行テスト（サンプルデータ）<br>・Hive削除処理 | ⭐⭐⭐ |
| **3週目** | 管理者機能 | ・Provider改修（Firestore対応）<br>・カレンダー画面のFirestore連携<br>・シフトCRUD機能（Firestore版）<br>・スタッフ管理のFirestore連携<br>・権限チェック実装（管理者のみ） | ⭐⭐⭐ |
| **4週目** | メンバー機能 | ・マイシフト画面作成<br>・休み希望入力画面作成<br>・カレンダー画面の閲覧モード<br>・自分のシフトハイライト<br>・メンバー用ナビゲーション | ⭐⭐⭐ |
| **5週目** | 締め日制御 | ・設定画面に締め日設定追加<br>・休み希望入力の締め日制御<br>・Security Rules詳細化<br>・権限別UI制御の最終調整<br>・メンバー管理画面（招待準備） | ⭐⭐ |
| **6週目** | FCM・テスト | ・Firebase Cloud Messaging基盤設定<br>・テスト通知送信<br>・既存ユーザーでの移行テスト<br>・新規ユーザーでの動作確認<br>・UI調整・バグ修正 | ⭐⭐ |
| **7週目** | リリース準備 | ・少人数テストチーム検証<br>・Security Rules最終確認<br>・バグ修正<br>・リリースノート作成<br>・ストア申請準備 | ⭐ |

**合計**: 7週間（約49日）

### 実装優先順位まとめ

**最優先（MVP）**:
1. ✅ Firebase Auth + ログイン画面
2. ✅ チーム作成機能
3. ✅ データ移行ツール（既存ユーザー対応）
4. ✅ 管理者機能（シフトCRUD）のFirestore対応
5. ✅ メンバー閲覧機能

**中優先（年内リリース目標）**:
6. ✅ 休み希望入力機能
7. ✅ 締め日制御
8. ✅ マイシフト画面
9. ✅ FCM基盤準備

**低優先（リリース後）**:
10. ⏸️ チーム招待機能（招待コード生成）
11. ⏸️ Push通知の実装（シフト変更通知）
12. ⏸️ 有料版（広告非表示）

> 複数人で開発する場合は短縮可能（4-5週間）。
> 優先度は「最低限動くオンライン化＋データ移行安定」が最優先。

## 7. データ移行戦略

### 7.1 ユーザー視点の移行フロー

#### 既存ユーザー（アップデート時）
1. **アップデート前**
   - 既存のバックアップ機能で現在のデータをJSONファイルに保存
   - アプリストアから最新版にアップデート

2. **初回起動時**
   - 「既存データがありますか？」ダイアログ表示
   - アカウント作成（Email/Password）
   - チーム作成（チーム名入力）
   - バックアップファイル選択
   - Firebase移行実行（自動）

3. **移行完了後**
   - Hiveデータは自動削除
   - Firestoreからデータ取得（以降はオンライン）

#### 新規ユーザー
1. アカウント作成
2. チーム作成 or 招待コード入力
3. そのままオンラインで利用開始

### 7.2 技術的な移行実装

```dart
// lib/services/migration_service.dart
class MigrationService {
  /// バックアップファイルからFirestoreへ移行
  static Future<void> migrateFromBackup(
    String backupFilePath,
    String teamId,
    String userId,
  ) async {
    // 1. バックアップファイル読み込み（既存のBackupService使用）
    final file = File(backupFilePath);
    final jsonString = await file.readAsString();
    final backupData = json.decode(jsonString);
    final data = backupData['data'];

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 2. スタッフデータ移行
    for (var staffJson in data['staff']) {
      final docRef = firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .doc(staffJson['id']);
      batch.set(docRef, {
        ...staffJson,
        'userId': null, // 初期は未紐付け
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. シフトデータ移行
    for (var shiftJson in data['shifts']) {
      final docRef = firestore
          .collection('teams')
          .doc(teamId)
          .collection('shifts')
          .doc(shiftJson['id']);
      batch.set(docRef, {
        ...shiftJson,
        'date': Timestamp.fromDate(DateTime.parse(shiftJson['date'])),
        'startTime': Timestamp.fromDate(DateTime.parse(shiftJson['startTime'])),
        'endTime': Timestamp.fromDate(DateTime.parse(shiftJson['endTime'])),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. 制約データ移行
    for (var constraintJson in data['constraints']) {
      final docRef = firestore
          .collection('teams')
          .doc(teamId)
          .collection('constraints')
          .doc(constraintJson['id']);
      batch.set(docRef, {
        ...constraintJson,
        'date': Timestamp.fromDate(DateTime.parse(constraintJson['date'])),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 5. シフト時間設定移行
    for (var settingJson in data['shift_time_settings']) {
      final docRef = firestore
          .collection('teams')
          .doc(teamId)
          .collection('shift_time_settings')
          .doc();
      batch.set(docRef, settingJson);
    }

    // 6. 月間シフト設定移行
    final requirements = data['shift_requirements'] as Map<String, dynamic>;
    for (var entry in requirements.entries) {
      final docRef = firestore
          .collection('teams')
          .doc(teamId)
          .collection('shift_requirements')
          .doc(entry.key);
      batch.set(docRef, {
        'shiftType': entry.key,
        'requiredCount': entry.value,
      });
    }

    // 7. バッチ実行
    await batch.commit();

    // 8. Hiveデータクリア
    await Hive.deleteBoxFromDisk('staff');
    await Hive.deleteBoxFromDisk('shifts');
    await Hive.deleteBoxFromDisk('constraints');
    await Hive.deleteBoxFromDisk('shift_time_settings');

    // 9. SharedPreferencesクリア
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs.getKeys()
        .where((key) => key.startsWith('shift_requirement_'))
        .toList();
    for (var key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
```

### 7.3 安全策
- ✅ 移行前に既存ユーザーのバックアップを必ず作成（アプリ内ガイド）
- ✅ 少人数テストチーム（5-10人）で事前に移行テスト
- ✅ 移行失敗時はバックアップから再試行可能
- ✅ バージョンチェックで旧バージョンからの書き込みを防止

## 8. 技術的な実装ポイント

### 8.1 必要な追加パッケージ

```yaml
dependencies:
  # 既存パッケージは維持
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.4
  cloud_firestore: ^5.2.1
  firebase_messaging: ^15.0.4  # Push通知用

  # Hive関連は削除
  # hive: 削除
  # hive_flutter: 削除
```

### 8.2 オフライン対応（Firestoreキャッシュ機能）

**決定事項**: Hive完全削除、Firestoreのキャッシュ機能のみでオフライン対応

```dart
// lib/main.dart初期化時
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Firestoreのキャッシュ設定（オフライン対応）
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,  // これだけでオフライン対応
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MyApp());
}
```

**オフライン機能の動作**:
- ✅ 一度見たデータはキャッシュに保存
- ✅ オフラインでも閲覧・編集可能
- ✅ オンライン復帰時に自動同期
- ✅ 追加実装ほぼゼロ
- ⚠️ 編集の競合は発生しうる（後から上書きが勝つ）

### 8.3 画面・機能の変更点

#### 新規画面
1. **ログイン/サインアップ画面** (`lib/screens/auth/`)
   - Email/Password認証
   - パスワードリセット機能

2. **チーム選択/作成画面** (`lib/screens/team/`)
   - チーム新規作成
   - 招待コード入力（将来的に）

3. **データ移行画面** (`lib/screens/migration/`)
   - バックアップファイル選択
   - 移行進捗表示
   - 移行完了確認

4. **マイシフト画面** (`lib/screens/my_shift/`)
   - メンバー用: 自分のシフトのみ表示
   - カレンダー形式
   - 次のシフト確認

5. **休み希望入力画面** (`lib/screens/holiday_request/`)
   - メンバー用: 休み希望日選択
   - 締め日表示
   - 締め日後は入力不可

6. **メンバー管理画面** (`lib/screens/member_management/`)
   - 管理者用: チームメンバー一覧
   - 招待コード生成
   - 権限変更

#### 既存画面の改修
1. **ホーム画面** (`lib/screens/home_screen.dart`)
   - ログアウトボタン追加
   - 権限表示（管理者/メンバー）
   - メンバー用の簡易版ナビゲーション

2. **カレンダー画面** (`lib/screens/calendar_screen.dart`)
   - 管理者: 全機能維持（編集・削除可能）
   - メンバー: 閲覧のみ + 自分のシフトをハイライト
   - リアルタイム更新（StreamBuilder使用）

3. **スタッフ管理画面** (`lib/screens/staff_list_screen.dart`)
   - 管理者: 全機能維持 + ユーザー紐付け機能
   - メンバー: 非表示

4. **設定画面** (`lib/screens/settings_screen.dart`)
   - 管理者: 締め日設定追加
   - メンバー: 制限版（個人情報のみ編集可）

5. **シフト表画面** (`lib/screens/export_screen.dart`)
   - 両権限: Excel/PNG出力維持
   - メンバー: 自分のシフトのみ出力オプション追加

### 8.4 Providerの改修

既存のProvider構造は維持し、データソースをFirestoreに変更

```dart
// Before: Hiveベース
class StaffProvider extends ChangeNotifier {
  final Box<Staff> _staffBox = Hive.box<Staff>('staff');
  List<Staff> get staffList => _staffBox.values.toList();
}

// After: Firestoreベース
class StaffProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _teamId;
  List<Staff> _staffList = [];

  List<Staff> get staffList => _staffList;

  Stream<List<Staff>> watchStaff(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Staff.fromJson(doc.data())).toList());
  }
}
```

### 8.5 自動シフト生成の実装

**決定事項**: クライアント実行（既存アルゴリズムをそのまま使用）

```dart
// lib/services/shift_assignment_service.dart
// 既存のアルゴリズムは維持
// 変更点: Firestoreからデータ取得、生成結果をFirestoreに保存

class ShiftAssignmentService {
  static Future<void> assignShifts(String teamId, /* ... */) async {
    // 1. Firestoreからスタッフ・制約データ取得
    final staff = await _fetchStaff(teamId);
    final constraints = await _fetchConstraints(teamId);

    // 2. 既存のアルゴリズムで生成（変更なし）
    final generatedShifts = _generateShifts(staff, constraints, /* ... */);

    // 3. Firestoreにバッチ書き込み
    final batch = FirebaseFirestore.instance.batch();
    for (var shift in generatedShifts) {
      final docRef = FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('shifts')
          .doc();
      batch.set(docRef, shift.toJson());
    }
    await batch.commit();
  }
}
```

### 8.6 AdMob広告の表示制御（Android版アプリ）

**決定事項**: 管理者・メンバー両方にバナー広告表示（メイン収益源）

```dart
// 全ユーザーにバナー広告表示
Widget buildBannerAd() {
  if (kIsWeb) {
    return SizedBox.shrink(); // Web版ではAdMobは使えない
  }
  return BannerAdWidget(); // Android/iOS版のみ
}
```

**広告配置**:
- **全ユーザー共通**:
  - ホーム画面下部（バナー広告）
  - カレンダー画面下部（バナー広告）

- **メンバー専用**:
  - マイシフト画面下部（バナー広告）

- **管理者専用**:
  - インタースティシャル広告（シフト自動生成完了時）
  - インタースティシャル広告（月次レポート確認時）

**Web版の広告**:
- AdSenseを使用（AdMobは使えない）
- 収益性が低いため、最小限の配置
- iOSユーザー向け救済措置のため、広告体験よりUX優先

## 9. プラットフォーム戦略（Android/Web/iOS）

### 9.1 基本方針

**決定事項**: 段階的な多段階リリース

```
フェーズ1: Android版（管理者向け）
  ↓
フェーズ2: Web版（メンバー向け）
  ↓
フェーズ3: iOS版（将来・インストール数次第）
```

### 9.2 各プラットフォームの役割

| プラットフォーム | 対象ユーザー | 主要機能 | 収益化 | リリース時期 |
|-----------------|-------------|---------|--------|-------------|
| **Android版アプリ** | **管理者+メンバー全員** | 全機能（権限で出し分け）<br>・管理者: シフト作成・編集・自動生成<br>・メンバー: 閲覧・休み希望入力 | AdMob（バナー+インタースティシャル） | フェーズ1（7週間） |
| **Web版（PWA）** | **iOSユーザー向け救済措置** | 基本機能のみ<br>・シフト閲覧・マイシフト・休み希望入力<br>・制限: Push通知不安定、オフライン限定的 | AdSense（低収益・赤字覚悟） | フェーズ2（+2週間） |
| **iOS版アプリ** | 管理者+メンバー | 全機能（Android版と同等） | AdMob | フェーズ3（採算ライン到達後）<br>→ Web版クローズ |

### 9.3 Web版の位置づけと実現可能性

#### 基本方針

**Web版はあくまでiOSユーザー向けの暫定的な救済措置**

```
ユーザー導線（推奨）:
├─ Androidユーザー → Android版アプリ（フル機能+AdMob）
└─ iOSユーザー     → Web版（基本機能のみ+AdSense）

iOS版リリース後:
└─ Web版クローズ（または最小限のメンテナンスモード）
```

#### コスト（無料枠で十分）

```
Firebase Hosting 無料枠
├─ ストレージ: 10GB
├─ 転送量: 360MB/日（約12,000ページビュー/日相当）
└─ カスタムドメイン対応

Firestore 無料枠（Android版と共用）
├─ 読み取り: 5万/日
├─ 書き込み: 2万/日
└─ iOSユーザーは少数想定なので余裕

合計コスト: 0円（小規模想定）
```

#### メリット

1. **iOS Developer Program不要**
   - $99/年のコスト削減
   - 元が取れるか不明な段階で初期投資不要

2. **クロスプラットフォーム対応**
   - iPhone・iPad・Android・PCすべて対応
   - ブラウザがあれば動く

3. **配布が簡単**
   - URLを共有するだけ（例: `https://shift-kobo.web.app`）
   - アプリストア審査不要
   - 即座にアップデート反映

4. **PWA対応でアプリライク**
   - 「ホーム画面に追加」でアプリ風に使える
   - オフラインキャッシュ対応
   - プッシュ通知対応（将来的に）

#### デメリット・技術的制限（重要）

1. **広告収益が極めて低い**
   - ❌ **AdMobは使えない**（モバイルアプリ専用）
   - ✅ **Google AdSenseのみ**（Web専用）
   - 収益性: AdSense << AdMob（約1/3〜1/5）
   - 対策: 赤字覚悟の救済措置と割り切る

2. **Push通知が不安定**
   - Android版: Firebase Cloud Messaging（⭐⭐⭐⭐⭐ 確実）
   - Web版: Push API + Service Worker（⭐⭐ 不安定）
     - ブラウザを閉じてると届かない
     - iOSのSafariは対応が不完全（iOS 16.4+でも制限多い）
   - 対策: Push通知機能は実装しない（Android版で提供）

3. **オフライン対応が限定的**
   - Android版: Firestoreキャッシュで完全対応
   - Web版: Service Worker次第で不安定
   - 対策: オフライン機能は期待しない（基本オンライン前提）

4. **レスポンシブデザイン必要**
   - 対策: カレンダー画面をPC/タブレット/スマホ対応
   - 作業量: 中程度（既存コード流用可能）

### 9.4 技術的な実装（Web版）

#### Firebase Hostingデプロイ手順

```bash
# 1. Firebase CLIインストール
npm install -g firebase-tools

# 2. Firebaseログイン
firebase login

# 3. プロジェクト初期化
firebase init hosting
# 質問に答える:
# - Public directory: build/web
# - Single-page app: Yes
# - Automatic builds: No

# 4. Web版ビルド
flutter build web --release

# 5. デプロイ
firebase deploy --only hosting

# 完了！ https://shift-kobo.web.app で公開
```

#### プラットフォーム判定で機能出し分け

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// Web版でAndroidユーザーを検出してアプリDLを促す
Widget buildPlatformNotice() {
  if (kIsWeb) {
    // User-Agentを見てAndroidユーザーならアプリDLバナー表示
    return Card(
      color: Colors.orange.shade100,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.android, size: 48),
            SizedBox(height: 8),
            Text('Androidをご利用の方へ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('アプリ版なら広告が少なく、オフラインでも使えます！'),
            ElevatedButton(
              onPressed: () => launchUrl('Google Playリンク'),
              child: Text('アプリをダウンロード'),
            ),
          ],
        ),
      ),
    );
  }
  return SizedBox.shrink();
}

// 管理者専用機能（アプリ版のみ表示）
Widget buildAdminFeatures(String userRole) {
  if (kIsWeb) {
    // Web版では管理者でも一部機能制限
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('管理者機能はアプリ版でご利用ください'),
      ),
    );
  }

  if (userRole != 'admin') {
    return SizedBox.shrink();
  }

  // Android/iOS版のみ表示
  return Column(
    children: [
      // 自動シフト生成ボタン
      ElevatedButton.icon(
        icon: Icon(Icons.auto_awesome),
        label: Text('自動シフト生成'),
        onPressed: _showAutoAssignmentDialog,
      ),
      // スタッフ管理
      ListTile(
        leading: Icon(Icons.people),
        title: Text('スタッフ管理'),
        onTap: () => Navigator.pushNamed(context, '/staff'),
      ),
      // 締め日設定
      ListTile(
        leading: Icon(Icons.event_busy),
        title: Text('締め日設定'),
        onTap: () => Navigator.pushNamed(context, '/deadline'),
      ),
    ],
  );
}

// メンバー用機能（全プラットフォーム対応）
Widget buildMemberFeatures(String userRole) {
  return Column(
    children: [
      // シフト閲覧（全プラットフォーム対応）
      CalendarView(),
      // マイシフト
      MyShiftView(),
      // 休み希望入力
      HolidayRequestButton(),
    ],
  );
}
```

#### PWA設定

```json
// web/manifest.json
{
  "name": "シフト工房 - メンバー用",
  "short_name": "シフト工房",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#2196F3",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

```dart
// web/index.html（Service Worker登録）
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('flutter-first-frame', function () {
      navigator.serviceWorker.register('flutter_service_worker.js');
    });
  }
</script>
```

### 9.5 段階的リリース計画

#### フェーズ1: Android版アプリ（管理者+メンバー全員）- 7週間

**目的**: 既存ユーザーのオンライン化 + 全ユーザーへのアプリ提供

- ✅ Firebase Auth + Firestore
- ✅ データ移行ツール
- ✅ 管理者機能（シフトCRUD・自動生成・スタッフ管理）
- ✅ メンバー機能（シフト閲覧・マイシフト・休み希望入力）
- ✅ 権限別UI制御（ログイン後のロールで画面出し分け）
- ✅ AdMob広告（全ユーザーにバナー+管理者にインタースティシャル）
- ✅ Google Play公開

**完了条件**:
- 既存ユーザー（管理者）が問題なく移行完了
- メンバーがアプリでシフト閲覧可能
- AdMob収益が発生開始

---

#### フェーズ2: Web版（iOSユーザー向け救済措置）- +2週間

**目的**: iOSユーザーへの暫定的な対応（AdSense収益は期待しない）

| タスク | 期間 | 内容 |
|--------|------|------|
| レスポンシブ対応 | 3日 | カレンダー・マイシフト画面のPC/タブレット/スマホ対応 |
| メンバー用UI構築 | 3日 | 閲覧専用モード・休み希望入力画面 |
| PWA設定 | 1日 | manifest.json・Service Worker設定（基本のみ） |
| Firebase Hosting設定 | 1日 | デプロイ・カスタムドメイン設定 |
| テスト | 2日 | iOS Safari・Chrome等での動作確認 |
| ドキュメント作成 | 1日 | iOSユーザー向けマニュアル・制限事項の説明 |
| リリース | 1日 | 本番デプロイ・iOS向けアナウンス |

**完了条件**:
- iOSユーザーがブラウザでシフト閲覧可能
- PWAでホーム画面追加できる（iOS Safariで動作確認）
- 「AndroidユーザーはアプリDL推奨」の導線設置

**期待効果**:
- iOSユーザーの救済（全体の約20-30%想定）
- iOS版リリース前の一時的な対応

**重要な注意事項**:
- ⚠️ Push通知は実装しない（iOS Safariでは不安定）
- ⚠️ オフライン機能は最小限（Androidアプリに誘導）
- ⚠️ AdSense収益は期待しない（赤字覚悟）

---

#### フェーズ3: iOS版アプリリリース（将来）- 採算ライン到達後

**開始条件**:
- Android版インストール数 1,000以上
- または AdMob収益 月$100以上（$99/年の開発者登録費が回収可能）
- iOSユーザーからの要望が多い（Web版の利用実績を参考）

**iOS版の優位性**:
- ネイティブアプリの高いUX
- App Storeでの信頼性
- Push通知の確実な配信（Firebase Cloud Messaging）
- オフライン機能の完全対応
- Android版と同等の機能提供

**リリース後の対応**:
- ✅ iOS版アプリをApp Storeで公開
- ✅ iOSユーザーにアプリDLを促す
- ✅ **Web版をクローズ**（または最小限のメンテナンスモード）
  - 理由: AdSense収益が低く、維持コストに見合わない
  - 移行期間: 3ヶ月（アナウンス → 移行促進 → クローズ）

**期待効果**:
- iOSユーザーのUX向上
- AdMob収益の拡大（iOS版からも収益発生）
- Web版の維持コスト削減

### 9.6 収益化戦略

```
【Android版アプリ】管理者+メンバー全員（メイン収益源）
├─ AdMob バナー広告（全ユーザーに常時表示）
├─ AdMob インタースティシャル広告（管理者のシフト生成後）
├─ 対象ユーザー: 全Androidユーザー（管理者+メンバー）
└─ 将来: プレミアムプラン（広告非表示、$2.99/月）

【Web版】iOSユーザー向け救済措置（収益期待しない）
├─ AdSense（オプション、収益極めて低い）
├─ 対象ユーザー: iOSユーザーのみ（全体の20-30%）
└─ 基本赤字覚悟の暫定対応

【iOS版アプリ】将来リリース（採算ライン到達後）
├─ AdMob（Android版と同等）
├─ 対象ユーザー: 全iOSユーザー
└─ リリース後はWeb版クローズ
```

**収益予測（修正版）**

| フェーズ | 対象ユーザー | 収益源 | 月間収益（保守的） |
|---------|-------------|-------|------------------|
| **フェーズ1** | Android版<br>（管理者+メンバー） | AdMob | $50-100/月<br>（500ユーザー想定） |
| **フェーズ2** | +Web版<br>（iOSユーザー） | AdSense | +$5-10/月<br>（100ユーザー想定） |
| **フェーズ3** | +iOS版アプリ<br>（iOSユーザー移行） | AdMob | +$30-50/月<br>（150ユーザー想定）<br>Web版クローズで-$10 |

**6ヶ月後の目標**:
- Android版: 1,000ユーザー × $0.5/月 = **$500/月**
- Web版: 少数（iOS版リリース前の暫定） = **$10/月**
- **合計**: 約$510/月（約¥76,000/月）

**iOS版リリース後（12ヶ月後）**:
- Android版: 1,500ユーザー × $0.5/月 = $750/月
- iOS版: 500ユーザー × $0.5/月 = $250/月
- **合計**: 約$1,000/月（約¥150,000/月）

## 10. 今後の拡張（リリース後）
- Push通知による変更通知（シフト確定・変更時）
- チーム招待／メンバー管理機能（招待コード生成）
- 広告収益や有料版（広告非表示プラン）
- 添付ファイル拡張（画像・Excel）
- 高度な権限管理（承認フロー、権限別操作）
- Supabase移行検討（コスト最適化）
