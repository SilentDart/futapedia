import 'package:flutter/material.dart';
import 'package:futapedia/templates/youtube_player.dart';


class Linklist{
  
  static Map<int, String> MTS104 = {
    1: "https://www.youtube.com/watch?v=uO4b3Bjhncw&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=1&pp=iAQB", // Magnitude of a Vector
    2: "https://www.youtube.com/watch?v=FZgBy1KjuR8&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=2&pp=iAQB", // Unit Vector
    3: "https://www.youtube.com/watch?v=aa7jS3o8W40&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=3&pp=iAQB", // Resultant Vector
    4: "https://www.youtube.com/watch?v=ZsxS23idEBM&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=4&pp=iAQB", // Direction Cosines of Vectors
    5: "https://www.youtube.com/watch?v=OjCgutGQNwk&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=5&pp=iAQB", // Dot Product of Vectors
    6: "https://www.youtube.com/watch?v=0ksz3E84Lyo&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=6&pp=iAQB", // Orthogonal and Perpendicular Vectors
    7: "https://www.youtube.com/watch?v=ve6YIn3fPfw&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=7&pp=iAQB", // Cross Product of Vectors
    8: "https://www.youtube.com/watch?v=QNXX4LbwkX4&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=8&pp=iAQB", // Triple Scalar Product of Vectors
    9: "https://www.youtube.com/watch?v=dxNfM2BqWps&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=9&pp=iAQB", // Equation of a Circle
    10: "https://www.youtube.com/watch?v=_81NspoFQH4&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=10&pp=iAQB", // Radius and Center of Circle
    11: "https://www.youtube.com/watch?v=rZyx4NIAaac&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=11&pp=iAQB", // General Equation of Circle
    12: "https://www.youtube.com/watch?v=XUus6-9E9sQ&list=PLD65dwM-N37lWwjWtWbSNRN3S04o3hhH5&index=2&pp=iAQB", // Circle Theorem
    13: "https://www.youtube.com/watch?v=uwBRVi_EtVY&list=PLup5FurE4zgpgasUavLgyd-9K9eZVgHF8&index=12&pp=iAQB", // Length of Tangent from a Point to a Circle
    14: "https://www.youtube.com/watch?v=hJRTY80yDT4&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=5&pp=iAQB", // Convert Circle to Standard Form
    15: "https://www.youtube.com/watch?v=iK5bEjQp7Ig&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=6&pp=iAQB", // Find Circle Equation
    16: "https://www.youtube.com/watch?v=sOm9D6GQ9W8&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=7&pp=iAQB", // Circle Equation From Tangent
    17: "https://youtu.be/vzW1wv0s4z0?si=JenESJZjEmd1XKu4", // Conic Sections and Circles
    18: "https://www.youtube.com/watch?v=vzW1wv0s4z0&t=52s", // Conic Sections And Circles 2
    19: "https://www.youtube.com/watch?v=2rV9GmDBvbY", // Conic Sections - Ellipses
    20: "https://www.youtube.com/watch?v=n0HC1eP4pNk&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=1&pp=iAQB", // Parabola Directrix Focus 1
    21: "https://www.youtube.com/watch?v=m7q8586NXlA&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=2&pp=iAQB", // Parabola Directrix Focus 2
    22: "https://www.youtube.com/watch?v=Z_xyX3NgQPA&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=3&pp=iAQB", // Given Focus and Vertex Find Equation
    23: "https://www.youtube.com/watch?v=bzyDmhv7XD8", // Conic Sections Hyperbolas
    24: "https://www.youtube.com/watch?v=_IHYpB0XgGQ&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=12&pp=iAQB", // Graph Hyperbola
    25: "https://www.youtube.com/watch?v=YMv9hsF7ZmM&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=13&pp=iAQB", // Hyperbola Equation Conic Sections
    26: "https://www.youtube.com/watch?v=T4ZCzsoMu6Y&list=PLU_DCVXL8MyMUfkoSP9tlhUZ2ZRm9IOoG&index=14&pp=iAQB", // Hyperbola General to Standard
  };
} 

class Mts104_w1 extends StatelessWidget {
  const Mts104_w1({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[1] ?? '');
  }
}

class Mts104_w2 extends StatelessWidget {
  const Mts104_w2({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[2] ?? '');
  }
}

class Mts104_w3 extends StatelessWidget {
  const Mts104_w3({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[3] ?? '');
  }
}

class Mts104_w4 extends StatelessWidget {
  const Mts104_w4({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[4] ?? '');
  }
}

class Mts104_w5 extends StatelessWidget {
  const Mts104_w5({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[5] ?? '');
  }
}

class Mts104_w6 extends StatelessWidget {
  const Mts104_w6({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[6] ?? '');
  }
}

class Mts104_w7 extends StatelessWidget {
  const Mts104_w7({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[7] ?? '');
  }
}

class Mts104_w8 extends StatelessWidget {
  const Mts104_w8({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[8] ?? '');
  }
}

class Mts104_w9 extends StatelessWidget {
  const Mts104_w9({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[9] ?? '');
  }
}

class Mts104_w10 extends StatelessWidget {
  const Mts104_w10({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[10] ?? '');
  }
}

class Mts104_w11 extends StatelessWidget {
  const Mts104_w11({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[11] ?? '');
  }
}

class Mts104_w12 extends StatelessWidget {
  const Mts104_w12({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[12] ?? '');
  }
}

class Mts104_w13 extends StatelessWidget {
  const Mts104_w13({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[13] ?? '');
  }
}

class Mts104_w14 extends StatelessWidget {
  const Mts104_w14({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[14] ?? '');
  }
}

class Mts104_w15 extends StatelessWidget {
  const Mts104_w15({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[15] ?? '');
  }
}

class Mts104_w16 extends StatelessWidget {
  const Mts104_w16({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[16] ?? '');
  }
}

class Mts104_w17 extends StatelessWidget {
  const Mts104_w17({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[17] ?? '');
  }
}

class Mts104_w18 extends StatelessWidget {
  const Mts104_w18({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[18] ?? '');
  }
}

class Mts104_w19 extends StatelessWidget {
  const Mts104_w19({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[19] ?? '');
  }
}

class Mts104_w20 extends StatelessWidget {
  const Mts104_w20({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[20] ?? '');
  }
}

class Mts104_w21 extends StatelessWidget {
  const Mts104_w21({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[21] ?? '');
  }
}

class Mts104_w22 extends StatelessWidget {
  const Mts104_w22({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[22] ?? '');
  }
}

class Mts104_w23 extends StatelessWidget {
  const Mts104_w23({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[23] ?? '');
  }
}

class Mts104_w24 extends StatelessWidget {
  const Mts104_w24({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[24] ?? '');
  }
}

class Mts104_w25 extends StatelessWidget {
  const Mts104_w25({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[25] ?? '');
  }
}

class Mts104_w26 extends StatelessWidget {
  const Mts104_w26({super.key});

  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS104[26] ?? '');
  }
}
