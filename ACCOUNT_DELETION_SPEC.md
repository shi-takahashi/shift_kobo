# アカウント削除機能 実装仕様書

## 概要

個人情報保護の観点から、ユーザーがアカウントを削除できる機能を実装する。
GDPR等のプライバシー規制に対応し、ユーザーに「削除権」を提供する。

---

## 実装計画（7つのPhase）

**Phaseは実装推奨順に番号付けしています**

### 実装推奨順序
1. **Phase 1**: ロール管理機能（アカウント削除の前提機能、最優先）
2. **Phase 2**: スタッフ本人がアカウント削除（最もシンプル）
3. **Phase 3**: 匿名化表示対応（Phase 2実装後に必要）
4. **Phase 4**: 管理者が自分を削除（Phase 1のロール管理機能が前提）
5. **Phase 5**: ドキュメント更新（Phase 2,4実装後）
6. **Phase 6**: チーム解散（Cloud Functions調査・実装が必要、最も複雑）
7. **Phase 7**: 管理者がスタッフを削除（Phase 6と同じ技術的課題）

---

### Phase 1: ロール管理機能 ⭐⭐⭐（最優先）
**優先度**: 最高（アカウント削除機能の前提）
**画面**: スタッフ編集ダイアログ - `lib/widgets/staff_edit_dialog.dart`

#### 機能
- スタッフのロール（admin/member）を変更できる
- 複数の管理者を許可（2〜3人推奨）
- 紐付けされたユーザー（userId != null）のみロール変更可能
- 唯一の管理者を降格させることはできない（警告表示）

#### 背景・目的
- **問題**: 現状、管理者権限を引き継ぐにはアカウント削除が必要
- **改善**: アカウント削除せずにロール変更可能にする
- **利点**:
  - 管理者交代が柔軟になる
  - 複数管理者で運用できる（冗長性確保）
  - 管理者が忙しい時の代替対応が可能

#### UI

**1. スタッフ編集ダイアログにロール選択を追加**

```dart
// 紐付けされているスタッフの場合のみ表示
if (staff.userId != null) {
  // ロールセクション
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ロール',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'member',
              label: Text('スタッフ'),
              icon: Icon(Icons.person),
            ),
            ButtonSegment(
              value: 'admin',
              label: Text('管理者'),
              icon: Icon(Icons.admin_panel_settings),
            ),
          ],
          selected: {_selectedRole},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _selectedRole = newSelection.first;
            });
          },
        ),
        if (_selectedRole == 'member' && _isLastAdmin) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'このユーザーは唯一の管理者です。\n'
                    '降格するには、他のスタッフを管理者にしてください。',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  ),
  const Divider(),
}
```

**2. 保存時のバリデーション**

```dart
// 唯一の管理者を降格させようとした場合
if (_isLastAdmin && _selectedRole == 'member') {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('唯一の管理者を降格できません。他のスタッフを管理者にしてください。'),
      backgroundColor: Colors.red,
    ),
  );
  return;
}
```

**3. 確認ダイアログ（ロール変更時）**

```dart
// 管理者に昇格する場合
if (oldRole == 'member' && newRole == 'admin') {
  AlertDialog(
    title: const Text('管理者に昇格'),
    content: Text(
      '「${staff.name}」さんを管理者に昇格させますか？\n\n'
      '管理者は以下の操作が可能になります：\n'
      '• シフト編集・削除\n'
      '• スタッフ管理\n'
      '• 承認機能\n'
      '• チーム設定の変更'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('昇格する'),
      ),
    ],
  );
}

// 管理者から降格する場合
if (oldRole == 'admin' && newRole == 'member') {
  AlertDialog(
    title: const Text('スタッフに降格'),
    content: Text(
      '「${staff.name}」さんをスタッフに降格させますか？\n\n'
      '降格後は以下の操作ができなくなります：\n'
      '• シフト編集・削除\n'
      '• スタッフ管理\n'
      '• 承認機能\n'
      '• チーム設定の変更'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.orange,
        ),
        child: const Text('降格する'),
      ),
    ],
  );
}
```

#### 処理フロー

1. スタッフ編集ダイアログを開く
2. 紐付けされているスタッフ（userId != null）の場合、ロール選択を表示
3. ロール変更を選択
4. **唯一の管理者チェック**:
   ```dart
   // 現在の管理者数を確認
   final adminCount = await _authService.getAdminCount(teamId);
   final isLastAdmin = (currentRole == 'admin' && adminCount == 1);
   ```
5. 唯一の管理者を降格させようとした場合 → エラー表示、保存不可
6. それ以外の場合 → 確認ダイアログ表示
7. 「昇格する」/「降格する」選択
8. Firestore更新:
   ```
   a. users/{userId}.role を更新（admin または member）
   b. スタッフ情報も更新（その他の変更があれば）
   ```
9. Provider通知 → 画面更新

#### バリデーション

- **紐付けチェック**: staff.userId != null の場合のみロール選択可能
- **唯一の管理者チェック**: 管理者が1人の場合、降格不可
- **権限チェック**: ロール変更操作は管理者のみ可能

#### エラーハンドリング

