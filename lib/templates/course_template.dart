import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:math';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseTemplate extends StatefulWidget {
  final String username;
  final List<Map<String, String>> courses;
  final String imagePath;
  final VoidCallback? onRefresh; // New callback for refresh functionality

  const CourseTemplate({
    super.key,
    required this.username,
    required this.courses,
    required this.imagePath,
    this.onRefresh, // Optional refresh callback
  });

  @override
  _CourseTemplateState createState() => _CourseTemplateState();
}

class _CourseTemplateState extends State<CourseTemplate> {
  final List<Color> colors = [
    Colors.blue,
    Colors.green,
    Colors.brown,
    Colors.orange,
    Colors.purple,
    Colors.grey,
  ];

  late Color selectedColor;
  final List<RewardedAd?> _rewardedAdPool = [null, null]; // Pool of ads for better availability
  bool _isAdLoading = false;
  DateTime? _lastFailedLoadTime;
  int _failureCount = 0;
  final int _maxFailureCount = 5;
  List<String> completedCourses = [];
  bool _isRefreshing = false; // Track refresh state

  @override
  void initState() {
    super.initState();
    selectedColor = colors[Random().nextInt(colors.length)];
    // Initialize multiple ad slots
    loadRewardedAdPool();
    loadCompletedCourses();
  }

  @override
  void dispose() {
    for (var ad in _rewardedAdPool) {
      ad?.dispose();
    }
    super.dispose();
  }

  void loadRewardedAdPool() {
    // Fill all available slots in the pool
    for (int i = 0; i < _rewardedAdPool.length; i++) {
      if (_rewardedAdPool[i] == null && !_isAdLoading) {
        loadRewardedAdAtIndex(i);
      }
    }
  }

