import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/home/first_semester.dart';
import 'package:futapedia/home/home.dart';
import 'package:futapedia/home/second_semester.dart';
import 'package:futapedia/login%20pages/login.dart';
import 'package:futapedia/firebase_services.dart/get_semester.dart';
import 'package:futapedia/firebase_services.dart/user.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

// Create a splash/home wrapper component
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isLoading = true;
  String? semester;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadSemester();
  }

  void _loadSemester() async{
    Semester semesterInstance = Semester();
    String? result = await semesterInstance.checkSemester();
    setState(() {
      semester = result;
    });
  }

  Future<void> _initializeApp() async {
  // Start both operations in parallel
  final splashDelay = Future.delayed(Duration(seconds: 4));
  final adsInitialization = MobileAds.instance.initialize();
  
  // Wait for both to complete
  await Future.wait([splashDelay, adsInitialization]);
  
  if (mounted) {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<Userdetails?>(context);

    return _isLoading
        ? Scaffold(
            body: Center(
              child: Lottie.asset(
                'jsons/loading.json',
                width: 180.w,
                height: 180.h,
                fit: BoxFit.contain,
              ),
            ),
          )
        : (user == null) ? StudentLoginPage() : NavigateScreen(child: (semester =='First')? FirstSemester(): SecondSemester());
  }
}