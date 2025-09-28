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

  // インタースティシャル広告のインスタンス保持
  static InterstitialAd? _interstitialAd;
  static bool _isLoadingInterstitial = false;
  
  // バナー広告のキャッシュ
  static final List<BannerAd> _bannerAdCache = [];
  static const int _maxCacheSize = 3;
  static bool _isPreloadingBanners = false;

  // テスト用広告ID（デバッグビルド時）
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';

  // 本番用広告ID（リリースビルド時）- 現在はテスト用IDを使用
  static const String _productionBannerAdUnitIdAndroid = 'ca-app-pub-4630894580841955/1697885857';
  static const String _productionBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _productionInterstitialAdUnitIdAndroid = 'ca-app-pub-4630894580841955/1657345646';
  static const String _productionInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';

  /// 現在の環境に応じたバナー広告IDを取得
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _isDebug ? _testBannerAdUnitIdAndroid : _productionBannerAdUnitIdAndroid;
    } else {
      return _isDebug ? _testBannerAdUnitIdIOS : _productionBannerAdUnitIdIOS;
    }
  }

  /// 現在の環境に応じたインタースティシャル広告IDを取得
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _isDebug ? _testInterstitialAdUnitIdAndroid : _productionInterstitialAdUnitIdAndroid;
    } else {
      return _isDebug ? _testInterstitialAdUnitIdIOS : _productionInterstitialAdUnitIdIOS;
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

    // インタースティシャル広告を事前読み込み
    await _preloadInterstitialAd();
    
    // バナー広告も事前にいくつか読み込んでおく
    if (showBannerAds) {
      _preloadBannerAds();
    }
  }

  /// バナー広告を作成
  static BannerAd createBannerAd({
    required Function() onAdLoaded,
    required Function() onAdFailedToLoad,
    AdSize adSize = AdSize.banner,
  }) {
    final adUnitId = bannerAdUnitId;
    print('バナー広告作成開始: $adUnitId (${_isDebug ? "テスト広告" : "本番広告"}, サイズ: $adSize)');
    
    return BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('バナー広告読み込み完了: $adUnitId');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          print('バナー広告読み込み失敗:');
          print('  - エラーコード: ${error.code}');
          print('  - エラーメッセージ: ${error.message}');
          print('  - ドメイン: ${error.domain}');
          print('  - 広告ID: $adUnitId');
          ad.dispose();
          onAdFailedToLoad();
        },
        onAdOpened: (_) {
          print('バナー広告がタップされました');
        },
        onAdClosed: (_) {
          print('バナー広告が閉じられました');
        },
        onAdImpression: (_) {
          print('バナー広告が表示されました（インプレッション）');
        },
      ),
    )..load();
  }

  /// インタースティシャル広告を事前読み込み
  static Future<void> _preloadInterstitialAd() async {
    // 広告表示フラグがfalseの場合は読み込まない
    if (!showBannerAds) {
      print('インタースティシャル広告: 表示フラグがfalseのため事前読み込みをスキップ');
      return;
    }

    // 既に読み込み中の場合はスキップ
    if (_isLoadingInterstitial) {
      print('インタースティシャル広告: 既に読み込み中のためスキップ');
      return;
    }

    // 既に読み込み済みの場合はスキップ
    if (_interstitialAd != null) {
      print('インタースティシャル広告: 既に読み込み済み');
      return;
    }

    _isLoadingInterstitial = true;
    print('インタースティシャル広告事前読み込み開始: $interstitialAdUnitId');

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('インタースティシャル広告事前読み込み完了');
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('インタースティシャル広告事前読み込み失敗: ${error.message}');
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// 事前読み込み済みのインタースティシャル広告を表示
  static void showInterstitialAd({
    Function()? onAdShown,
    Function()? onAdClosed,
    Function()? onAdFailedToShow,
  }) {
    // 広告表示フラグがfalseの場合は何もしない
    if (!showBannerAds) {
      print('インタースティシャル広告: 表示フラグがfalseのためスキップ');
      onAdClosed?.call();
      return;
    }

    // 事前読み込み済み広告がない場合
    if (_interstitialAd == null) {
      print('インタースティシャル広告: 事前読み込み済み広告がありません');
      onAdFailedToShow?.call();
      // 次回のために再読み込みを開始
      _preloadInterstitialAd();
      return;
    }

    print('インタースティシャル広告表示開始');

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('インタースティシャル広告表示開始');
        onAdShown?.call();
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('インタースティシャル広告が閉じられました');
        ad.dispose();
        _interstitialAd = null;
        onAdClosed?.call();
        // 次回のために新しい広告を事前読み込み
        _preloadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('インタースティシャル広告表示失敗: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        onAdFailedToShow?.call();
        // 次回のために新しい広告を事前読み込み
        _preloadInterstitialAd();
      },
    );

    _interstitialAd!.show();
  }

  /// 【旧メソッド：互換性のため残す】インタースティシャル広告を読み込み・表示
  @Deprecated('Use showInterstitialAd() instead. This method will be removed in future versions.')
  static Future<void> loadAndShowInterstitialAd({
    Function()? onAdShown,
    Function()? onAdClosed,
    Function()? onAdFailedToLoad,
  }) async {
    showInterstitialAd(
      onAdShown: onAdShown,
      onAdClosed: onAdClosed,
      onAdFailedToShow: onAdFailedToLoad,
    );
  }
  
  /// バナー広告を事前に複数読み込み
  static void _preloadBannerAds() async {
    if (_isPreloadingBanners || !showBannerAds) return;
    
    _isPreloadingBanners = true;
    print('バナー広告の事前読み込み開始');
    
    // 異なるサイズの広告を事前に読み込む
    final adSizes = [AdSize.banner, AdSize.largeBanner];
    
    for (final size in adSizes) {
      if (_bannerAdCache.length >= _maxCacheSize) break;
      
      // 少し間隔を空けて読み込み
      await Future.delayed(const Duration(milliseconds: 500));
      
      final ad = BannerAd(
        adUnitId: bannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            print('バナー広告事前読み込み成功: $size');
            if (_bannerAdCache.length < _maxCacheSize) {
              _bannerAdCache.add(_ as BannerAd);
            } else {
              _.dispose();
            }
          },
          onAdFailedToLoad: (ad, error) {
            print('バナー広告事前読み込み失敗: $size');
            ad.dispose();
          },
        ),
      )..load();
    }
    
    _isPreloadingBanners = false;
  }
  
  /// キャッシュからバナー広告を取得
  static BannerAd? getCachedBannerAd() {
    if (_bannerAdCache.isEmpty) return null;
    
    final ad = _bannerAdCache.removeAt(0);
    print('キャッシュからバナー広告を取得 (残り${_bannerAdCache.length}個)');
    
    // キャッシュが減ったら補充
    if (_bannerAdCache.length < 2 && !_isPreloadingBanners) {
      Future.delayed(const Duration(seconds: 1), _preloadBannerAds);
    }
    
    return ad;
  }
  
  /// キャッシュをクリア（メモリ解放用）
  static void clearCache() {
    for (final ad in _bannerAdCache) {
      ad.dispose();
    }
    _bannerAdCache.clear();
    print('バナー広告キャッシュをクリアしました');
  }
}
