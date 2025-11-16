# 匿名認証実装計画書

## 📅 作成日
2025-11-15

---

## 🎯 目的

### 課題
- オンライン化により、アカウント作成が必須になった
- これがユーザーにとってハードルを上げ、逆効果になっている
- 実際のニーズは「管理者のシフト作成支援」であり、初回からチーム共有を強要する必要はない

### 解決策
**Firebase Anonymous Authentication（匿名認証）**を導入

- 初回起動時にアカウント登録不要（匿名で即使える）
- データはFirestoreに保存（アプリ削除しても復元可能）
- 後からメールアドレスでアカウント登録可能（データ完全引き継ぎ）

---

## 🔍 匿名認証の仕組み

### Firebase Authenticationの構造

#### 匿名ユーザー（初回）
```
┌─────────────────────────────────┐
│ ID（識別子）: (空欄)              │
│ ユーザーUID: kF8mX2nQ5rZtP9vW... │ ← ランダム文字列（Firebase自動生成）
│ Provider: anonymous              │
└─────────────────────────────────┘
```

#### メールアドレス登録後（linkWithCredential）
```
┌─────────────────────────────────┐
│ ID（識別子）: user@example.com   │ ← メールアドレスが追加される
│ ユーザーUID: kF8mX2nQ5rZtP9vW... │ ← 同じまま！（重要）
│ Provider: password                │
└─────────────────────────────────┘
```

### データの保存先
```
Firestore:
users/{ユーザーUID}/
  ├── email: null（匿名）または "user@example.com"（登録後）
  ├── displayName: "ゲスト" → "山田太郎"
  ├── teamId: "abc123"（デフォルトチーム）
  └── ...

teams/abc123/  ← デフォルトチーム「マイワークスペース」
  ├── name: "マイワークスペース"
  ├── ownerId: {ユーザーUID}
  ├── shifts/
  ├── staff/
  └── ...
```

---

## 📝 実装タスク詳細

### タスク1: AppUserモデルの修正

**ファイル**: `lib/models/app_user.dart`

**変更内容**:
```dart
// 変更前
final String email;

// 変更後
final String? email;  // nullable（匿名ユーザーはnull）
```

**理由**:
- 匿名ユーザーはメールアドレスを持たないため

**影響範囲**:
- `fromFirestore`でnullチェック追加
- 既存ユーザーは必ずemailを持つので影響なし

---

### タスク2: AuthServiceに匿名ログイン機能を追加

**ファイル**: `lib/services/auth_service.dart`

**追加メソッド**:
```dart
/// 匿名ログイン + デフォルトチーム自動作成
Future<User?> signInAnonymously() async {
  // 1. Firebase匿名認証
  final userCredential = await _auth.signInAnonymously();
  final user = userCredential.user;

  // 2. デフォルトチーム「マイワークスペース」を作成
  final team = await _createDefaultTeam(user!.uid);

  // 3. AppUserをFirestoreに保存
  final appUser = AppUser(
    uid: user.uid,
    email: null,  // 匿名なのでnull
    displayName: 'ゲスト',
    role: UserRole.admin,
    teamId: team.id,  // デフォルトチームに所属
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await _firestore.collection('users').doc(user.uid).set(appUser.toFirestore());

  return user;
}

/// デフォルトチームを作成
Future<Team> _createDefaultTeam(String ownerId) async {
  final team = Team(
    id: '',
    name: '',  // 空文字（アカウント登録時に入力）
    ownerId: ownerId,
    adminIds: [ownerId],
    memberIds: [ownerId],
    inviteCode: await _generateUniqueInviteCode(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final docRef = await _firestore.collection('teams').add(team.toFirestore());
  return team.copyWith(id: docRef.id);
}
```

**処理フロー**:
1. Firebase匿名認証 → UID自動発行
2. デフォルトチーム「マイワークスペース」作成
3. AppUser作成（email: null, teamId: デフォルトチームID）
4. Firestoreに保存

