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
          const SizedBox(height: 16),
          _buildIOSWebGuideCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('管理者向け'),
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
                  'シフト工房の使い方',
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
              'シフト工房は、チーム単位でシフトを管理するアプリです。\n管理者とスタッフで役割が異なります。',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSWebGuideCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smartphone, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'アプリを始める',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Androidユーザー向け
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.android, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Androidの方',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google Playストアから「シフト工房」で検索してアプリをインストール',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                        'iPhoneの方',
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
                    'アプリは準備中です。下記のアドレスからWebアプリをご利用ください',
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
                ],
              ),
            ),
          ],
        ),
      ),
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
          'スタッフを招待する方法',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'スタッフは受信したメールの指示に従うだけ！\n招待コードも自動で送信されます',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
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
                        '• シフトの編集・削除はできません（閲覧のみ）\n'
                        '• スタッフの追加・削除はできません\n'
                        '• シフト自動作成はできません',
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
          '基本機能の使い方（管理者）',
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '管理者1人でも使えます。スタッフ招待は任意です。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHowToItem(
                  'スタッフを追加する',
                  'ホーム画面の「スタッフ」タブ > 「スタッフを追加」ボタンから登録',
                ),
                _buildHowToItem(
                  'スタッフを招待する（任意）',
                  'その他 > チーム招待 > 招待メールを送る\n※ 詳しくは下の「スタッフを招待する方法」を参照',
                ),
                _buildHowToItem(
                  'シフトを自動生成する',
                  'カレンダー画面右上の「自動生成」アイコン > 期間と必要人数を設定',
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
                _buildHowToItem(
                  'スタッフの制約申請を承認・却下する',
                  'ホーム画面の「スタッフ」タブ > 承認待ちバナーをタップ > 申請一覧から承認または却下\n※ スタッフが制約を申請すると通知されます（Android版のみ）',
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