- 唯一の管理者を降格: 「唯一の管理者を降格できません」
- ネットワークエラー: 「通信エラーが発生しました」
- 権限不足: 「管理者権限が必要です」
- 更新失敗: 「ロール変更に失敗しました」

#### 実装ファイル

- `lib/widgets/staff_edit_dialog.dart`: ロール選択UI追加
- `lib/services/auth_service.dart`:
  - `getAdminCount(teamId)` メソッド追加
  - `updateUserRole(userId, newRole)` メソッド追加
- `lib/providers/staff_provider.dart`: 既存メソッド活用

#### テスト項目

1. **基本動作**:
   - [ ] 紐付けされたスタッフのみロール選択が表示される
   - [ ] 紐付けされていないスタッフはロール選択が非表示

2. **昇格テスト**:
   - [ ] スタッフを管理者に昇格できる
   - [ ] 昇格後、管理者機能が使用可能

3. **降格テスト**:
   - [ ] 管理者をスタッフに降格できる（他に管理者がいる場合）
   - [ ] 降格後、管理者機能が使用不可

4. **唯一の管理者テスト**:
   - [ ] 唯一の管理者は降格できない（警告表示）
   - [ ] 他のスタッフを管理者に昇格後、降格可能になる

5. **複数管理者テスト**:
   - [ ] 2人の管理者が同時に存在できる
   - [ ] 3人の管理者が同時に存在できる
   - [ ] 各管理者が管理者機能を使用可能

---

### Phase 2: スタッフ本人がアカウント削除 ⭐（最もシンプル）
**優先度**: 高
**画面**: 設定画面（その他タブ）- `lib/screens/settings_screen.dart`

#### 機能
- スタッフロールのユーザーが自分のアカウントを削除できる
- 削除後は招待前の状態に戻る（管理者から見たスタッフデータは残る）

#### UI
1. **設定画面に「アカウント削除」ボタン追加**
   - 場所: 「ヘルプ・情報」セクションの下部
   - 色: 赤色（危険な操作）
   - アイコン: Icons.delete_forever
   - テキスト: 「アカウント削除」
   - サブタイトル: 「アカウントと個人情報を削除」

2. **確認ダイアログ**
   ```dart
   AlertDialog(
     title: Text('アカウント削除'),
     content: Text(
       'アカウントを削除すると以下が削除されます：\n'
       '• ログイン情報（メールアドレス・パスワード）\n'
       '• 個人情報（メールアドレス等）\n'
       '• 休み希望の申請データ\n\n'
       'スタッフ登録データは管理者側に残ります。\n'
       '再度同じメールアドレスで登録・紐付けできます。\n\n'
       '本当に削除しますか？'
     ),
     actions: [
       TextButton('キャンセル'),
       TextButton('削除する', style: red),
     ],
   )
   ```

#### 処理フロー
1. ユーザーが「アカウント削除」ボタンをタップ
2. 確認ダイアログ表示
3. 「削除する」選択
4. ローディング表示
5. 以下を順番に実行:
   ```
   a. constraint_requests/ サブコレクション削除（staffIdで検索）
   b. Staff.userId = null に更新（紐付け解除）
   c. users/{userId} ドキュメント削除
   d. FirebaseAuth.currentUser.delete() 実行
   ```
6. ログアウト処理
7. ウェルカム画面へ遷移

#### エラーハンドリング
- Authentication削除失敗: 「削除に失敗しました。再ログインしてください」
- Firestore削除失敗: 「データ削除に失敗しました」
- 再認証が必要な場合: 「最近ログインしていないため、削除できません。再ログインしてください」

#### 実装ファイル
- `lib/services/auth_service.dart`: `deleteAccount()` メソッド追加
- `lib/screens/settings_screen.dart`: 削除ボタン＆ダイアログ追加
- `lib/providers/staff_provider.dart`: `unlinkStaffUser(staffId)` メソッド追加
- `lib/providers/constraint_request_provider.dart`: `deleteRequestsByStaffId(staffId)` メソッド追加

---

### Phase 3: 匿名化表示対応 ⭐⭐
**優先度**: 中
**画面**: カレンダー、シフト表、スタッフ一覧、その他

#### 機能
- Staffが削除されている場合、名前の代わりに「不明なユーザー (ID: xxx)」を表示
- 削除済みスタッフのシフトも表示できるようにする

#### 対応箇所

**1. カレンダー画面（lib/screens/calendar_screen.dart）**
```dart
// 現在
Text(shift.staffName)

// 修正後
Text(_getStaffName(shift.staffId))

String _getStaffName(String staffId) {
  final staff = staffProvider.getStaffById(staffId);
  if (staff == null) {
    return '不明なユーザー (ID: ${staffId.substring(0, 8)})';
  }
  return staff.name;
}
```

**2. シフト表出力（lib/screens/export_screen.dart）**
- Excel: セルに「不明なユーザー (ID: xxx)」を出力
- PNG: 同様に匿名化表示

**3. スタッフ一覧画面（lib/screens/staff_list_screen.dart）**
- 削除済みスタッフは非表示（userId == null かつ 最近のシフトなし）
- または「削除済み」ラベル付きで表示

