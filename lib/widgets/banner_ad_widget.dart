import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 6;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  DateTime? _lastLoadTime;
  DateTime? _lastFailureTime;
  static const Duration _minimumReloadInterval = Duration(seconds: 30);
  Timer? _retryTimer;
  
  // 広告サイズのリスト（フォールバック用）
  int _currentSizeIndex = 0;
  static const List<AdSize> _adSizes = [
    AdSize.banner,
    AdSize.largeBanner,
    AdSize.fullBanner,
    AdSize.leaderboard,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // AdServiceのフラグが有効な場合のみ広告を読み込み
    if (AdService.showBannerAds) {
      // 初回は少し遅延させて読み込み（他の初期化処理と競合を避ける）
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // キャッシュから広告を取得してみる
          final cachedAd = AdService.getCachedBannerAd();
          if (cachedAd != null) {
            print('キャッシュされた広告を使用');
            setState(() {
              _bannerAd = cachedAd;
              _isAdLoaded = true;
              _isLoading = false;
            });
            // リスナーを追加
            _setupAdListener(cachedAd);
          } else {
            _loadBannerAd();
          }
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // アプリがフォアグラウンドに戻った時、広告が読み込まれていない場合は再読み込み
    if (state == AppLifecycleState.resumed && 
        AdService.showBannerAds && 
        !_isAdLoaded && 
        !_isLoading &&
        mounted) {
      final now = DateTime.now();
      // 最後の読み込みから一定時間経過していれば再読み込み
      if (_lastLoadTime == null || 
          now.difference(_lastLoadTime!) > _minimumReloadInterval) {
        print('アプリがフォアグラウンドに戻りました。バナー広告を再読み込みします。');
        _retryCount = 0;
        _loadBannerAd();
      }
    }
  }

  /// バナー広告を読み込み
  void _loadBannerAd({bool resetSizeIndex = false}) {
    // 既に読み込み中の場合はスキップ
    if (_isLoading) {
      print('バナー広告: 既に読み込み中のためスキップ');
      return;
    }
    
    // リトライタイマーをキャンセル
    _retryTimer?.cancel();
    _retryTimer = null;

    // 既存の広告を破棄
    _bannerAd?.dispose();
    _bannerAd = null;
    
    if (resetSizeIndex) {
      _currentSizeIndex = 0;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isAdLoaded = false;
      });
    }

    final currentSize = _adSizes[_currentSizeIndex % _adSizes.length];
    print('バナー広告読み込み開始 (リトライ回数: $_retryCount/$_maxRetries, サイズ: $currentSize)');

    _lastLoadTime = DateTime.now();
    
    _bannerAd = AdService.createBannerAd(
      adSize: currentSize,
      onAdLoaded: () {
        print('バナー広告読み込み成功 (サイズ: $currentSize)');
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
            _isLoading = false;
            _retryCount = 0; // 成功したらリトライカウントをリセット
            _currentSizeIndex = 0; // サイズインデックスもリセット
            _lastFailureTime = null;
          });
        }
      },
      onAdFailedToLoad: () {
        print('バナー広告読み込み失敗 (リトライ回数: $_retryCount/$_maxRetries, サイズ: $currentSize)');
        _lastFailureTime = DateTime.now();
        
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _isLoading = false;
          });
          
          // 次の広告サイズを試す
          _currentSizeIndex++;
          
          // 全サイズを試したらリトライカウントを増やす
          if (_currentSizeIndex >= _adSizes.length) {
            _currentSizeIndex = 0;
            _retryCount++;
          }
          
          // 最大リトライ回数に達していない場合は再読み込みを試行
          if (_retryCount < _maxRetries) {
            // リトライ間隔を徐々に長くする（指数バックオフ）
            final delay = _initialRetryDelay * (1 << (_retryCount ~/ _adSizes.length));
            print('バナー広告再読み込みを${delay.inSeconds}秒後に開始します（次のサイズ: ${_adSizes[_currentSizeIndex % _adSizes.length]}）');
            
            _retryTimer = Timer(delay, () {
              if (mounted && !_isAdLoaded && !_isLoading) {
                _loadBannerAd();
              }
            });
          } else {
            print('バナー広告: 最大リトライ回数に達しました');
            // 長い待機時間後に再度試行
            _retryTimer = Timer(const Duration(minutes: 2), () {
              if (mounted && !_isAdLoaded && !_isLoading) {
                print('バナー広告: 2分後の再試行');
                _retryCount = 0;
                _currentSizeIndex = 0;
                _loadBannerAd();
              }
            });
          }
        }
      },
    );
  }

  /// 広告にリスナーを設定
  void _setupAdListener(BannerAd ad) {
    // 既存のリスナーは上書きできないため、新しい広告の場合のみ設定
    // キャッシュされた広告は既にリスナーが設定されているため、ここでは何もしない
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _retryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // プログラムフラグで広告表示が無効の場合は何も表示しない
    if (!AdService.showBannerAds) {
      return const SizedBox.shrink();
    }

    // 広告が読み込まれていない場合は高さ分のスペースを確保
    if (!_isAdLoaded || _bannerAd == null) {
      return Container(
        height: 50,
        color: Colors.grey[100],
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _isLoading
                    ? '広告読み込み中...'
                    : (_retryCount >= _maxRetries
                        ? '広告を読み込めませんでした'
                        : '広告読み込み待機中...'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (!_isLoading && _retryCount < _maxRetries) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _retryCount = 0;
                    _currentSizeIndex = 0;
                    _loadBannerAd(resetSizeIndex: true);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '再読み込み',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // バナー広告を表示
    return Container(
      height: 50,
      color: Colors.grey[100],
      child: AdWidget(ad: _bannerAd!),
    );
  }
}