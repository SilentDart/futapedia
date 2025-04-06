import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:futapedia/firebase_services.dart/auth.dart';
import 'package:futapedia/firebase_services.dart/user.dart';
import 'package:futapedia/home%20pages/home/second_semester.dart';
import 'package:futapedia/home%20pages/home/first_semester.dart';
import 'package:futapedia/remote_config.dart/app_update.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:futapedia/route.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';
import 'package:screen_protector/screen_protector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  await MobileAds.instance.initialize(); // Initialize AdMob
  await ScreenProtector.preventScreenshotOn();
  await ScreenProtector.protectDataLeakageOn();
  await FirebaseQueryCacheSecondSemester.clearCache();
  await FirebaseQueryCacheFirstSemester.clearCache();
  ThemeColorManager.initCachedColor();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to handle both user auth and theme
    return MultiProvider(
      providers: [
        // Existing user authentication stream provider
        StreamProvider<Userdetails?>.value(
          value: AuthServices().userstream,
          initialData: null,
        ),
        // Add the new ThemeProvider
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadSavedTheme(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            // Apply the theme from provider
            theme: ThemeData(
              primarySwatch: themeProvider.themeColor,
              // Other theme configurations can go here
            ),
            routeInformationParser: RoutemasterParser(),
            routerDelegate: RoutemasterDelegate(
              routesBuilder: (context) => getAppRoutes(),
            ),
          );
        },
      ),
    );
  }
}

// Use this wrapper widget to check for updates
class UpdateCheckerWrapper extends StatefulWidget {
  final Widget child;
  
  const UpdateCheckerWrapper({Key? key, required this.child}) : super(key: key);
  
  @override
  _UpdateCheckerWrapperState createState() => _UpdateCheckerWrapperState();
}

class _UpdateCheckerWrapperState extends State<UpdateCheckerWrapper> {
  @override
  void initState() {
    super.initState();
    // Check for updates after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
  
  Future<void> _checkForUpdates() async {
    try {
      // Store the update status
      final updateChecker = await AppUpdateChecker.getInstance();
      final updateStatus = await updateChecker.checkForUpdate();
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      // Now it's safe to use context
      if (updateStatus.updateAvailable) {
        // Use a separate method to show the dialog to avoid context issue warnings
        _showUpdateDialog(updateStatus);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }
  
  void _showUpdateDialog(UpdateStatus updateStatus) {
    // This method uses context right away without async gaps
    showDialog(
      context: context,
      barrierDismissible: !updateStatus.forceUpdate,
      builder: (dialogContext) => UpdateDialog(
        updateStatus: updateStatus,
        onLaterPressed: () {
          // Handle 'Later' button press if needed
        },
      ),
    );
  }
}