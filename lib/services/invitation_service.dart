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
   - iPhoneの方：App Storeが開くので、アプリをインストール

2. アプリを起動すると、最初の画面で「シフト作成を始める」と「招待を受けて参加する」の2つの選択肢が表示されます
   →「招待を受けて参加する」を選択してください

3. あなたのメールアドレス（このメールが届いたアドレス）と、任意の6文字以上のパスワードを入力してアカウント登録

4. 上記の招待コード（$inviteCode）を入力して参加完了！

よろしくお願いいたします。
''');

    // 宛先（カンマ区切り、空の場合もあり）
    final recipients = recipientEmails.join(',');

    // mailto URLを生成
    final uri = Uri.parse('mailto:$recipients?subject=$subject&body=$body');

    // メーラーを起動する。
    // ※ iOSでは canLaunchUrl(mailto:) が false を返すことがある（Info.plistの
    //   LSApplicationQueriesSchemes未宣言や判定の癖）。canLaunchUrlで弾くと、
    //   実際には開けるのに「失敗」扱いになりiOSだけメールが送れない状態になる。
    //   launchUrl自体は canOpenURL を使わないため、直接呼ぶ（url_launcher公式の推奨）。
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        throw 'メーラーを起動できませんでした';
      }
    } catch (_) {
      // メールアプリが未設定/削除済みなどで起動できない場合
      throw 'メーラーを起動できませんでした';
    }
  }
}