**重要**:
- チーム作成/参加画面をスキップできる（既にチーム所属済み）
- すぐにHomeScreenへ遷移可能

---

### タスク3: AuthServiceにアカウントアップグレード機能を追加

**ファイル**: `lib/services/auth_service.dart`

**追加メソッド**:
```dart
/// 匿名ユーザーをメールアドレスでアップグレード
/// ★UIDは変わらない = データは完全に引き継がれる★
Future<User?> upgradeAnonymousToEmail({
  required String email,
  required String password,
  required String teamName,  // チーム名を追加
}) async {
  final user = _auth.currentUser;

  // 匿名ユーザーかチェック
  if (user == null || !user.isAnonymous) {
    throw '匿名ユーザーではありません';
  }

  print('🔄 [Upgrade] 匿名 → メール登録');
  print('🔄 [Upgrade] 現在のUID: ${user.uid}（変わりません）');

  // メールアドレスを紐付け（★重要: UIDは変わらない★）
  final credential = EmailAuthProvider.credential(
    email: email,
    password: password,
  );

  await user.linkWithCredential(credential);

  // displayNameを自動設定（@より前）
  final displayName = email.split('@')[0];
  await user.updateDisplayName(displayName);

  // Firestoreのusersドキュメントを更新
  await _firestore.collection('users').doc(user.uid).update({
    'email': email,
    'displayName': displayName,  // 自動設定
    'updatedAt': Timestamp.now(),
  });

  // チーム名を更新（空文字 → 入力値）
  final appUser = await getUser(user.uid);
  if (appUser?.teamId != null) {
    await _firestore.collection('teams').doc(appUser!.teamId).update({
      'name': teamName,
      'updatedAt': Timestamp.now(),
    });
  }

  print('✅ [Upgrade] 完了！UID: ${user.uid}（データはそのまま）');

  return user;
}
```

**重要なポイント**:
- ❌ `createUserWithEmailAndPassword`は使わない
  - 新しいUIDが発行される → 前のデータにアクセスできなくなる
- ✅ `linkWithCredential`を使う
  - UIDは変わらない → データは完全に引き継がれる
- ✅ `displayName`は自動設定（メールアドレスの@より前）
- ✅ チーム名を更新（空文字から入力値へ）

**データの変化**:
```
【登録前】
users/abc123/
  ├── email: null
  ├── displayName: "ゲスト"
  └── teamId: "xyz789"

teams/xyz789/  ← シフトデータあり
  ├── name: ""  ← 空文字
  ├── shifts/ (100件)
  └── staff/ (10人)

【登録後】
users/abc123/  ← パスは同じ（UIDが同じため）
  ├── email: "user@example.com"  ← 追加
  ├── displayName: "user"         ← 自動設定（メールアドレスの@より前）
  └── teamId: "xyz789"            ← 同じ

teams/xyz789/  ← パスは同じ（データそのまま）
  ├── name: "○○店"  ← 登録時に入力
  ├── shifts/ (100件)  ← そのまま
  └── staff/ (10人)    ← そのまま
```

---

### タスク4: アカウント登録画面を作成

**新規ファイル**: `lib/screens/auth/register_account_screen.dart`

**UI構成**:
```
┌─────────────────────────────┐
│  アカウント登録               │
│                              │
│  データを守るために           │
│  メールアドレスを登録しましょう │
│                              │
│  [メールアドレス入力欄]       │
│  [パスワード入力欄]           │
│  [チーム名入力欄]            │
│   ※チーム共有機能を使う場合に必要 │
│                              │
│  メリット:                   │
│  ・端末を変えてもデータ引き継ぎ│
│  ・チーム共有機能が使える     │
│                              │
│  [登録]ボタン                │
│  [後で登録]ボタン             │
└─────────────────────────────┘
```

