import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hmts101 extends StatefulWidget {
  const Hmts101({super.key});

  @override
  State<Hmts101> createState() => _Hmts101State();
}

class _Hmts101State extends State<Hmts101> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "MTS 101",
        imagePath: "jsons/mathematics.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hmts101/mtsw1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hmts101/mtsw2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hmts101/mtsw3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hmts101/mtsw4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hmts101/mtsw5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hmts101/mtsw6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hmts101/mtsw7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hmts101/mtsw8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hmts101/mtsw9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hmts101/mtsw10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hmts101/mtsw11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hmts101/mtsw12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
          
        ],
      ),
      // bottomNavigationBar: BannerAdWidget(),
      
    );
  }
}
 
 