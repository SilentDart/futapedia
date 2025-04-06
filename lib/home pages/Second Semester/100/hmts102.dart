import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hmts102 extends StatefulWidget {
  const Hmts102({super.key});

  @override
  State<Hmts102> createState() => _Hmts102State();
}

class _Hmts102State extends State<Hmts102> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "MTS 102",
        imagePath: "jsons/mathematics.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Definition of Function of Real Variable", "route": "/hmts102/mtsw1"},
          {"week": "Lesson 2", "topicName": "Types of Functions", "route": "/hmts102/mtsw2"},
          {"week": "Lesson 3", "topicName": "Graph of a Function of Real Variables", "route": "/hmts102/mtsw3"},
          {"week": "Lesson 4", "topicName": "Introduction to Limit 1", "route": "/hmts102/mtsw4"},
          {"week": "Lesson 5", "topicName": "Introduction to Limit 2", "route": "/hmts102/mtsw5"},
          {"week": "Lesson 6", "topicName": "Limit Example", "route": "/hmts102/mtsw6"},
          {"week": "Lesson 7", "topicName": "Limit Example 2", "route": "/hmts102/mtsw7"},
          {"week": "Lesson 8", "topicName": "More on Limit", "route": "/hmts102/mtsw8"},
          {"week": "Lesson 9", "topicName": "Epsilon Delta Limit", "route": "/hmts102/mtsw9"},
          {"week": "Lesson 10", "topicName": "Epsilon Delta Limit 2", "route": "/hmts102/mtsw10"},
          {"week": "Lesson 11", "topicName": "Derivative Overview", "route": "/hmts102/mtsw11"},
          {"week": "Lesson 12", "topicName": "Derivative 2", "route": "/hmts102/mtsw12"},
          {"week": "Lesson 13", "topicName": "Chain Rule", "route": "/hmts102/mtsw13"},
          {"week": "Lesson 14", "topicName": "Examples on Chain Rule", "route": "/hmts102/mtsw14"},
          {"week": "Lesson 15", "topicName": "More Example on Chain Rule", "route": "/hmts102/mtsw15"},
          {"week": "Lesson 16", "topicName": "Product Rule", "route": "/hmts102/mtsw16"},
          {"week": "Lesson 17", "topicName": "Quotient Rule", "route": "/hmts102/mtsw17"},
          {"week": "Lesson 18", "topicName": "Second Derivative", "route": "/hmts102/mtsw18"},
          {"week": "Lesson 19", "topicName": "Implicit Differentiation 1", "route": "/hmts102/mtsw19"},
          {"week": "Lesson 20", "topicName": "Inflection Points", "route": "/hmts102/mtsw20"},
          {"week": "Lesson 21", "topicName": "Maxima and Minima Slope", "route": "/hmts102/mtsw21"},
          {"week": "Lesson 22", "topicName": "Introduction to L'Hospital's Rule", "route": "/hmts102/mtsw22"},
          {"week": "Lesson 23", "topicName": "More on L'Hospital's Rule", "route": "/hmts102/mtsw23"},
          {"week": "Lesson 24", "topicName": "More Examples on Hospital's", "route": "/hmts102/mtsw24"},
          {"week": "Lesson 25", "topicName": "More on L'Hospital's", "route": "/hmts102/mtsw25"},
          {"week": "Lesson 26", "topicName": "Introduction to Rate of Change", "route": "/hmts102/mtsw26"},
          {"week": "Lesson 27", "topicName": "Equation of a Tangent Line", "route": "/hmts102/mtsw27"},
          {"week": "Lesson 28", "topicName": "Rate of Change 2", "route": "/hmts102/mtsw28"},
          {"week": "Lesson 29", "topicName": "Rate of Change 3", "route": "/hmts102/mtsw29"},
          {"week": "Lesson 30", "topicName": "Indefinite Integral", "route": "/hmts102/mtsw30"},
          {"week": "Lesson 31", "topicName": "Indefinite Integral 2", "route": "/hmts102/mtsw31"},
          {"week": "Lesson 32", "topicName": "U Substitution", "route": "/hmts102/mtsw32"},
          {"week": "Lesson 33", "topicName": "U Substitution 2", "route": "/hmts102/mtsw33"},
          {"week": "Lesson 34", "topicName": "Definite Integral", "route": "/hmts102/mtsw34"},
          {"week": "Lesson 35", "topicName": "Definite Integral 2", "route": "/hmts102/mtsw35"},
          {"week": "Lesson 36", "topicName": "Integration by Parts", "route": "/hmts102/mtsw36"},
          {"week": "Lesson 37", "topicName": "Integration by Parts 2 (Hard Example)", "route": "/hmts102/mtsw37"},
          {"week": "Lesson 38", "topicName": "Integral Trigonometric", "route": "/hmts102/mtsw38"},
          {"week": "Lesson 39", "topicName": "Integral Trigonometric U Substitution", "route": "/hmts102/mtsw39"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
          
        ],
      ),
      
    );
  }
}