**4. シフト編集ダイアログ（lib/widgets/shift_edit_dialog.dart）**
- スタッフ選択ドロップダウンから削除済みスタッフを除外

**5. 自動割り当てダイアログ（lib/widgets/auto_assignment_dialog.dart）**
- 削除済みスタッフは自動割り当て対象外

**6. マイページ（lib/screens/my_page_screen.dart）**
- 紐付け解除されたスタッフは「スタッフ情報が見つかりません」表示

#### ヘルパー関数追加
```dart
// lib/providers/staff_provider.dart
Staff? getStaffById(String staffId) {
  try {
    return _staff.firstWhere((s) => s.id == staffId);
  } catch (e) {
    return null;
  }
}

// 各画面で使用
String getStaffDisplayName(String staffId) {
  final staff = context.read<StaffProvider>().getStaffById(staffId);
  if (staff == null) {
    return '不明なユーザー (ID: ${staffId.substring(0, 8)})';
  }
  return staff.name;
}
```

#### 実装ファイル
- `lib/providers/staff_provider.dart`: `getStaffById()` メソッド追加
- `lib/screens/calendar_screen.dart`: 匿名化表示対応
- `lib/screens/export_screen.dart`: 匿名化表示対応
- `lib/widgets/shift_edit_dialog.dart`: 削除済みスタッフ除外
- `lib/widgets/auto_assignment_dialog.dart`: 削除済みスタッフ除外

---

### Phase 4: 管理者が自分を削除 ⭐⭐⭐
**優先度**: 中（Phase 1のロール管理実装後）
**画面**: 設定画面（その他タブ）- `lib/screens/settings_screen.dart`

#### 機能
- 管理者が自分のアカウントを削除できる
- **唯一の管理者の場合**: チーム解散を促す
- **他に管理者がいる場合**: 通常のアカウント削除

#### 前提条件
- Phase 1（ロール管理機能）が実装済み
- 管理者権限の引き継ぎはロール変更で対応（アカウント削除不要）

#### UI

**1. 設定画面に「アカウント削除」ボタン追加**
- 場所: 「アカウント」セクション
- 条件: すべてのユーザーに表示（管理者・スタッフ共通）
- 色: 赤色（危険な操作）
- アイコン: Icons.delete_forever
- テキスト: 「アカウント削除」
- サブタイトル: 「アカウントと個人情報を削除」

**2. 確認ダイアログ（唯一の管理者の場合）**
```dart
// 管理者が1人のみの場合
AlertDialog(
  title: Row(
    children: [
      Icon(Icons.warning_amber, color: Colors.red),
      SizedBox(width: 8),
      Expanded(child: Text('チームが削除されます')),
    ],
  ),
  content: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚠️ あなたは唯一の管理者です\n',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade900,
          ),
        ),
        Text(
          'アカウントを削除すると、チーム全体が解散されます。\n'
          '全データ・全アカウントが削除されます。',
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade900, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'チームを継続したい場合',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'スタッフ画面から、アプリを使用中のユーザー\n'
                '（アプリに登録済みのスタッフ）を\n'
                '次の管理者に指定してください。',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text(
          'どちらを選択しますか？',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('キャンセル'),
    ),
    TextButton(
      onPressed: () {
        Navigator.of(context).pop();
        // スタッフ画面に遷移
        _navigateToStaffScreen();
      },
      child: Text('スタッフ画面へ'),
    ),
    FilledButton(
      onPressed: () {
        Navigator.of(context).pop();
        // チーム解散画面に遷移
        _navigateToDissolveTeamScreen();
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
      ),
      child: Text('チームを解散する'),
    ),
  ],
)
```

**3. 確認ダイアログ（他に管理者がいる場合）**
```dart
// 管理者が複数いる場合
AlertDialog(
  title: Text('アカウント削除'),
  content: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'アカウントを削除すると以下が削除されます：\n'
          '• ログイン情報（メールアドレス・パスワード）\n'
          '• 個人情報（メールアドレス等）\n'
          '• 休み希望の申請データ\n'
          '• スタッフ登録データ',
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade900, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '他の管理者（${otherAdminCount}人）がチームを管理します',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '重要: 他の管理者がログインできない場合、\n'
                'チームが管理不能になります。\n'
                '削除前に必ず確認してください。',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text(
          '本当に削除しますか？\n'
          'この操作は取り消せません。',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: Text('キャンセル'),
    ),
    FilledButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
      ),
      child: Text('削除する'),
    ),
  ],
)
```

#### 処理フロー

**フロー1: 唯一の管理者の場合**
1. ユーザーが「アカウント削除」ボタンをタップ
2. 管理者数をチェック:
   ```dart
   final adminCount = await _authService.getAdminCount(teamId);
   final isLastAdmin = (appUser.role == 'admin' && adminCount == 1);
   ```
3. `isLastAdmin == true` の場合:
   - チーム解散促進ダイアログ表示
   - 「スタッフ画面へ」→ スタッフ一覧へ遷移（他のスタッフを管理者に昇格）
   - 「チーム解散へ」→ チーム解散画面へ遷移（Phase 6）
   - 「キャンセル」→ ダイアログ閉じる

