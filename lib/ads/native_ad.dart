import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Enum to select which ad unit to use
enum AdUnitType {
  primary,
  secondary,
  setting,  // Added new enum value
  test      // Added new enum value
}

class NativeAdWidget extends StatefulWidget {
  final AdSize? size;
  final EdgeInsetsGeometry margin;
  final AdUnitType adUnitType; // Parameter to select which ad unit to use
   
  const NativeAdWidget({
    Key? key, 
    this.size, 
    this.margin = const EdgeInsets.symmetric(vertical: 10),
    this.adUnitType = AdUnitType.primary, // Default to primary ad unit
  }) : super(key: key);
  
  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  int _currentRetry = 0;
  final int _maxRetries = 5;
  
  // Define all four ad unit IDs
  final Map<AdUnitType, String> _adUnitIds = {
    AdUnitType.primary: 'ca-app-pub-2303106437123151/7694112015',
    AdUnitType.secondary: 'ca-app-pub-2303106437123151/5107477125',
    AdUnitType.setting: 'ca-app-pub-2303106437123151/6875016648',
    AdUnitType.test: 'ca-app-pub-2303106437123151/9782782407',
  };
  
  // Method to get the appropriate ad unit ID based on the selected type
  String _getAdUnitId() {
    return _adUnitIds[widget.adUnitType] ?? _adUnitIds[AdUnitType.primary]!;
  }
  
  @override
  void initState() {
    super.initState();
    _loadAd();
  }
  
  void _loadAd() {
    try {
      _nativeAd = NativeAd(
        adUnitId: _getAdUnitId(),
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _nativeAd = ad as NativeAd;
                _isAdLoaded = true;
                _currentRetry = 0; // Reset retry count
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            print('Native ad failed to load: ${error.message}');
            
            if (_currentRetry < _maxRetries) {
              _currentRetry++;
              Future.delayed(Duration(seconds: _currentRetry * 3), () {
                if (mounted) {
                  _loadAd();
                }
              });
            }
          },
        ),
      );
      
      _nativeAd!.load();
    } catch (e) {
      print('Error creating or loading ad: $e');
      
      if (_currentRetry < _maxRetries) {
        _currentRetry++;
        Future.delayed(Duration(seconds: _currentRetry * 3), () {
          if (mounted) {
            _loadAd();
          }
        });
      }
    }
  }
  
  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return _isAdLoaded
      ? Container(
          margin: EdgeInsets.symmetric(vertical: 25),
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign, color: Colors.grey[600], size: 30),
              SizedBox(width: 15),
              // Wrap the AdWidget in an Expanded widget to constrain its width
              Expanded(
                child: Container(
                  height: 40, // Provide a fixed height
                  child: AdWidget(ad: _nativeAd!),
                ),
              ),
            ],
          ),
        )
      : SizedBox.shrink();
  }
}