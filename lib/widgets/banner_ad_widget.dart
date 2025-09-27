import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // AdServiceのフラグが有効な場合のみ広告を読み込み
    if (AdService.showBannerAds) {
      _loadBannerAd();
    }
  }

  /// バナー広告を読み込み
  void _loadBannerAd() {
    _bannerAd = AdService.createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
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
        child: const Center(
          child: Text(
            '広告読み込み中...',
            style: TextStyle(color: Colors.grey),
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