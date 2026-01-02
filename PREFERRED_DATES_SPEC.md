# 勤務希望日機能 設計仕様書

## 概要
スタッフが「この日はシフトに入りたい」という勤務希望日を設定できる機能。
自動割り当て時に希望を考慮し、手動編集の必要性を減らす。

---

## 背景・目的

### 課題
- Firebaseイベント分析により、手動でのシフト編集が多いことが判明
- 現状の自動生成は「勤務不可日」のみ考慮し、「勤務希望日」は考慮できない
- これが手動編集が多い原因の一つと推測

### 目的
- 勤務希望日を考慮した自動割り当てにより、手動編集を減らす
- スタッフ満足度の向上
- 管理者の負担軽減

---

## 設計方針

### MVP（最小限の実装）
- 特定日のみ対応（曜日指定は将来拡張）
- 既存UIを大きく変えず、オプション的に追加
- イベント送信で使用状況を追跡

### 拡張性
- 将来的に曜日指定も追加できる設計
- スタッフ優先度設定も追加できる設計

---

## データモデル

### Staff モデルへの追加

```dart
// lib/models/staff.dart

@HiveType(typeId: 0)
class Staff extends HiveObject {
  // 既存フィールド...

  // 勤務希望日（特定日）
  @HiveField(7)
  List<DateTime> preferredDates;

  // 将来拡張用（今は実装しない）
  // @HiveField(8)
  // List<int> preferredWeekdays;  // 勤務希望曜日
}
```

### Firestore スキーマ（オンライン版）

```
teams/{teamId}/staffs/{staffId}
├── ... 既存フィールド
└── preferredDates: array<timestamp>  // 勤務希望日
```

※ カウント（granted/denied）は永続化しない。
  1回の自動生成内で公平性を保つ方式のため。

---

## 優先度ルール

### 制約の優先順位
```
1. 勤務不可制約（最優先）
   - 勤務不可曜日
   - 勤務不可日

2. 勤務希望日
   - 勤務不可制約に違反しなければ割り当て

3. 公平性重視の自動割り当て
   - 残りのシフトを既存ロジックで割り当て
```

### 勤務希望日と勤務不可制約の競合
```
例: Aさんが12/25（水曜）を勤務希望日に設定
    しかしAさんは水曜が勤務不可曜日

結果: 勤務不可制約が優先 → 12/25は割り当てない
```

---

## 希望日競合時の公平性ルール

### 問題
同じ日に複数のスタッフが勤務希望を出した場合、
全員の希望を通すことはできない（シフト枠に限りがある）

### 解決策：ハイブリッド方式（1回の生成内で公平性を保つ）

```
優先順位の決定方法:

1. 充足率が低いスタッフを優先
   充足率 = 割り当て済み希望日数 / 希望日総数

2. 充足率が同じなら、希望日が少ないスタッフを優先
   （希望を絞って出している人を優先）

3. それも同じならランダム
```

### 例
```
【ケース1: 充足率で判定】
12/10 が競合（残り枠1）

Aさん: 希望5日中、2日割り当て済み → 充足率40%
Bさん: 希望4日中、2日割り当て済み → 充足率50%

→ Aさん優先（充足率が低い）

---

【ケース2: 充足率が同じ → 希望日数で判定】
12/15 が競合（残り枠1）

Aさん: 希望4日中、2日割り当て済み → 充足率50%
Dさん: 希望2日中、1日割り当て済み → 充足率50%

→ Dさん優先（充足率同じ、希望日数が少ない）

---

【ケース3: 充足率も希望日数も同じ → ランダム】
12/20 が競合（残り枠1）

Aさん: 希望3日中、1日割り当て済み → 充足率33%
Bさん: 希望3日中、1日割り当て済み → 充足率33%

→ ランダムで決定
```

### この方式のメリット
- カウントの永続化が不要
- 手動編集の影響を受けない
- 何回自動生成しても問題なし
- 1回の生成内では公平に分配される

### 将来拡張（締め機能実装時）
締め機能実装後は、確定したシフトに対して希望達成度を評価し、
月をまたいだ公平性も考慮できるようになる可能性がある。

---

## 自動割り当てロジック（2段階方式）

### 第1段階：勤務希望日の割り当て

```dart
void assignPreferredDates(List<Staff> staffs, Map<DateTime, List<String>> shifts) {
  // 各スタッフの割り当て済み希望日数を追跡（この生成内でのみ使用）
  Map<String, int> grantedCount = {};
  for (var staff in staffs) {
    grantedCount[staff.id] = 0;
  }

  // 1. 各日付ごとに希望者をグループ化
  Map<DateTime, List<Staff>> preferencesByDate = {};

  for (var staff in staffs) {
    for (var date in staff.preferredDates) {
      // 勤務不可制約チェック
      if (isAvailable(staff, date)) {
        preferencesByDate[date] ??= [];
        preferencesByDate[date]!.add(staff);
      }
    }
  }

  // 2. 各日付について割り当て処理
  for (var entry in preferencesByDate.entries) {
    var date = entry.key;
    var candidates = entry.value;

    // 既に埋まっているシフト枠を確認
    var remainingSlots = getAvailableSlots(date, shifts);

    if (remainingSlots <= 0) continue;

    // ハイブリッド方式で候補者をソート
    candidates.sort((a, b) {
      // 1. 充足率で比較（低い方が優先）
      var rateA = grantedCount[a.id]! / a.preferredDates.length;
      var rateB = grantedCount[b.id]! / b.preferredDates.length;
      if (rateA != rateB) return rateA.compareTo(rateB);

      // 2. 希望日数で比較（少ない方が優先）
      if (a.preferredDates.length != b.preferredDates.length) {
        return a.preferredDates.length.compareTo(b.preferredDates.length);
      }

      // 3. ランダム
      return Random().nextInt(3) - 1;
    });

    // 枠数分だけ割り当て
    for (var i = 0; i < min(remainingSlots, candidates.length); i++) {
      assignStaff(date, candidates[i]);
      grantedCount[candidates[i].id] = grantedCount[candidates[i].id]! + 1;
    }
  }
}
```