**フロー2: 他に管理者がいる場合**
1. ユーザーが「アカウント削除」ボタンをタップ
2. 管理者数をチェック: `isLastAdmin == false`
3. 確認ダイアログ表示（他の管理者の人数も表示）
4. 「削除する」選択
5. ローディング表示
6. 以下を順番に実行:
   ```
   a. constraint_requests/ サブコレクション削除（自分の申請データ）
   b. Staff削除（自分のstaffIdを取得して削除）
   c. users/{userId} ドキュメント削除
   d. FirebaseAuth.currentUser.delete() 実行
   ```
7. ログアウト処理
8. ウェルカム画面へ遷移

#### バリデーション

- **管理者数チェック**: 削除前に必ず確認
- **唯一の管理者**: チーム解散または他のスタッフを管理者に昇格
- **再認証**: 最近ログインしていない場合、再認証が必要

#### エラーハンドリング

- Authentication削除失敗: 「削除に失敗しました。再ログインしてください」
- Firestore削除失敗: 「データ削除に失敗しました」
- 再認証が必要な場合: 「最近ログインしていないため、削除できません。再ログインしてください」
- ネットワークエラー: 「通信エラーが発生しました」

#### 実装ファイル

- `lib/services/auth_service.dart`:
  - `getAdminCount(teamId)` メソッド追加（Phase 1で実装済み）
  - `deleteAccount()` メソッド追加
- `lib/screens/settings_screen.dart`: 削除ボタン＆ダイアログ追加
- `lib/providers/staff_provider.dart`: `unlinkStaffUser(staffId)` メソッド活用
- `lib/providers/constraint_request_provider.dart`: `deleteRequestsByStaffId(staffId)` メソッド活用

#### テスト項目

1. **唯一の管理者テスト**:
   - [ ] 唯一の管理者が削除しようとすると、チーム解散促進ダイアログ表示
   - [ ] 「スタッフ画面へ」でスタッフ画面に遷移
   - [ ] 「チーム解散へ」でチーム解散画面に遷移

2. **複数管理者テスト**:
   - [ ] 管理者が2人以上いる場合、通常の削除ダイアログ表示
   - [ ] 他の管理者の人数が表示される
   - [ ] 削除後、ログイン不可
   - [ ] 残った管理者がチームを管理できる

3. **スタッフテスト**（Phase 2と同様）:
   - [ ] スタッフがアカウント削除
   - [ ] 削除後、ログイン不可
   - [ ] 管理者側でStaff.userId = null確認
   - [ ] 再登録・再紐付け可能

---

### Phase 5: ドキュメント更新 ⭐
**優先度**: 低（実装完了後）
**ファイル**: help_screen.dart, privacy-policy.html

#### ヘルプ画面更新（lib/screens/help_screen.dart）

**追加セクション: 「アカウント削除について」**
```dart
ExpansionTile(
  leading: Icon(Icons.delete_forever),
  title: Text('アカウント削除について'),
  children: [
    Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'スタッフの場合',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '「その他」タブ → 「アカウント削除」から削除できます。\n'
            '削除されるもの：\n'
            '• ログイン情報\n'
            '• 個人情報\n'
            '• 休み希望の申請データ\n\n'
            'スタッフ登録データは管理者側に残ります。'
          ),
          SizedBox(height: 16),
          Text(
            '管理者の場合',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '管理者がアカウントを削除しようとすると：\n\n'
            '• 他に管理者がいる場合\n'
            '  → 警告が表示されます\n'
            '  → 他の管理者がログインできるか確認してください\n'
            '  → 確認後、削除できます\n\n'
            '• 唯一の管理者の場合\n'
            '  → チーム全体が解散されます\n'
            '  → 全データ・全アカウントが削除されます\n'
            '  → チームを継続したい場合：\n'
            '    スタッフ画面から、アプリを使用中のユーザー\n'
            '    （アプリに登録済みのスタッフ）を\n'
            '    次の管理者に指定してください'
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade900),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '重要: 退職した管理者は必ずアカウントを削除してください。\n\n'
                    '理由:\n'
                    '• 個人情報が残り続ける\n'
                    '• 退職後もログインして操作できてしまう',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            '管理者権限の変更',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'スタッフ一覧から、アプリに登録済みスタッフの\n'
            'ロール（管理者/スタッフ）を変更できます。\n\n'
            '複数の管理者を設定することも可能です。'
          ),
        ],
      ),
    ),
  ],
)
```

#### プライバシーポリシー更新（docs/privacy-policy.html）

