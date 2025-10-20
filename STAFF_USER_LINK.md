# スタッフ・ユーザー紐付け設計書

## 📋 概要

シフト工房のオンライン版では、以下の2つの概念が存在します：
- **Staff（スタッフ）**: シフトに割り当てられる「勤務者」情報（名前、制約、シフト設定など）
- **AppUser（ユーザー）**: アプリにログインする「アカウント」（メール、パスワード、権限）

この設計書では、この2つを適切に紐付ける仕組みを定義します。

---

## 🎯 設計目的

### 管理者の柔軟性を維持
- スタッフがアプリを使っていなくてもシフト作成が可能
- 未参加スタッフには印刷・LINE等で共有すればOK

### メンバーの利便性を提供
- アプリ参加したメンバーは自分のシフト閲覧・休み希望入力が可能
- 休み希望を自分で入力 → PUSH通知で管理者に届く
- 自動紐付けで手間を最小化

### 拡張性を確保
- 将来のメール招待リンク機能に対応
- コメント機能など、将来の拡張に対応

---

## 🔧 設計方針

### ハイブリッド方式：自動紐付け + 手動補正

#### 1. **自動紐付け（メールアドレスベース）**
メンバーがチーム参加時に、登録したメールアドレスで既存スタッフを検索し、一致したら自動で紐付け。

#### 2. **手動補正（スタッフ編集）**
メールアドレスが一致しない場合、管理者がスタッフ編集画面でメールアドレスを修正すれば紐付け。

#### 3. **可視化（スタッフ一覧）**
スタッフ一覧・編集画面で紐付け状態を明示。

---

## 📐 データモデル

### Staffモデル（既存）
```dart
class Staff {
  final String id;           // スタッフID
  final String name;         // 名前
  final String? email;       // メールアドレス（紐付けキー）
  final String? userId;      // 紐付けされたユーザーID（nullなら未紐付け）
  final String? phoneNumber; // 電話番号
  final int maxShiftsPerMonth;
  final bool isActive;
  // ... その他のフィールド
}
```

### AppUserモデル（既存）
```dart
class AppUser {
  final String uid;          // ユーザーID（Firebase Auth UID）
  final String email;        // メールアドレス
  final String displayName;  // 表示名
  final UserRole role;       // 権限（admin/member）
  final String? teamId;      // 所属チームID
  // ...
}
```

---

## 🔄 紐付けフロー

### パターンA：自動紐付け成功（理想的）

```
1. 管理者がスタッフAさんを登録
   - 名前: 田中太郎
   - メール: tanaka@example.com
   - userId: null（未紐付け）

2. 管理者が田中さんに招待コードを送る（LINE/メール等）

3. 田中さんが招待コードでチーム参加
   - サインアップ時のメール: tanaka@example.com

4. システムが自動紐付け
   - teamId + email で既存スタッフを検索
   - 一致 → staffs/{staffId}.userId = user.uid に更新
   - 結果: 紐付け完了 ✅

5. 田中さんは以下が可能に
   - 自分のシフトを閲覧
   - 休み希望を自分で入力（PUSH通知で管理者に届く）
   - 将来的にはコメント機能も利用可能
```

### パターンB：手動補正が必要（メールアドレス不一致）

```
1. 管理者がスタッフBさんを登録
   - 名前: 鈴木花子
   - メール: suzuki@example.com（または未入力）
   - userId: null

2. 鈴木さんが招待コードでチーム参加
   - サインアップ時のメール: hanako@gmail.com（違うアドレス）

3. システムが自動紐付けを試行
   - 一致するスタッフが見つからない
   - 結果: 未紐付けのまま ⚠️

4. 管理者がスタッフ一覧で「鈴木さんが未紐付け」と気づく

5. 管理者がスタッフ編集画面で対応
   方法1: 鈴木さんに「hanako@gmail.com」を教えてもらい、メールアドレスを更新
   方法2: 将来実装予定の「手動紐付け」機能を使用

6. メールアドレス更新 → 保存時に再度自動紐付け処理
   - 一致 → 紐付け完了 ✅
```

### パターンC：スタッフ未参加（管理者のみで運用）

