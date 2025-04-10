import 'dart:async';
import 'package:flutter/material.dart';
import 'package:futapedia/ads/native_ad.dart';
import 'package:futapedia/firebase_services.dart/auth.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:futapedia/test.dart/saved_test_result.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';

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
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: themeColor[700],
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontSize: 12),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            items: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.book, 'Study', 1),
              _buildNavItem(Icons.quiz, 'Test', 2),
              _buildNavItem(Icons.settings, 'Settings', 3),
            ],
          ),
        ),
      ),
    );
  }
  
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(isSelected ? 8.0 : 4.0),
        child: Icon(
          icon,
          size: isSelected ? 25.0 : 20.0,
        ),
      ),
      label: label,
    );
  }
}



class StudyResourcesPage extends StatelessWidget {
  const StudyResourcesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the theme provider (important: don't use listen: false here)
    final themeColor = Provider.of<ThemeProvider>(context).themeColor;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(child: Text("Study Resources")),
        backgroundColor: themeColor[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enhanced Study Materials",
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: themeColor[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Access premium notes, practice questions and study guides to boost your academic performance.",
                      style: TextStyle(
                        fontSize: 16,
                        color: themeColor[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30),
              
              // Study Resources List
              Text(
                "Available Resources",
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 15),
              
              // Resource Items
              _buildResourceItem(
                icon: Icons.note_alt,
                color: themeColor,
                title: "Premium Lecture Notes",
                description: "Comprehensive notes with explanations and examples",
                onTap: () => Routemaster.of(context).push("/google_drive"),
              ),
              
              _buildResourceItem(
                icon: Icons.quiz,
                color: themeColor,
                title: "Past Questions",
                description: "Test your knowledge with our extensive question bank",
                onTap: () => Routemaster.of(context).push("/google_past_questions"),
              ),
              
              _buildResourceItem(
                icon: Icons.download_done_rounded,
                color: themeColor,
                title: "All Downloads",
                description: "Access all downloads here",
                onTap: () => Routemaster.of(context).push("/all_downloads"),
              ),

              SizedBox(height: 20),
              
              // Premium Feature Section
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[700]!, themeColor[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.white, size: 40),
                      SizedBox(height: 10),
                      Text(
                        "Unlock Premium Features",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Get access to all resources, past papers, and one-on-one tutoring sessions",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          // Premium subscription logic
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: themeColor[700],
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text("Learn More"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required MaterialColor color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15),
        margin: EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: Offset(0, 3),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.brown[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
// Test Page (based on your SponsoredCourseCard)
class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // Add a key to force FutureBuilder refresh
  Key _futureBuilderKey = UniqueKey();
  
  // Method to refresh the recent tests
  void refreshRecentTests() {
    setState(() {
      _futureBuilderKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the theme provider
    final themeColor = Provider.of<ThemeProvider>(context).themeColor;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(child: Text("Practice Tests")),
        backgroundColor: themeColor[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor[400]!, themeColor[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "Practice Tests",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: Text(
                        "Test your knowledge and prepare for your exams with our comprehensive practice tests",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                   
                  ],
                ),
              ),
              
              SizedBox(height: 25),
              
              // Test Categories
              Text(
                "Test Categories",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 15),
              
              // Grid of test categories
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildTestCategory(
                    context: context,
                    title: "100 Level",
                    icon: Icons.looks_one,
                    color: Colors.blue[700]!,
                    route: "/test?url=${Uri.encodeComponent('100L')}",
                  ),
                  _buildTestCategory(
                    context: context, 
                    title: "200 Level",
                    icon: Icons.looks_two,
                    color: Colors.green[700]!,
                    route: "/test?url=${Uri.encodeComponent('200L')}",
                  ),
                  _buildTestCategory(
                    context: context,
                    title: "300 Level",
                    icon: Icons.timer,
                    color: Colors.orange[700]!,
                    route: "/test/url=${Uri.encodeComponent('300L')}",
                  ),
                  _buildTestCategory(
                    context: context,
                    title: "Past Questions",
                    icon: Icons.history_edu,
                    color: Colors.purple[700]!,
                    route: "/test/past",
                  ),
                ],
              ),
              
              SizedBox(height: 25),
              
              // Recent Tests
              Text(
                "Recent Test Activity",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 15),
              
              // List of recent tests
              FutureBuilder<List<TestResult>>(
                key: _futureBuilderKey,
                future: RecentTestsManager.getRecentTests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No recent test activity"),
                    );
                  }
                  
                  // Display the test results
                  return Column(
                    children: List.generate(snapshot.data!.length, (index) {
                      final result = snapshot.data![index];
                      // Alternate colors: green for even indices, orange for odd
                      final Color iconColor = index % 2 == 0 ? Colors.green : Colors.orange;
                      
                      return _buildRecentTestItem(
                        title: result.title,
                        score: result.score,
                        date: result.date,
                        iconColor: iconColor,
                      );
                    }),
                  );
                },
              ),
              
              SizedBox(height: 12.5),
              NativeAdWidget(adUnitType: AdUnitType.test),
              SizedBox(height: 12.5),
              
              // Ad Banner
              Container(
                margin: EdgeInsets.symmetric(vertical: 25),
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.grey[600], size: 30),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "Upgrade to premium for ad-free experience",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text("Go Pro"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestCategory({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Routemaster.of(context).push(route),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 27),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTestItem({
    required String title,
    required String score,
    required String date,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(15),
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_outlined, color: iconColor),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Completed on $date",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              score,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Page
class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the theme provider
    final themeColor = Provider.of<ThemeProvider>(context).themeColor;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: themeColor[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage("images/futapedia.jpg"),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Scholar",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Edit your profile",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.edit, color: Colors.black),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 25),
              
              Text(
                "Account Settings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              
              _buildSettingsItem(
                icon: Icons.person_outline,
                title: "Personal Information",
                subtitle: "Update your personal details",
                onTap: () {},
              ),
              
              _buildSettingsItem(
                icon: Icons.lock_outline,
                title: "Security",
                subtitle: "Change password and security settings",
                onTap: () {},
              ),
              
              _buildSettingsItem(
                icon: Icons.notifications_outlined,
                title: "Notifications",
                subtitle: "Manage notification preferences",
                onTap: () {
                  Routemaster.of(context).push('/notifications');
                },
              ),
              
              SizedBox(height: 12.5),
              NativeAdWidget(adUnitType: AdUnitType.setting),
              SizedBox(height: 12.5),

              Text(
                "App Settings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              
              _buildSettingsItem(
                icon: Icons.palette_outlined,
                title: "Appearance",
                subtitle: "Change theme and display settings",
                onTap: () {
                  Routemaster.of(context).push('/theme');
                }
              ),
              
              _buildSettingsItem(
                icon: Icons.download_outlined,
                title: "Download Settings",
                subtitle: "Manage offline content and downloads",
                onTap: () {},
              ),
              
              _buildSettingsItem(
                icon: Icons.language,
                title: "Language",
                subtitle: "Change language preferences",
                onTap: () {},
              ),
              
              SizedBox(height: 12.5),
              NativeAdWidget(adUnitType: AdUnitType.setting),
              SizedBox(height: 12.5),
              
              Text(
                "Support",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              
              _buildSettingsItem(
                icon: Icons.help_outline,
                title: "Help Center",
                subtitle: "Find answers to common questions",
                onTap: () {},
              ),
              
              _buildSettingsItem(
                icon: Icons.feedback_outlined,
                title: "Feedback",
                subtitle: "Share your thoughts and suggestions",
                onTap: () {},
              ),
              
              _buildSettingsItem(
                icon: Icons.info_outline,
                title: "About",
                subtitle: "App version and information",
                onTap: () {},
              ),
              
              SizedBox(height: 10),
              NativeAdWidget(adUnitType: AdUnitType.test),
              SizedBox(height: 10),
              
              // Logout button
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 5),
                child: ElevatedButton(
                  onPressed: () {
                    signOut(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Log Out",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 24),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}// // Update the main app file to use NavigateScreen

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp.router(
//       title: 'Futapedia',
//       theme: ThemeData(
//         primarySwatch: Colors.brown,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       routerDelegate: RoutemasterDelegate(
//         routesBuilder: (context) => RouteMap(
//           routes: {
//             '/': (_) => MaterialPage(child: NavigateScreen(child: SecondSemester())),
//             '/google_drive': (_) => MaterialPage(child: NavigateScreen(child: StudyResourcesPage())),
//             '/google_drive/notes': (_) => MaterialPage(child: PlaceholderPage(title: "Premium Lecture Notes")),
//             '/google_drive/questions': (_) => MaterialPage(child: PlaceholderPage(title: "Practice Questions")),
//             '/google_drive/videos': (_) => MaterialPage(child: PlaceholderPage(title: "Video Tutorials")),
//             '/google_drive/references': (_) => MaterialPage(child: PlaceholderPage(title: "Reference Materials")),
//             '/test/100L': (_) => MaterialPage(child: SubjectSelectionPage()),
//             '/test/200L': (_) => MaterialPage(child: PlaceholderPage(title: "200 Level Tests")),
//             '/test/quiz': (_) => MaterialPage(child: PlaceholderPage(title: "Quick Quiz")),
//             '/test/past': (_) => MaterialPage(child: PlaceholderPage(title: "Past Questions")),
//             // Add routes for all your course pages here using the format you defined in SecondSemester
//           },
//         ),
//       ),
//       routeInformationParser: RoutemasterParser(),
//     );
//   }
// }

// // Simple placeholder page for routes that are not yet implemented
// class PlaceholderPage extends StatelessWidget {
//   final String title;
  
//   const PlaceholderPage({Key? key, required this.title}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(title),
//         backgroundColor: Colors.brown[700],
//         foregroundColor: Colors.white,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.construction, size: 80, color: Colors.brown[300]),
//             SizedBox(height: 20),
//             Text(
//               "Coming Soon",
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 10),
//             Text(
//               "This feature is under development.",
//               style: TextStyle(color: Colors.grey[600]),
//             ),
//             SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text("Go Back"),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.brown[700],
//                 foregroundColor: Colors.white,
//                 padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }