import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:futapedia/ads/native_ad.dart';
import 'package:futapedia/firebase_services.dart/get_semester.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:routemaster/routemaster.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Class to manage Firebase query caching
class FirebaseQueryCacheSecondSemester {
  static const String _timestampSuffix = "_timestamp";
  static const int _defaultCacheDurationDays = 30;
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Save query result to cache
  static Future<void> saveQueryResult(String cacheKey, dynamic data) async {
    try {
      // Save the data as string (JSON)
      if (data is List<String>) {
        final jsonData = jsonEncode(data);
        await _secureStorage.write(key: cacheKey, value: jsonData);
      } else if (data is String) {
        await _secureStorage.write(key: cacheKey, value: data);
      }
      
      // Save timestamp
      await _secureStorage.write(
        key: "$cacheKey$_timestampSuffix", 
        value: DateTime.now().millisecondsSinceEpoch.toString()
      );
      
      // print("Cached Firebase query result: $cacheKey");
    } catch (e) {
      // print("Error saving query cache: $e");
    }
  }
  
  // Check if cached data is valid
  static Future<bool> isCacheValid(String cacheKey, {int durationDays = _defaultCacheDurationDays}) async {
    try {
      // Check if cache exists
      final cachedValue = await _secureStorage.read(key: cacheKey);
      
      if (cachedValue == null) {
        return false;
      }
      
      // Check timestamp
      final timestampKey = "$cacheKey$_timestampSuffix";
      final timestampStr = await _secureStorage.read(key: timestampKey);
      
      if (timestampStr == null) {
        return false;
      }
      
      // Calculate cache age
      final timestamp = int.parse(timestampStr);
      final cachedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final cacheAge = DateTime.now().difference(cachedDate).inDays;
      
      return cacheAge < durationDays;
    } catch (e) {
      // print("Error checking cache validity: $e");
      return false;
    }
  }
  
  // Get cached string data
  static Future<String?> getCachedString(String cacheKey) async {
    try {
      return await _secureStorage.read(key: cacheKey);
    } catch (e) {
      // print("Error getting cached string: $e");
      return null;
    }
  }
  
  // Get cached string list data
  static Future<List<String>?> getCachedStringList(String cacheKey) async {
    try {
      final jsonData = await _secureStorage.read(key: cacheKey);
      if (jsonData == null) return null;
      
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      // print("Error getting cached string list: $e");
      return null;
    }
  }
  
  static Future<void> clearCache({int durationDays = _defaultCacheDurationDays}) async {
    try {
      final allEntries = await _secureStorage.readAll();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final entry in allEntries.entries) {
        final key = entry.key;
        if (!key.endsWith(_timestampSuffix)) continue;
        
        final cacheKey = key.substring(0, key.length - _timestampSuffix.length);
        final timestamp = int.parse(entry.value);
        final age = (now - timestamp) ~/ (1000 * 60 * 60 * 24); // Convert to days
        
        if (age >= durationDays) {
          await _secureStorage.delete(key: cacheKey);
          await _secureStorage.delete(key: key);
        }
      }
    } catch (e) {
      // print("Error clearing expired cache: $e");
    }
  }
}

class SecondSemester extends StatefulWidget {
  const SecondSemester({super.key});

  @override
  State<SecondSemester> createState() => _SecondSemesterState();
}

class _SecondSemesterState extends State<SecondSemester> with AutomaticKeepAliveClientMixin {
  String? scholar;
  String? userImageUrl;
  late NativeAdWidget _firstNativeAd;
  late NativeAdWidget _secondNativeAd;
  late NativeAdWidget _thirdNativeAd;
  final String defaultImage = "images/futapedia.jpg";
  final String userImageKey = "user_profile_image";
  String? semester;
  MaterialColor? themeColor;

  // Cache keys
  final String _semesterCacheKey = "cached_semester";
  final String _level100CacheKey = "cached_courses_100L";
  final String _level200CacheKey = "cached_courses_200L";
  final String _level300CacheKey = "cached_courses_300L";
  final int _cacheDurationDays = 30; // 30-day cache expiration

  // Lists for storing courses fetched from Firestore
  List<String> level100Courses = [];
  List<String> level200Courses = [];
  List<String> level300Courses = [];
  Map<String, String> courseRoutes = {};
  
  // Loading states
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize MobileAds
    MobileAds.instance.initialize();
    
    _firstNativeAd = const NativeAdWidget(adUnitType: AdUnitType.primary);
    _secondNativeAd = const NativeAdWidget(adUnitType: AdUnitType.secondary);
    _thirdNativeAd = const NativeAdWidget(adUnitType: AdUnitType.primary);
    
    _loadUserData();
    
    // Load semester first, then fetch courses
    _loadSemesterAndCourses();
    _loadThemeColor();
    
