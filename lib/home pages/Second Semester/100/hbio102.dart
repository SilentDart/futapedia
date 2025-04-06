import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hbio102 extends StatefulWidget {
  const Hbio102({super.key});

  @override
  State<Hbio102> createState() => _Hbio102State();
}

class _Hbio102State extends State<Hbio102> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "BIO 102",
        imagePath: "jsons/biology.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hbio102/biow1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hbio102/biow2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hbio102/biow3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hbio102/biow4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hbio102/biow5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hbio102/biow6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hbio102/biow7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hbio102/biow8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hbio102/biow9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hbio102/biow10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hbio102/biow11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hbio102/biow12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
          
        ],
      ),
      
    );
  }
}
 
 