  void loadRewardedAdAtIndex(int index) {
  // Don't load if already loading or if we recently had too many failures
  if (_isAdLoading) return;
  
  if (_lastFailedLoadTime != null) {
    final timeSinceLastFailure = DateTime.now().difference(_lastFailedLoadTime!);
    // Use exponential backoff based on failure count
    int backoffSeconds = _failureCount > 0 ? pow(2, min(_failureCount - 1, 4)).toInt() * 5 : 0;
    if (timeSinceLastFailure.inSeconds < backoffSeconds) return;
  }

  _isAdLoading = true;
  
  // Define both ad unit IDs
  final List<String> adUnitIds = [
    'ca-app-pub-2303106437123151/6867591440',
    'ca-app-pub-2303106437123151/6487175851',
    'ca-app-pub-2303106437123151/6632768638',
  ];
  
  // Select random ad unit ID
  final String selectedAdUnitId = adUnitIds[Random().nextInt(adUnitIds.length)];
  
  RewardedAd.load(
    adUnitId: selectedAdUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (RewardedAd ad) {
        _isAdLoading = false;
        _lastFailedLoadTime = null;
        _failureCount = 0; // Reset failure count on success
        
        setState(() => _rewardedAdPool[index] = ad);
        
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (Ad ad) {
            ad.dispose();
            setState(() => _rewardedAdPool[index] = null);
            loadRewardedAdAtIndex(index); // Reload this slot
            
            // Also check and load any other empty slots
            loadRewardedAdPool();
          },
          onAdFailedToShowFullScreenContent: (Ad ad, AdError error) {
            ad.dispose();
            setState(() => _rewardedAdPool[index] = null);
            loadRewardedAdAtIndex(index); // Reload this slot
          },
        );
      },
      onAdFailedToLoad: (LoadAdError error) {
        _isAdLoading = false;
        _lastFailedLoadTime = DateTime.now();
        _failureCount++; // Increment failure count
        
        if (_failureCount <= _maxFailureCount) {
          // Use exponential backoff for retries
          int backoffSeconds = pow(2, min(_failureCount - 1, 4)).toInt() * 5;
          Future.delayed(Duration(seconds: backoffSeconds), () {
            loadRewardedAdAtIndex(index);
          });
        } else {
          // After max failures, wait longer before trying again
          Future.delayed(const Duration(minutes: 2), () {
            _failureCount = 0; // Reset after long wait
            loadRewardedAdAtIndex(index);
          });
        }
      },
    ),
  );
}

  Future<void> markCourseAsCompleted(String topicName) async {
    final prefs = await SharedPreferences.getInstance();
    if (!completedCourses.contains(topicName)) {
      completedCourses.add(topicName);
      await prefs.setStringList('${widget.username}_completed', completedCourses);
    }
  }

  Future<void> loadCompletedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      completedCourses = prefs.getStringList('${widget.username}_completed') ?? [];
    });
  }

  double calculateProgress() {
    return completedCourses.length / widget.courses.length * 100;
  }

  RewardedAd? getAvailableAd() {
    // Find first available ad from the pool
    for (var ad in _rewardedAdPool) {
      if (ad != null) return ad;
    }
    return null;
  }

  // Method to handle refresh action
  Future<void> _handleRefresh() async {
    if (_isRefreshing || widget.onRefresh == null) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Call the parent's refresh method
    widget.onRefresh!();
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(child: const Text("Refreshing course content")),
        duration: const Duration(milliseconds: 600),
        backgroundColor: Colors.grey[900],
      ),
    );
    
    // Reset refreshing state after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }

  void showRewardedAd(BuildContext context, String route, int index) {
    int lastIndex = widget.courses.length - 1;
    String topicName = widget.courses[index]['topicName']!;

    // Check if we need to show an ad
    bool needToShowAd = (index + 1) % 2 == 0 || index == lastIndex;

    if (needToShowAd) {
      RewardedAd? availableAd = getAvailableAd();
      
      if (availableAd == null) {
        // If no ad is available, provide better user feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Center(
              child: Text("Loading ad... Please wait some seconds"),
            ),
            duration: const Duration(milliseconds: 300),
            backgroundColor: selectedColor,
          ),
        );
        
        // Ensure we're trying to load more ads
        loadRewardedAdPool();
        return;
      } else {
        int adIndex = _rewardedAdPool.indexOf(availableAd);
        
        // Show the ad and then navigate only when completed
        availableAd.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            // Navigate only when ad is completed
            Routemaster.of(context).push(route);
            
            // Mark course as completed only after watching the ad
            markCourseAsCompleted(topicName);
            setState(() {});
          },
        );
        
        // Set slot to null to prevent reuse
        setState(() => _rewardedAdPool[adIndex] = null);
        
        // Load a new ad immediately for this slot
        loadRewardedAdAtIndex(adIndex);
        
        // Also ensure other slots are being filled
        loadRewardedAdPool();
      }
    } else  {
      // No ad needed, just navigate
      Routemaster.of(context).push(route);
      
      // Mark course as completed
      markCourseAsCompleted(topicName);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pre-check ad availability on build and try to load if empty
    if (!_rewardedAdPool.any((ad) => ad != null) && !_isAdLoading) {
      loadRewardedAdPool();
    }
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: selectedColor,
        title: Text(
          widget.username,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                height: 150,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 20,
                      child: CircleAvatar(
                        radius: 40,
                        child: ClipOval(
                          child: SizedBox(
                            height: 80, 
                            child: Lottie.asset(widget.imagePath, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 30,
                      right: 30,
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: const [
                                Text("Rating", style: TextStyle(fontSize: 15, color: Colors.white)),
                                Text("4.5", style: TextStyle(fontSize: 15, color: Colors.white)),
                              ],
                            ),
                            Container(width: 2, height: 50, color: Colors.white),
                            Column(
                              children: [
                                const Text("Your progress", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                                Icon(Icons.linear_scale_rounded, color: Colors.white),
                                Text("${calculateProgress().toStringAsFixed(1)}%", style: const TextStyle(fontSize: 15, color: Colors.white)),
                              ],
                            ),
                            Container(width: 2, height: 50, color: Colors.white),
                            Column(
                              children: const [
                                Text("Review", style: TextStyle(fontSize: 15, color: Colors.white)),
                                Text("44 reviews", style: TextStyle(fontSize: 15, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Add a pull-to-refresh button here as well for better discoverability
              if (widget.onRefresh != null && widget.courses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: _isRefreshing 
                          ? SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(
                                color: selectedColor,
                                strokeWidth: 2,
                              )
                            )
                          : Icon(Icons.refresh, color: selectedColor, size: 18),
                        label: Text(
                          "Refresh Content",
                          style: TextStyle(color: selectedColor, fontSize: 14),
                        ),
                        onPressed: _isRefreshing ? null : _handleRefresh,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Topics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.courses.length,
                itemBuilder: (context, index) {
                  return CourseListView(
                    week: widget.courses[index]['week']!,
                    topicName: widget.courses[index]['topicName']!,
                    color: selectedColor,
                    route: widget.courses[index]['route']!,
                    showAdBeforeNavigation: showRewardedAd,
                    index: index,
                    completedCourses: completedCourses,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ImprovedBannerAdWidget(),
    );
  }
}

class CourseListView extends StatelessWidget {
  final String week;
  final String topicName;
  final Color color;
  final String route;
  final Function(BuildContext, String, int) showAdBeforeNavigation;
  final int index;
  final List<String> completedCourses;

  const CourseListView({
    super.key,
    required this.week,
    required this.topicName,
    required this.color,
    required this.route,
    required this.showAdBeforeNavigation,
    required this.index,
    required this.completedCourses,
  });

  @override
  Widget build(BuildContext context) {
    bool isCompleted = completedCourses.contains(topicName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: color,
      child: ListTile(
        leading: Text(
          week,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        title: Text(topicName, style: const TextStyle(color: Colors.white)),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: Colors.white)
            : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
        onTap: () => showAdBeforeNavigation(context, route, index),
      ),
    );
  }
}

class ImprovedBannerAdWidget extends StatefulWidget {
  const ImprovedBannerAdWidget({Key? key}) : super(key: key);

  @override
  State<ImprovedBannerAdWidget> createState() => _ImprovedBannerAdWidgetState();
}

class _ImprovedBannerAdWidgetState extends State<ImprovedBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _loadAttempts = 0;
  final int _maxFailedLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _createBannerAd();
  }

  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2303106437123151/7021826076', // Replace with your banner ad unit ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
            _loadAttempts = 0; // Reset attempts on success
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _loadAttempts++;
          
          if (_loadAttempts <= _maxFailedLoadAttempts) {
            // Exponential backoff for retries
            int backoffSeconds = pow(2, _loadAttempts - 1).toInt();
            Future.delayed(Duration(seconds: backoffSeconds), _createBannerAd);
          } else {
            // After max failures, wait longer
            Future.delayed(const Duration(seconds: 60), () {
              _loadAttempts = 0;
              _createBannerAd();
            });
          }
        },
        onAdClosed: (ad) {
          // Try to load a new ad when the current one is closed
          _createBannerAd();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    
    // Show a placeholder while ad is loading
    return Container(
      alignment: Alignment.center,
      height: 50,
      child: const Text("", style: TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}