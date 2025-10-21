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

## ✅ 実装タスク（6週目）

### Phase 1: データ層（2日）
- [ ] ConstraintRequestモデル作成
- [ ] ConstraintRequestProvider作成
- [ ] Firestore構造追加・Security Rules更新
- [ ] 単体テスト

### Phase 2: スタッフ側UI（3日）
- [ ] マイページ編集機能を申請に変更
- [ ] 申請状態表示（承認待ち・承認済み・却下バッジ）
- [ ] 管理者の即時反映処理（従来通り）
- [ ] UIテスト

### Phase 3: 管理者側UI（2日）
- [ ] 承認画面作成（constraint_approval_screen.dart）
- [ ] 申請一覧表示
- [ ] 承認・却下処理
- [ ] 却下理由入力ダイアログ
- [ ] UIテスト

### Phase 4: 通知基盤準備（選択・7週目で実装）
- [ ] FCM基盤設定（6週目で準備のみ）
- [ ] 承認時の通知実装（7週目）
- [ ] 却下時の通知実装（7週目）

### Phase 5: 締め日制御（残り時間で実装）
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