**実装**:
```dart
class RegisterAccountScreen extends StatefulWidget {
  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService().upgradeAnonymousToEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        teamName: _teamNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウント登録が完了しました')),
        );
        Navigator.of(context).pop(); // 設定画面に戻る
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント登録')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 説明文
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('データを守るために\nメールアドレスを登録しましょう'),
                    SizedBox(height: 8),
                    Text('メリット:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('・端末を変えてもデータを引き継げます'),
                    Text('・チーム共有機能が使えます'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // メールアドレス
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'メールアドレス'),
              validator: (value) {
                if (value == null || value.isEmpty) return '入力してください';
                if (!value.contains('@')) return '正しいメールアドレスを入力してください';
                return null;
              },
            ),

            // パスワード
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'パスワード'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) return '入力してください';
                if (value.length < 6) return '6文字以上入力してください';
                return null;
              },
            ),

            // チーム名
            TextFormField(
              controller: _teamNameController,
              decoration: InputDecoration(
                labelText: 'チーム名',
                hintText: '例: ○○店、○○部署',
                helperText: 'チーム共有機能を使う場合に表示されます',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '入力してください';
                return null;
              },
            ),

            SizedBox(height: 24),

            // 登録ボタン
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('登録'),
            ),

            // 後で登録ボタン
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('後で登録'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### タスク5: 設定画面の修正

**ファイル**: `lib/screens/settings_screen.dart`

**変更内容**:
1. アカウント登録ボタンを追加（匿名ユーザーのみ）
2. チーム共有機能を制限（匿名ユーザーはアカウント登録を促す）

**追加箇所**:
```dart
// 既存のListViewのchildrenを修正

// アカウント情報セクション
final user = FirebaseAuth.instance.currentUser;
if (user != null) ...[
  Padding(
    padding: EdgeInsets.all(16),
    child: Text('アカウント', style: TextStyle(fontWeight: FontWeight.bold)),
  ),

  if (user.isAnonymous) ...[
    // 匿名ユーザー: 警告バナー
    Card(
      color: Colors.blue[50],
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: Colors.blue),
        title: Text('アカウント未登録'),
        subtitle: Text('端末を変えるとデータが引き継げません'),
      ),
    ),
    // アカウント登録ボタン
    ListTile(
      leading: Icon(Icons.account_circle, color: Colors.blue),
      title: Text('アカウント登録'),
      subtitle: Text('データを守るため、チーム共有機能を使うため'),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterAccountScreen(),
          ),
        );
      },
    ),
  ] else ...[
    // 既存ユーザー: アカウント情報を表示
    ListTile(
      leading: Icon(Icons.account_circle),
      title: Text('ログイン中'),
      subtitle: Text(user.email ?? ''),
    ),
  ],

  Divider(),
],

// 所属チーム（匿名ユーザーは非表示）
if (widget.appUser.teamId != null && user != null && !user.isAnonymous)
  StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.appUser.teamId!)
        .snapshots(),
    builder: (context, snapshot) {
      final teamName = snapshot.data?.data() != null
          ? (snapshot.data!.data() as Map<String, dynamic>)['name'] as String?
          : null;

      return ListTile(
        leading: const Icon(Icons.groups),
        title: const Text('所属チーム'),
        subtitle: Text(teamName?.isEmpty == true ? '未設定' : teamName ?? '読み込み中...'),
        onTap: widget.appUser.isAdmin ? _showTeamNameEditDialog : null,
      );
    },
  ),

// チーム招待（匿名ユーザーにはアカウント登録を促す）
if (user != null && widget.appUser.isAdmin)
  ListTile(
    leading: const Icon(Icons.group_add),
    title: const Text('チーム招待'),
    subtitle: Text(user.isAnonymous ? 'アカウント登録が必要です' : 'スタッフを招待する'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      if (user.isAnonymous) {
        _showRegisterAccountPrompt(context);
      } else {
        _navigateToTeamInvite();
      }
    },
  ),
