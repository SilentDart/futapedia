import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';


class Hche101 extends StatefulWidget {
  const Hche101({super.key});

  @override
  State<Hche101> createState() => _Hche101State();
}

class _Hche101State extends State<Hche101> {




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "CHE 101",
        imagePath: "jsons/chemistry.json", // Pass the image as an argument
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to CHEMISTRY", "route": "/hche101/chew1"},
          {"week": "Lesson 2", "topicName": "Algebra Basics", "route": "/hche101/chew2"},
          {"week": "Lesson 3", "topicName": "Trigonometry", "route": "/hche101/chew3"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Chemistry"},
        ],
      ),
      //  bottomNavigationBar: BannerAdWidget(),
    );
  }
}

