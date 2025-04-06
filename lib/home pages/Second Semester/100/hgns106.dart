import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hgns106 extends StatefulWidget {
  const Hgns106({super.key});

  @override
  State<Hgns106> createState() => _Hgns106State();
}

class _Hgns106State extends State<Hgns106> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "GNS 106",
        imagePath: "jsons/gns.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hgns106/gnsw1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hgns106/gnsw2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hgns106/gnsw3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hgns106/gnsw4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hgns106/gnsw5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hgns106/gnsw6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hgns106/gnsw7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hgns106/gnsw8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hgns106/gnsw9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hgns106/gnsw10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hgns106/gnsw11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hgns106/gnsw12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
        ],
      ),
      
    );
  }
}
 
 