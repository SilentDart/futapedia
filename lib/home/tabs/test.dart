import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/ads/native_ad.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:futapedia/test.dart/saved_test_result.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';

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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.h),
        child: AppBar(
          title: Center(child: Text("Practice Tests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp))),
          backgroundColor: themeColor[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(25.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor[400]!, themeColor[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "Practice Tests",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Center(
                      child: Text(
                        "Test your knowledge and prepare for your exams with our comprehensive practice tests",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 15.h),
                   
                  ],
                ),
              ),
              
              SizedBox(height: 20.h),
              
              // Test Categories
              Text(
                "Test Categories",
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: themeColor[800],
                ),
              ),
              SizedBox(height: 10.h),
              
              // Grid of test categories
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 30.w,
                mainAxisSpacing: 30.h,
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
              
              SizedBox(height: 25.h),
              
              // Recent Tests
              Text(
                "Recent Test Activity",
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: themeColor[900],
                ),
              ),
              SizedBox(height: 15.h),
              
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
                      padding: EdgeInsets.all(13.r),
                      child: Text("No recent test activity", style: TextStyle(color: Colors.black, fontSize: 14.sp),),
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
              
              SizedBox(height: 9.r),
              NativeAdWidget(adUnitType: AdUnitType.test),
              SizedBox(height: 9.r),
              NativeAdWidget(adUnitType: AdUnitType.test)
              
              // Ad Banner
              // Container(
              //   margin: EdgeInsets.symmetric(vertical: 20.r),
              //   padding: EdgeInsets.all(10.r),
              //   decoration: BoxDecoration(
              //     color: Colors.grey[100],
              //     borderRadius: BorderRadius.circular(12.r),
              //     border: Border.all(color: Colors.grey[300]!),
              //   ),
              //   child: Row(
              //     children: [
              //       Icon(Icons.campaign, color: Colors.grey[600], size: 30),
              //       SizedBox(width: 15.w),
              //       Expanded(
              //         child: Text(
              //           "Upgrade to premium for ad-free experience",
              //           style: TextStyle(color: Colors.grey[700], fontSize: 14.sp),
              //         ),
              //       ),
              //       TextButton(
              //         onPressed: () {},
              //         child: Text("Go Pro"),
              //       ),
              //     ],
              //   ),
              // ),
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
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20.sp),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16.sp
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
      padding: EdgeInsets.all(12.r),
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_outlined, color: iconColor),
          ),
          SizedBox(width: 12.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                ),
                Text(
                  "Completed on $date",
                  style: TextStyle(color: Colors.grey[600], fontSize: 10.sp),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.r),
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

