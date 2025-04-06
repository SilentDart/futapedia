import 'package:flutter/material.dart';
import 'package:futapedia/templates/course_template.dart';

class Hphy102 extends StatefulWidget {
  const Hphy102({super.key});

  @override
  State<Hphy102> createState() => _Hphy102State();
}

class _Hphy102State extends State<Hphy102> {

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourseTemplate(
        username: "PHY 102",
        imagePath: "jsons/physics.json",
        courses: [
          {"week": "Lesson 1", "topicName": "Electrons and Electrostatics", "route": "/hphy102/phyw1"},
          {"week": "Lesson 2", "topicName": "Conservation of Law of Electric Charges", "route": "/hphy102/phyw2"},
          {"week": "Lesson 3", "topicName": "Conservation of Charge", "route": "/hphy102/phyw3"},
          {"week": "Lesson 4", "topicName": "Coulomb's Law 1", "route": "/hphy102/phyw4"},
          {"week": "Lesson 5", "topicName": "Coulomb's Law 2", "route": "/hphy102/phyw5"},
          {"week": "Lesson 6", "topicName": "Comparison between Gravitational Force and Coulomb's Law", "route": "/hphy102/phyw6"},
          {"week": "Lesson 7", "topicName": "Electric Field Due to a Point Charge", "route": "/hphy102/phyw7"},
          {"week": "Lesson 8", "topicName": "Electric Field and Forces", "route": "/hphy102/phyw8"},
          {"week": "Lesson 9", "topicName": "Charged Particles in an Electric Field", "route": "/hphy102/phyw9"},
          {"week": "Lesson 10", "topicName": "Superposition Principle", "route": "/hphy102/phyw10"},
          {"week": "Lesson 11", "topicName": "Electric Field Lines 1", "route": "/hphy102/phyw11"},
          {"week": "Lesson 12", "topicName": "Electric Field Lines 2", "route": "/hphy102/phyw12"},
          {"week": "Lesson 13", "topicName": "Electric Dipole", "route": "/hphy102/phyw13"},
          {"week": "Lesson 14", "topicName": "Electric Flux", "route": "/hphy102/phyw14"},
          {"week": "Lesson 15", "topicName": "Gauss's Law and Its Applications", "route": "/hphy102/phyw15"},
          {"week": "Lesson 16", "topicName": "Capacitors and Capacitance", "route": "/hphy102/phyw16"},
          {"week": "Lesson 17", "topicName": "Capacitors in Series and Parallel", "route": "/hphy102/phyw17"},
          {"week": "Lesson 18", "topicName": "Energy Stored in a Capacitor", "route": "/hphy102/phyw18"},
          {"week": "Lesson 19", "topicName": "Resistor Overview", "route": "/hphy102/phyw19"},
          {"week": "Lesson 20", "topicName": "Resistors in Series", "route": "/hphy102/phyw20"},
          {"week": "Lesson 21", "topicName": "Resistors in Parallel", "route": "/hphy102/phyw21"},
          {"week": "Lesson 22", "topicName": "Ohm's Law", "route": "/hphy102/phyw22"},
          {"week": "Lesson 23", "topicName": "More Explanations and Examples", "route": "/hphy102/phyw23"},
          {"week": "Lesson 24", "topicName": "Magnetism", "route": "/hphy102/phyw24"},
          {"week": "Test", "topicName": "Practice Past Questions", "route": "/testpage/Mathematics"},
          
        ],
      ),
      
    );
  }
}
 
 