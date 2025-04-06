import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdScreen extends StatefulWidget {
  final String nextRoute;

  const RewardedAdScreen({super.key, required this.nextRoute});

  @override
  _RewardedAdScreenState createState() => _RewardedAdScreenState();
}

class _RewardedAdScreenState extends State<RewardedAdScreen> {
  // Two rewarded ad instances
  RewardedAd? _primaryAd;
  RewardedAd? _secondaryAd;
  
  bool _isAdShown = false;
  bool _hasEarnedReward = false;
  int _retryCount = 0;
  final int _maxRetries = 3;
  bool _isFirstAdLoaded = false;
  
  // Ad unit IDs
  final String _primaryAdUnitId = "ca-app-pub-2303106437123151/6867591440";
  final String _secondaryAdUnitId = "ca-app-pub-2303106437123151/6487175851";

  @override
  void initState() {
    super.initState();
    _loadBothAds();
  }

  void _loadBothAds() {
    // Load both ads simultaneously
    _loadPrimaryAd();
    _loadSecondaryAd();
  }

  void _loadPrimaryAd() {
    RewardedAd.load(
      adUnitId: _primaryAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print("✅ Primary ad loaded");
          setState(() {
            _primaryAd = ad;
          });
          
          // If this is the first ad to load, show it and terminate the other one
          if (!_isFirstAdLoaded && !_isAdShown) {
            setState(() {
              _isFirstAdLoaded = true;
            });
            _showAd(ad);
            
            // Dispose of the secondary ad if it exists
            if (_secondaryAd != null) {
              _secondaryAd!.dispose();
              _secondaryAd = null;
            }
          }
        },
        onAdFailedToLoad: (error) {
          print("❌ Primary Ad Failed: ${error.message}");
          
          // If both ads failed and we haven't exceeded retry limit
          if (_primaryAd == null && _secondaryAd == null && !_isFirstAdLoaded && _retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 3), _loadBothAds);
          } else if (_retryCount >= _maxRetries && _primaryAd == null && _secondaryAd == null && !_isFirstAdLoaded) {
            _showRetryOption();
          }
        },
      ),
    );
  }

  void _loadSecondaryAd() {
    RewardedAd.load(
      adUnitId: _secondaryAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print("✅ Secondary ad loaded");
          setState(() {
            _secondaryAd = ad;
          });
          
          // If this is the first ad to load, show it and terminate the other one
          if (!_isFirstAdLoaded && !_isAdShown) {
            setState(() {
              _isFirstAdLoaded = true;
            });
            _showAd(ad);
            
            // Dispose of the primary ad if it exists
            if (_primaryAd != null) {
              _primaryAd!.dispose();
              _primaryAd = null;
            }
          }
        },
        onAdFailedToLoad: (error) {
          print("❌ Secondary Ad Failed: ${error.message}");
          
          // If both ads failed and we haven't exceeded retry limit
          if (_primaryAd == null && _secondaryAd == null && !_isFirstAdLoaded && _retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 3), _loadBothAds);
          } else if (_retryCount >= _maxRetries && _primaryAd == null && _secondaryAd == null && !_isFirstAdLoaded) {
            _showRetryOption();
          }
        },
      ),
    );
  }

  void _showAd(RewardedAd ad) {
    if (_isAdShown) return;
    
    setState(() {
      _isAdShown = true;
    });
    
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        print("Ad dismissed");
        
        // User closed the ad
        setState(() {
          _isAdShown = false;
        });
        
        if (!_hasEarnedReward) {
          if (!mounted) return;
          Navigator.pop(context); // Return to previous screen if user didn't earn reward
        }
        
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print("❌ Failed to show ad: ${error.message}");
        setState(() {
          _isAdShown = false;
          _isFirstAdLoaded = false;
        });
        
        ad.dispose();
        
        if (!mounted) return;
        _showRetryOption();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      print("✅ User watched ad! Navigating to ${widget.nextRoute}");
      setState(() {
        _hasEarnedReward = true;
      });
      
      if (!mounted) return;
      Routemaster.of(context).replace(widget.nextRoute);
    });
  }

  // Method to show second ad if available (to be called when user requests it)
  void showSecondAd() {
    if (_primaryAd != null) {
      _showAd(_primaryAd!);
      _primaryAd = null;
    } else if (_secondaryAd != null) {
      _showAd(_secondaryAd!);
      _secondaryAd = null;
    } else {
      // No ad available, load new ones
      setState(() {
        _isFirstAdLoaded = false;
        _retryCount = 0;
      });
      _loadBothAds();
    }
  }

  void _showRetryOption() {
    if (!mounted) return;
    setState(() {
      _isAdShown = false;
    });
  }

  @override
  void dispose() {
    _primaryAd?.dispose();
    _secondaryAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        body: Center(
          child: !_isFirstAdLoaded && _retryCount >= _maxRetries && !_isAdShown
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Ad failed to load. Try again?",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _retryCount = 0;
                          _isAdShown = false;
                          _hasEarnedReward = false;
                          _isFirstAdLoaded = false;
                        });
                        _loadBothAds();
                      },
                      child: const Text("Retry"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}