```
1. 管理者がスタッフCさんを登録
   - 名前: 佐藤次郎
   - メール: 未入力 or 入力済み
   - userId: null

2. 佐藤さんは招待されない（またはアプリを使わない）

3. 管理者は佐藤さんにシフトを割り当て可能
   - 印刷してシフト表を共有
   - LINEでスクリーンショットを送る

4. 佐藤さんの休み希望は、口頭やLINEで聞いて管理者が代理入力

5. 佐藤さんは後日参加してもOK
   - 参加時に自動紐付けされる
   - 以降は自分で休み希望入力が可能に
```

---

## 🛠️ 実装詳細

### 1. 自動紐付けロジック

#### AuthService.joinTeamByCode の拡張
```dart
Future<void> joinTeamByCode({
  required String inviteCode,
  required String userId,
}) async {
  try {
    // 1. 招待コードでチーム検索（既存処理）
    final team = await _findTeamByInviteCode(inviteCode);

    // 2. ユーザー情報を取得
    final user = await getUser(userId);
    final userEmail = user?.email;

    // 3. チーム参加処理（既存処理）
    await _joinTeam(teamId: team.id, userId: userId);

    // 4. 【新規】メールアドレスで既存スタッフを検索して自動紐付け
    if (userEmail != null && userEmail.isNotEmpty) {
      await _autoLinkStaffByEmail(
        teamId: team.id,
        userId: userId,
        email: userEmail,
      );
    }
  } catch (e) {
    throw '❌ チーム参加に失敗しました: $e';
  }
}

/// メールアドレスで既存スタッフを検索し、自動紐付け
Future<void> _autoLinkStaffByEmail({
  required String teamId,
  required String userId,
  required String email,
}) async {
  try {
    // emailが一致するスタッフを検索
    final staffQuery = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .where('email', isEqualTo: email)
        .where('userId', isNull: true) // 未紐付けのみ
        .limit(1)
        .get();

    if (staffQuery.docs.isNotEmpty) {
      final staffId = staffQuery.docs.first.id;

      // userIdを更新（紐付け）
      await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .doc(staffId)
          .update({
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 自動紐付け成功: staffId=$staffId, userId=$userId');
    } else {
      debugPrint('⚠️ 自動紐付け: 一致するスタッフが見つかりません（email=$email）');
    }
  } catch (e) {
    // 紐付け失敗してもチーム参加は成功させる（エラーを投げない）
    debugPrint('❌ 自動紐付けエラー: $e');
  }
}
```

### 2. スタッフ編集での再紐付け

#### StaffProvider.updateStaff の拡張
```dart
Future<void> updateStaff(Staff staff) async {
  try {
    // 1. Firestoreを更新（既存処理）
    await _firestore
        .collection('teams')
        .doc(_teamId)
        .collection('staff')
        .doc(staff.id)
        .update(staff.toFirestore());

    // 2. 【新規】メールアドレスが変更されていたら再紐付け試行
    if (staff.email != null && staff.email!.isNotEmpty && staff.userId == null) {
      await _tryAutoLinkByEmail(staff.id, staff.email!);
    }

    notifyListeners();
  } catch (e) {
    throw '❌ スタッフ更新に失敗しました: $e';
  }
}

/// メールアドレスで未紐付けユーザーを検索して紐付け
Future<void> _tryAutoLinkByEmail(String staffId, String email) async {
  try {
    // emailが一致する未紐付けユーザーを検索
    final usersQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .where('teamId', isEqualTo: _teamId)
        .limit(1)
        .get();

    if (usersQuery.docs.isNotEmpty) {
      final userId = usersQuery.docs.first.id;

      // userIdを更新（紐付け）
      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('staff')
          .doc(staffId)
          .update({
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 再紐付け成功: staffId=$staffId, userId=$userId');
    }
  } catch (e) {
    debugPrint('❌ 再紐付けエラー: $e');
  }
}
```

### 3. スタッフ一覧での可視化

#### UI表示の追加
```dart
// スタッフ一覧画面（staff_list_screen.dart）
ListTile(
  leading: CircleAvatar(
    child: Text(staff.name[0]),
  ),
  title: Text(staff.name),
  subtitle: Row(
    children: [
      Text(staff.email ?? '未設定'),
      const SizedBox(width: 8),
      // 紐付け状態アイコン
      if (staff.userId != null)
        const Icon(Icons.check_circle, color: Colors.green, size: 16)
      else
        const Icon(Icons.circle_outlined, color: Colors.grey, size: 16),
      const SizedBox(width: 4),
      Text(
        staff.userId != null ? 'アプリ利用中' : '未参加',
        style: TextStyle(
          fontSize: 12,
          color: staff.userId != null ? Colors.green : Colors.grey,
        ),
      ),
    ],
  ),
  // ...
)
```

