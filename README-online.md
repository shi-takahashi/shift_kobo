# シフト工房 オンライン化 開発計画

## 📋 実装方針サマリー（2025-10-16更新）

### 主要決定事項
- ✅ **完全オンライン化**: Hive完全削除、Firestoreのみ使用
- ✅ **オフライン対応**: Firestoreのキャッシュ機能のみ（`persistenceEnabled: true`）
- ✅ **認証**: Firebase Authentication（Email/Password）
- ✅ **データ移行戦略**: **案A採用** - 既存アプリを完全オンライン移行（オンボーディング画面付き）
  - 既存ユーザー: オンボーディング画面 → アカウント作成 → チーム作成 → **チーム作成時に自動データ移行**
  - 新規ユーザー: 通常のサインアップフロー
  - Hive → Firestore自動移行（**ユーザーは何もしなくてOK**、バックアップ不要）
  - 移行完了後にHiveデータ自動削除
- ✅ **自動生成**: クライアント実行（既存アルゴリズム維持）
- ✅ **広告**: Android版はAdMob（メイン収益源）、Web版はAdSense（赤字覚悟）
- ✅ **開発期間**: 7週間（Android版）+ 2週間（Web版）
- ✅ **プラットフォーム戦略**:
  - Android版アプリ（管理者+メンバー全員）→ メイン
  - Web版（iOSユーザー救済）→ 暫定
  - iOS版アプリ（採算ライン到達後）→ Web版クローズ

### データ移行の自動化方針（重要）
**既存ユーザーの体験**:
1. アプリ更新後、起動すると **オンボーディング画面** が表示される
2. 「アカウント作成して始める」ボタンをタップ → サインアップ画面
3. メールアドレス・パスワードを入力して新規登録
4. チーム名を入力してチーム作成
5. **チーム作成完了後、自動的に既存データ（Hive）をFirestoreに移行**
6. 移行進捗ダイアログ表示（プログレスバー + 完了件数）
7. 移行完了 → Hiveデータ自動削除 → ホーム画面へ
8. **以降はオンライン版として利用** 🎉

**ユーザーがすること**:
- アカウント作成（メールアドレス・パスワード入力）
- チーム名入力