**セクション7（ユーザーの権利）に追加**
```html
<h3>7.3 データ削除権（追加）</h3>
<ul>
    <li><strong>アカウント削除機能</strong>
        <ul>
            <li>スタッフ: アプリ内から自分のアカウントを削除可能</li>
            <li>管理者: 他に管理者がいる場合、自分のアカウントを削除可能</li>
            <li>管理者: 唯一の管理者の場合、他のスタッフを管理者に昇格後に削除可能</li>
            <li>管理者: チーム全体を解散し、全データ・全アカウントを削除可能</li>
        </ul>
    </li>
    <li><strong>管理者権限の変更</strong>
        <ul>
            <li>スタッフのロール（管理者/スタッフ）を変更可能</li>
            <li>複数の管理者を設定可能（冗長性確保）</li>
            <li>紐付け済みユーザーのみロール変更可能</li>
        </ul>
    </li>
    <li><strong>削除されるデータ</strong>
        <ul>
            <li>Firebase Authentication（ログイン情報）</li>
            <li>Firestore Database（個人情報、申請データ）</li>
            <li>スタッフ登録データ（チーム解散時のみ）</li>
        </ul>
    </li>
    <li><strong>削除後の状態</strong>
        <ul>
            <li>アカウント削除: 再度同じメールアドレスで登録可能</li>
            <li>チーム解散: 全員がログインできなくなります</li>
        </ul>
    </li>
</ul>

<div class="warning">
    <strong>注意:</strong> 削除操作は取り消せません。重要なデータは事前にバックアップしてください。
</div>
```

**変更履歴に追加**
```html
<li><strong>2025-10-XX</strong>: アカウント削除機能の追加
    <ul>
        <li>ユーザーによるアカウント削除機能を実装</li>
        <li>GDPR「削除権」に対応</li>
        <li>管理者権限管理機能を追加（ロール変更、複数管理者対応）</li>
        <li>チーム解散機能を追加</li>
    </ul>
</li>
```

#### 実装ファイル
- `lib/screens/help_screen.dart`: 「アカウント削除について」セクション追加
- `docs/privacy-policy.html`: セクション7.3追加、変更履歴更新

---

### Phase 6: チーム解散 ⭐⭐⭐⭐⭐（最も複雑）
**優先度**: 中
**画面**: 新規「チーム解散画面」- `lib/screens/dissolve_team_screen.dart`（新規作成）

#### 機能
- 管理者がチーム全体を解散できる
- 全スタッフのアカウント削除、全データ削除
- 全員がアプリにログインできなくなる

#### UI

**1. 設定画面にボタン追加**
- 場所: 「データ管理」セクションの最下部
- 条件: `appUser.isAdmin` の場合のみ表示
- 色: 赤色（危険な操作）
- テキスト: 「チーム解散」
- サブタイトル: 「全データ・全アカウント削除」
- アイコン: Icons.cancel

**2. チーム解散画面（警告画面）**
```dart
Scaffold(
  appBar: AppBar(
    title: Text('チーム解散'),
    backgroundColor: Colors.red,
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 警告アイコン
        Center(
          child: Icon(
            Icons.warning_amber_rounded,
            size: 80,
            color: Colors.red,
          ),
        ),
        SizedBox(height: 24),

        // 警告メッセージ
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ 重要な警告',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'チームを解散すると、以下がすべて削除されます：',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16),

        // 削除されるデータ一覧
        _buildDeletedDataSection(),

        SizedBox(height: 24),

        // 確認テキスト入力
        Text(
          '本当に解散する場合は、下記に「解散する」と入力してください',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _confirmTextController,
          decoration: InputDecoration(
            hintText: '解散する',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _canDissolve = value == '解散する';
            });
          },
        ),

        SizedBox(height: 32),

        // 解散ボタン
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canDissolve ? _confirmDissolve : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'チームを解散する',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  ),
)

Widget _buildDeletedDataSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildDeletedItem('全スタッフのアカウント（${staffCount}人）'),
      _buildDeletedItem('全スタッフのログイン情報'),
      _buildDeletedItem('全スタッフの個人情報'),
      _buildDeletedItem('全シフトデータ（${shiftCount}件）'),
      _buildDeletedItem('全休み希望申請データ'),
      _buildDeletedItem('チーム設定'),
      _buildDeletedItem('シフト時間設定'),
      _buildDeletedItem('月間シフト設定'),
      SizedBox(height: 16),
      Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade900),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '解散後、全員がアプリにログインできなくなります。\n'
                  'この操作は取り消せません。',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildDeletedItem(String text) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.close, color: Colors.red, size: 20),
        SizedBox(width: 8),
        Text(text),
      ],
    ),
  );
}
```

**3. 最終確認ダイアログ**
```dart
AlertDialog(
  title: Text('本当に解散しますか？'),
  content: Text(
    '最後の確認です。\n\n'
    'チームを解散すると：\n'
    '• ${staffCount}人全員のアカウントが削除されます\n'
    '• 全データが完全に削除されます\n'
    '• この操作は取り消せません\n\n'
    '本当によろしいですか？'
  ),
  actions: [
    TextButton('キャンセル'),
    TextButton(
      '解散する',
      style: TextButton.styleFrom(foregroundColor: Colors.red),
    ),
  ],
)
```

#### 処理フロー
1. 設定画面で「チーム解散」をタップ
2. チーム解散画面へ遷移
3. 削除されるデータ一覧を表示
4. 「解散する」と入力
5. 「チームを解散する」ボタンが有効化
6. ボタンタップ → 最終確認ダイアログ
7. 「解散する」選択
8. プログレスダイアログ表示（キャンセル不可）
9. 以下を順番に実行:
   ```
   a. 全スタッフのuserIdリスト取得
   b. 全スタッフのAuthentication削除（Cloud Functions経由？）
   c. users/ 全ドキュメント削除（チームメンバー全員）
   d. constraint_requests/ 全削除
   e. shifts/ 全削除
   f. staffs/ 全削除
   g. teams/{teamId}/settings/shift_time_settings 削除
   h. teams/{teamId}/settings/monthly_requirements 削除
   i. teams/{teamId} 削除
   ```
