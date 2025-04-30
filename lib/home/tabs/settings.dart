import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/ads/native_ad.dart';
import 'package:futapedia/firebase_services.dart/auth.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';
// Settings Page
class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the theme provider
    final themeColor = Provider.of<ThemeProvider>(context).themeColor;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.h),
          child: AppBar(
            title: Center(child: Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp))),
            backgroundColor: themeColor[700],
            foregroundColor: Colors.white,
            elevation: 0,
          ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile section
              Container(
                height: 65.h,
                padding: EdgeInsets.fromLTRB(20.w, 20.w, 10.w, 20.w),
                decoration: BoxDecoration(
                  color: themeColor[50],
                  borderRadius: BorderRadius.circular(25.r),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30.r,
                      backgroundImage: AssetImage("images/futapedia.jpg", ),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Scholar",
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Edit your profile",
                            style: TextStyle(fontSize: 15.sp, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.edit, size: 30.sp, color: Colors.black),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 25.h),
              
              Text(
                "Account Settings",
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4.h),
              
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
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4.h),
              
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
               style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4.h),
              
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
              
              SizedBox(height: 10.h),
              NativeAdWidget(adUnitType: AdUnitType.test),
              SizedBox(height: 10.h),
              
              // Logout button
              Container(
                width: double.infinity,
                height: 50.h,
                padding: EdgeInsets.symmetric(vertical: 3.h),
                child: ElevatedButton(
                  onPressed: () {
                    signOut(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "Log Out",
                      style: TextStyle(fontWeight: FontWeight.bold,fontSize: 17.sp),
                    ),
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
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.sp),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.grey[99],
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          borderRadius: BorderRadius.all(Radius.circular(30.r)),
        ),
        
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 24.sp),
            SizedBox(width: 20.sp),
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
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20.sp),
          ],
        ),
      ),
    );
  }
}// // Update the main app file to use NavigateScreen

