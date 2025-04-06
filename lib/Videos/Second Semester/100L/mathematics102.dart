import 'package:flutter/material.dart';
import 'package:futapedia/templates/youtube_player.dart';



class Linklist{
  
  static Map<int, String> MTS102 = {
    1 : "http://www.youtube.com/watch?v=lGfsp2CWjok", //Definition of function of real variable
    2 : "http://www.youtube.com/watch?v=Air3gz2KabA", //Types of Functions
    3 : "http://www.youtube.com/watch?v=iXl25GfxDXw", //Graph of a Function of Real Variables
    4 : "https://www.youtube.com/watch?v=riXcZT2ICjA&list=PL19E79A0638C8D449&index=2&t=3s&pp=iAQB", // Introduction to Limit 1
    5 : "https://www.youtube.com/watch?v=W0VWO4asgmk&list=PL19E79A0638C8D449&index=3&pp=iAQB", //Introduction to Limit 2
    6 : "https://www.youtube.com/watch?v=GGQngIp0YGI&list=PL19E79A0638C8D449&index=4&pp=iAQB", //Limit example
    7 : "https://www.youtube.com/watch?v=YRw8udexH4o&list=PL19E79A0638C8D449&index=5&pp=iAQB", //Limit example 2
    8 : "https://www.youtube.com/watch?v=rkeU8_4nzKo&list=PL19E79A0638C8D449&index=10&pp=iAQB", //More on Limit
    9 : "https://www.youtube.com/watch?v=-ejyeII0i5c&list=PL19E79A0638C8D449&index=11&pp=iAQB", //Epsilon delta limit
    10 : "https://www.youtube.com/watch?v=Fdu5-aNJTzU&list=PL19E79A0638C8D449&index=12&pp=iAQB", //Epsilon delta limit 2
    11 : "https://www.youtube.com/watch?v=rAof9Ld5sOg&list=PL19E79A0638C8D449&index=17&pp=iAQB", //Derivative Overview
    12 : "https://www.youtube.com/watch?v=ay8838UZ4nM&list=PL19E79A0638C8D449&index=18&t=57s&pp=iAQB", //Derivative 2
    13 : "https://www.youtube.com/watch?v=XIQ-KnsAsbg&list=PL19E79A0638C8D449&index=20&pp=iAQB", //Chain rule
    14 : "https://www.youtube.com/watch?v=6_lmiPDedsY&list=PL19E79A0638C8D449&index=21&pp=iAQB", //Examples on Chain Rule
    15 : "https://www.youtube.com/watch?v=DYb-AN-lK94&list=PL19E79A0638C8D449&index=22&pp=iAQB", //More Example on Chain Rule
    16 : "https://www.youtube.com/watch?v=h78GdGiRmpM&list=PL19E79A0638C8D449&index=23&pp=iAQB", //Product Rule
    17 : "https://www.youtube.com/watch?v=E_1gEtiGPNI&list=PL19E79A0638C8D449&index=24&pp=iAQB", //Quotient Rule
    18 : "https://www.youtube.com/watch?v=WC5VYKI807Q", //Second Derivative
    19 : "https://www.youtube.com/watch?v=sL6MC-lKOrw&list=PL19E79A0638C8D449&index=32&pp=iAQB", //Implicit Differentiation 1
    20 : "https://www.youtube.com/watch?v=dIE22eL6q90&list=PL19E79A0638C8D449&index=43&pp=iAQB", //Inflection Points
    21 : "https://www.youtube.com/watch?v=tpHz0gZfVss&list=PL19E79A0638C8D449&index=42&pp=iAQB", //Maxima and Minima Slope
    22 : "https://www.youtube.com/watch?v=PdSzruR5OeE&list=PL19E79A0638C8D449&index=38&pp=iAQB", //Introduction to L'Hospital's Rule
    23 : "https://www.youtube.com/watch?v=BiVOC3WocXs&list=PL19E79A0638C8D449&index=39&pp=iAQB", //More on L'Hospital's Rule
    24 : "https://www.youtube.com/watch?v=FJo18AwLfuI&list=PL19E79A0638C8D449&index=40&pp=iAQB", //More Examples on Hospital's
    25 : "https://www.youtube.com/watch?v=MeVFZjT-ABM&list=PL19E79A0638C8D449&index=41&pp=iAQB", //More 
    26 : "https://www.youtube.com/watch?v=Zyq6TmQVBxk&list=PL19E79A0638C8D449&index=53&pp=iAQB", //Introduction to rate of change
    27 : "https://www.youtube.com/watch?v=1KwW1v__T_0&list=PL19E79A0638C8D449&index=54&pp=iAQB", //Equation of a Tangent Line
    28 : "https://www.youtube.com/watch?v=xmgk8_l3lig&list=PL19E79A0638C8D449&index=55&pp=iAQB", //Rate of change 2
    29 : "https://www.youtube.com/watch?v=hD3U65CcZ0Q&list=PL19E79A0638C8D449&index=56&pp=iAQB", //Rate of Change 3
    30 : "https://youtu.be/gbJAHMX80dY?si=FdHj3d2-HZee8WkQ", // Indefinite Integral
    31 : "https://youtu.be/ltHoDiANp2U?si=J2oWjV7fOIA4fzAQ", // Indefinite Integral 2
    32 : "https://youtu.be/PDkp2Mu66fo?si=CWSBPhvpTkDrflWE", //U substitution
    33 : "https://youtu.be/4oEVrV7AM74?si=BulDvDVAnuHwHG5_", //U substitution 2
    34 : "https://youtu.be/gX8BWiIGFkQ?si=QJiUAsP4J2iOEAdu", // Definite Integral 
    35 : "https://youtu.be/YbpU8HeIi2U?si=pH5bWUNp-oTOV3jz", //Definite Integral 2
    36 : "https://youtu.be/01ZAriWg97I?si=40Oo1AmDCV9uwZz6", //Integration by parts
    37 : "https://youtu.be/QK521aR1X3Y?si=I-8vZZfY4IHyGhHs", //Integration by parts 2 (Hard example)
    38 : "https://youtu.be/voARbUTBhxs?si=aLPV2B7p_6abWwYa", //Integral Trignometric 
    39 : "https://youtu.be/pgn-wCewSoA?si=bQ_kYLkhQowmqobU" //Integral Trignometric U Substitution 
  };
   
}

