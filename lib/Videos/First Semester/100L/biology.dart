import 'package:flutter/material.dart';
import 'package:futapedia/templates/youtube_player.dart';



class Linklist{
  
  static Map<int, String> BIO101 = {
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



class Biow1 extends StatelessWidget {
  const Biow1({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[1] ?? '');
  }
}



class Biow2 extends StatelessWidget {
  const Biow2 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[2] ?? '');
  }
}


class Biow3 extends StatelessWidget {
  const Biow3 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[3] ?? '');
  }
}


class Biow4 extends StatelessWidget {
  const Biow4 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[4] ?? '');
  }
}


class Biow5 extends StatelessWidget {
  const Biow5 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[5] ?? '');
  }
}


class Biow6 extends StatelessWidget {
  const Biow6 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[6] ?? '');
  }
}


class Biow7 extends StatelessWidget {
  const Biow7 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[7] ?? '');
  }
}


class Biow8 extends StatelessWidget {
  const Biow8 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[8] ?? '');
  }
}


class Biow9 extends StatelessWidget {
  const Biow9 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[9] ?? '');
  }
}

class Biow10 extends StatelessWidget {
  const Biow10 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[10] ?? '');
  }
}

class Biow11 extends StatelessWidget {
  const Biow11 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[11] ?? '');
  }
}


class Biow12 extends StatelessWidget {
  const Biow12 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.BIO101[12] ?? '');
  }
}