import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TestResult {
  final String title;
  final String score;
  final String date;
  
  TestResult({
    required this.title,
    required this.score,
    required this.date,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'score': score,
      'date': date,
    };
  }
  
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      title: json['title'],
      score: json['score'],
      date: json['date'],
    );
  }
}

class RecentTestsManager {
  static const String _storageKey = 'recent_test_results';
  static const int _maxResults = 3;
  
  // Save a new test result
  static Future<void> saveTestResult({
    required String subjectId,
    required String score,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current date in formatted string
    final now = DateTime.now();
    final dateStr = "${_getMonthName(now.month)} ${now.day}, ${now.year}";
    
    // Create new test result
    final newResult = TestResult(
      title: subjectId,
      score: score,
      date: dateStr,
    );
    
    // Get existing results
    List<TestResult> results = await getRecentTests();
    
    // Add the new result at the beginning
    results.insert(0, newResult);
    
    // Keep only the most recent 3 results
    if (results.length > _maxResults) {
      results = results.sublist(0, _maxResults);
    }
    
    // Save the updated list
    final jsonList = results.map((result) => result.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
  
  // Get all recent test results
  static Future<List<TestResult>> getRecentTests() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get stored data
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    // Parse and return the list
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => TestResult.fromJson(json)).toList();
  }
  
  // Helper method to get month name
  static String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
}