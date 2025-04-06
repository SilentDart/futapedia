import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hcsc102 extends StatefulWidget {
  const Hcsc102({super.key});

  @override
  State<Hcsc102> createState() => _Hcsc102State();
}

class _Hcsc102State extends State<Hcsc102> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "CSC 102",
        imagePath: "jsons/computer.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hcsc102/cscw1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hcsc102/cscw2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hcsc102/cscw3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hcsc102/cscw4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hcsc102/cscw5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hcsc102/cscw6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hcsc102/cscw7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hcsc102/cscw8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hcsc102/cscw9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hcsc102/cscw10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hcsc102/cscw11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hcsc102/cscw12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
        ],
      ),
      
    );
  }
}
 
 