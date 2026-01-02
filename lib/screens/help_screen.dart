import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

/// ヘルプ画面
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  void initState() {
    super.initState();
    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('help_screen');
  }

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
          _buildCalendarOperationsCard(),
          const SizedBox(height: 16),
          _buildStaffOperationsCard(),
          const SizedBox(height: 16),
          _buildTeamOperationsCard(),
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
                      _buildSimpleStep('1', 'チーム > チーム招待 を開く'),
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
                  'シフトタイプを設定する',
                  'ホーム画面の「チーム」タブ > 「シフト時間設定」メニューから設定',
                ),
                _buildHowToItem(
                  'シフト割り当てを設定する',
                  'ホーム画面の「チーム」タブ > 「シフト割当て設定」メニューから設定',
                ),
                _buildHowToItem(
                  'シフトを自動作成する',
                  'カレンダー画面右上の「自動作成」アイコンをタップ',
                ),
                _buildHowToItem(
                  '（必要に応じて）異なる戦略で再作成する',
                  '割り当て戦略を選択し（シフト数優先・分散優先）異なるシフトを生成できます',
                ),
                _buildHowToItem(
                  '（必要に応じて）前のシフトに戻す',
                  '再作成後、元の方が良かった場合は「切替」ボタンで直前の状態に戻せます',
                ),
                _buildHowToItem(
                  'シフトを調整する',
                  'カレンダー画面で日付をタップ > スタッフをタップして微調整',
                ),
                if (!kIsWeb)
                  _buildHowToItem(
                    'シフト表を出力する',
                    'カレンダー画面で「シフト表」ボタンをタップ > 保存または共有を選択',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarOperationsCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.touch_app, color: Colors.teal),
        title: const Text(
          'カレンダー画面の操作',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // シフトの追加
                Text(
                  'シフトを追加する',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOperationStep('1', 'カレンダーで日付をタップ'),
                      _buildOperationStep('2', '「シフトを追加」ボタンをタップ'),
                      _buildOperationStep('3', 'スタッフとシフトタイプを選択して保存'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // シフトの編集・削除
                Text(
                  'シフトを編集・削除する',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '編集：シフトをタップすると編集画面が開きます',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '削除：シフト右端の「︙」メニューから削除できます',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // クイックメニュー
                Text(
                  'クイックメニュー',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
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
                          Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'シフトを長押し、または「︙」メニューの「操作」ボタンからクイックメニューを開けます',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildQuickMenuItem(
                        Icons.person,
                        'スタッフ変更',
                        '別のスタッフにシフトを変更',
                      ),
                      _buildQuickMenuItem(
                        Icons.calendar_today,
                        '日付移動',
                        'シフトを別の日に移動',
                      ),
                      _buildQuickMenuItem(
                        Icons.swap_horiz,
                        'スタッフ入替',
                        '2人のスタッフのシフトを入れ替え',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // スタッフ入れ替えの詳細
                Text(
                  'スタッフ入れ替えの使い方',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOperationStep('1', '入れ替えたいシフトを長押し（または「︙」メニューの「操作」）'),
                      _buildOperationStep('2', '「スタッフ入替」をタップ'),
                      _buildOperationStep('3', '入れ替え先のシフトをタップ'),
                      _buildOperationStep('4', '確認ダイアログで「入れ替える」をタップ'),
                      const SizedBox(height: 8),
                      Text(
                        '※ 入れ替え時に休み希望などの制約違反がある場合は警告が表示されます',
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
          ),
        ],
      ),
    );
  }

  Widget _buildStaffOperationsCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.people, color: Colors.indigo),
        title: const Text(
          'スタッフ画面の操作',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // スタッフの追加・編集
                Text(
                  'スタッフを追加・編集する',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
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
                      Text(
                        '追加：「スタッフ」タブ > 「スタッフを追加」ボタン',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '編集：スタッフ一覧から該当スタッフをタップ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 基本情報
                Text(
                  '基本情報',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStaffSettingItem(
                  '名前',
                  'シフト表に表示される名前です',
                ),
                _buildStaffSettingItem(
                  '電話番号・メールアドレス',
                  '任意。メールアドレスを入力すると、同じアドレスでアプリに参加したスタッフと自動紐付けされます',
                ),
                _buildStaffSettingItem(
                  '月間最大シフト数',
                  '0にすると自動割り当ての対象外になります（手動では追加可能）',
                ),
                const SizedBox(height: 16),

                // 休み希望
                Text(
                  '休み希望の設定',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStaffSettingItem(
                        '休み希望曜日',
                        '毎週決まった曜日に休みを希望する場合に設定',
                      ),
                      _buildStaffSettingItem(
                        '祝日を休み希望とする',
                        'チェックすると祝日を自動的に休み希望として扱います',
                      ),
                      _buildStaffSettingItem(
                        '休み希望日（特定日）',
                        '特定の日付で休みを希望する場合に設定。「設定」ボタンからカレンダーで複数日を選択できます',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 勤務希望日
                Text(
                  '勤務希望日の設定',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStaffSettingItem(
                        '勤務希望日',
                        'シフトに入りたい日を設定。「設定」ボタンからカレンダーで複数日を選択できます',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '勤務希望日の注意点',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• 他のスタッフの希望日との兼ね合いで、必ずしも希望通りになるとは限りません\n'
                              '• 休み希望（曜日・特定日・祝日）と重なる場合は、休み希望が優先されます\n'
                              '• 自動割り当て時に考慮され、できるだけ公平に割り振られます',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 勤務不可シフトタイプ
                Text(
                  '勤務不可シフトタイプ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStaffSettingItem(
                  '',
                  '特定のシフトタイプ（早番、遅番など）に入れないスタッフの場合に設定。選択したシフトタイプは自動割り当ての対象外になります',
                ),
                const SizedBox(height: 16),

                // 個別制約設定
                Text(
                  '個別制約設定',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStaffSettingItem(
                        '連続勤務日数上限',
                        'このスタッフが連続して勤務できる最大日数を設定。空欄の場合はチーム設定が適用されます',
                      ),
                      _buildStaffSettingItem(
                        '勤務間インターバル',
                        '前のシフト終了から次のシフト開始までに必要な最低時間。空欄の場合はチーム設定が適用されます',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.purple.shade700, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '活用例',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '責任者やリーダーなど、シフトが埋まらない時に柔軟に対応できるスタッフに対して、チーム設定より緩い制約を設定できます。\n'
                              '例: チーム設定が連続5日の場合、責任者だけ連続7日まで許可',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // スタッフの無効化・削除
                Text(
                  'スタッフの無効化・削除',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'スタッフ一覧で該当スタッフの「︙」メニューから操作できます',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildStaffSettingItem(
                        '無効化',
                        '一時的にシフト割り当ての対象外にします。スタッフ情報は残り、後から有効に戻せます',
                      ),
                      _buildStaffSettingItem(
                        '削除',
                        'スタッフ情報を完全に削除します。アプリ利用中のスタッフの場合はアカウントも削除されます',
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

  Widget _buildStaffSettingItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
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
    );
  }

  Widget _buildTeamOperationsCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.groups, color: Colors.deepPurple),
        title: const Text(
          'チーム画面の操作',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 共有機能
                Text(
                  '共有機能',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStaffSettingItem(
                  'チーム招待',
                  'スタッフをチームに招待します。詳しくは「チーム共有機能について」をご覧ください',
                ),
                const SizedBox(height: 16),

                // 基本設定
                Text(
                  '基本設定',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStaffSettingItem(
                        'シフト時間設定',
                        '各シフトタイプ（早番、遅番など）の開始・終了時間、表示名を設定します。使わないシフトタイプは無効にできます',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 自動シフト作成
                Text(
                  '自動シフト作成',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStaffSettingItem(
                        'シフト割当て設定',
                        '各シフトタイプの必要人数を曜日ごとに設定します。自動割り当て時にこの人数分のスタッフが割り当てられます。曜日毎の設定や特定日のみ割り当てを変えることも可能です',
                      ),
                      _buildStaffSettingItem(
                        'チーム休み設定',
                        'チーム全体の休みを設定します。曜日（毎週○曜定休）、祝日、特定日（年末年始など）を指定できます。設定した日は自動割り当ての対象外になります',
                      ),
                      _buildStaffSettingItem(
                        '制約条件設定',
                        '連続勤務日数の上限と、勤務間インターバル（前のシフト終了から次のシフト開始までの最低時間）を設定します',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'これらの設定は自動割り当て時に適用されます。手動でシフトを追加する場合は制約に関係なく追加できます',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
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

  Widget _buildOperationStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMenuItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
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