### 第2段階：残りシフトの割り当て（既存ロジック）

```dart
void assignRemainingShifts(List<Staff> staffs, Map<DateTime, List<String>> shifts) {
  // 既存の自動割り当てロジックを適用
  // - 公平性考慮
  // - 勤務不可制約考慮
  // - 選択された戦略（バランス型/公平性重視/分散重視）適用
}
```

---

## UI設計

### スタッフ編集ダイアログへの追加

```
┌─────────────────────────────────────┐
│ スタッフ編集                    [×] │
├─────────────────────────────────────┤
│ 名前: [田中太郎        ]            │
│                                     │
│ 勤務不可曜日:                       │
│ [月][火][水][木][金][土][日]        │
│                                     │
│ 勤務不可日:                         │
│ 12/25, 12/31                   [+]  │
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ [📅 勤務希望日を設定...]  ← 追加   │
│                                     │
├─────────────────────────────────────┤
│        [キャンセル]  [保存]         │
└─────────────────────────────────────┘
```

### 勤務希望日ダイアログ（別ダイアログ）

```
┌─────────────────────────────────────┐
│ 勤務希望日の設定              [×]   │
├─────────────────────────────────────┤
│                                     │
│ この日はシフトに入りたい日を        │
│ 選択してください                    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │      2025年1月              │    │
│ │ 日 月 火 水 木 金 土        │    │
│ │        1  2  3 [4] 5  6     │    │
│ │  7  8  9 10 11[12]13        │    │
│ │ 14 15 16 17 18 19 20        │    │
│ │ 21 22 23 24 25 26 27        │    │
│ │ 28 29 30 31                 │    │
│ └─────────────────────────────┘    │
│                                     │
│ 選択中: 1/4, 1/12                   │
│                                     │
│ ※勤務不可日・曜日と重なる場合は    │
│  勤務不可が優先されます             │
│                                     │
├─────────────────────────────────────┤
│          [キャンセル]  [保存]       │
└─────────────────────────────────────┘
```

---

## Analytics イベント

### 追加するイベント

```dart
// 勤務希望日を設定した
analytics.logEvent(
  name: 'preferred_dates_set',
  parameters: {
    'staff_id': staffId,
    'count': preferredDates.length,  // 設定した日数
  },
);

// 自動割り当てで勤務希望日が考慮された
analytics.logEvent(
  name: 'preferred_dates_assigned',
  parameters: {
    'total_preferences': totalPreferences,  // 全希望数
    'granted': grantedCount,                // 通った数
    'denied': deniedCount,                  // 通らなかった数
  },
);
```

---

## 実装フェーズ

### Phase 1: データモデル・基盤（0.5日）
- [ ] Staff モデルに preferredDates フィールド追加
- [ ] Hive アダプター更新（build_runner）
- [ ] Firestore スキーマ対応（StaffProvider）
- [ ] null安全な初期化処理

### Phase 2: UI実装（1日）
- [ ] スタッフ編集ダイアログにボタン追加
- [ ] 勤務希望日選択ダイアログ作成
- [ ] カレンダーでの日付選択UI（table_calendar使用）

### Phase 3: 自動割り当てロジック（1日）
- [ ] 第1段階ロジック実装（希望日割り当て）
- [ ] ハイブリッド方式の優先度計算
- [ ] 既存ロジック（第2段階）との統合

### Phase 4: テスト・Analytics（0.5日）
- [ ] 動作確認（Androidエミュレータ）
- [ ] Analytics イベント実装
- [ ] エッジケースのテスト

### 合計: 3日

---

## 将来拡張（今回は実装しない）

### 曜日指定での勤務希望
```dart
List<int> preferredWeekdays;  // 0=日曜, 1=月曜, ...
```

### スタッフ優先度設定
```dart
int staffPriority;  // 管理者が設定する優先度
```

### 希望強度
```dart
enum PreferenceStrength { must, preferred, optional }
```

---

## 注意事項

1. **後方互換性**: 既存データにはnullが入るため、null安全な実装（空リストで初期化）
2. **パフォーマンス**: 希望日が多い場合のソート処理に注意
3. **勤務不可との整合性**: 勤務希望日を設定する際、勤務不可曜日/日と重複する日は警告またはフィルタ

---

## 承認

- [ ] 設計レビュー完了
- [ ] 実装開始承認