**ユーザーがしなくていいこと**:
- ❌ バックアップファイル作成
- ❌ ファイル選択
- ❌ 移行ボタン押下
- ❌ 難しい操作は一切なし

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

  /constraints/{constraintId}  (サブコレクション) - 【廃止予定】
    - id: string
    - staffId: string
    - date: timestamp
    - isAvailable: bool
    - reason: string
    - createdAt: timestamp
    - updatedAt: timestamp

  /constraint_requests/{requestId}  (サブコレクション) - 🆕 **承認フロー用**
    - id: string
    - staffId: string (申請者のスタッフID)
    - userId: string (申請者のユーザーID)
    - requestType: string ("specificDay" | "weekday" | "shiftType")
    - specificDate: timestamp | null (特定日の場合)
    - weekday: int | null (曜日の場合: 1-7)
    - shiftType: string | null (シフトタイプの場合)
    - status: string ("pending" | "approved" | "rejected")
    - approvedBy: string | null (承認者のユーザーID)
    - approvedAt: timestamp | null (承認日時)
    - rejectedReason: string | null (却下理由)
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

      // 休み希望（自分のものは編集可、締め日後は管理者のみ）- 【廃止予定】
      match /constraints/{constraintId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;
        allow create, update: if (request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds
                                  && request.resource.data.staffId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.staffId
                                  && request.time < get(/databases/$(database)/documents/teams/$(teamId)).data.shiftDeadline)
                                  || request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
        allow delete: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
      }

      // 🆕 休み希望申請（承認フロー）
      match /constraint_requests/{requestId} {
        // 全員が閲覧可能（管理者：全件、スタッフ：自分の申請のみ）
        allow read: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds;

        // 申請作成：スタッフ自身のみ（締め日前のみ）
        allow create: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.memberIds
                         && request.resource.data.userId == request.auth.uid
                         && request.time < get(/databases/$(database)/documents/teams/$(teamId)).data.shiftDeadline;

        // 申請更新：管理者のみ（承認・却下操作）
        allow update: if request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds
                         && request.resource.data.keys().hasAny(['status', 'approvedBy', 'approvedAt', 'rejectedReason']);

        // 申請削除：本人または管理者
        allow delete: if request.resource.data.userId == request.auth.uid
                         || request.auth.uid in get(/databases/$(database)/documents/teams/$(teamId)).data.adminIds;
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

### 必須機能（リリース前に実装）
- ✅ 管理者・メンバー権限によるログイン
- ✅ 管理者：シフト作成・編集・削除
- ✅ メンバー：シフト閲覧、休み希望入力（締め日まで）
- ✅ **チーム招待機能（招待コード方式）** ← **追加：リリース必須**
- ✅ 締め日制御（休み希望入力期限）
- ✅ オフライン版からFirebaseへのデータ移行
- ✅ 基本UI（権限に応じた画面切替）

### Push通知
- 送信仕組みのみ準備（Firebase Cloud Messaging）
- リリース段階では通知送信は後回し

### 後回し機能（リリース後追加）
- 実際のシフト変更通知
- QRコード招待（招待コードのみで十分）
- メール招待リンク
- 広告収益・有料版
- 高度なUI改善・添付ファイル拡張

## 6. 開発ロードマップ（1人開発想定・7週間）

| 週 | フェーズ | タスク詳細 | 重要度 |
|----|---------|-----------|--------|
| **1週目** | Firebase基盤 | ✅ Firebase初期設定（コンソール・Android/iOS設定）<br>✅ Firebase Auth実装（Email/Password）<br>✅ ログイン/サインアップ画面作成<br>✅ チーム作成画面<br>✅ Firestore基本接続確認 | ⭐⭐⭐ |
| **2週目** | データ移行 | ✅ **オンボーディング画面実装**（MigrationOnboardingScreen）<br>✅ 既存データ検出ロジック（Hive有無チェック）<br>✅ MigrationService作成<br>✅ Hive→Firestore自動移行機能<br>✅ 移行進捗表示UI<br>✅ 移行テスト（サンプルデータ）<br>✅ Hive削除処理 | ⭐⭐⭐ |
| **3週目** | Provider改修 | ✅ Provider改修（Firestore対応）<br>✅ カレンダー画面のFirestore連携<br>✅ シフトCRUD機能（Firestore版）<br>✅ スタッフ管理のFirestore連携<br>✅ バックアップ・復元のFirestore対応 | ⭐⭐⭐ |
| **4週目** | 招待機能 + 自動紐付け | ✅ チーム招待コード生成機能<br>✅ 招待コード入力画面<br>✅ チーム参加処理（Firestore更新）<br>✅ スタッフ-ユーザー自動紐付け（メールアドレス一致）<br>✅ 招待案内UX改善（InviteGuideDialog）<br>✅ 用語統一（「メンバー」→「スタッフ」） | ⭐⭐⭐ |
| **5週目** | 権限制御 + マイページ | ✅ AppUser.roleによる権限制御実装<br>✅ ホーム画面のタブ構成変更（権限別）<br>✅ カレンダー画面の権限制御（管理者：編集可、スタッフ：閲覧のみ）<br>✅ 設定画面の権限制御（管理者専用機能の非表示）<br>✅ マイページ画面作成（直近の予定・全予定カレンダー・休み希望編集）<br>✅ マイページUI調整（スワイプ無効化、チップ固定幅、データ形式統一） | ⭐⭐⭐ |
| **6週目** | ✅ **休み希望承認フロー** | ✅ **ConstraintRequestモデル作成**（status: pending/approved/rejected）<br>✅ **スタッフ側：休み希望申請機能**（特定日・曜日・シフトタイプ別）<br>✅ **管理者側：承認画面作成**（申請一覧・承認/却下ボタン）<br>✅ **申請状態表示**（マイページで承認待ち・承認済み・却下を色分け表示）<br>✅ **Firestore構造拡張**（teams/{teamId}/constraint_requests コレクション）<br>✅ **Security Rules更新**（申請は本人のみ作成、承認は管理者のみ）<br>✅ **マイページ表示最適化**（カード並び替え、1週間分の直近予定、カレンダー年月表示）<br>⏸️ FCM基盤準備（将来対応）<br>⏸️ 締め日制御実装（将来対応） | ⭐⭐⭐ |
| **7週目** | 🔥 **ファーストリリース準備** | ✅ **Firebase開発/本番環境分離**<br>・本番用Firebaseプロジェクト作成<br>・google-services.json 開発/本番切り替え<br>✅ **iOS用Webアプリ準備**<br>・Flutter Web ビルド設定<br>・PWA対応（manifest.json、service worker）<br>・Firebase Hosting デプロイ<br>✅ **個人情報暗号化対応**<br>・メールアドレス・電話番号の暗号化実装<br>✅ **プライバシーポリシー更新**<br>・Firebase利用・チーム機能記載追加<br>✅ **デバッグログ削除**<br>・debugPrint条件分岐、未使用コード削除 | ⭐⭐⭐ |
| **8週目** | テスト・調整 | ・既存ユーザーでの移行テスト<br>・新規ユーザーでの動作確認<br>・招待機能テスト<br>・承認フローテスト（申請→承認の一連フロー）<br>・iOS Web版動作確認<br>・UI調整・バグ修正 | ⭐⭐ |
| **9週目** | リリース準備 | ・少人数テストチーム検証（Android + iOS Web）<br>・本番Firebase環境でのテスト<br>・Security Rules最終確認<br>・バグ修正<br>・リリースノート作成<br>・ストア申請準備（Google Play + Firebase Hosting） | ⭐ |

**合計**: 9週間（約63日）← 承認フロー機能追加により7週間→9週間に延長

### ファーストリリースに入れるか検討中

| 機能 | 説明 | 優先度 |
|------|------|--------|
| **手動編集時の希望外シフト警告** | シフト編集時、スタッフの休み希望と矛盾する場合に警告表示<br>・preferredDaysOff、unavailableShiftTypes をチェック<br>・警告ダイアログ表示（無視して保存も可能） | ⭐⭐ |

---

## 🔮 セカンドリリース以降の機能ロードマップ

### 優先度順の機能リスト

| 優先度 | 機能 | 説明 | 実装工数目安 |
|--------|------|------|-------------|
| ⭐⭐⭐ | **Push通知機能（FCM）** | ・承認・却下通知（スタッフ向け）<br>・申請通知（管理者向け）<br>・シフト確定通知（全員向け）<br>・FCM基盤準備（既に完了）<br>・通知送信処理実装<br>・通知受信UI実装 | 3-4日 |
| ⭐⭐⭐ | **一括承認機能** | ・スタッフ単位でまとめて承認（現在は1件ずつ）<br>・チェックボックスで複数選択<br>・一括承認ボタン追加<br>・Firestore バッチ処理で高速処理 | 2-3日 |
| ⭐⭐ | **自動承認機能** | ・管理者向け設定: 全スタッフ自動承認ON/OFF<br>・スタッフ単位の自動承認設定<br>・特定条件下での自動承認（例: 月X回まで）<br>・Firestore Cloud Functions で自動承認トリガー | 3-4日 |
| ⭐⭐ | **チーム名変更機能** | ・設定画面からチーム名を変更可能<br>・Firestore teams/{teamId}/name を更新<br>・変更履歴の記録（任意） | 1日 |
| ⭐⭐ | **祝日勤務不可設定** | ・スタッフ毎に祝日勤務不可フラグ追加<br>・自動割り当て時に祝日を考慮<br>・holiday_jp パッケージ利用（既に導入済み）<br>・Staff モデルに canWorkOnHolidays フィールド追加 | 2日 |
| ⭐ | **締め日機能** | ・設定画面で締め日設定（例: 毎月25日）<br>・締め日以降は休み希望入力を制限<br>・管理者は制限なし<br>・Team モデルに deadlineDay フィールド追加 | 2-3日 |
| ⭐ | **SNS連携（Apple・Google認証）** | ・Apple Sign In（iOS向け）<br>・Google Sign In（Android向け）<br>・既存のEmail/Password認証と併用<br>・スタッフ自動紐付けはメールアドレスベースで継続<br>・Firebase Authentication 設定追加 | 3-4日 |

### セカンドリリース実装順序（推奨）

1. **一括承認機能**（2-3日）
   - 理由: 管理者の承認作業効率化、実装も比較的簡単

2. **祝日勤務不可設定**（2日）
   - 理由: シフト自動生成の精度向上、既にholiday_jpパッケージ導入済み

3. **チーム名変更機能**（1日）
   - 理由: 簡単な機能、ユーザー要望が多い可能性

4. **Push通知機能**（3-4日）
   - 理由: ユーザー体験の大幅向上、FCM基盤は準備済み

5. **自動承認機能**（3-4日）
   - 理由: 管理者の負担軽減、Cloud Functions 必要

6. **締め日機能**（2-3日）
   - 理由: シフト管理の正確性向上

7. **SNS連携**（3-4日）
   - 理由: サインアップの障壁を下げる

**合計**: 18-25日（約3-4週間）

---

### 実装優先順位まとめ

**ファーストリリース完了項目（MVP）**:
1. ✅ Firebase Auth + ログイン画面
2. ✅ チーム作成機能
3. ✅ オンボーディング画面実装（既存ユーザー向け案A）
4. ✅ 既存データ検出ロジック（Hive有無チェック）
5. ✅ データ移行ツール（Hive→Firestore自動移行）
6. ✅ 管理者機能（シフトCRUD）のFirestore対応
7. ✅ チーム招待機能（招待コード方式）
8. ✅ スタッフ閲覧機能
9. ✅ 休み希望申請・承認機能
10. ✅ マイページ画面（直近予定・カレンダー・休み希望編集）
11. ✅ 権限制御（管理者・スタッフ）

**ファーストリリース前の必須作業**:
- ⏸️ Firebase開発/本番環境分離
- ⏸️ iOS用Webアプリ準備
- ⏸️ 個人情報暗号化対応
- ⏸️ プライバシーポリシー更新
- ⏸️ デバッグログ削除

**セカンドリリース以降（上記「セカンドリリース以降の機能ロードマップ」参照）**:
- 一括承認機能
- 祝日勤務不可設定
- チーム名変更機能
- Push通知機能
- 自動承認機能
- 締め日機能
- SNS連携（Apple・Google認証）

**低優先（将来検討）**:
- QRコード招待（招待コードで十分）
- メール招待リンク
- 有料版（広告非表示）

> ファーストリリース: 9週間（約63日）
> セカンドリリース: 3-4週間（約18-25日）

## 7. データ移行戦略

### 7.1 ユーザー視点の移行フロー

#### **【採用】案A: 既存アプリの完全オンライン移行（オンボーディング画面付き）**

##### 既存ユーザー（アップデート時）

1. **アップデート前の準備**
   - Google Playストアの更新情報に移行手順を記載
   - 既存ユーザーへの事前告知（アプリ内通知または更新情報）
   - ※バックアップは不要（自動移行）

2. **アップデート後の初回起動時**
   - アプリ起動時にHiveデータの有無を自動検出
   - **既存データあり** → オンボーディング画面を表示
   - **既存データなし** → 通常のログイン画面へ

3. **オンボーディング画面（MigrationOnboardingScreen）**
   - オンライン化の説明
     - 「シフト工房がパワーアップしました！」
     - メリット：チームでシフト共有、メンバーが休み希望入力可能、複数端末で同期
     - 新機能：メンバー招待、リアルタイム更新、データ自動バックアップ
   - データ移行の案内
     - 「既存のデータは自動で移行されます」
     - 「アカウント作成後、すぐにご利用いただけます」
   - 「アカウント作成して始める」ボタン
   - 「後で」ボタン（アプリ起動のたびに表示、移行しないと使えない）

4. **アカウント作成・チーム作成**
   - サインアップ画面へ遷移（Email/Password）
   - チーム作成画面へ遷移
     - チーム名入力（既存データから店舗名を推測してプリセット可能）
     - チーム作成ボタン押下

5. **データ移行実行（自動）**
   - チーム作成完了後、バックグラウンドで既存Hiveデータを自動検出
   - MigrationServiceが既存データをFirestoreへ自動移行
   - 移行進捗表示（プログレスバー + 完了件数）
   - 移行完了メッセージ（「データ移行が完了しました！」）

6. **移行完了後**
   - Hiveデータは自動削除（移行完了確認後）
   - 以降はFirestoreからデータ取得（オンライン）
   - 通常のホーム画面へ遷移
   - ウェルカムダイアログ表示（新機能の簡単な説明）

##### 新規ユーザー
1. アカウント作成（Email/Password）
2. チーム作成 or 招待コード入力（将来実装）
3. そのままオンラインで利用開始

##### **【不採用】案B: 別アプリとしてリリース**
- 理由：インストール数が少ないため、既存アプリを移行する方が効率的

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

### 7.3 オンボーディング画面の実装（案A）

#### 7.3.1 AuthGateでの既存データ検出

```dart
// lib/widgets/auth_gate.dart
import 'package:hive_flutter/hive_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// 既存のHiveデータが存在するかチェック
  Future<bool> _hasExistingData() async {
    try {
      // Hiveボックスが存在するかチェック
      final staffBoxExists = await Hive.boxExists('staff');
      final shiftsBoxExists = await Hive.boxExists('shifts');

      if (!staffBoxExists || !shiftsBoxExists) {
        return false;
      }

      // ボックスを開いてデータが存在するか確認
      final staffBox = await Hive.openBox('staff');
      final shiftsBox = await Hive.openBox('shifts');

      final hasData = staffBox.isNotEmpty || shiftsBox.isNotEmpty;

      await staffBox.close();
      await shiftsBox.close();

      return hasData;
    } catch (e) {
      return false; // エラー時は既存データなしとして扱う
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasExistingData(),
      builder: (context, dataSnapshot) {
        if (dataSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasExistingData = dataSnapshot.data ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            // 既存データがあり、未ログインの場合 → オンボーディング画面
            if (hasExistingData && !authSnapshot.hasData) {
              return const MigrationOnboardingScreen();
            }

            // 既存データなし、未ログインの場合 → ログイン画面
            if (!authSnapshot.hasData) {
              return const LoginScreen();
            }

            // ログイン済み → チーム所属チェック
            return FutureBuilder(
              future: AuthService().getUser(authSnapshot.data!.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final appUser = userSnapshot.data;

                // チーム未所属 → チーム作成画面（データ移行フラグ付き）
                if (appUser?.teamId == null) {
                  return TeamCreationScreen(
                    userId: authSnapshot.data!.uid,
                    shouldMigrateData: hasExistingData,
                  );
                }

                // チーム所属済み → ホーム画面
                return const HomeScreen();
              },
            );
          },
        );
      },
    );
  }
}
```

#### 7.3.2 オンボーディング画面の実装

```dart
// lib/screens/migration/migration_onboarding_screen.dart
class MigrationOnboardingScreen extends StatelessWidget {
  const MigrationOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // アイコン
              Icon(
                Icons.rocket_launch,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // タイトル
              Text(
                'シフト工房が\nパワーアップしました！',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // メリット説明
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎉 新機能',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('✅ チームでシフトを共有'),
                      Text('✅ メンバーが休み希望を入力可能'),
                      Text('✅ 複数端末でリアルタイム同期'),
                      Text('✅ データ自動バックアップ'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // データ移行の案内
              Card(
                color: Colors.green.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'データ移行について',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('既存のスタッフ・シフトデータは自動で移行されます'),
                      Text('アカウント作成後、すぐにご利用いただけます'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // アカウント作成ボタン
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SignUpScreen(fromMigration: true),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('アカウント作成して始める'),
              ),
              const SizedBox(height: 8),

              // 後でボタン
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('後で'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### 7.3.3 チーム作成後の自動データ移行

```dart
// lib/screens/team/team_creation_screen.dart（修正版）
class TeamCreationScreen extends StatefulWidget {
  final String userId;
  final bool shouldMigrateData; // データ移行フラグ

  const TeamCreationScreen({
    super.key,
    required this.userId,
    this.shouldMigrateData = false,
  });

  // ... 省略 ...

  Future<void> _handleCreateTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // チーム作成
      await _authService.createTeam(
        teamName: _teamNameController.text.trim(),
        ownerId: widget.userId,
      );

      if (!mounted) return;

      // データ移行が必要な場合
      if (widget.shouldMigrateData) {
        await _showMigrationDialog();
      } else {
        // 通常のホーム画面遷移
        _navigateToHome();
      }
    } catch (e) {
      // エラー処理
    }
  }

  Future<void> _showMigrationDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MigrationProgressDialog(
        teamId: _authService.currentTeamId!,
        userId: widget.userId,
        onComplete: () {
          Navigator.of(context).pop(); // ダイアログを閉じる
          _navigateToHome();
        },
      ),
    );
  }

  void _navigateToHome() {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_first_time_help', true);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(showWelcomeDialog: true),
      ),
      (route) => false,
    );
  }
}
```

### 7.4 安全策
- ✅ 自動移行によりユーザー操作を最小化（エラーリスク低減）
- ✅ 少人数テストチーム（5-10人）で事前に移行テスト
- ✅ 移行失敗時は既存Hiveデータを保持（再試行可能）
- ✅ アプリストアの更新情報で事前告知

## 8. チーム招待機能の詳細設計（リリース必須）

### 8.1 招待コード方式（シンプル実装）

#### 管理者側：招待コード生成・表示

```dart
// 設定画面に「チーム招待」メニュー追加
class TeamInviteScreen extends StatelessWidget {
  final String teamId;

