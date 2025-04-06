import 'package:flutter/material.dart';
import 'package:futapedia/templates/youtube_player.dart';



class Linklist{
  
  static Map<int, String> PHY101 = {
    1 : "https://www.youtube.com/watch?v=bXZmu807UfQ", //Units and dimension
    2 : "https://www.youtube.com/watch?v=xS-gdFgZel0", //Vector
    3 : "https://youtu.be/xS-gdFgZel0", //Vector continuation
    4 : "https://www.youtube.com/watch?v=s1V_Tfzmm3o", //Displacement, velocity and acceleration
    5 : "https://www.youtube.com/watch?v=s-Ul9dIS9AE&list=PLBlnK6fEyqRgp46KUv4ZY69yXmpwKOIev&index=38",
  };
  
}



class Phyw1 extends StatelessWidget {
  const Phyw1({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[1] ?? '');
  }
}



class Phyw2 extends StatelessWidget {
  const Phyw2({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[2] ?? '');
  }
}


class Phyw3 extends StatelessWidget {
  const Phyw3({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[3] ?? '');
  }
}


class Phyw4 extends StatelessWidget {
  const Phyw4({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[4] ?? '');
  }
}


class Phyw5 extends StatelessWidget {
  const Phyw5({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[5] ?? '');
  }
}


class Phyw6 extends StatelessWidget {
  const Phyw6({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[6] ?? '');
  }
}


class Phyw7 extends StatelessWidget {
  const Phyw7({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[7] ?? '');
  }
}

class Phyw8 extends StatelessWidget {
  const Phyw8({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[8] ?? '');
  }
} 

class Phyw9 extends StatelessWidget {
  const Phyw9({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[9] ?? '');
  }
} 

class Phyw10 extends StatelessWidget {
  const Phyw10({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.PHY101[10] ?? '');
  }
} 
