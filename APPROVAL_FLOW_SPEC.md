# 休み希望承認フロー 仕様書

## 📋 概要

スタッフの休み希望に管理者の承認プロセスを追加する機能

## 🎯 目的

- **現状の問題**: スタッフが休み希望を入力すると無条件で反映される
- **必要な改善**: 管理者の承認を経てから正式な休み希望として扱う
- **ユーザー体験**:
  - スタッフ: 申請→承認待ち状態を確認→承認/却下通知を受け取る
  - 管理者: 申請一覧確認→承認または却下→スタッフに通知

## 📊 データモデル

### ConstraintRequest（新規モデル）

```dart
class ConstraintRequest {
  final String id;
  final String staffId;        // 申請者のスタッフID
  final String userId;         // 申請者のユーザーID
  final String requestType;    // "specificDay" | "weekday" | "shiftType"
  final DateTime? specificDate; // 特定日の場合
  final int? weekday;          // 曜日の場合: 1-7
  final String? shiftType;     // シフトタイプの場合
  final String status;         // "pending" | "approved" | "rejected"
  final String? approvedBy;    // 承認者のユーザーID
  final DateTime? approvedAt;  // 承認日時
  final String? rejectedReason; // 却下理由
  final DateTime createdAt;
  final DateTime updatedAt;

  // toJson, fromJson実装
}
```

### Firestoreコレクション構造

```
teams/{teamId}/constraint_requests/{requestId}
```

### Security Rules

```javascript
// 休み希望申請（承認フロー）
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
```

## 🎨 UI設計

### マイページ（スタッフ側）

```
┌─────────────────────────────┐
│ その他の制約                 │
├─────────────────────────────┤
│ 編集ボタン → 申請ダイアログ   │
│                             │
│ ◆ 休み希望曜日              │
│   [月] [水] ⏳承認待ち      │
│   [金] ✅承認済み           │
│                             │
│ ◆ 勤務不可シフトタイプ       │
│   [夜勤] ⏳承認待ち         │
│   [遅番] ❌却下（人手不足のため）│
│                             │
│ ◆ 休み希望日（特定日）       │
│   10/25 ⏳承認待ち          │
│   10/30 ✅承認済み          │
└─────────────────────────────┘
```

### 承認画面（管理者専用・新規作成）

```
┌─────────────────────────────┐
│ 休み希望承認                 │
├─────────────────────────────┤
│ 🔔 承認待ち 3件             │
│                             │
│ ┌─────────────────────┐    │
│ │ 佐藤 太郎 (10/21 申請)│    │
│ │ 休み希望曜日: 月・水   │    │
│ │ [承認] [却下]         │    │
│ └─────────────────────┘    │
│                             │
│ ┌─────────────────────┐    │
│ │ 田中 花子 (10/20 申請)│    │
│ │ 休み希望日: 10/25     │    │
│ │ [承認] [却下]         │    │
│ └─────────────────────┘    │
└─────────────────────────────┘
```

## 🔄 フロー

### スタッフ側

1. マイページで「編集」ボタンタップ
2. 休み希望を選択（曜日・特定日・シフトタイプ）
3. 「保存」→ ConstraintRequest作成（status: "pending"）
4. マイページに「⏳承認待ち」バッジ表示
5. 管理者が承認 → プッシュ通知受信
6. マイページに「✅承認済み」バッジ表示
7. または却下 → 「❌却下（理由）」バッジ表示

### 管理者側

1. 設定画面 → 「休み希望承認」メニュー（管理者のみ表示）
2. 承認画面で申請一覧確認
3. 各申請の詳細確認
4. 承認ボタンタップ
   - status → "approved"
   - Staffデータに反映（preferredDaysOff等を更新）
   - FCMでスタッフに通知
5. または却下ボタンタップ
   - 却下理由入力ダイアログ表示
   - status → "rejected"
   - rejectedReason を設定
   - FCMでスタッフに通知

### 管理者自身の休み希望

- 管理者が自分の休み希望を編集する場合は**即時反映**
- ConstraintRequestを作成せず、Staffデータを直接更新（従来通り）
- 承認プロセスは不要

## 📂 ファイル構成

```
lib/
├── models/
│   └── constraint_request.dart         🆕 承認リクエストモデル
├── providers/
│   └── constraint_request_provider.dart 🆕 承認リクエストProvider
├── screens/
│   ├── my_page_screen.dart             🔄 申請機能追加・状態表示
│   ├── settings_screen.dart            🔄 承認画面メニュー追加
│   └── approval/
│       └── constraint_approval_screen.dart 🆕 承認画面
└── widgets/
    └── constraint_request_card.dart    🆕 申請カード（承認画面用）
```

## ✅ 実装タスク（段階的実装）

**実装方針**: 4つのフェーズに分けて段階的に実装。各フェーズ完了後に動作確認してから次へ進む。

### Phase 1: データ層の構築（基盤）✅ 完了
**目的**: 申請データを管理する仕組みを作る

