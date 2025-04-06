import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hmee102 extends StatefulWidget {
  const Hmee102({super.key});

  @override
  State<Hmee102> createState() => _Hmee102State();
}

class _Hmee102State extends State<Hmee102> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "MEE 102",
        imagePath: "jsons/pdf.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hmee102/meew1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hmee102/meew2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hmee102/meew3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hmee102/meew4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hmee102/meew5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hmee102/meew6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hmee102/meew7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hmee102/meew8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hmee102/meew9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hmee102/meew10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hmee102/meew11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hmee102/meew12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
        ],
      ),
      
    );
  }
}
 
 