10. 完了メッセージ表示
11. ログアウト処理
12. ウェルカム画面へ遷移

#### 技術的課題

**最大の課題: 他人のAuthentication削除**

**問題**:
- FlutterクライアントからFirebaseAuthの他のユーザーを削除できない
- セキュリティ上の制約

**解決策（3つの選択肢）**:

**選択肢A: Firebase Admin SDK + Cloud Functions**
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.dissolveTeam = functions.https.onCall(async (data, context) => {
  // 認証チェック: 呼び出し元が管理者か
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
  }

  const teamId = data.teamId;
  const callerUid = context.auth.uid;

  // 呼び出し元が該当チームの管理者か確認
  const userDoc = await admin.firestore().collection('users').doc(callerUid).get();
  if (!userDoc.exists || userDoc.data().teamId !== teamId || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Not authorized');
  }

  // チームの全メンバーのuserIdを取得
  const usersSnapshot = await admin.firestore()
    .collection('users')
    .where('teamId', '==', teamId)
    .get();

  const userIds = usersSnapshot.docs.map(doc => doc.id);

  // 全メンバーのAuthenticationを削除
  const deletePromises = userIds.map(uid => admin.auth().deleteUser(uid));
  await Promise.all(deletePromises);

  // Firestoreデータ削除（バッチ処理）
  // ... (省略)

  return { success: true, deletedUsers: userIds.length };
});
```

Flutter側:
```dart
final callable = FirebaseFunctions.instance.httpsCallable('dissolveTeam');
final result = await callable.call({'teamId': teamId});
```

**選択肢B: Firestore削除のみ（Authenticationは残す）**
- Authenticationは孤立データとして残る
- ユーザーが次回ログイン時に「チームが見つかりません」エラー
- メリット: Cloud Functions不要、実装が簡単
- デメリット: 個人情報（メールアドレス）が残る

**選択肢C: 手動削除案内**
- アプリ内では削除できない旨を表示
- 管理者に「解散希望」をサポートメールで送信してもらう
- 開発者が手動でFirebase Consoleから削除
- メリット: 実装不要
- デメリット: ユーザー体験が悪い

**推奨**: 選択肢A（Cloud Functions）
- 理由: 個人情報保護の観点、完全な削除が必要

#### エラーハンドリング
- Authentication削除失敗: 「一部のアカウント削除に失敗しました」
- Firestore削除失敗: ロールバック不可のため、エラーログ記録
- ネットワークエラー: 「通信エラー。再試行してください」
- 権限エラー: 「管理者権限がありません」

#### プログレス表示
```dart
// 進捗ダイアログ
AlertDialog(
  title: Text('チームを解散しています...'),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 16),
      Text(_progressMessage), // 「アカウント削除中...」「データ削除中...」
    ],
  ),
)
```

#### 実装ファイル
- `lib/screens/dissolve_team_screen.dart`: 新規作成
- `lib/services/team_service.dart`: 新規作成、`dissolveTeam(teamId)` メソッド
- `lib/screens/settings_screen.dart`: 「チーム解散」ボタン追加
- `functions/index.js`: Cloud Functions（選択肢Aの場合）

#### テスト計画
- 開発環境で十分にテスト
- 削除前にバックアップ機能でデータ保存
- 少人数のテストチームで動作確認
- 本番環境では慎重に展開

---

---

### Phase 7: 管理者がスタッフを削除 ⭐⭐
**優先度**: 低（Phase 6実装後）
**画面**: スタッフ編集ダイアログ - `lib/widgets/staff_edit_dialog.dart`

#### 機能
- 管理者がスタッフを削除する際、そのスタッフのアカウントも同時に削除できる
- 従来通りスタッフデータのみ削除することも可能

#### UI
1. **スタッフ編集ダイアログの削除ボタン改修**
   - 現在: 「削除」ボタン → 確認ダイアログ
   - 追加: チェックボックス「アカウントも削除する」

2. **確認ダイアログ更新**
   ```dart
   // チェックなしの場合（従来通り）
   'スタッフ「〇〇」を削除しますか？'

   // チェックありの場合
   'スタッフ「〇〇」を削除しますか？\n\n'
   '⚠️ アカウントも削除されます：\n'
   '• ログイン情報\n'
   '• 個人情報\n'
   '• 申請データ\n\n'
   'このスタッフはアプリにログインできなくなります。'
   ```

#### 処理フロー

**チェックなし（従来通り）**:
1. staffs/{staffId} 削除
2. 関連シフト削除

**チェックあり**:
1. Staff.userId 取得
2. userId が null でない場合:
   ```
   a. constraint_requests/ サブコレクション削除
   b. users/{userId} 削除
   c. Authentication削除（Cloud Functions経由）
   ```
3. staffs/{staffId} 削除
4. 関連シフト削除

#### 技術的課題
**問題**: 管理者が他のユーザーのAuthenticationを削除できるか？

**解決策**: Phase 6（チーム解散）と同じCloud Functions方式を使用

**実装**:
- Phase 6で実装した`dissolveTeam` Cloud Functionを参考にする
- 新しいCloud Function `deleteStaffAccount(staffUserId)` を追加
- 管理者のみ呼び出し可能（セキュリティルール）

#### 実装ファイル
- `lib/services/auth_service.dart`: `deleteStaffAccount(userId)` メソッド追加
- `lib/widgets/staff_edit_dialog.dart`: チェックボックス＆確認ダイアログ追加
- `lib/providers/staff_provider.dart`: `deleteStaffWithAccount(staffId)` メソッド追加
- `functions/index.js`: `deleteStaffAccount` Cloud Function追加（Phase 6と同様）

---

## 技術的課題まとめ

### 課題1: 他人のAuthentication削除
**問題**: FlutterクライアントからFirebase Authの他のユーザーを削除できない

**解決策**:
- Cloud Functions + Firebase Admin SDK
- または Firestore削除のみ（Authentication孤立）

**必要な作業**:
- Firebase Functionsプロジェクトのセットアップ
- `firebase-tools` インストール
- `functions/` ディレクトリ作成
- `dissolveTeam` Cloud Function実装
- セキュリティルール（管理者のみ呼び出し可能）

### 課題2: トランザクション処理
**問題**: 複数のコレクション削除を安全に実行

**解決策**:
- Firestore Batch Writes（最大500操作まで）
- 500件以上の場合はループ処理
- エラー時のロールバック困難（一部削除済み）

**対応**:
- 削除前にバックアップ推奨メッセージ
- 「この操作は取り消せません」警告
- プログレス表示で進捗を可視化

### 課題3: 再認証の必要性
**問題**: Firebase Authのアカウント削除は「機密性の高い操作」

**現象**:
- 最近ログインしていない場合、`requires-recent-login` エラー
- 削除前に再認証が必要

**解決策**:
```dart
try {
  await FirebaseAuth.instance.currentUser?.delete();
} on FirebaseAuthException catch (e) {
  if (e.code == 'requires-recent-login') {
    // 再認証ダイアログ表示
    showDialog(
      context: context,
      builder: (context) => ReauthDialog(),
    );
  }
}

