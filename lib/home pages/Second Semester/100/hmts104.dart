import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hmts104 extends StatefulWidget {
  const Hmts104({super.key});

  @override
  State<Hmts104> createState() => _Hmts104State();
}

class _Hmts104State extends State<Hmts104> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "MTS 104",
        // progress: 75.5,
        imagePath: "jsons/mathematics.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Magnitude Of A Vector", "route": "/hmts104/mtsw1"},
          {"week": "Lesson 2", "topicName": "Unit Vector", "route": "/hmts104/mtsw2"},
          {"week": "Lesson 3", "topicName": "Resultant Vector", "route": "/hmts104/mtsw3"},
          {"week": "Lesson 4", "topicName": "Direction Cosines Of Vectors", "route": "/hmts104/mtsw4"},
          {"week": "Lesson 5", "topicName": "Dot Product Of Vectors", "route": "/hmts104/mtsw5"},
          {"week": "Lesson 6", "topicName": "Orthogonal And Perpendicular Vectors", "route": "/hmts104/mtsw6"},
          {"week": "Lesson 7", "topicName": "Cross Product Of Vectors", "route": "/hmts104/mtsw7"},
          {"week": "Lesson 8", "topicName": "Triple Scalar Product Of Vectors", "route": "/hmts104/mtsw8"},
          {"week": "Lesson 9", "topicName": "Equation Of A Circle", "route": "/hmts104/mtsw9"},
          {"week": "Lesson 10", "topicName": "Radius And Center Of Circle", "route": "/hmts104/mtsw10"},
          {"week": "Lesson 11", "topicName": "General Equation Of Circle", "route": "/hmts104/mtsw11"},
          {"week": "Lesson 12", "topicName": "Circle Theorem", "route": "/hmts104/mtsw12"},
          {"week": "Lesson 13", "topicName": "Length Of Tangent From A Point To A Circle", "route": "/hmts104/mtsw13"},
          {"week": "Lesson 14", "topicName": "Convert Circle To Standard Form", "route": "/hmts104/mtsw14"},
          {"week": "Lesson 15", "topicName": "Find Circle Equation", "route": "/hmts104/mtsw15"},
          {"week": "Lesson 16", "topicName": "Circle Equation From Tangent", "route": "/hmts104/mtsw16"},
          {"week": "Lesson 17", "topicName": "Conic Sections And Circles", "route": "/hmts104/mtsw17"},
          {"week": "Lesson 18", "topicName": "Conic Sections And Circles 2", "route": "/hmts104/mtsw18"},
          {"week": "Lesson 19", "topicName": "Conic Sections - Ellipses", "route": "/hmts104/mtsw19"},
          {"week": "Lesson 20", "topicName": "Parabola Directrix Focus 1", "route": "/hmts104/mtsw20"},
          {"week": "Lesson 21", "topicName": "Parabola Directrix Focus 2", "route": "/hmts104/mtsw21"},
          {"week": "Lesson 22", "topicName": "Given Focus And Vertex Find Equation", "route": "/hmts104/mtsw22"},
          {"week": "Lesson 23", "topicName": "Conic Sections Hyperbolas", "route": "/hmts104/mtsw23"},
          {"week": "Lesson 24", "topicName": "Graph Hyperbola", "route": "/hmts104/mtsw24"},
          {"week": "Lesson 25", "topicName": "Hyperbola Equation Conic Sections", "route": "/hmts104/mtsw25"},
          {"week": "Lesson 26", "topicName": "Hyperbola General To Standard", "route": "/hmts104/mtsw26"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"}
        ],
      ),
      
    );
  }
}
 
 