    // Listen for auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        setState(() {
          scholar = user.displayName?.split(" ")[0]; // Extracts first name
        });
        
        // If user has a photo URL, update shared preferences
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          _saveUserImage(user.photoURL!);
        }
      }
    });
  }

  void _loadThemeColor() async {
    final color = await ThemeColorManager.getSavedColor();
    setState(() {
      themeColor = color;
    });
  }
  // Load semester and courses with caching
  void _loadSemesterAndCourses({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });
    
    // First try to load semester from cache if not forcing refresh
    if (!forceRefresh && await FirebaseQueryCacheSecondSemester.isCacheValid(_semesterCacheKey, durationDays: _cacheDurationDays)) {
      final cachedSemester = await FirebaseQueryCacheSecondSemester.getCachedString(_semesterCacheKey);
      if (cachedSemester != null && cachedSemester.isNotEmpty) {
        setState(() {
          semester = cachedSemester;
        });
        
        // print("Using cached semester: $cachedSemester");
        
        // Try to load courses from cache
        await _loadCoursesWithCache(forceRefresh: forceRefresh);
        return;
      }
    }
    
    // If no valid cache or forced refresh, fetch semester from Firebase
    try {
      Semester semesterInstance = Semester();
      String? result = await semesterInstance.checkSemester();
      
      if (result != null && result.isNotEmpty) {
        setState(() {
          semester = result;
        });
        
        // Cache the semester
        await FirebaseQueryCacheSecondSemester.saveQueryResult(_semesterCacheKey, result);
        
        // Now fetch courses
        await _loadCoursesWithCache(forceRefresh: true); // Force fetch courses for first time
      } else {
        // If we can't get a semester, use a default value
        setState(() {
          semester = "default"; // Use a default value to prevent null issues
          _isLoading = false;
        });
        // print("Failed to get semester, using default value");
      }
    } catch (e) {
      // print("Error fetching semester: $e");
      if(!mounted) return;
      setState(() {
        semester = "default"; // Use a default value even on error
        _isLoading = false;
      });
    }
  }
  
  // Load courses with caching
  Future<void> _loadCoursesWithCache({bool forceRefresh = false}) async {
    if (semester == null) {
      // print("Semester is null, cannot load courses");
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    bool needToFetchLevel100 = forceRefresh;
    bool needToFetchLevel200 = forceRefresh;
    bool needToFetchLevel300 = forceRefresh;
    
    // Check if we have valid cache for 100L courses
    if (!forceRefresh) {
      if (await FirebaseQueryCacheSecondSemester.isCacheValid(_level100CacheKey, durationDays: _cacheDurationDays)) {
        final cachedCourses = await FirebaseQueryCacheSecondSemester.getCachedStringList(_level100CacheKey);
        if (cachedCourses != null && cachedCourses.isNotEmpty) {
          setState(() {
            level100Courses = cachedCourses;
          });
          needToFetchLevel100 = false;
          // print("Using cached 100L courses");
        } else {
          needToFetchLevel100 = true;
          // print("Cache exists but is empty for 100L courses");
        }
      }
      
      // Check if we have valid cache for 200L courses
      if (await FirebaseQueryCacheSecondSemester.isCacheValid(_level200CacheKey, durationDays: _cacheDurationDays)) {
        final cachedCourses = await FirebaseQueryCacheSecondSemester.getCachedStringList(_level200CacheKey);
        if (cachedCourses != null && cachedCourses.isNotEmpty) {
          setState(() {
            level200Courses = cachedCourses;
          });
          needToFetchLevel200 = false;
          // print("Using cached 200L courses");
        } else {
          needToFetchLevel200 = true;
          // print("Cache exists but is empty for 200L courses");
        }
      }
      
      // Check if we have valid cache for 300L courses
      if (await FirebaseQueryCacheSecondSemester.isCacheValid(_level300CacheKey, durationDays: _cacheDurationDays)) {
        final cachedCourses = await FirebaseQueryCacheSecondSemester.getCachedStringList(_level300CacheKey);
        if (cachedCourses != null && cachedCourses.isNotEmpty) {
          setState(() {
            level300Courses = cachedCourses;
          });
          needToFetchLevel300 = false;
          // print("Using cached 300L courses");
        } else {
          needToFetchLevel300 = true;
          // print("Cache exists but is empty for 300L courses");
        }
      }
    }
    
    // If we have all cached data and not forcing refresh, just build routes and exit
    if (!needToFetchLevel100 && !needToFetchLevel200 && !needToFetchLevel300) {
      _buildCourseRoutes();
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Need to fetch at least some data from Firebase
    try {
      // Fetch 100L courses if needed
      if (needToFetchLevel100) {
        // print("Fetching 100L courses from Firebase");
        final level100Snapshot = await FirebaseFirestore.instance
            .collection('Semester')
            .doc(semester)
            .collection('100L')
            .get();
        
        // Process 100L courses
        List<String> courses100 = [];
        for (var doc in level100Snapshot.docs) {
          String courseCode = doc.id.toUpperCase();
          courses100.add(courseCode);
        }
        
        setState(() {
          level100Courses = courses100;
        });
        
        // Cache the results
        await FirebaseQueryCacheSecondSemester.saveQueryResult(_level100CacheKey, courses100);
        print("Fetched and cached ${courses100.length} 100L courses");
      }
      
      // Fetch 200L courses if needed
      if (needToFetchLevel200) {
        // print("Fetching 200L courses from Firebase");
        final level200Snapshot = await FirebaseFirestore.instance
            .collection('Semester')
            .doc(semester)
            .collection('200L')
            .get();
        
        // Process 200L courses
        List<String> courses200 = [];
        for (var doc in level200Snapshot.docs) {
          String courseCode = doc.id.toUpperCase();
          courses200.add(courseCode);
        }
        
        setState(() {
          level200Courses = courses200;
        });
        
        // Cache the results
        await FirebaseQueryCacheSecondSemester.saveQueryResult(_level200CacheKey, courses200);
        // print("Fetched and cached ${courses200.length} 200L courses");
      }
      
      // Fetch 300L courses
      if (needToFetchLevel300) {
        // print("Fetching 300L courses from Firebase");
        final level300Snapshot = await FirebaseFirestore.instance
            .collection('Semester')
            .doc(semester)
            .collection('300L')
            .get();
        
        // Process 300L courses
        List<String> courses300 = [];
        for (var doc in level300Snapshot.docs) {
          String courseCode = doc.id.toUpperCase();
          courses300.add(courseCode);
        }
        
        setState(() {
          level300Courses = courses300;
        });
        
        // Cache the results
        await FirebaseQueryCacheSecondSemester.saveQueryResult(_level300CacheKey, courses300);
        // print("Fetched and cached ${courses300.length} 300L courses");
      }
      
      // Build course routes
      _buildCourseRoutes();
      
      // Update loading state
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // print("Error fetching courses: $e");
      if(!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Build course routes from course lists
  void _buildCourseRoutes() {
    Map<String, String> routes = {};
    
    // Process 100L courses
    for (var course in level100Courses) {
      routes[course] = "/h${course.toLowerCase()}";
    }
    
    // Process 200L courses
    for (var course in level200Courses) {
      routes[course] = "/h${course.toLowerCase()}";
    }
    
    // Process 300L courses
    for (var course in level300Courses) {
      routes[course] = "/h${course.toLowerCase()}";
    }
    
    // Add the TEST route if needed
    routes["TEST"] = "/test/100L";
    
    setState(() {
      courseRoutes = routes;
    });
    
    print("Built ${routes.length} course routes");
  }
  
  // Manually refresh data
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    
    _loadSemesterAndCourses(forceRefresh: true);
    
    setState(() {
      _isRefreshing = false;
    });
  }
  
  // Load user image from SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedImageUrl = prefs.getString(userImageKey);
      
      if (savedImageUrl != null && savedImageUrl.isNotEmpty) {
        setState(() {
          userImageUrl = savedImageUrl;
        });
      }
    } catch (e) {
      // print("Error loading user data: $e");
      // If error occurs, will just use default image
    }
  }
  
  // Save user image to SharedPreferences
  Future<void> _saveUserImage(String imageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(userImageKey, imageUrl);
      setState(() {
        userImageUrl = imageUrl;
      });
    } catch (e) {
      // print("Error saving user image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {

    super.build(context);

    if (themeColor == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading 
          ? _buildLoadingIndicator()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: themeColor!,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      _buildSectionHeader("🔥 Trending Courses", showRefreshButton: true),
                      _buildHorizontalCourseList(),
                      const SizedBox(height: 20),
                      
                      const SizedBox(height: 20),
                      _buildSectionTitle("    📚 100L Tutorial Videos"),
                      const SizedBox(height: 10),
                      level100Courses.isEmpty
                        ? _buildEmptyCoursesMessage("No 100 Level courses available")
                        : _buildCourseGrid(level100Courses),
                      
                      _firstNativeAd,
                      SizedBox(height:20),
                      _buildSectionTitle("    📚 200L Tutorial Videos"),
                      const SizedBox(height: 10),
                      level200Courses.isEmpty
                        ? _buildEmptyCoursesMessage("No 200 Level courses available")
                        : _buildCourseGrid(level200Courses),
                      
                      SizedBox(height:20),
                      _secondNativeAd,
                      SizedBox(height:20),
                      
                      _buildSectionTitle("    📚 300L Tutorial Videos"),
                      const SizedBox(height: 10),
                      level300Courses.isEmpty
                        ? _buildEmptyCoursesMessage("No 300 Level courses available")
                        : _buildCourseGrid(level300Courses),
                      
                      SizedBox(height:20),
                      _thirdNativeAd,
                      
                      // Cache info text
                      _buildCacheInfo(),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
  
  Widget _buildCacheInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Center(
        child: Text(
          "Pull down to refresh",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, {bool showRefreshButton = false}) {

    return FutureBuilder<Color>(
      future: ThemeColorManager.getSavedColorWithShade(600), // Using a slightly darker shade for text
      builder: (context, snapshot) {
        // Default color while loading
        final Color themeColor= snapshot.hasData ? snapshot.data! : Colors.black;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (showRefreshButton)
              _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.refresh, color: themeColor),
                    onPressed: _refreshData,
                    tooltip: 'Refresh course data',
                  ),
          ],
        );
      }
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(color: Colors.brown,size: 50),

          SizedBox(height: 20),
          
          Text(
            "Loading courses...",
            style: TextStyle(
              fontSize: 16,
              color: Colors.brown,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyCoursesMessage(String message) {
    return FutureBuilder<Color>(
      future: ThemeColorManager.getSavedColorWithShade(600), // Using a slightly darker shade for text
      builder: (context, snapshot) {
        // Default color while loading
        final Color themeColor= snapshot.hasData ? snapshot.data! : Colors.black;
        
        return Container(
          padding: EdgeInsets.all(20),
          alignment: Alignment.center,
          child: Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: themeColor,
            ),
          ),
        );
      }
    );
  }
  

  Widget _buildHeader() {
    return FutureBuilder<Color>(
      future: ThemeColorManager.getSavedColorWithShade(600), // Using a slightly darker shade for text
      builder: (context, snapshot) {
        // Default color while loading
        final Color themeColor= snapshot.hasData ? snapshot.data! : Colors.black;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yo, ${scholar ?? "Scholar"}!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    "Ready to ace your courses?",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 25,
                backgroundImage: _getProfileImage(),
                onBackgroundImageError: (exception, stackTrace) {
                  // If there's an error loading the network image, it will fall back to default
                  setState(() {
                    userImageUrl = null;
                  });
                },
              ),
            ],
          ),
        );
      }
    );
   
  }

  // Helper method to get the appropriate ImageProvider
  ImageProvider _getProfileImage() {
    if (userImageUrl != null && userImageUrl!.isNotEmpty) {
      // Try to use the user's image from SharedPreferences or Firebase
      return NetworkImage(userImageUrl!);
    } else {
      // Fall back to default image
      return AssetImage(defaultImage);
    }
  }

  Widget _buildSearchBar() {
    return FutureBuilder<Color>(
      future: ThemeColorManager.getSavedColorWithShade(), // Using a slightly darker shade for text
      builder: (context, snapshot) {
        // Default color while loading
        final Color themeColor= snapshot.hasData ? snapshot.data! : Colors.black;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search courses...",
              border: InputBorder.none,
              icon: Icon(Icons.search, color: themeColor),
            ),
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildHorizontalCourseList() {
    // If no courses available, show only the sponsored card
    if (level100Courses.isEmpty && level200Courses.isEmpty && level300Courses.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Text(
            "Pull down to refresh courses",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    
    // Include courses from all levels in the trending section
    List<String> trendingCourses = [];
    
    // Add a few courses from each level to trending
    trendingCourses.addAll(level100Courses.take(3));
    trendingCourses.addAll(level200Courses.take(3));
    trendingCourses.addAll(level300Courses.take(3));
    
    // Shuffle for more variety
    trendingCourses.shuffle();
    
    // Limit to 8 trending courses max
    if (trendingCourses.length > 8) {
      trendingCourses = trendingCourses.take(8).toList();
    }
    
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: trendingCourses.length,
        itemBuilder: (context, index) => _buildCourseCard(trendingCourses[index]),
      ),
    );
  }

  Widget _buildCourseCard(String courseName) {
    
    return FutureBuilder<Color>(
      future: ThemeColorManager.getSavedColorWithShade(500), // Using a slightly darker shade for text
      builder: (context, snapshot) {
        // Default color while loading
        final Color themeColor= snapshot.hasData ? snapshot.data! : Colors.black;

        return GestureDetector(
          onTap: () => _navigateToCourse(courseName),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                courseName,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildCourseGrid(List<String> courses) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _navigateToCourse(courses[index]),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
                ],
              ),
              child: Center(
                child: Text(
                  courses[index],
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToCourse(String courseName) {
    String? route = courseRoutes[courseName];
    if (route != null) {
      Routemaster.of(context).push('/course_details/$courseName');
    }
  }
}