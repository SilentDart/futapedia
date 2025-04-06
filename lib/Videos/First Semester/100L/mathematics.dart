import 'package:flutter/material.dart';
import 'package:futapedia/templates/youtube_player.dart';



class Linklist{
  
  static Map<int, String> MTS101 = {
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



class Mtsw1 extends StatelessWidget {
  const Mtsw1({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[1] ?? '');
  }
}



class Mtsw2 extends StatelessWidget {
  const Mtsw2 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[2] ?? '');
  }
}


class Mtsw3 extends StatelessWidget {
  const Mtsw3 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[3] ?? '');
  }
}


class Mtsw4 extends StatelessWidget {
  const Mtsw4 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[4] ?? '');
  }
}


class Mtsw5 extends StatelessWidget {
  const Mtsw5 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[5] ?? '');
  }
}


class Mtsw6 extends StatelessWidget {
  const Mtsw6 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[6] ?? '');
  }
}


class Mtsw7 extends StatelessWidget {
  const Mtsw7 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[7] ?? '');
  }
}


class Mtsw8 extends StatelessWidget {
  const Mtsw8 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[8] ?? '');
  }
}


class Mtsw9 extends StatelessWidget {
  const Mtsw9 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[9] ?? '');
  }
}

class Mtsw10 extends StatelessWidget {
  const Mtsw10 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[10] ?? '');
  }
}

class Mtsw11 extends StatelessWidget {
  const Mtsw11 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[11] ?? '');
  }
}


class Mtsw12 extends StatelessWidget {
  const Mtsw12 ({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS101[12] ?? '');
  }
}