#### スタッフ編集画面での表示
```dart
// スタッフ編集ダイアログ（staff_edit_dialog.dart）
if (staff.userId != null)
  Card(
    color: Colors.green.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'アプリ利用中',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'このスタッフはアプリでシフト閲覧・休み希望入力が可能です',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  )
else
  Card(
    color: Colors.grey.shade100,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const Icon(Icons.circle_outlined, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '未参加',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'メールアドレスを入力して招待コードを共有すると、自動で紐付けされます',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  )
```

---

## 📊 実装ステップ

### ステップ1: 自動紐付けロジック実装
- [ ] `AuthService.joinTeamByCode`に自動紐付け処理を追加
- [ ] メールアドレスで既存スタッフを検索
- [ ] 一致したら`staff.userId`を更新
- [ ] デバッグログで動作確認

### ステップ2: スタッフ一覧の可視化
- [ ] `StaffListScreen`に紐付け状態アイコンを追加
- [ ] 「アプリ利用中」「未参加」のラベル表示
- [ ] カラーリング（緑/グレー）

### ステップ3: スタッフ編集での再紐付け
- [ ] `StaffProvider.updateStaff`に再紐付け処理を追加
- [ ] メールアドレス変更時に自動で再紐付け試行
- [ ] スタッフ編集ダイアログに紐付け状態カード追加

### ステップ4: テスト
- [ ] 自動紐付けの動作確認（メールアドレス一致）
- [ ] 自動紐付け失敗の確認（メールアドレス不一致）
- [ ] 手動補正の動作確認（メールアドレス編集）
- [ ] 未参加スタッフへのシフト割り当て確認

### ステップ5: ドキュメント更新
- [ ] CLAUDE.mdに実装完了を記録
- [ ] README-online.mdに紐付け機能の説明を追加

---

## 🚀 将来の拡張構想

### フェーズ2: メール招待リンク機能（v2.0）

#### 実装内容
1. **スタッフ編集画面に「招待メールを送る」ボタン追加**
2. **ディープリンク生成**
   ```
   https://shift-kobo.app/invite?code=ABC12345&email=tanaka@example.com
   ```
3. **リンクタップ時の動作**
   - アプリインストール済み → アプリ起動（招待コード自動入力）
   - 未インストール → Google Play/App Storeへ遷移
4. **サインアップ画面でパラメータ受け取り**
   - メールアドレス自動入力
   - 招待コード自動適用
5. **自動チーム参加 + 自動紐付け**

#### 技術スタック
- **Firebase Dynamic Links** または **App Links（Android）/ Universal Links（iOS）**
- `url_launcher`パッケージでメール送信
- `uni_links`パッケージでディープリンク受信

#### メリット
- ユーザー体験が劇的に向上（ワンタップで完了）
- 招待コード手動入力不要
- メールアドレスのタイポがなくなる

#### 実装時期
- Android版月間アクティブユーザー100人以上
- または、ユーザーからの強い要望がある場合

---

### フェーズ3: コメント機能（v2.5）

#### 実装内容
1. **シフト単位のコメント機能**
   - 各シフトにコメントスレッド
   - 管理者・メンバー間でやり取り可能
   - 例：「この日は早く帰りたいです」「了解しました」

2. **通知機能との連携**
   - コメント投稿時にPUSH通知
   - 既読機能

3. **急な欠勤・シフト変更の連絡**
   - 「今日シフトに入れません」等の緊急連絡
   - 管理者に即座に通知

4. **全体連絡**
   - チーム全体への連絡事項
   - 例：「来月のシフト締め切りは〇日です」

#### ユースケース
- **細かい要望を伝える**: 「この日は16時までに帰りたい」
- **急な欠勤連絡**: 「体調不良でシフトに入れません」
- **シフト交代の相談**: 「誰かこの日代わってもらえませんか？」
- **管理者からの連絡**: 「シフト確定しました。確認してください」

#### 技術的課題
- リアルタイム性（Firestore Realtime更新）
- PUSH通知の実装（Firebase Cloud Messaging）
- 既読管理
- スレッド表示UI

