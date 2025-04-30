import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/home/tabs/settings.dart';
import 'package:futapedia/home/tabs/study.dart';
import 'package:futapedia/home/tabs/test.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:provider/provider.dart';

// Main app scaffold with bottom navigation
class NavigateScreen extends StatefulWidget {
  final Widget child;
  
  const NavigateScreen({Key? key, required this.child}) : super(key: key);

  @override
  State<NavigateScreen> createState() => _NavigateScreenState();
}

class _NavigateScreenState extends State<NavigateScreen> {
  int _currentIndex = 0;
  // ignore: unused_field
  MaterialColor _currentThemeColor = Colors.brown;
  late StreamSubscription<MaterialColor> _themeSubscription;
  

  @override
  void initState() {
    super.initState();
    _loadThemeColor();
    
    // Listen for theme changes
    _themeSubscription = ThemeChangeNotifier().themeStream.listen((color) {
      setState(() {
        _currentThemeColor = color;
      });
    });
  }
  
  @override
  void dispose() {
    _themeSubscription.cancel();
    super.dispose();
  }

  // Load initial theme color
  void _loadThemeColor() async {
    final color = await ThemeColorManager.getSavedColor();
    setState(() {
      _currentThemeColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Provider.of<ThemeProvider>(context).themeColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home page (your existing SecondSemester)
          widget.child,
          // Study page
          StudyResourcesPage(key: UniqueKey()),
          // Test page
          TestPage(key: UniqueKey()),
          // Settings page
          SettingsPage(key: UniqueKey()),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60.h,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12.r,
              spreadRadius: 0,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.r),
            topRight: Radius.circular(30.r),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: themeColor[600],
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp),
            unselectedLabelStyle: TextStyle(fontSize: 11.sp),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            iconSize: 26.r,
            items: [
              _buildNavItem(Icons.home_rounded, 'Dashboard', 0, themeColor),
              _buildNavItem(Icons.menu_book_rounded, 'Learn', 1, themeColor),
              _buildNavItem(Icons.assignment_rounded, 'Practice', 2, themeColor),
              _buildNavItem(Icons.person_rounded, 'Profile', 3, themeColor),
            ],
          ),
        ),
      ),
    );
  }
  
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index, MaterialColor themeColor) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: EdgeInsets.symmetric(vertical: 3.r),
        child: Icon(icon),
      ),
      activeIcon: Container(
        padding: EdgeInsets.symmetric(vertical: 3.r),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon),
            Positioned(
              bottom: -1.r,
              child: Container(
                width: 14.r,
                height: 2.r,
                decoration: BoxDecoration(
                  color: themeColor[600],
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),
          ],
        ),
      ),
      label: label,
    );
  }
}