class Mts102_w1 extends StatelessWidget {
  const Mts102_w1({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[1] ?? '');
  }
}
class Mts102_w2 extends StatelessWidget {
  const Mts102_w2 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[2] ?? '');
  }
}
class Mts102_w3 extends StatelessWidget {
  const Mts102_w3 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[3] ?? '');
  }
}
class Mts102_w4 extends StatelessWidget {
  const Mts102_w4 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[4] ?? '');
  }
}
class Mts102_w5 extends StatelessWidget {
  const Mts102_w5 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[5] ?? '');
  }
}
class Mts102_w6 extends StatelessWidget {
  const Mts102_w6 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[6] ?? '');
  }
}
class Mts102_w7 extends StatelessWidget {
  const Mts102_w7 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[7] ?? '');
  }
}
class Mts102_w8 extends StatelessWidget {
  const Mts102_w8 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[8] ?? '');
  }
}
class Mts102_w9 extends StatelessWidget {
  const Mts102_w9 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[9] ?? '');
  }
}
class Mts102_w10 extends StatelessWidget {
  const Mts102_w10 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[10] ?? '');
  }
}
class Mts102_w11 extends StatelessWidget {
  const Mts102_w11 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[11] ?? '');
  }
}
class Mts102_w12 extends StatelessWidget {
  const Mts102_w12 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[12] ?? '');
  }
}
class Mts102_w13 extends StatelessWidget {
  const Mts102_w13 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[13] ?? '');
  }
}
class Mts102_w14 extends StatelessWidget {
  const Mts102_w14 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[14] ?? '');
  }
}
class Mts102_w15 extends StatelessWidget {
  const Mts102_w15 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[15] ?? '');
  }
}
class Mts102_w16 extends StatelessWidget {
  const Mts102_w16 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[16] ?? '');
  }
}
class Mts102_w17 extends StatelessWidget {
  const Mts102_w17 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[17] ?? '');
  }
}
class Mts102_w18 extends StatelessWidget {
  const Mts102_w18 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[18] ?? '');
  }
}
class Mts102_w19 extends StatelessWidget {
  const Mts102_w19 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[19] ?? '');
  }
}
class Mts102_w20 extends StatelessWidget {
  const Mts102_w20 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[20] ?? '');
  }
}
class Mts102_w21 extends StatelessWidget {
  const Mts102_w21 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[21] ?? '');
  }
}
class Mts102_w22 extends StatelessWidget {
  const Mts102_w22 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[22] ?? '');
  }
}
class Mts102_w23 extends StatelessWidget {
  const Mts102_w23 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[23] ?? '');
  }
}
class Mts102_w24 extends StatelessWidget {
  const Mts102_w24 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[24] ?? '');
  }
}
class Mts102_w25 extends StatelessWidget {
  const Mts102_w25 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[25] ?? '');
  }
}
class Mts102_w26 extends StatelessWidget {
  const Mts102_w26 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[26] ?? '');
  }
}
class Mts102_w27 extends StatelessWidget {
  const Mts102_w27 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[27] ?? '');
  }
}
class Mts102_w28 extends StatelessWidget {
  const Mts102_w28 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[28] ?? '');
  }
}
class Mts102_w29 extends StatelessWidget {
  const Mts102_w29 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[29] ?? '');
  }
}
class Mts102_w30 extends StatelessWidget {
  const Mts102_w30 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[30] ?? '');
  }
}
class Mts102_w31 extends StatelessWidget {
  const Mts102_w31 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[31] ?? '');
  }
}
class Mts102_w32 extends StatelessWidget {
  const Mts102_w32 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[32] ?? '');
  }
}
class Mts102_w33 extends StatelessWidget {
  const Mts102_w33 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[33] ?? '');
  }
}
class Mts102_w34 extends StatelessWidget {
  const Mts102_w34 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[34] ?? '');
  }
}
class Mts102_w35 extends StatelessWidget {
  const Mts102_w35 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[35] ?? '');
  }
}
class Mts102_w36 extends StatelessWidget {
  const Mts102_w36 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[36] ?? '');
  }
}
class Mts102_w37 extends StatelessWidget {
  const Mts102_w37 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[37] ?? '');
  }
}
class Mts102_w38 extends StatelessWidget {
  const Mts102_w38 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[38] ?? '');
  }
}
class Mts102_w39 extends StatelessWidget {
  const Mts102_w39 ({super.key});
  @override
  Widget build(BuildContext context) {
    return YouTubePlayerWidget(youtubeLink: Linklist.MTS102[39] ?? '');
  }
}