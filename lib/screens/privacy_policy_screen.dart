import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const String privacyPolicyUrl = 'https://shi-takahashi.github.io/shift_kobo/privacy-policy.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'シフト工房 プライバシーポリシー',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '最終更新日: 2025年9月27日',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. 基本方針',
              'シフト工房（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。'
              '本アプリは主にローカル環境でデータを管理し、外部サーバーへの個人情報送信は行いません。',
            ),
            
            _buildSection(
              '2. 収集する情報',
              '本アプリは以下の情報をデバイス内にのみ保存します：\n'
              '• スタッフ情報（名前、連絡先、勤務条件）\n'
              '• シフトスケジュール\n'
              '• アプリ設定情報\n'
              '• 制約条件とプリファレンス\n\n'
              'これらの情報は全てデバイス内のローカルストレージに保存され、外部に送信されることはありません。',
            ),
            
            _buildSection(
              '3. データの使用目的',
              '収集した情報は以下の目的にのみ使用されます：\n'
              '• シフトスケジュールの作成と管理\n'
              '• スタッフ情報の管理\n'
              '• アプリ機能の提供と改善\n'
              '• ユーザー体験の向上',
            ),
            
            _buildSection(
              '4. データの保存と管理',
              '• 全てのデータはデバイス内にローカル保存されます\n'
              '• バックアップ機能使用時は、ユーザーが指定した場所にのみエクスポートされます\n'
              '• シフト表共有機能では、PNG画像やExcelファイルをユーザーが選択したアプリ（LINE、メール等）に送信します\n'
              '• 共有されるデータは本アプリで作成されたシフト情報のみです\n'
              '• アプリ削除時には全てのデータが削除されます\n'
              '• データの暗号化については端末の標準的な保護機能に依存します',
            ),
            
            _buildSection(
              '5. 第三者への情報提供',
              '本アプリは、法令に基づく場合を除き、ユーザーの同意なしに個人情報を第三者に提供することはありません。\n\n'
              '【広告サービス】\n'
              '本アプリではGoogle AdMobによる広告配信を行っています：\n'
              '• 広告表示のため、Google AdMobが匿名化された使用統計や広告識別子を収集する場合があります\n'
              '• 収集される情報には個人を特定できる情報は含まれません\n'
              '• 詳細についてはGoogleのプライバシーポリシーをご確認ください',
            ),
            
            _buildSection(
              '6. アプリの権限',
              '本アプリは以下の端末機能を使用します：\n'
              '• ストレージ：バックアップファイルの保存・読み込み\n'
              '• インターネット：広告表示のための通信\n'
              '• カメラ・ギャラリー：スクリーンショット機能（端末内処理のみ）\n'
              '• 他のアプリとの連携：シフト表共有時のLINE・メール等との連携\n\n'
              'これらの権限は必要な機能でのみ使用され、不要な情報収集は行いません。',
            ),
            
            _buildSection(
              '7. ユーザーの権利',
              'ユーザーは以下の権利を有します：\n'
              '• 保存されたデータの確認と修正\n'
              '• データの削除（アプリアンインストール）\n'
              '• バックアップによるデータのエクスポート\n'
              '• シフト表データの共有（PNG・Excel形式）\n'
              '• 本ポリシーに関する問い合わせ',
            ),
            
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.web,
                    color: Colors.blue,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '詳細版プライバシーポリシー',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'より詳細な情報については、Web版のプライバシーポリシーをご確認ください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(privacyPolicyUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('詳細版を見る'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '8. お問い合わせ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '本プライバシーポリシーに関するご質問は、以下までお問い合わせください：',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Email: fdks487351@yahoo.co.jp',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2025 Shift Kobo\n本ポリシーは予告なく変更される場合があります',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
      // エラー時はスナックバーで通知
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ブラウザで開けませんでした: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}