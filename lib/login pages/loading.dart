import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Colors.brown,
            size: 50,
          ),
        ),
    );
  }
} 