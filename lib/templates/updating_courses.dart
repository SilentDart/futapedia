import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:futapedia/firebase_services.dart/get_semester.dart';

/// Utility class for writing course data to Firestore
class CourseDataWriter {
  /// Writes topic data to Firestore for a specific course
  /// 
  /// Parameters:
  /// - [level]: The level (e.g., '100L', '200L')
  /// - [courseName]: The name of the course (e.g., 'csc101')
  /// - [context]: BuildContext for showing snackbars/dialogs
  /// - [topicData]: List of topic maps in the format required by Firestore
  static Future<void> writeTopicData({
    required String level,
    required String courseName,
    required BuildContext context,
    required List<Map<String, dynamic>> topicData,
  }) async {
    try {
      // Get current semester
      Semester semesterInstance = Semester();
      String? currentSemester = await semesterInstance.checkSemester();
      
      if (currentSemester == null) {
        throw Exception("Couldn't determine current semester");
      }
      
      // Prepare the course document data
      final Map<String, dynamic> courseData = {
        'Topic': topicData,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Get reference to the course document
      final DocumentReference courseDocRef = FirebaseFirestore.instance
          .collection('Semester')
          .doc(currentSemester)
          .collection(level)
          .doc(courseName.toLowerCase());
      
      // Update or create the document
      await courseDocRef.set(courseData, SetOptions(merge: true));
      
      // Clear any cache for immediate visibility of changes
      // This matches the cache structure in your CourseDetailsPage
      _clearCourseCache(courseName);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course $courseName updated successfully')),
      );
      
    } catch (e) {
      print("Error updating course data: $e");
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating course: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Helper method to clear course cache if it exists
  /// This assumes your static _courseCache is exposed or similar cache clearance logic
  static void _clearCourseCache(String courseName) {
    // This is a placeholder - you'll need to integrate with your actual caching logic
    // If your CourseDetailsPage._courseCache is accessible, you could do:
    // CourseDetailsPage._courseCache.remove(courseName);
    
    // If the cache is not directly accessible, consider implementing a cache
    // clearing mechanism in CourseDetailsPage as a static method
    print("Cache for course $courseName should be cleared");
  }
}

/// Example usage method as you provided
void updateCourseData({
  required BuildContext context,
  required String level,
  required String courseName,
}) {
  // Create topic data in the format expected by your _fetchCourseData method
  List<Map<String, dynamic>> topicData = [
    { 'Lesson 1': 'Definition of function of real variable', 'Link 1': 'http://www.youtube.com/watch?v=lGfsp2CWjok', 'imagePath': 'jsons/mathematics.json', },
{ 'Lesson 2': 'Types of Functions', 'Link 2': 'http://www.youtube.com/watch?v=Air3gz2KabA', },
{ 'Lesson 3': 'Graph of a Function of Real Variables', 'Link 3': 'http://www.youtube.com/watch?v=iXl25GfxDXw', },
{ 'Lesson 4': 'Introduction to Limit 1', 'Link 4': 'https://www.youtube.com/watch?v=riXcZT2ICjA&list=PL19E79A0638C8D449&index=2&t=3s&pp=iAQB', },
{ 'Lesson 5': 'Introduction to Limit 2', 'Link 5': 'https://www.youtube.com/watch?v=W0VWO4asgmk&list=PL19E79A0638C8D449&index=3&pp=iAQB', },
{ 'Lesson 6': 'Limit example', 'Link 6': 'https://www.youtube.com/watch?v=GGQngIp0YGI&list=PL19E79A0638C8D449&index=4&pp=iAQB', },
{ 'Lesson 7': 'Limit example 2', 'Link 7': 'https://www.youtube.com/watch?v=YRw8udexH4o&list=PL19E79A0638C8D449&index=5&pp=iAQB', },
{ 'Lesson 8': 'More on Limit', 'Link 8': 'https://www.youtube.com/watch?v=rkeU8_4nzKo&list=PL19E79A0638C8D449&index=10&pp=iAQB', },
{ 'Lesson 9': 'Epsilon delta limit', 'Link 9': 'https://www.youtube.com/watch?v=-ejyeII0i5c&list=PL19E79A0638C8D449&index=11&pp=iAQB', },
{ 'Lesson 10': 'Epsilon delta limit 2', 'Link 10': 'https://www.youtube.com/watch?v=Fdu5-aNJTzU&list=PL19E79A0638C8D449&index=12&pp=iAQB', },
{ 'Lesson 11': 'Derivative Overview', 'Link 11': 'https://www.youtube.com/watch?v=rAof9Ld5sOg&list=PL19E79A0638C8D449&index=17&pp=iAQB', },
{ 'Lesson 12': 'Derivative 2', 'Link 12': 'https://www.youtube.com/watch?v=ay8838UZ4nM&list=PL19E79A0638C8D449&index=18&t=57s&pp=iAQB', },
{ 'Lesson 13': 'Chain rule', 'Link 13': 'https://www.youtube.com/watch?v=XIQ-KnsAsbg&list=PL19E79A0638C8D449&index=20&pp=iAQB', },
{ 'Lesson 14': 'Examples on Chain Rule', 'Link 14': 'https://www.youtube.com/watch?v=6_lmiPDedsY&list=PL19E79A0638C8D449&index=21&pp=iAQB', },
{ 'Lesson 15': 'More Example on Chain Rule', 'Link 15': 'https://www.youtube.com/watch?v=DYb-AN-lK94&list=PL19E79A0638C8D449&index=22&pp=iAQB', },
{ 'Lesson 16': 'Product Rule', 'Link 16': 'https://www.youtube.com/watch?v=h78GdGiRmpM&list=PL19E79A0638C8D449&index=23&pp=iAQB', },
{ 'Lesson 17': 'Quotient Rule', 'Link 17': 'https://www.youtube.com/watch?v=E_1gEtiGPNI&list=PL19E79A0638C8D449&index=24&pp=iAQB', },
{ 'Lesson 18': 'Second Derivative', 'Link 18': 'https://www.youtube.com/watch?v=WC5VYKI807Q', },
{ 'Lesson 19': 'Implicit Differentiation 1', 'Link 19': 'https://www.youtube.com/watch?v=sL6MC-lKOrw&list=PL19E79A0638C8D449&index=32&pp=iAQB', },
{ 'Lesson 20': 'Inflection Points', 'Link 20': 'https://www.youtube.com/watch?v=dIE22eL6q90&list=PL19E79A0638C8D449&index=43&pp=iAQB', },
{ 'Lesson 21': 'Maxima and Minima Slope', 'Link 21': 'https://www.youtube.com/watch?v=tpHz0gZfVss&list=PL19E79A0638C8D449&index=42&pp=iAQB', },
{ 'Lesson 22': 'Introduction to L\'Hospital\'s Rule', 'Link 22': 'https://www.youtube.com/watch?v=PdSzruR5OeE&list=PL19E79A0638C8D449&index=38&pp=iAQB', },
{ 'Lesson 23': 'More on L\'Hospital\'s Rule', 'Link 23': 'https://www.youtube.com/watch?v=BiVOC3WocXs&list=PL19E79A0638C8D449&index=39&pp=iAQB', },
{ 'Lesson 24': 'More Examples on Hospital\'s', 'Link 24': 'https://www.youtube.com/watch?v=FJo18AwLfuI&list=PL19E79A0638C8D449&index=40&pp=iAQB', },
{ 'Lesson 25': 'More', 'Link 25': 'https://www.youtube.com/watch?v=MeVFZjT-ABM&list=PL19E79A0638C8D449&index=41&pp=iAQB', },
{ 'Lesson 26': 'Introduction to rate of change', 'Link 26': 'https://www.youtube.com/watch?v=Zyq6TmQVBxk&list=PL19E79A0638C8D449&index=53&pp=iAQB', },
{ 'Lesson 27': 'Equation of a Tangent Line', 'Link 27': 'https://www.youtube.com/watch?v=1KwW1v__T_0&list=PL19E79A0638C8D449&index=54&pp=iAQB', },
{ 'Lesson 28': 'Rate of change 2', 'Link 28': 'https://www.youtube.com/watch?v=xmgk8_l3lig&list=PL19E79A0638C8D449&index=55&pp=iAQB', },
{ 'Lesson 29': 'Rate of Change 3', 'Link 29': 'https://www.youtube.com/watch?v=hD3U65CcZ0Q&list=PL19E79A0638C8D449&index=56&pp=iAQB', },
{ 'Lesson 30': 'Indefinite Integral', 'Link 30': 'https://youtu.be/gbJAHMX80dY?si=FdHj3d2-HZee8WkQ', },
{ 'Lesson 31': 'Indefinite Integral 2', 'Link 31': 'https://youtu.be/ltHoDiANp2U?si=J2oWjV7fOIA4fzAQ', },
{ 'Lesson 32': 'U substitution', 'Link 32': 'https://youtu.be/PDkp2Mu66fo?si=CWSBPhvpTkDrflWE', },
{ 'Lesson 33': 'U substitution 2', 'Link 33': 'https://youtu.be/4oEVrV7AM74?si=BulDvDVAnuHwHG5_', },
{ 'Lesson 34': 'Definite Integral', 'Link 34': 'https://youtu.be/gX8BWiIGFkQ?si=QJiUAsP4J2iOEAdu', },
{ 'Lesson 35': 'Definite Integral 2', 'Link 35': 'https://youtu.be/YbpU8HeIi2U?si=pH5bWUNp-oTOV3jz', },
{ 'Lesson 36': 'Integration by parts', 'Link 36': 'https://youtu.be/01ZAriWg97I?si=40Oo1AmDCV9uwZz6', },
{ 'Lesson 37': 'Integration by parts 2 (Hard example)', 'Link 37': 'https://youtu.be/QK521aR1X3Y?si=I-8vZZfY4IHyGhHs', },
{ 'Lesson 38': 'Integral Trignometric', 'Link 38': 'https://youtu.be/voARbUTBhxs?si=aLPV2B7p_6abWwYa', },
{ 'Lesson 39': 'Integral Trignometric U Substitution', 'Link 39': 'https://youtu.be/pgn-wCewSoA?si=bQ_kYLkhQowmqobU', },
  ];
  
  // Call the method with explicit level and courseName
  CourseDataWriter.writeTopicData(
    level: "100L",  // Explicitly pass the level parameter
    courseName: "MTS 102",  // Explicitly pass the courseName parameter
    context: context,
    topicData: topicData,
  );
}