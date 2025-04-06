import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hche102 extends StatefulWidget {
  const Hche102({super.key});

  @override
  State<Hche102> createState() => _Hche102State();
}

class _Hche102State extends State<Hche102> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "CHE 102",
        imagePath: "jsons/chemistry.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hche102/chew1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hche102/chew2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hche102/chew3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hche102/chew4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hche102/chew5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hche102/chew6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hche102/chew7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hche102/chew8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hche102/chew9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hche102/chew10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hche102/chew11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hche102/chew12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
          
        ],
      ),
      
    );
  }
}
 
 