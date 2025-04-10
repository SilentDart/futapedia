import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:futapedia/firebase_services.dart/get_semester.dart';
import 'package:futapedia/templates/course_template.dart';

class CourseDetailsPage extends StatefulWidget {
  final String courseName;
  
  const CourseDetailsPage({super.key, required this.courseName});
  
  @override
  _CourseDetailsPageState createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage> {
  bool _isLoading = true;
  List<Map<String, String>> _courseTopics = [];
  String _imagePath = 'assets/animations/course_default.json'; // Default animation
  
  // Create secure storage instance
  final _secureStorage = const FlutterSecureStorage();
  
  // Cache expiration time in milliseconds (30 days)
  static const int _cacheExpirationDays = 30;
  static const int _cacheExpirationMs = _cacheExpirationDays * 24 * 60 * 60 * 1000;
  
  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }
  
  Future<void> _loadCourseData() async {
    try {
      // Try to get cached data from secure storage
      final String? cachedDataJson = await _secureStorage.read(key: 'course_${widget.courseName}');
      
      if (cachedDataJson != null) {
        // Parse the JSON data
        final Map<String, dynamic> cachedData = json.decode(cachedDataJson);
        final int cacheTimestamp = cachedData['timestamp'] as int;
        final int currentTime = DateTime.now().millisecondsSinceEpoch;
        
        // If cache is less than 30 days old, use it
        if (currentTime - cacheTimestamp < _cacheExpirationMs) {
          // Extract topics list and convert each item to Map<String, String>
          final List<dynamic> topicsJson = cachedData['topics'];
          final List<Map<String, String>> topics = topicsJson
              .map((topic) => Map<String, String>.from(topic))
              .toList();
          
          setState(() {
            _courseTopics = topics;
            _imagePath = cachedData['imagePath'] as String;
            _isLoading = false;
          });
          return; // Exit early, no need to fetch from Firestore
        }
        
        // Cache is expired, remove it
        await _secureStorage.delete(key: 'course_${widget.courseName}');
        print("Cache expired for ${widget.courseName}, fetching fresh data");
      }
    } catch (e) {
      print("Error reading from secure storage: $e");
      // Continue to fetch data if there's an error with the cache
    }
    
    // If not cached or cache expired, fetch from Firestore
    await _fetchCourseData();
  }
  
  Future<void> _fetchCourseData() async {
    try {
      // Get semester from the Semester class
      Semester semesterInstance = Semester();
      String? currentSemester = await semesterInstance.checkSemester();
      
      if (currentSemester == null) {
        throw Exception("Couldn't determine current semester");
      }
      
      // Determine level from course name
      String level;

      if (["50", "51", "52", "53", "54", "55", "56", "57", "58", "59"]
          .any((e) => widget.courseName.contains(e))) {
        level = "500L";
      } else if (["40", "41", "42", "43", "44", "45", "46", "47", "48", "49"]
          .any((e) => widget.courseName.contains(e))) {
        level = "400L";
      } else if (["30", "31", "32", "33", "34", "35", "36", "37", "38", "39"]
          .any((e) => widget.courseName.contains(e))) {
        level = "300L";
      } else if (["20", "21", "22", "23", "24", "25", "26", "27", "28", "29"]
          .any((e) => widget.courseName.contains(e))) {
        level = "200L";
      } else {
        level = "100L";
      }

      // Fetch the document for this course
      final DocumentSnapshot courseDoc = await FirebaseFirestore.instance
          .collection('Semester')
          .doc(currentSemester)
          .collection(level)
          .doc(widget.courseName.toLowerCase())
          .get();
      
      // Check if the document exists and has data
      if (!courseDoc.exists) {
        throw Exception("Course document not found");
      }
      
      // Safely extract and check the data
      final Map<String, dynamic>? courseData = courseDoc.data() as Map<String, dynamic>?;
      
      if (courseData == null || !courseData.containsKey('Topic')) {
        throw Exception("Course data missing or missing Topic array");
      }
      
      // Now we can safely access the Topic array
      final List<dynamic>? topicsArray = courseData['Topic'] as List<dynamic>?;
      
      if (topicsArray == null || topicsArray.isEmpty) {
        throw Exception("Topics array is empty or null");
      }
      
      // Transform the topics data into the format needed by CourseTemplate
      List<Map<String, String>> formattedTopics = [];
      String imagePath = _imagePath; // Start with default
      
      for (int i = 0; i < topicsArray.length; i++) {
        Map<String, dynamic>? topic = topicsArray[i] as Map<String, dynamic>?;
        
        // Skip null topics
        if (topic == null) continue;
        
        // Set image path if found
        if (topic.containsKey('imagePath') && topic['imagePath'] != null) {
          imagePath = topic['imagePath'] as String;
        }
        
        // Find all lesson keys in this topic map
        List<String> lessonKeys = topic.keys
            .where((key) => key.startsWith('Lesson'))
            .toList();
        
        // Process each lesson key found
        for (String lessonKey in lessonKeys) {
          // Extract the lesson number from the key (e.g., "Lesson 1" -> "1")
          String lessonNumberStr = lessonKey.replaceAll('Lesson ', '');
          int lessonNumber = int.tryParse(lessonNumberStr) ?? (i + 1);
          
          // Find the corresponding link key with the same number
          String linkKey = 'Link $lessonNumberStr';
          
          // Get link value if it exists
          String link = topic.containsKey(linkKey) && topic[linkKey] != null 
              ? topic[linkKey] as String 
              : "";
          
          // Create a formatted topic entry with null-safe access
          formattedTopics.add({
            'week': 'Lesson $lessonNumber',
            'topicName': topic[lessonKey] as String? ?? 'Topic $lessonNumber',
            'route': link.isNotEmpty ? '/video_player?url=${Uri.encodeComponent(link)}' : '/coming_soon',
          });
        }
      }
      
      // Sort topics by lesson number to ensure correct order
      formattedTopics.sort((a, b) {
        int aNumber = int.tryParse(a['week']!.split(' ').last) ?? 0;
        int bNumber = int.tryParse(b['week']!.split(' ').last) ?? 0;
        return aNumber.compareTo(bNumber);
      });
      
      // Save to secure storage with timestamp
      final Map<String, dynamic> cacheData = {
        'topics': formattedTopics,
        'imagePath': imagePath,
        'timestamp': DateTime.now().millisecondsSinceEpoch, // Add current timestamp
      };
      
      // Convert to JSON and store
      await _secureStorage.write(
        key: 'course_${widget.courseName}',
        value: json.encode(cacheData),
      );
      
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _courseTopics = formattedTopics;
          _imagePath = imagePath;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print("Error fetching course data: $e");
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Method to refresh data - will be passed to CourseTemplate
  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    // Remove from cache
    await _secureStorage.delete(key: 'course_${widget.courseName}');
    
    // Fetch fresh data
    await _fetchCourseData();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_courseTopics.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.courseName),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("No topics available for this course"),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text("Refresh"),
                onPressed: _refreshData,
              ),
            ],
          ),
        ),
      );
    }
    
    // Pass the refresh callback to CourseTemplate
    return Scaffold(
      body: CourseTemplate(
        username: widget.courseName,
        courses: _courseTopics,
        imagePath: _imagePath,
        onRefresh: _refreshData, // Pass the refresh function
      ),
    );
  }
}