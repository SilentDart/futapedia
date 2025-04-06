import 'package:flutter/material.dart';
import 'package:futapedia/templates/youtube_player.dart';



class Linklist{
  
  static Map<int, String> BIO102 = {
    1 : "https://youtu.be/5ZhNmKb-dqk?si=S3c-ufYSKETtu0Ci", //set theory
    2 : "https://youtu.be/7uXkia8h4lw?si=-o8hngIat08cWNpx", //real numbers and the likes
    3 : "https://youtu.be/JTgWbq-S6Zc?si=JSOTa-nwXbc-JolU", //mathematical induction
    4 : "https://https://www.youtube.com/watch?v=tHNVX3e9zd0", //mathematical induction continuation
    5 : "https://www.youtube.com/watch?v=IWigvJcCAJ0", //Quadratic equation
    6 : "https://www.youtube.com/watch?v=WxwiEFDmSGQ", //More on quadratic equation: quadratic formular
    7 : "https://www.youtube.com/watch?v=s19dWIHficY", //Binomial theorem
    8 : "https://youtu.be/-F-FHNTz4qk", //Nth root of unity
    9 : "https://www.youtube.com/watch?v=5d9HhtmqO6g",  //Circular measure
    10: "https://www.youtube.com/watch?v=KZJm8VUpugw", //More on circular measure
    11: "https://www.youtube.com/watch?v=m5Yn4BdpOV0", //Real sequence and series
    12: "https://www.youtube.com/watch?v=PUB0TaZ7bhA"//Trigonometry
  };
   
}



class Bio102_w1 extends StatelessWidget {
  const Bio102_w1({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[1] ?? '');
  }
}



class Bio102_w2 extends StatelessWidget {
  const Bio102_w2 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[2] ?? '');
  }
}


class Bio102_w3 extends StatelessWidget {
  const Bio102_w3 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[3] ?? '');
  }
}


class Bio102_w4 extends StatelessWidget {
  const Bio102_w4 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[4] ?? '');
  }
}


class Bio102_w5 extends StatelessWidget {
  const Bio102_w5 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[5] ?? '');
  }
}


class Bio102_w6 extends StatelessWidget {
  const Bio102_w6 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[6] ?? '');
  }
}


class Bio102_w7 extends StatelessWidget {
  const Bio102_w7 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[7] ?? '');
  }
}


class Bio102_w8 extends StatelessWidget {
  const Bio102_w8 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[8] ?? '');
  }
}


class Bio102_w9 extends StatelessWidget {
  const Bio102_w9 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[9] ?? '');
  }
}

class Bio102_w10 extends StatelessWidget {
  const Bio102_w10 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[10] ?? '');
  }
}

class Bio102_w11 extends StatelessWidget {
  const Bio102_w11 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[11] ?? '');
  }
}


class Bio102_w12 extends StatelessWidget {
  const Bio102_w12 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO102[12] ?? '');
  }
}