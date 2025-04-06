import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hbio101 extends StatefulWidget {
  const Hbio101({super.key});

  @override
  State<Hbio101> createState() => _Hbio101State();
}

class _Hbio101State extends State<Hbio101> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "BIO 101",
        imagePath: "jsons/biology.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Introduction to set theory", "route": "/hbio101/biow1"},
          {"week": "Lesson 2", "topicName": "Real numbers, integers, rational and irrational numbers", "route": "/hbio101/biow2"},
          {"week": "Lesson 3", "topicName": "Introduction to Mathematical Induction", "route": "/hbio101/biow3"},
          {"week": "Lesson 4", "topicName": "More on Mathematical Induction", "route": "/hbio101/biow4"},
          {"week": "Lesson 5", "topicName": "Quadratic equations", "route": "/hbio101/biow5"},
          {"week": "Lesson 6", "topicName": "More on Quadratic equations", "route": "/hbio101/biow6"},
          {"week": "Lesson 7", "topicName": "Binomial theorem", "route": "/hbio101/biow7"},
          {"week": "Lesson 8", "topicName": "Nth root of unity", "route": "/hbio101/biow8"},
          {"week": "Lesson 9", "topicName": "Circular measure", "route": "/hbio101/biow9"},
          {"week": "Lesson 10", "topicName": "More on Circular measure", "route": "/hbio101/biow10"},
          {"week": "Lesson 11", "topicName": "Real sequence and Series", "route": "/hbio101/biow11"},
          {"week": "Lesson 12", "topicName": "Trigonometry", "route": "/hbio101/biow12"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
          
        ],
      ),
      // bottomNavigationBar: BannerAdWidget(),
      
    );
  }
}
 
 