  @override
  Widget build(BuildContext context) {
    // teamIdの最初6文字を大文字に変換して招待コードとして表示
    final inviteCode = teamId.substring(0, 6).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text('チーム招待')),
      body: Center(
        child: Column(
          children: [
            Text('招待コード', style: TextStyle(fontSize: 18)),
            Text(inviteCode, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            Text('このコードをメンバーに共有してください'),
            // コピーボタン、QRコード表示（将来的）
          ],
        ),
      ),
    );
  }
}
```

#### メンバー側：招待コード入力

```dart
// ログイン後、teamIdがnullの場合に表示
class JoinTeamScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('チームに参加')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text('管理者から受け取った招待コードを入力してください'),
            TextField(
              decoration: InputDecoration(labelText: '招待コード（6桁）'),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
            ),
            ElevatedButton(
              onPressed: _handleJoinTeam,
              child: Text('チームに参加'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### チーム参加処理

```dart
class TeamService {
  Future<void> joinTeamByCode(String inviteCode, String userId) async {
    // 1. 招待コードからteamIdを検索
    final teamsQuery = await FirebaseFirestore.instance
        .collection('teams')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: inviteCode.toLowerCase())
        .where(FieldPath.documentId, isLessThan: inviteCode.toLowerCase() + '\uf8ff')
        .limit(1)
        .get();

    if (teamsQuery.docs.isEmpty) {
      throw '招待コードが見つかりません';
    }

    final teamId = teamsQuery.docs.first.id;

    // 2. usersコレクションのteamIdを更新
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'teamId': teamId,
      'role': 'member', // メンバーとして参加
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. teamsコレクションのmemberIdsに追加
    await FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

### 8.2 ユーザーフロー

#### 管理者（チーム作成済み）
1. 設定画面 → 「チーム招待」
2. 招待コード表示（例: `ABC123`）
3. コードをメンバーに共有（LINEなど）

#### メンバー（新規登録）
1. アプリ起動 → ウェルカム画面 → サインアップ
2. ログイン後、「チームに参加」画面が表示される
3. 招待コード入力 → 「チームに参加」ボタン
4. チーム参加完了 → カレンダー画面（閲覧モード）

### 8.3 実装スコープ

**リリース時に実装**:
- ✅ 招待コード生成・表示
- ✅ 招待コード入力画面
- ✅ チーム参加処理（Firestore更新）
- ✅ チーム参加後のナビゲーション

**リリース後に追加**:
- QRコード表示・読み取り
- メール招待リンク
- 招待履歴管理

## 9. 技術的な実装ポイント

### 9.1 必要な追加パッケージ

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

## 10. プラットフォーム戦略（Android/Web/iOS）

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

## 11. 今後の拡張（リリース後）
- Push通知による変更通知（シフト確定・変更時）
- チーム招待／メンバー管理機能（招待コード生成）
- 広告収益や有料版（広告非表示プラン）
- 添付ファイル拡張（画像・Excel）
- 高度な権限管理（承認フロー、権限別操作）
- Supabase移行検討（コスト最適化）
