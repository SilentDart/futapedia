import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  final int _maxRetry = 4;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2303106437123151/7021826076',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
            _retryCount = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (_retryCount < _maxRetry) {
            _retryCount++;
            int delay = _retryCount * 2;
            Future.delayed(Duration(seconds: delay), () {
              if (mounted) {
                _loadBannerAd();
              }
            });
          }
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return _isAdLoaded && _bannerAd != null
        ? SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          )
        : const SizedBox(); // Hide when not loaded
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
