import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const bool _isDebug = kDebugMode;
  
  /// スクリーンショット撮影時など、広告を非表示にするためのフラグ
  /// 
  /// 使用方法:
  /// - スクリーンショット撮影時: false に設定してビルド
  /// - 本番リリース時: 必ず true に設定してビルド
  /// - ユーザーが自由に変更できないよう、設定画面には表示しない
  /// 
  /// true: 広告を表示、false: 広告を非表示
  static const bool showBannerAds = true;
  
  // テスト用広告ID（デバッグビルド時）
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';

  // 本番用広告ID（リリースビルド時）- 現在はテスト用IDを使用
  static const String _productionBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _productionBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';

  /// 現在の環境に応じた広告IDを取得
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _isDebug ? _testBannerAdUnitIdAndroid : _productionBannerAdUnitIdAndroid;
    } else {
      return _isDebug ? _testBannerAdUnitIdIOS : _productionBannerAdUnitIdIOS;
    }
  }

  /// AdMobを初期化
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();

    // デバッグ時のテストデバイス設定
    if (_isDebug) {
      final requestConfiguration = RequestConfiguration(
        testDeviceIds: ['C774D381A6F78EB27EBA6CB37B4551E3'], // 必要に応じて実際のテストデバイスIDに変更
      );
      await MobileAds.instance.updateRequestConfiguration(requestConfiguration);
    }
  }

  /// バナー広告を作成
  static BannerAd createBannerAd({
    required Function() onAdLoaded,
    required Function() onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('バナー広告読み込み完了: $bannerAdUnitId');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          print('バナー広告読み込み失敗: ${error.message}');
          ad.dispose();
          onAdFailedToLoad();
        },
        onAdOpened: (_) {
          print('バナー広告がタップされました');
        },
        onAdClosed: (_) {
          print('バナー広告が閉じられました');
        },
      ),
    )..load();
  }
}