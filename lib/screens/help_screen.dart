import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// ヘルプ画面
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ヘルプ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('基本的な使い方'),
          const SizedBox(height: 8),
          _buildBasicFeaturesCard(),
          const SizedBox(height: 16),
          _buildInviteMembersCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('スタッフ向け（アプリ参加者）'),
          const SizedBox(height: 8),
          _buildMemberGuideCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('アカウント・データ管理'),
          const SizedBox(height: 8),
          _buildAccountDeletionCard(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'シフト工房について',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'シフト工房は、シフト作成を自動化・効率化するアプリです。\n\n'
              '• スタッフの希望を考慮した自動シフト作成\n'
              '• PNG・Excel形式での出力\n'
              '• スタッフを招待してリアルタイム共有（任意）',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRegistrationBenefitsCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'アカウント登録をおすすめします',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'データを保護するため、登録をおすすめします',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'アカウント登録しない場合、端末の故障・紛失、誤ってアプリを削除した場合などにデータを復旧できません。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'アカウント登録していない方は、設定画面から登録できます。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBenefitItem(
                    Icons.phone_android,
                    '機種変更してもデータを復元できる',
                    '誤ってアプリを削除しても安心',
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitItem(
                    Icons.group_add,
                    'スタッフを招待できる',
                    'リアルタイムでシフト情報を共有',
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitItem(
                    Icons.sync,
                    '休み希望の申請・承認機能',
                    'スタッフが直接希望を入力できる',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '設定画面の「アカウント登録」からご登録ください',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green.shade700, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInviteMembersCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.group_add, color: Colors.green),
        title: const Text(
          'チーム共有機能について（要アカウント登録）',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
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
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'アカウント登録について',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'チーム共有機能（スタッフ招待、休み希望申請・承認など）を使うには、アカウント登録が必要です。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'また、アカウント登録しない場合、端末の故障・紛失、誤ってアプリを削除した場合などにデータを復旧できません。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '設定画面の「アカウント登録」から登録できます。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'スタッフを招待する',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.email, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '簡単3ステップ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSimpleStep('1', 'その他 > チーム招待 を開く'),
                      _buildSimpleStep('2', '「招待メールを送る」ボタンをタップ'),
                      _buildSimpleStep('3', 'スタッフを選択してメール送信'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                          Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'スタッフ側の手順',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '招待メールの指示に従って参加できます：\n'
                        '1. 最初の画面で「招待を受けて参加する」を選択\n'
                        '2. メールアドレス・パスワードを入力してアカウント登録\n'
                        '3. 招待コードを入力して参加完了',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // iPhoneユーザー向け
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.apple, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'iPhoneユーザーのスタッフへ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'iPhone版アプリは準備中です。下記のWebアプリをご利用ください',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'https://shift-kobo-online-prod.web.app/app',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.bookmark_outline, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ブックマークに保存すると便利です',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '招待メールを送った場合は、メール内のリンクからアクセスできます',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '自動紐付けについて',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'スタッフ登録時に入力したメールアドレスと同じアドレスでアカウント作成すると、自動的に紐付けられます。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '手動で紐付ける場合',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'スタッフ一覧 > 該当スタッフをタップ > メールアドレス欄にスタッフのアドレスを入力 > 保存',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '休み希望の申請・承認',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'スタッフを招待すると、スタッフが休み希望や制約を申請できるようになります。\n管理者は申請を承認・却下できます。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.purple.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'スタッフ側',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'マイページから休み希望を入力 > 申請ボタンをタップ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.indigo.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '管理者側',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'スタッフタブ > 承認待ちバナーをタップ > 申請一覧から承認または却下\n※ Android版ではPush通知でお知らせされます',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberGuideCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.person, color: Colors.blue),
        title: const Text(
          'スタッフができること',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'スタッフとしてアプリに参加すると、以下の機能が利用できます：',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  Icons.calendar_today,
                  'シフト閲覧',
                  'マイページで自分のシフトを確認、カレンダー画面で全員分のシフトを日毎に確認',
                ),
                _buildFeatureItem(
                  Icons.event_busy,
                  '休み希望・制約の入力・申請',
                  'マイページから休み希望や月間最大シフト数などの制約を入力し、管理者に申請',
                ),
                _buildFeatureItem(
                  Icons.check_circle,
                  '申請結果の通知（Android版のみ）',
                  '管理者が申請を承認・却下したらPush通知でお知らせ',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '制限事項',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• シフトの作成・変更はできません（閲覧のみ）\n'
                        '• スタッフの登録・削除はできません',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFeaturesCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.star, color: Colors.purple),
        title: const Text(
          'シフト管理の基本',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHowToItem(
                  'スタッフを追加する',
                  'ホーム画面の「スタッフ」タブ > 「スタッフを追加」ボタンから登録',
                ),
                _buildHowToItem(
                  'シフトを自動作成する',
                  'カレンダー画面右上の「自動作成」アイコン > 期間と必要人数を設定',
                ),
                _buildHowToItem(
                  '異なる戦略で再作成する',
                  '割り当て戦略を選択し（シフト数優先・分散優先）異なるシフトを生成できます。',
                ),
                _buildHowToItem(
                  '前のシフトに戻す',
                  '再作成後、元の方が良かった場合は「切替」ボタンで直前の状態に戻せます',
                ),
                _buildHowToItem(
                  'シフトを調整する（必要に応じて）',
                  'カレンダー画面で日付をタップ > スタッフとシフトタイプを変更して微調整',
                ),
                if (!kIsWeb)
                  _buildHowToItem(
                    'シフト表を出力する',
                    'ホーム画面の「シフト表」タブ > PNG保存またはExcel出力を選択',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_right, size: 20, color: Colors.purple.shade700),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDeletionCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text(
          'アカウント削除について',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 共通説明
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'アカウント削除は取り消せません。削除されたアカウント・データは復元できません。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // スタッフ向け説明
                const Text(
                  'スタッフがアカウント削除する場合',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHowToItem(
                  '削除方法',
                  'その他 > アカウント削除 > パスワード入力 > 削除実行',
                ),
                _buildHowToItem(
                  '削除されるデータ',
                  '• 自分のアカウント情報（メールアドレス、パスワード等）\n'
                      '• 自分が申請した制約データ\n'
                      '• スタッフ情報との紐付け（スタッフ情報自体は残る）',
                ),
                _buildHowToItem(
                  '削除されないデータ',
                  '• チームのシフトデータ\n'
                      '• スタッフ情報（管理者が登録したデータ）\n'
                      '• 他のメンバーのデータ',
                ),
                const SizedBox(height: 16),

                // 管理者向け説明
                const Text(
                  '管理者がアカウント削除する場合',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
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
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '管理者が削除する場合の動作',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• 唯一の管理者の場合: チーム全体が削除されます\n'
                        '• 複数管理者がいる場合: 自分のアカウントのみ削除されます',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildHowToItem(
                  '削除前の確認',
                  '• 他に管理者がいるか確認（スタッフ一覧で確認可能）\n'
                      '• 他に管理者がいない場合は、スタッフ編集画面で、アプリ利用中のスタッフを管理者に昇格させることで、チームを継続可能',
                ),
                const SizedBox(height: 16),

                // 管理者がスタッフを削除する場合
                const Text(
                  '管理者が他のスタッフを削除する場合',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHowToItem(
                  '削除方法',
                  'スタッフ一覧 > 該当スタッフのメニュー > スタッフを削除',
                ),
                _buildHowToItem(
                  '削除されるデータ',
                  '• 該当スタッフのアカウント（アプリ利用中の場合）\n'
                      '• 該当スタッフの制約データ\n'
                      '• スタッフ情報（名前、連絡先等）',
                ),
                _buildHowToItem(
                  '削除されないデータ',
                  '• 過去のシフトデータ（「不明なスタッフ」と表示されます）\n'
                      '• 他のスタッフのデータ',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
