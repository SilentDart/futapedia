import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';




class Hphy101 extends StatefulWidget {
  const Hphy101({super.key});

  @override
  State<Hphy101> createState() => _Hphy101State();
}

class _Hphy101State extends State<Hphy101> {
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: CourseTemplate(
          username: "PHY 101",
          imagePath: "jsons/physics.json",
          courses: [
    {"week": "Lesson 1", "topicName": "Units and Dimensions", "route": "/hphy101/phyw1"},
    {"week": "Lesson 2", "topicName": "Kinematics Vector", "route": "hphy101/phyw2"},
    {"week": "Lesson 3", "topicName": "More on Vectors", "route": "/hphy101/phyw3"},
    {"week": "Lesson 4", "topicName": "Displacement, Velocity and Acceleration", "route": "/hphy101/phyw4"},
    {"week": "Lesson 5", "topicName": "What you should know", "route": "hphy101/phyw5"},
    {"week": "Lesson 6", "topicName": "Trigonometry", "route": "/hphy101/phyw6"},
    {"week": "Lesson 7", "topicName": "Introduction to Physics 101", "route": "/hphy101/phyw7"},
    {"week": "Lesson 8", "topicName": "What you should know", "route": "hphy101/phyw8"},
    {"week": "Lesson 9", "topicName": "Trigonometry", "route": "/hphy101/phyw9"},
    {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Physics"},
  ],
        ),
        // bottomNavigationBar: BannerAdWidget(),
  );
        
  }
}