```

**アカウント登録促進ダイアログ**:
```dart
void _showRegisterAccountPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('アカウント登録が必要です'),
      content: const Text(
        'チーム共有機能を使うには、アカウント登録が必要です。\n\n'
        'アカウント登録すると：\n'
        '・スタッフを招待できます\n'
        '・端末を変えてもデータを引き継げます',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('後で'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RegisterAccountScreen(),
              ),
            );
          },
          child: const Text('登録する'),
        ),
      ],
    ),
  );
}
```

**UI（匿名ユーザーの場合）**:
```
┌────────────────────────────────┐
│ 【アカウント】                  │
├────────────────────────────────┤
│ ℹ️ アカウント未登録             │
│    端末を変えるとデータが引き継げません │
├────────────────────────────────┤
│ 👤 アカウント登録         >     │
│    データを守るため、チーム共有機能を使うため │
├────────────────────────────────┤
│ 👥 チーム招待            >     │
│    アカウント登録が必要です     │
│    （タップでアカウント登録画面へ）│
└────────────────────────────────┘
```

**UI（登録済みユーザーの場合）**:
```
┌────────────────────────────────┐
│ 【アカウント】                  │
├────────────────────────────────┤
│ 👤 ログイン中                   │
│    user@example.com            │
├────────────────────────────────┤
│ 👥 所属チーム                   │
│    ○○店                        │
├────────────────────────────────┤
│ 👥 チーム招待            >     │
│    スタッフを招待する           │
├────────────────────────────────┤
│ 🚪 ログアウト                   │
│    （既存機能そのまま）         │
└────────────────────────────────┘
```

---

### タスク6: WelcomeScreenの修正

**ファイル**: `lib/screens/auth/welcome_screen.dart`

**変更内容**:
新規ユーザーに3つの選択肢を提示
1. とりあえず試してみる（匿名ログイン）← 最優先
2. アカウント登録
3. ログイン

**UI構成**:
```
┌─────────────────────────────────┐
│                                 │
│     シフト工房へようこそ        │
│                                 │
│  スタッフのシフト表を自動作成   │
│                                 │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────┐      │
│  │                        │      │
│  │  とりあえず試してみる  │      │
│  │                        │      │
│  └───────────────────────┘      │
│         ↑ 大きいボタン           │
│                                 │
├─────────────────────────────────┤
│                                 │
│  機種変更してもデータを           │
│  引き継ぎたい方                  │
│  [アカウント登録] ←小さいテキストボタン│
│                                 │
│  すでにアカウントをお持ちの方    │
│  [ログイン] ←小さいテキストボタン │
│                                 │
└─────────────────────────────────┘
```

**実装**:
```dart
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              // タイトル
              const Text(
                'シフト工房へようこそ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'スタッフのシフト表を自動作成',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 64),

              // とりあえず試してみるボタン（大きい）
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    // 匿名ログイン実行
                    try {
                      await AuthService().signInAnonymously();
                      // HomeScreenへ自動遷移（AuthGateが処理）
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('エラー: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('とりあえず試してみる'),
                ),
              ),

              const SizedBox(height: 48),

              // アカウント登録（小さい）
              const Text(
                '機種変更してもデータを\n引き継ぎたい方',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                },
                child: const Text('アカウント登録'),
              ),

              const SizedBox(height: 24),

              // ログイン（小さい）
              const Text(
                'すでにアカウントをお持ちの方',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('ログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**戦略**:
1. **入口（Welcome）**: ハードルを下げる、怖がらせない
   - 「機種変更」という具体的でわかりやすい表現
   - データ消失を直接言及しない
2. **使用後（設定画面バナー）**: 使って気に入った人に詳しく説明
   - 「予期せぬ問題でデータが消える可能性」まで言及

---

### タスク7: HomeScreenの修正（匿名ユーザーはマイページ非表示）

**ファイル**: `lib/screens/home_screen.dart`

**問題点**:
- 現在はインデックスベースでタブを管理している
- タブの数が変わるとインデックスがズレてバグが発生する

**解決策**:
定数またはenumでタブを管理する

**実装**:
```dart
// タブの定義（enumで管理）
enum TabType {
  myPage,
  calendar,
  staff,
  settings,
}

class _HomeScreenState extends State<HomeScreen> {
  TabType _selectedTab = TabType.myPage;

  /// 表示するタブのリスト
  List<TabType> get _visibleTabs {
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? false;

    if (widget.appUser.isAdmin) {
      // 管理者
      if (isAnonymous) {
        // 匿名管理者: マイページなし
        return [TabType.calendar, TabType.staff, TabType.settings];
      } else {
        // 登録済み管理者: 全タブ
        return [TabType.myPage, TabType.calendar, TabType.staff, TabType.settings];
      }
    } else {
      // スタッフ
      if (isAnonymous) {
        // 匿名スタッフ: マイページなし（実際にはほぼないケース）
        return [TabType.calendar, TabType.settings];
      } else {
        // 登録済みスタッフ: マイページあり
        return [TabType.myPage, TabType.calendar, TabType.settings];
      }
    }
  }

  /// 現在選択されているタブのインデックス
  int get _selectedIndex {
    return _visibleTabs.indexOf(_selectedTab);
  }

  /// タブが表示されているかチェック
  bool _isTabVisible(TabType tab) {
    return _visibleTabs.contains(tab);
  }

  /// タブに対応する画面を取得
  Widget _getScreen(TabType tab) {
    switch (tab) {
      case TabType.myPage:
        return MyPageScreen(appUser: widget.appUser);
      case TabType.calendar:
        return CalendarScreen(appUser: widget.appUser);
      case TabType.staff:
        return StaffListScreen(appUser: widget.appUser);
      case TabType.settings:
        return SettingsScreen(appUser: widget.appUser);
    }
  }

  /// タブに対応するタイトルを取得
  String _getTitle(TabType tab) {
    switch (tab) {
      case TabType.myPage:
        return 'マイページ';
      case TabType.calendar:
        return 'シフト';
      case TabType.staff:
        return 'スタッフ';
      case TabType.settings:
        return 'その他';
    }
  }

  /// 権限に応じてタブ画面を取得
  List<Widget> get _screens {
    return _visibleTabs.map((tab) => _getScreen(tab)).toList();
  }

  /// 権限に応じてタブタイトルを取得
  List<String> get _titles {
    return _visibleTabs.map((tab) => _getTitle(tab)).toList();
  }

  /// 権限に応じてナビゲーション項目を取得
  List<NavigationDestination> _navigationDestinations(int pendingCount) {
    return _visibleTabs.map((tab) {
      switch (tab) {
        case TabType.myPage:
          return const NavigationDestination(
            icon: Icon(Icons.person, size: 22),
            label: 'マイページ',
          );
        case TabType.calendar:
          return const NavigationDestination(
            icon: Icon(Icons.calendar_month, size: 22),
            label: 'シフト',
          );
        case TabType.staff:
          return NavigationDestination(
            icon: Badge(
              label: Text('$pendingCount'),
              isLabelVisible: pendingCount > 0,
              child: const Icon(Icons.people, size: 22),
            ),
            label: 'スタッフ',
          );
        case TabType.settings:
          return const NavigationDestination(
            icon: Icon(Icons.more_horiz, size: 22),
            label: 'その他',
          );
      }
    }).toList();
  }

  // 初期タブ選択の修正
  if (!_hasCheckedInitialTab) {
    _hasCheckedInitialTab = true;
    if (widget.appUser.isAdmin) {
      final myStaff = staffProvider.staff
          .where((staff) =>
              (staff.userId != null && staff.userId == myUid) ||
              (staff.email != null && staff.email!.toLowerCase() == widget.appUser.email.toLowerCase()))
          .firstOrNull;

      // スタッフ情報がない場合はカレンダータブを初期選択
      if (myStaff == null && _isTabVisible(TabType.calendar)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedTab = TabType.calendar; // インデックスではなくタブタイプ
            });
          }
        });
      }
    }
  }

  // タブ選択時
  bottomNavigationBar: NavigationBar(
    height: 65,
    onDestinationSelected: (int index) {
      setState(() {
        _selectedTab = _visibleTabs[index]; // インデックスからタブタイプに変換
      });
    },
    selectedIndex: _selectedIndex,
    destinations: _navigationDestinations(requestProvider.pendingRequests.length),
  ),
}
```

**メリット**:
- ✅ タブの数が変わってもバグが発生しない
- ✅ インデックスではなく意味のある名前で管理
- ✅ 可読性が向上

---

### タスク8: AuthGateを匿名ログイン対応に修正

**ファイル**: `lib/widgets/auth_gate.dart`

**変更内容**:

#### 変更前
```dart
// ログインしていない場合
if (!authSnapshot.hasData) {
  return const WelcomeScreen(); // アカウント登録を要求
}
```

#### 変更後
```dart
// ログインしていない場合 → 自動的に匿名ログイン
if (!authSnapshot.hasData) {
  return FutureBuilder<User?>(
    future: AuthService().signInAnonymously(),
    builder: (context, anonymousSnapshot) {
      if (anonymousSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (anonymousSnapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Text('エラー: ${anonymousSnapshot.error}'),
          ),
        );
      }

      // 匿名ログイン完了 → AppUserを取得してHomeScreenへ
      return FutureBuilder(
        future: _getUserWithRetry(anonymousSnapshot.data!.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final appUser = userSnapshot.data;
          if (appUser == null) {
            return const Scaffold(
              body: Center(child: Text('ユーザー情報の取得に失敗しました')),
            );
          }

          // HomeScreenへ（チーム作成/参加画面をスキップ）
          return HomeScreen(appUser: appUser);
        },
      );
    },
  );
}
```

**フロー**:
```
アプリ起動
  ↓
_hasExistingData() でHiveデータをチェック
  ↓
Hiveデータあり？
  ├─ YES → MigrationOnboardingScreen（アカウント登録を促す）
  │         ※匿名ログインはスキップ
  │
  └─ NO → authStateChanges で認証状態をチェック
           ↓
         未ログイン？
           ├─ YES → WelcomeScreen表示
           │         ├─ [とりあえず試してみる] → signInAnonymously()
           │         │                             ↓
           │         │                           デフォルトチーム作成
           │         │                             ↓
           │         │                           AppUser作成（teamId設定済み）
           │         │                             ↓
           │         │                           HomeScreen へ（即使える）
           │         ├─ [アカウント登録] → SignUpScreen
           │         └─ [ログイン] → LoginScreen
           │
           └─ NO → ログイン済み
                    ↓
                  AppUser取得
                    ↓
                  匿名？
                    ├─ YES → HomeScreen（アカウント登録促進バナー表示）
                    └─ NO  → HomeScreen（通常表示）
```

**重要**:
- ✅ WelcomeScreenは修正して残す（3つの選択肢を提示）
- ✅ TeamCreationScreen、JoinTeamScreenは残す（Hiveデータ移行で使用）
- ✅ チーム作成/参加画面をスキップ（デフォルトチームが既にある、匿名ログインの場合）
- ✅ すぐにHomeScreenへ遷移（匿名ログインの場合）

---

### タスク8: 動作確認

**テストケース**:

#### ケース1: 新規インストール（匿名で開始）
```
1. アプリをアンインストール
2. 再インストール
3. アプリ起動
   → 自動的に匿名ログイン
   → デフォルトチーム作成
   → HomeScreen表示（アカウント登録なし）
4. シフト作成できる
5. スタッフ登録できる
6. アプリを再起動
   → データはそのまま（ログイン状態維持）
```

#### ケース2: 匿名ユーザーがアカウント登録
```
1. 匿名で開始
2. シフトを10件作成、スタッフを5人登録
3. 設定画面 → 「アカウント登録」
4. メールアドレス、パスワード、表示名を入力
5. 登録完了
   → シフト10件、スタッフ5人はそのまま ✅
   → UID変わらず ✅
6. ログアウト → ログイン
   → データアクセス可能 ✅
```

#### ケース3: アカウント登録後の端末変更
```
1. 匿名で開始 → アカウント登録（端末A）
2. シフトを20件作成
3. 別の端末（端末B）でアプリインストール
4. メールアドレスでログイン
   → シフト20件表示される ✅
   → 同じUIDでアクセス ✅
```

#### ケース4: 既存ユーザー（メール登録済み）
```
1. 既存ユーザーでログイン
   → 匿名ログインの処理は実行されない ✅
   → 既存のチームに所属したまま ✅
   → データは全てそのまま ✅
2. 設定画面
   → 「アカウント登録」ボタンは表示されない ✅
   → 「アカウント情報」が表示される ✅
```

#### ケース5: Hiveデータ移行（既存のオフライン版ユーザー）
```
1. オフライン版でシフトを作成
2. アプリアップデート（オンライン版）
3. アプリ起動
   → Hiveデータ検出
   → MigrationOnboardingScreen表示
   → アカウント登録を促す（匿名ログインはスキップ）
4. ユーザーがアカウント登録
   → TeamCreationScreen表示（データ移行フラグ付き）
5. チーム作成
   → Hive → Firestore移行
   → データ引き継ぎ成功 ✅

注意: オフライン版ユーザーは匿名ログインではデータ移行できません。
データ移行するにはアカウント登録が必須です。
```

---

## ⚠️ 注意事項

### 絶対に避けること
1. ❌ `createUserWithEmailAndPassword`を使ってはいけない
   - 新しいUIDが発行される
   - 前のデータにアクセスできなくなる

2. ❌ 匿名ユーザーに対してチーム作成/参加を要求してはいけない
   - デフォルトチームが自動作成されるため不要

3. ❌ `signUp`メソッドを使ってアカウント登録してはいけない
   - 必ず`upgradeAnonymousToEmail`（linkWithCredential）を使う

4. ❌ 匿名ユーザーがチーム共有機能を使えるようにしてはいけない
   - 端末変更でチームにアクセスできなくなる
   - アカウント登録を促す

### 必ず守ること
1. ✅ アカウント登録は`linkWithCredential`を使う
   - UIDが変わらない = データが引き継がれる

2. ✅ 匿名ログイン時にデフォルトチームを自動作成
   - チーム名は空文字
   - チーム作成/参加画面をスキップできる

3. ✅ 既存のHiveデータ移行ロジックは残す
   - オフライン版からのアップデートユーザーに対応
   - **重要**: Hiveデータがある場合は匿名ログインをスキップ
   - アカウント登録を促す（MigrationOnboardingScreen）

4. ✅ AppUserの`email`をnullableにする
   - 匿名ユーザーは`email: null`

5. ✅ 匿名ユーザーのチーム共有機能を制限
   - チーム招待：アカウント登録を促す
   - チーム名変更：アカウント登録を促す
   - 所属チーム表示：非表示

6. ✅ `displayName`は自動設定（メールアドレスの@より前）
   - ユーザーに入力させない

---

## 🔄 既存ユーザーへの影響

### メール登録済みユーザー
- ✅ 影響なし
- ✅ 既存のログインフローがそのまま動く
- ✅ データはそのまま
- ✅ `user.isAnonymous == false`なので匿名ユーザー用の処理には入らない

### Hiveデータ移行ユーザー（オフライン版からのアップデート）
- ✅ 影響なし（既存のフローを維持）
- ✅ `_hasExistingData()`でHiveデータを検出
- ✅ MigrationOnboardingScreenを表示（**匿名ログインはスキップ**）
- ✅ アカウント登録を促す
- ✅ アカウント登録後、TeamCreationScreenへ遷移
- ✅ データ移行成功

**重要**: オフライン版ユーザーは匿名ログインではデータ移行できません。
データ移行するにはアカウント登録が必須です。これは既存の動作と同じです。

---

## 📊 期待される効果

### ユーザー体験の改善
- ✅ アカウント登録不要で即使える
- ✅ 初回のハードルが大幅に下がる
- ✅ 「とりあえず試してみる」が可能に
- ✅ チーム共有機能はオプション扱い

### データ保護
- ✅ Firestoreに保存されるので安心
- ✅ アプリ再起動でもデータ維持
- ✅ アカウント登録後は端末変更でも引き継ぎ可能

### コンバージョン率向上
- 匿名で開始 → 気に入ったらアカウント登録
- チーム共有を使いたくなったらアカウント登録（促される）
- 段階的なコミットメント

### 健全なチーム運用
- ✅ チーム共有機能を使う管理者は必ずアカウント登録済み
- ✅ 匿名管理者によるチーム崩壊を防ぐ
- ✅ 端末変更でチームにアクセスできなくなるリスクを回避

---

## 🚀 実装後のユーザーフロー

### 新規ユーザー（個人利用）
```
アプリインストール
  ↓
起動（アカウント登録なし）
  ↓
すぐにシフト作成画面
  ↓
シフト作成・スタッフ登録（数日使用）
  ↓
「便利だな」
  ↓
設定画面で「アカウント登録」バナー発見
  ↓
アカウント登録（データはそのまま）
  ↓
端末を変えてもデータアクセス可能
```

### チーム共有を使いたいユーザー
```
匿名で開始
  ↓
シフト作成（数日使用）
  ↓
「スタッフと共有したい」
  ↓
設定 → 「チーム招待」をタップ
  ↓
「アカウント登録が必要です」ダイアログ表示
  ↓
アカウント登録画面へ
  ↓
メールアドレス、パスワード、チーム名を入力
  ↓
アカウント登録完了（データはそのまま）
  ↓
チーム招待機能が使えるようになる
  ↓
スタッフを招待
  ↓
チーム共有開始
```

---

## 📝 実装順序

1. ✅ AppUserモデルの修正（email nullable）
2. ✅ AuthServiceに匿名ログイン機能追加
3. ✅ AuthServiceにアカウントアップグレード機能追加
4. ✅ アカウント登録画面作成
5. ✅ 設定画面の修正（アカウント登録ボタン、チーム共有制限）
6. ✅ WelcomeScreenの修正（3つの選択肢を提示）
7. ✅ HomeScreenの修正（匿名ユーザーはマイページ非表示、enumでタブ管理）
8. ✅ AuthGateを匿名ログイン対応に修正
9. ✅ 動作確認（全テストケース）

---

## 🔍 レビューポイント

### 確認事項
- [ ] AppUserの`email`がnullableになっているか
- [ ] `linkWithCredential`を使っているか（`createUserWithEmailAndPassword`ではない）
- [ ] デフォルトチームが自動作成されるか（名前は空文字）
- [ ] `displayName`が自動設定されるか（メールアドレスの@より前）
- [ ] チーム名がアカウント登録時に更新されるか
- [ ] 匿名ユーザーのチーム共有機能が制限されているか
- [ ] 既存ユーザーに影響がないか
- [ ] Hiveデータ移行ロジックが残っているか

### テスト
- [ ] 新規インストール → 匿名ログイン → すぐに使える
- [ ] シフト作成 → アカウント登録 → データ引き継ぎ
- [ ] 匿名ユーザー → チーム招待タップ → アカウント登録促進ダイアログ
- [ ] 匿名ユーザー → 所属チーム非表示
- [ ] 登録ユーザー → チーム招待可能、所属チーム表示
- [ ] ログアウト → ログイン → データアクセス可能
- [ ] 端末変更 → ログイン → データアクセス可能
- [ ] 既存ユーザー → 影響なし

---

## 📚 参考資料

- [Firebase Anonymous Authentication](https://firebase.google.com/docs/auth/web/anonymous-auth)
- [Firebase Link Multiple Auth Providers](https://firebase.google.com/docs/auth/web/account-linking)
- [Firebase Auth Best Practices](https://firebase.google.com/docs/auth/users)

---

以上
