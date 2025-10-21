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
          _buildSectionTitle('管理者向け'),
          const SizedBox(height: 8),
          _buildBasicFeaturesCard(),
          const SizedBox(height: 16),
          _buildInviteMembersCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('スタッフ向け（アプリ参加者）'),
          const SizedBox(height: 8),
          _buildMemberGuideCard(),
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
                _buildStepItem(
                  '1',
                  '招待コードを確認',
                  'その他 > チーム招待 から8桁の招待コードを確認します',
                ),
                _buildStepItem(
                  '2',
                  '招待コードをスタッフに共有',
                  'LINE、メール、口頭などで招待コードをスタッフに伝えます',
                ),
                _buildStepItem(
                  '3',
                  'スタッフ側の手順を案内',
                  '以下の手順をスタッフに伝えてください：\n'
                      '• アプリをインストール\n'
                      '• メールアドレスでアカウント作成\n'
                      '• 「既存のチームに参加」を選択\n'
                      '• 招待コードを入力',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'スタッフ登録時に入力したメールアドレスと同じアドレスでアカウント作成すると自動紐付き',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildStepItem(
                  '4',
                  '自動紐付けできなかった場合（手動対応）',
                  'スタッフ管理画面で該当スタッフをタップ > メールアドレス欄に、スタッフがアカウント作成時に入力したメールアドレスを入力 > 保存すると紐付けが完了します',
                ),
              ],
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
          'スタッフができること（準備中）',
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
                    '現在は管理者が作成したシフトを閲覧できます。\n'
                    '今後のアップデートで以下の機能を追加予定です：',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.event_busy, '休み希望入力', '自分で休み希望日を入力（予定）'),
                _buildFeatureItem(Icons.notifications, 'プッシュ通知', '新しいシフトが作成されたら通知（予定）'),
                _buildFeatureItem(Icons.comment, 'コメント機能', '急な変更やリクエストをコメント（予定）'),
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
                  'チームでシフトを共有したい場合は招待できます\n※ 詳しくは下の「スタッフを招待する方法」を参照',
                ),
                _buildHowToItem(
                  'シフトを作成する',
                  'カレンダー画面で日付をタップ > スタッフとシフトタイプを選択',
                ),
                _buildHowToItem(
                  'シフトを自動生成する',
                  'カレンダー画面右上の「自動生成」アイコン > 期間と必要人数を設定',
                ),
                _buildHowToItem(
                  'シフト表を出力する',
                  'ホーム画面の「シフト表」タブ > PNG保存またはExcel出力を選択',
                ),
                _buildHowToItem(
                  'データをバックアップする',
                  'その他 > データバックアップ > バックアップファイルを保存',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
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
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
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
}