#### 実装タイミング
- v2.0（メール招待リンク）が安定稼働した後
- ユーザーからの要望次第
- 優先度：中〜高（コミュニケーション改善に直結）

---

### フェーズ4: 手動紐付け機能（v1.1〜v1.2）

#### 実装内容
1. **メンバー管理画面を追加**
   - 未紐付けユーザー一覧
   - 未紐付けスタッフ一覧
2. **ドラッグ&ドロップまたは選択式で紐付け**
3. **紐付け解除機能**

#### 実装タイミング
- メールアドレス自動紐付けでカバーできないケースが多発した場合
- 優先度：中（現状の自動紐付けで大半はカバー可能）

---

### フェーズ5: 複数チーム対応（v3.0）

#### 実装内容
- 1ユーザーが複数チームに所属可能
- チーム切り替え機能
- スタッフとして複数チームに登録可能

#### 実装タイミング
- 複数チーム運営のニーズが出てきた場合
- 優先度：低（まずは1チーム運用を完成させる）

---

## 📊 機能別の実装優先度まとめ

### ファーストリリース（v1.0）- 今回実装
| 機能 | 優先度 | 状態 |
|------|--------|------|
| 招待コード生成（8文字ランダム） | ⭐⭐⭐ | ✅ 完了 |
| メールアドレスベース自動紐付け | ⭐⭐⭐ | 🔄 実装中 |
| スタッフ一覧での紐付け状態表示 | ⭐⭐⭐ | 🔄 実装中 |
| スタッフ編集での再紐付け | ⭐⭐⭐ | 🔄 実装中 |
| 未参加スタッフへのシフト割り当て | ⭐⭐⭐ | ✅ 既存機能 |
| 管理者による休み希望代理入力 | ⭐⭐⭐ | ✅ 既存機能 |

### セカンドリリース（v1.1〜v1.2）- 短期
| 機能 | 優先度 | 想定時期 |
|------|--------|----------|
| 手動紐付け機能 | ⭐⭐ | 必要に応じて |
| メンバーによる休み希望入力 | ⭐⭐⭐ | v1.1 |
| PUSH通知（休み希望→管理者） | ⭐⭐⭐ | v1.1 |

### サードリリース（v2.0）- 中期
| 機能 | 優先度 | 想定時期 |
|------|--------|----------|
| メール招待リンク（ディープリンク） | ⭐⭐⭐ | v2.0 |
| QRコード招待 | ⭐ | v2.0 |

### フォースリリース（v2.5〜v3.0）- 長期
| 機能 | 優先度 | 想定時期 |
|------|--------|----------|
| コメント機能（シフト単位） | ⭐⭐ | v2.5 |
| コメント機能（チーム全体） | ⭐⭐ | v2.5 |
| 急な欠勤連絡機能 | ⭐⭐⭐ | v2.5 |
| 複数チーム対応 | ⭐ | v3.0 |

---

## 📝 関連ドキュメント

- [README-online.md](README-online.md) - オンライン化全体計画
- [CLAUDE.md](CLAUDE.md) - 開発進捗管理
- [Firestoreデータ構造](README-online.md#4-firestore構造設計詳細版)
- [Security Rules](README-online.md#43-security-rules)

---

## 🔧 トラブルシューティング

### Q: 自動紐付けされない
**原因**: メールアドレスが一致しない、またはスタッフが既に別のユーザーに紐付けられている

**対処法**:
1. スタッフ一覧で該当スタッフの紐付け状態を確認
2. スタッフ編集でメールアドレスを確認・修正
3. 保存時に自動再紐付けされる

### Q: 1つのメールアドレスに複数スタッフが登録されている
**原因**: 管理者が誤って同じメールアドレスを複数のスタッフに設定

**対処法**:
1. 自動紐付けは最初に見つかった1件のみ対象
2. 他のスタッフは手動で別のメールアドレスに修正

### Q: ユーザーが複数チームに参加した場合
**現状**: 1ユーザー1チームのみ対応（teamIdが上書きされる）

**将来対応**: v3.0で複数チーム対応を予定

---

## 📅 更新履歴

| 日付 | バージョン | 内容 |
|------|-----------|------|
| 2025-10-20 | v1.0 | 初版作成（ハイブリッド方式設計） |