// 再認証後に再度削除
final credential = EmailAuthProvider.credential(
  email: user.email!,
  password: password,
);
await user.reauthenticateWithCredential(credential);
await user.delete();
```

---

## セキュリティ考慮事項

### 1. 権限チェック
- 削除操作は本人または管理者のみ
- FirestoreルールでもWサーバー側で検証

### 2. 確認ダイアログ
- 重要な操作には必ず確認ダイアログ
- 「削除する」等のテキスト入力で誤操作防止

### 3. 削除の取り消し不可
- ユーザーに明示的に警告
- バックアップ推奨メッセージ

### 4. 個人情報の完全削除
- Authentication + Firestore両方を削除
- 孤立データを残さない

---

## テスト計画

### Phase 1テスト: ロール管理
1. 紐付け済みスタッフのロール変更
2. 管理者に昇格できることを確認
3. スタッフに降格できることを確認（他に管理者がいる場合）
4. 唯一の管理者は降格できないことを確認
5. 複数管理者が同時に存在できることを確認

### Phase 2テスト: スタッフ本人がアカウント削除
1. スタッフがアカウント削除
2. 削除後、ログイン不可を確認
3. 管理者側でStaff.userId = null確認
4. 再登録・再紐付け可能を確認

### Phase 4テスト: 管理者が自分を削除
1. 唯一の管理者が削除しようとすると、チーム解散促進ダイアログ表示
2. 他のスタッフを管理者に昇格後、削除可能
3. 管理者が複数いる場合、そのまま削除可能
4. 削除後、ログイン不可
5. 残った管理者がチームを管理できる

### Phase 6テスト: チーム解散（慎重に）
1. テスト用チーム作成
2. 複数スタッフ登録
3. チーム解散実行
4. 全員がログイン不可を確認
5. Firestoreデータ削除を確認

---

## 実装チェックリスト

### Phase 1: ロール管理機能
- [ ] AuthService.getAdminCount(teamId) メソッド実装
- [ ] AuthService.updateUserRole(userId, newRole) メソッド実装
- [ ] StaffEditDialog にロール選択UI追加
- [ ] 唯一の管理者チェック実装
- [ ] 昇格・降格の確認ダイアログ実装
- [ ] ロール変更処理実装
- [ ] エラーハンドリング実装
- [ ] テスト実施（基本動作、昇格、降格、唯一の管理者、複数管理者）

### Phase 2: スタッフ本人がアカウント削除
- [ ] AuthService.deleteAccount() メソッド実装
- [ ] ConstraintRequestProvider.deleteRequestsByStaffId() メソッド実装
- [ ] StaffProvider.unlinkStaffUser() メソッド実装
- [ ] SettingsScreen に削除ボタン追加
- [ ] 確認ダイアログ実装
- [ ] エラーハンドリング実装
- [ ] 再認証処理実装
- [ ] テスト実施

### Phase 3: 匿名化表示対応
- [ ] StaffProvider.getStaffById() メソッド追加
- [ ] CalendarScreen 匿名化対応
- [ ] ExportScreen 匿名化対応
- [ ] ShiftEditDialog 削除済みスタッフ除外
- [ ] AutoAssignmentDialog 削除済みスタッフ除外
- [ ] テスト実施

### Phase 4: 管理者が自分を削除
- [ ] AuthService.getAdminCount(teamId) メソッド活用（Phase 1で実装済み）
- [ ] SettingsScreen に削除ボタン追加
- [ ] 唯一の管理者チェック実装
- [ ] チーム解散促進ダイアログ実装
- [ ] 複数管理者時の確認ダイアログ実装
- [ ] アカウント削除処理実装
- [ ] エラーハンドリング実装
- [ ] テスト実施（唯一の管理者、複数管理者、スタッフ）

### Phase 5: ドキュメント更新
- [ ] HelpScreen に「アカウント削除について」追加
- [ ] HelpScreen に「管理者権限の変更」追加
- [ ] privacy-policy.html セクション7.3追加
- [ ] privacy-policy.html 変更履歴更新

### Phase 6: チーム解散
- [ ] Cloud Functions プロジェクトセットアップ
- [ ] dissolveTeam Cloud Function 実装
- [ ] セキュリティルール設定
- [ ] DissolveTeamScreen 作成
- [ ] 削除データ一覧表示
- [ ] テキスト入力確認実装
- [ ] TeamService.dissolveTeam() メソッド実装
- [ ] プログレスダイアログ実装
- [ ] エラーハンドリング実装
- [ ] SettingsScreen にボタン追加
- [ ] テスト実施（テスト環境で十分に）

### Phase 7: 管理者がスタッフを削除
- [ ] StaffEditDialog にチェックボックス追加
- [ ] 確認ダイアログ更新
- [ ] deleteStaffAccount Cloud Function 実装（Phase 6と同様）
- [ ] StaffProvider.deleteStaffWithAccount() メソッド実装
- [ ] エラーハンドリング実装
- [ ] テスト実施

---

## よくある質問（FAQ）

### Q1: スタッフが削除された後、過去のシフトはどうなる？
A1: シフトデータは残りますが、名前は「不明なユーザー (ID: xxx)」と表示されます。

### Q2: 唯一の管理者が自分のアカウントを削除したらどうなる？
A2: チーム全体が解散され、全データ・全アカウントが削除されます。チームを継続したい場合は、削除前に他のスタッフを管理者に昇格させてください。

### Q3: 管理者が複数いる状態で、1人の管理者がアカウント削除したらどうなる？
A3: その管理者のアカウントのみ削除されます。他の管理者がチームを管理します。ただし、削除前に必ず「他の管理者がログインできるか」確認してください。

### Q4: チーム解散後、データを復元できる？
A4: できません。解散前に必ずバックアップしてください。

### Q5: スタッフが削除したアカウントを復活できる？
A5: できません。同じメールアドレスで再登録・再紐付けは可能です。

### Q6: 管理者が退職する前にやるべきことは？
A6:
- 他に管理者がいる場合: 他の管理者がログインできることを確認後、アカウント削除
- 唯一の管理者の場合: スタッフ一覧から次の管理者を指定後、アカウント削除
- 重要: 退職した管理者は必ずアカウントを削除してください
  - 理由: 個人情報が残り続ける、退職後もログインして操作できてしまう

### Q7: 管理者は何人まで設定できる？
A7: 制限はありませんが、2〜3人が推奨です。管理者が多すぎると運用が複雑になる可能性があります。

### Q8: 紐付けされていないスタッフを管理者にできる？
A8: できません。管理者はアプリにログインする必要があるため、アプリに登録済み（紐付け済み）のユーザーのみロール変更可能です。

---

## 変更履歴

- 2025-10-23: 初版作成
  - Phase 1〜6の計画策定
- 2025-10-23: Phase 1（ロール管理機能）を追加
  - ユーザーからのフィードバックにより、アカウント削除前にロール管理機能が必要と判断
  - 複数管理者対応、唯一の管理者チェック、ロール変更機能を追加
  - Phase番号を1つずつずらし、全7フェーズに変更
  - Phase 4（管理者削除）のロジックを大幅変更（権限引き継ぎ画面を削除、ロール変更で対応）
  - ドキュメント、FAQ、テスト計画も更新
- 2025-10-23: Phase 4（管理者削除）の警告文を強化
  - 唯一の管理者の場合: 「チーム全体が解散されます」を明確に表示、チーム継続したい場合の案内を追加
  - 他に管理者がいる場合: 「他の管理者がログインできない場合の警告」を追加（退職済み管理者の放置問題に対応）
  - ヘルプ画面: 「退職した管理者は必ずアカウントを削除」という注意書きを追加（理由: 個人情報保護、セキュリティリスク）
  - FAQ更新: Q2, Q3, Q6を詳細化、Q8を追加（管理者の退職シナリオに対応）
  - 警告文の表現を修正: 「チームが管理不能になる」という誤解を招く表現を削除、「個人情報保護」と「セキュリティリスク」を主な理由に変更
