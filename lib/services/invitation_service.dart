import 'package:url_launcher/url_launcher.dart';

/// 招待メール送信サービス
class InvitationService {
  /// 招待メールを送信（メーラーを起動）
  ///
  /// [recipientEmails] 宛先メールアドレスのリスト（空でも可）
  /// [teamName] チーム名
  /// [inviteCode] 招待コード
  static Future<void> sendInvitationEmail({
    required List<String> recipientEmails,
    required String teamName,
    required String inviteCode,
  }) async {
    // 招待用URL
    const appUrl = 'https://shift-kobo-online-prod.web.app/app';

    // 件名
    final subject = Uri.encodeComponent('【シフト工房】チーム招待');

    // 本文
    final body = Uri.encodeComponent('''
「$teamName」チームへの招待です。

以下のリンクからアクセスしてください：
$appUrl

【招待コード】
$inviteCode

【参加方法】
1. 上記リンクをタップ
   - Androidの方：Google Playストアが開くので、アプリをインストール
   - iPhoneの方：そのままWebアプリが開きます

2. アプリを起動し、あなたのメールアドレス（このメールが届いたアドレス）と、任意の6文字以上のパスワードでアカウントを作成

3. メニューから「チームに参加」を選択

4. 上記の招待コードを入力して参加

よろしくお願いいたします。
''');

    // 宛先（カンマ区切り、空の場合もあり）
    final recipients = recipientEmails.join(',');

    // mailto URLを生成
    final uri = Uri.parse('mailto:$recipients?subject=$subject&body=$body');

    // メーラーを起動
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'メーラーを起動できませんでした';
    }
  }
}
