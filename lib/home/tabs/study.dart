import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';

class StudyResourcesPage extends StatelessWidget {
  const StudyResourcesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the theme provider (important: don't use listen: false here)
    final themeColor = Provider.of<ThemeProvider>(context).themeColor;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.h), // You can adjust this value as needed
        child: AppBar(
          title: Center(child: Text("Study Resources", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp))),
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
              // Header Section
              Center(
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: themeColor[100],
                    borderRadius: BorderRadius.circular(25.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enhanced Study Materials",
                        style: TextStyle(
                          fontSize: 20.sp, 
                          fontWeight: FontWeight.bold,
                          color: themeColor[800],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        "Access premium notes, practice questions and study guides to boost your academic performance.",
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: themeColor[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20.h),
              
              // Study Resources List
              Text(
                "   Available Resources",
                style: TextStyle(
                  fontSize: 20.sp, 
                  fontWeight: FontWeight.bold,
                  color: themeColor[800],
                ),
              ),
              SizedBox(height: 10.h),
              
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

              SizedBox(height: 20.h),
              
              // Premium Feature Section
              // Center(
              //   child: Container(
              //     padding: EdgeInsets.all(20.r),
              //     decoration: BoxDecoration(
              //       gradient: LinearGradient(
              //         colors: [Colors.amber[700]!, themeColor[700]!],
              //         begin: Alignment.topLeft,
              //         end: Alignment.bottomRight,
              //       ),
              //       borderRadius: BorderRadius.circular(25.r),
              //     ),
              //     child: Column(
              //       children: [
              //         Icon(Icons.workspace_premium, color: Colors.white, size: 40.sp),
              //         SizedBox(height: 10.h),
              //         Text(
              //           "Unlock Premium Features",
              //           style: TextStyle(
              //             color: Colors.white,
              //             fontSize: 18,
              //             fontWeight: FontWeight.bold,
              //           ),
              //         ),
              //         SizedBox(height: 10.h),
              //         Text(
              //           "Get access to all resources, past papers, and one-on-one tutoring sessions",
              //           textAlign: TextAlign.center,
              //           style: TextStyle(
              //             color: Colors.white,
              //             fontSize: 15.sp,
              //           ),
              //         ),
              //         SizedBox(height: 15.h),
              //         ElevatedButton(
              //           onPressed: () {
              //             // Premium subscription logic
              //           },
              //           style: ElevatedButton.styleFrom(
              //             backgroundColor: Colors.white,
              //             foregroundColor: themeColor[700],
              //             padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 12.h),
              //             shape: RoundedRectangleBorder(
              //               borderRadius: BorderRadius.circular(25.r),
              //             ),
              //           ),
              //           child: Text("Learn More"),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
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
        padding: EdgeInsets.all(20.w),
        margin: EdgeInsets.only(bottom: 15.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: Offset(0, 3),
              blurRadius: 5.r,
              spreadRadius: 2.r,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(5.r),
              decoration: BoxDecoration(
                color: Colors.brown[50],
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Icon(icon, color: color, size: 28.sp),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11.9.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

