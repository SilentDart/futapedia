import 'dart:async';
import 'dart:developer';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:futapedia/firebase_services.dart/auth.dart';
import 'package:futapedia/firebase_services.dart/user.dart';
import 'package:futapedia/remote_config.dart/app_update.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:futapedia/route.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';
import 'package:screen_protector/screen_protector.dart';

void main() async {
  // Catch top-level errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log to crash analytics service
    FirebaseCrashlytics.instance.recordFlutterError(details);
  };

  // Set up zone to catch async errors
  runZonedGuarded(() async {
    // Initialize Flutter binding
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize critical services first with proper error handling
    try {
      await Firebase.initializeApp();
    } catch (e, stackTrace) {
      // log('Firebase initialization failed', error: e, stackTrace: stackTrace);
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Firebase Init Error');
      // Show graceful fallback or disable Firebase-dependent features
    }
    
    // Initialize remaining services
    try {
      await Future.wait([

        // MobileAds.instance.initialize().catchError((e, stackTrace) {

        //   // log('Ad initialization failed', error: e, stackTrace: stackTrace);
          
        //   FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Ads Init Error');
        //   return InitializationStatus({}); // Continue initialization process despite ads failure
          
        // }),

        _initializeSecurityFeatures(),

        Future(() => ThemeColorManager.initCachedColor())
            .timeout(const Duration(seconds: 3), onTimeout: () {
          // log('Theme initialization timed out, using defaults');
          return null; // Use default theme
        }),
      ]);
    } catch (e, stackTrace) {

      // log('Non-critical initialization error', error: e, stackTrace: stackTrace);

      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Init Error');
      // Continue with app launch
    }
    await MobileAds.instance.initialize();
    // Cache clearing can be deferred until after app launch
    // _clearCachesIfNeeded();
    
    runApp(MyApp());
    
  }, (error, stackTrace) {
    // Handle exceptions thrown outside of the Flutter framework
    // log('Unhandled error', error: error, stackTrace: stackTrace);
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: 'Unhandled Error');
  });
}

Future<void> _initializeSecurityFeatures() async {
  try {
    await Future.wait([
      ScreenProtector.preventScreenshotOn(),
      ScreenProtector.protectDataLeakageOn(),
    ]);
  } catch (e, stackTrace) {
    log('Security features initialization failed', error: e, stackTrace: stackTrace);
    FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Security Init Error');
    // Could display a warning to the user that security features are limited
  }
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
  
  const UpdateCheckerWrapper({super.key, required this.child});
  
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