import 'dart:async';
import 'dart:developer';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/firebase_services.dart/auth.dart';
import 'package:futapedia/firebase_services.dart/user.dart';
import 'package:futapedia/notification/notification_controller.dart';
import 'package:futapedia/remote_config.dart/app_update.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:futapedia/settings/theme_provider.dart';
import 'package:futapedia/route.dart';
import 'package:futapedia/study_material/services/tab_nav.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:routemaster/routemaster.dart';
import 'package:screen_protector/screen_protector.dart';

Future<void> main() async {
  // Catch top-level errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log to crash analytics service
    FirebaseCrashlytics.instance.recordFlutterError(details);
  };
  
  // Set up zone to catch async errors
  runZonedGuarded(() async {
    // Initialize Flutter binding
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize scheduler notifications
    await initializeNotifications();
    
    // Initialize critical services first with proper error handling
    try {
      await Firebase.initializeApp();
      
      // Initialize Firebase App Check
      await FirebaseAppCheck.instance.activate(
        // For Android: Use Play Integrity provider
        androidProvider: AndroidProvider.debug,//playIntegrity,

        // For iOS: Use App Attest provider for iOS 14+ or DeviceCheck for earlier versions
        appleProvider: AppleProvider.debug,//appAttest,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Firebase Init Error');
    }
    
    // Initialize remaining services
    try {
      await Future.wait([
        _initializeSecurityFeatures(),
        Future(() => ThemeColorManager.initCachedColor())
            .timeout(const Duration(seconds: 3), onTimeout: () {
          return null; // Use default theme
        }),
      ]);
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Init Error');
    }
    
    await MobileAds.instance.initialize();
    
    runApp(MyApp());
  }, (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: 'Unhandled Error');
  });
}
// Add this notification initialization function
Future<void> initializeNotifications() async {
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'scheduled_channel',
        channelName: 'Scheduled Notifications',
        channelDescription: 'Channel for scheduled notifications',
        defaultColor: Colors.blue,
        ledColor: Colors.blue,
        importance: NotificationImportance.High,
        locked: false,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        soundSource: 'resource://raw/notification_sound',
        enableVibration: true,
      )
    ],
    debug: true,
  );
  
  // Register notification action handler
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onActionReceivedMethod,
  );
  
  // Check notification permissions (but don't prompt right away)
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    // We'll handle requesting permissions on the scheduler page
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
    // Design size with minimum width of 715
      designSize: const Size(700, 1024),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
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
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
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