- [x] **ConstraintRequestモデル作成** (`models/constraint_request.dart`)
  - 申請ID、スタッフID、ユーザーID
  - 申請タイプ（特定日/曜日/シフトタイプ）
  - ステータス（pending/approved/rejected）
  - 承認者情報、却下理由など
  - toJson/fromJson実装
  - copyWith実装

- [x] **ConstraintRequestProvider作成** (`providers/constraint_request_provider.dart`)
  - Firestoreからリアルタイム取得（Stream）
  - CRUD操作（作成、更新、削除）
  - フィルタ機能（承認待ちのみ、自分の申請のみ等）
  - 承認処理（ステータス更新＋Staffデータ反映）
  - 却下処理（ステータス更新＋却下理由設定）

- [x] **Firestore構造追加**
  - `teams/{teamId}/constraint_requests/{requestId}` コレクション
  - Security Rules追加（簡易版）
  - firestore_security_rules.mdにドキュメント化

- [x] **HomeScreen統合**
  - MultiProviderにConstraintRequestProvider追加
  - Consumer統合
  - isLoadingチェック追加

- [x] **動作確認**: flutter analyze実行（エラーなし）

**完了日**: 2025-10-22

---

### Phase 2: スタッフ側の申請機能 ✅ 完了
**目的**: スタッフが休み希望を申請できるようにする

- [x] **マイページの編集ダイアログ改修**
  - **管理者の場合**: 即時反映（従来通り、Staffデータを直接更新）
  - **スタッフの場合**: ConstraintRequest作成（status: "pending"）
  - 保存ボタンのラベル: 管理者・スタッフ共通で「保存」に統一
  - _saveAsAdminメソッド: 管理者用の即時反映処理
  - _saveAsStaffメソッド: スタッフ用の申請作成処理
    - 既存のpending/rejected申請を全削除→新しい内容で再作成方式
    - 追加・削除の両方に対応
    - 曜日、特定日、シフトタイプごとに個別のConstraintRequest作成
    - 申請件数に応じたメッセージ分岐（0件なら「変更を保存しました」）

- [x] **マイページに申請状態表示を追加**
  - 各制約項目に状態バッジを表示
    - ⏳ 承認待ち（オレンジアイコン）
    - ❌ 却下（グレーアイコン、却下理由も表示）
    - 承認済み・申請なしはバッジ非表示
    - 管理者はバッジ非表示（即時反映のため）
  - ヘルパーメソッド実装
    - _getWeekdayRequest: 曜日の申請状態取得
    - _getSpecificDayRequest: 特定日の申請状態取得
    - _getShiftTypeRequest: シフトタイプの申請状態取得
    - _buildStatusBadge: 状態バッジウィジェット生成
  - Consumer4に変更（ConstraintRequestProvider追加）
  - 休み希望曜日、特定日、シフトタイプの全セクションに対応
  - 承認済み＋pending/rejected申請を統合表示（Set使用で重複排除）

- [x] **編集ダイアログの改善**
  - pending/rejected申請も初期表示に含める
  - 特定日の休み希望を日付順にソート
  - 今月以降のみ表示（過去月は完全非表示）

- [x] **表示の改善**
  - 勤務不可シフトタイプを時間順にソート（shiftTimeProvider.settings順）
  - Chipの幅を自然な幅に調整、レイアウト改善
  - マイページでも今月以降のみ表示

- [x] **ConstraintRequestProviderの修正**
  - createdAt/updatedAtのnullチェック追加（FieldValue.serverTimestamp対応）

- [x] **動作確認**: flutter analyze実行（エラーなし）、ビルド成功

**完了日**: 2025-10-22（全ての修正・改善完了）

**Phase 2 完了のポイント：**
- スタッフは休み希望を申請できる（追加・削除の両方に対応）
- 申請状態がバッジで明確に表示される（承認待ち・却下のみ）
- 管理者は即時反映、スタッフは申請→承認待ちフローが実装された
- 過去月のデータは表示されず、今月以降のみ表示される

---

### Phase 3: 管理者側の承認画面 ✅ 完了（バナー改善版）
**目的**: 管理者が申請を承認/却下できるようにする

- [x] **承認画面作成** (`screens/approval/constraint_approval_screen.dart`)
  - 承認待ちの申請一覧表示
  - 申請日時の新しい順にソート
  - 承認待ちなしの場合の空状態表示
  - Consumer2でConstraintRequestProviderとStaffProviderを統合

- [x] **申請カードウィジェット作成** (`widgets/constraint_request_card.dart`)
  - 再利用可能なカード形式コンポーネント
  - スタッフ名、申請日時、申請内容を表示
  - 申請タイプ別のアイコン表示
  - 承認・却下ボタン

- [x] **承認・却下処理実装**
  - **承認時**:
    1. ConstraintRequestProviderのapproveRequestを呼び出し
    2. ConstraintRequestのステータスを"approved"に更新
    3. Staffデータに反映（preferredDaysOff等を更新）
    4. 承認者情報・承認日時を記録
    5. 成功メッセージ表示

  - **却下時**:
    1. 却下理由入力ダイアログ表示
    2. 却下理由の入力必須チェック
    3. ConstraintRequestProviderのrejectRequestを呼び出し
    4. ConstraintRequestのステータスを"rejected"に更新
    5. 却下理由を記録
    6. Staffデータには反映しない
    7. 却下メッセージ表示

- [x] **UI配置の改善（ユーザーフィードバック対応）**
  - **当初計画**: 「その他」タブに承認メニュー → 「重要機能が埋もれる」と指摘
  - **第1案**: スタッフタブに承認待ちセクション統合 → 「スタッフ一覧が圧迫される」「レイアウト崩れ」と指摘
  - **最終判断**: コンパクトなバナー＋タップで専用画面に遷移

- [x] **承認待ちバナー実装** (`screens/staff_list_screen.dart`)
  - オレンジ背景の目立つバナー（Colors.orange.shade50）
  - 左：承認アイコン、中央：「承認待ち (X件)」＋「タップして確認」、右：右矢印
  - InkWellでタップ可能、リップルエフェクト付き
  - タップでConstraintApprovalScreenに遷移
  - 承認待ちがない場合は非表示（SizedBox.shrink）
  - Consumer<ConstraintRequestProvider>でリアルタイム更新

- [x] **スタッフタブにバッジ追加** (`screens/home_screen.dart`)
  - 承認待ち件数をリアルタイム表示（Badge widget使用）
  - _navigationDestinationsをメソッド化（動的バッジ生成）
  - Badge(isLabelVisible: pendingCount > 0)で件数0時は非表示

- [x] **動作確認**:
  - flutter analyze実行（エラーなし）
  - ビルド成功確認
  - レイアウト崩れなし確認

- [x] **エラー修正**:
  - Providerスコープエラー（ConstraintApprovalScreen遷移時）
    - Navigator.pushでProviderスコープ外になる問題
    - MultiProvider + Provider.valueでProviderを引き継ぐ修正
    - 対象: staff_list_screen.dartのバナータップ処理

**完了日**: 2025-10-22（バナー改善版＋エラー修正）

**Phase 3 完了のポイント（バナー改善版）：**
- スタッフ一覧が圧迫されず、ファーストビューで複数のスタッフが表示可能
- 承認待ちバナーはコンパクトで目立つ（オレンジ背景）
- バッジ（タブ）＋バナー（画面内）の2箇所で承認待ちを通知
- ワンアクション（タップ）で承認専用画面に遷移
- 承認待ちがない場合は完全に非表示（スタッフ一覧のみ表示）
- 承認・却下処理が実装され、Staffデータへの反映も自動化
- 承認待ち件数がリアルタイムで表示される
- 却下時は理由入力が必須

---

### Phase 4: 統合テスト
**目的**: 全体の動作確認

**テストケース**:
1. スタッフログイン → 休み希望申請 → 承認待ち表示確認
2. 管理者ログイン → 申請一覧確認 → 承認実行 → Staffデータ反映確認
3. スタッフログイン → 承認済みバッジ表示確認
4. 管理者ログイン → 別の申請を却下 → 却下理由入力
5. スタッフログイン → 却下バッジ+理由表示確認
6. 管理者が自分の休み希望編集 → 即時反映確認（申請なし）

---

### 将来対応（今回は実装しない）

**Phase 5: Push通知機能（7週目以降）**
- [ ] FCM基盤設定
- [ ] 承認時の通知実装
- [ ] 却下時の通知実装

**Phase 6: 締め日制御（7週目以降）**
- [ ] 設定画面に締め日設定追加
- [ ] 締め日後の申請制限
- [ ] Security Rules反映

## 🧪 テストケース

### スタッフ側
1. 休み希望申請→承認待ち表示確認
2. 申請後、マイページで状態確認
3. 承認後、承認済みバッジ表示確認
4. 却下後、却下バッジ+理由表示確認

### 管理者側
1. 承認画面で申請一覧表示確認
2. 承認処理→Staffデータ反映確認
3. 却下処理→却下理由入力・保存確認
4. 自分の休み希望は即時反映確認

### 統合テスト
1. スタッフA申請→管理者承認→スタッフA確認（承認済み）
2. スタッフB申請→管理者却下→スタッフB確認（却下+理由）
3. 管理者が自分の希望編集→即時反映

## 📅 スケジュール

| 日 | タスク |
|----|--------|
| 1-2日目 | データ層実装 |
| 3-5日目 | スタッフ側UI |
| 6-7日目 | 管理者側UI |

**完了目標**: 6週目終了時（7日後）

## 🔗 関連ドキュメント

- README-online.md（6週目タスク詳細）
- CLAUDE.md（次回作業内容）
- Firestoreデータ構造設計（README-online.md 4.1節）
