import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;
import 'package:permission_handler/permission_handler.dart';

class ScheduledNotificationManager {
  static final ScheduledNotificationManager _instance = ScheduledNotificationManager._internal();
  factory ScheduledNotificationManager() => _instance;

  late SharedPreferences _prefs;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Constants for notification channels and IDs
  static const String scheduledChannelId = 'scheduled_notifications_channel';
  static const String scheduledChannelName = 'Scheduled Notifications';
  static const String scheduledChannelDescription = 'Daily scheduled notifications';
  static const int scheduledNotificationId = 1000;

  // Constants for preferences
  static const String prefNotificationTime = 'notification_time';
  static const String prefNotificationEnabled = 'notification_enabled';

  // Initialization flag
  bool _isInitialized = false;

  ScheduledNotificationManager._internal();

  // Check if already initialized
  bool get isInitialized => _isInitialized; // No await needed here

  Future<void> initialize() async {
    // Return early if already initialized
    if (_isInitialized) return;

    // Initialize shared preferences first
    _prefs = await SharedPreferences.getInstance();

    // Initialize timezone properly
    tz_init.initializeTimeZones();
    try {
      // Add error handling for timezone setting
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
      debugPrint("Timezone set to Africa/Lagos");
    } catch (e) {
      debugPrint("Error setting timezone: $e");
      // Fall back to local timezone if there's an issue
      tz.setLocalLocation(tz.local);
    }

    // Initialize notification plugin with proper channels
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Create Android notification channel explicitly
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        scheduledChannelId,
        scheduledChannelName,
        description: scheduledChannelDescription,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        playSound: true,
      );
      
      // Create the channel before initializing
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      requestCriticalPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _isInitialized = true;

    debugPrint("Notification manager initialized successfully");
  }

  // Future<bool> requestAlarmPermissions() async {
  //   if (Platform.isAndroid) {
  //     // For Android 12+
  //     if (await Permission.systemAlertWindow.isGranted) {
  //       return true;
  //     }
      
  //     final status = await Permission.systemAlertWindow.request();
  //     return status.isGranted;
  //   }
  //   return true; // Non-Android platforms don't need this
  // }

  // Check current permission status
  Future<bool> checkNotificationPermission() async {
    // Ensure initialization is done FIRST
    await initialize(); // <--- ADD THIS

    if (Platform.isAndroid) {
      if (await Permission.notification.isGranted) {
        return true;
      }
      return false;
    // } else if (Platform.isIOS) { // Assuming you might uncomment this later
    //   final hasRequestedBefore = _prefs.getBool('notification_permission_requested') ?? false;
    //   // Even if you don't use _prefs here now, adding initialize() is safer
    //   // if you modify this method later.
    //   // Also, the plugin check might depend on initialization too.
    //   return hasRequestedBefore;
    }
    return false; // Default case
  }

  // Request notification permission
  Future<bool> requestNotificationPermission() async {
    // Ensure initialization is done FIRST
    await initialize(); // <--- ADD THIS

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true, // Critical alerts require special entitlement
          ) ?? false;

      // Save that we've requested permission
      await _prefs.setBool('notification_permission_requested', true);
      return granted;
    }
    return false; // Default case
  }


  // Initialize notification manager and check/request permissions
  Future<bool> initializeWithPermissionCheck() async {
    // First initialize the plugin (this already checks _isInitialized)
    await initialize(); // Ensures _prefs and plugin are ready

    // Check if we have permission
    // checkNotificationPermission will now call initialize() again, but it will return quickly
    bool hasPermission = await checkNotificationPermission();
    if (!hasPermission) {
      // Request permission if not granted
      // requestNotificationPermission will now call initialize() again, but it will return quickly
      hasPermission = await requestNotificationPermission();
    }

    // If we have permission and notifications are enabled, schedule
    // isNotificationEnabled will call initialize() again, returning quickly
    if (hasPermission && isNotificationEnabled()) {
      // scheduleNotification will call initialize() again, returning quickly
      await scheduleNotification();
    }

    return hasPermission;
  }

  void _handleNotificationResponse(NotificationResponse response) {
     // Ensure initialization just in case this handler is called unexpectedly early
     // although usually it's called after init. Better safe than sorry.
     // No await needed if not accessing async resources initialized later
     // if (!_isInitialized) return; // Or await initialize(); if needed

    final String? payload = response.payload;
    if (payload == null) return;

    debugPrint('Notification Payload: $payload');
    // Add your navigation logic here
  }

  // Get the currently set notification time
  TimeOfDay getNotificationTime() {
    // IMPORTANT: This method cannot be async IF its return type is sync (TimeOfDay)
    // Ensure initialize() has been called BEFORE this method is invoked.
    // If that guarantee cannot be made, this method needs redesigning
    // (e.g., make it async, or pass _prefs to it).
    // Let's assume for now that callers ensure initialization first.
     if (!_isInitialized) {
       // This situation should ideally be avoided by calling initialize()
       // before calling getNotificationTime(). Throwing an error or returning
       // a default might be necessary if initialization isn't guaranteed.
       debugPrint("Warning: getNotificationTime called before initialization!");
       return const TimeOfDay(hour: 19, minute: 00); // Return default as fallback
     }

    final String? timeString = _prefs.getString(prefNotificationTime);
    if (timeString != null) {
      final parts = timeString.split(':');
      if (parts.length == 2) {
         try {
           return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
         } catch (e) {
            // Handle parsing error, return default
           debugPrint("Error parsing saved time: $e");
           return const TimeOfDay(hour: 8, minute: 0);
         }
      }
    }
    // Default to 8:00 AM if not set or invalid format
    return const TimeOfDay(hour: 8, minute: 0);
  }

  // Get whether notifications are enabled
  bool isNotificationEnabled() {
    // IMPORTANT: Like getNotificationTime, this is synchronous.
    // Ensure initialize() has been called BEFORE this method is invoked.
     if (!_isInitialized) {
       debugPrint("Warning: isNotificationEnabled called before initialization!");
       return false; // Return default as fallback
     }
    return _prefs.getBool(prefNotificationEnabled) ?? false;
  }

  // Set notification time and enable/disable
  Future<void> setNotificationTime(TimeOfDay time, {bool enabled = true}) async {
    // Ensure initialization is done FIRST
    await initialize(); // <--- Already correctly placed here

    // Save preferences
    await _prefs.setString(prefNotificationTime, '${time.hour}:${time.minute}');
    await _prefs.setBool(prefNotificationEnabled, enabled);

    // Check permission before scheduling
    final hasPermission = await checkNotificationPermission(); // Will await initialize() again internally

    if (enabled && hasPermission) {
      // Schedule notification with new time if we have permission
      await scheduleNotification(); // Will await initialize() again internally
    } else if (!enabled) {
      // Cancel scheduled notification if disabled
      await cancelScheduledNotification(); // Will await initialize() again internally
    }

    // No return needed for void Future
  }

  // Schedule the daily notification based on saved time
  // Schedule the daily notification based on saved time
  Future<void> scheduleNotification() async {
    // Ensure initialization is done FIRST
     await initialize();

    // Add this debug statement
    debugPrint("Starting schedule notification process...");

    // Now it's safe to call isNotificationEnabled
    if (!isNotificationEnabled()) {
      debugPrint("Notifications are disabled, not scheduling");
      return;
    }

    // Check notification permission before scheduling
    final hasNotificationPermission = await checkNotificationPermission();
    if (!hasNotificationPermission) {
      debugPrint("No notification permission, cannot schedule");
      return;
    }

    // Check alarm permission on Android and add verbose logging
    if (Platform.isAndroid) {
      final hasAlarmPermission = await Permission.scheduleExactAlarm.isGranted;
      debugPrint("Exact alarm permission status: $hasAlarmPermission");
      if (!hasAlarmPermission) {
        debugPrint("❌ No alarm permission, cannot schedule exact alarms");
        return;
      }
    }

    // Get the notification time
    final TimeOfDay notificationTime = getNotificationTime();
    debugPrint("Scheduling notification for ${notificationTime.hour}:${notificationTime.minute}");

    // Create the notification details
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      scheduledChannelId,
      scheduledChannelName,
      channelDescription: scheduledChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      category: AndroidNotificationCategory.reminder,
      // For Android 12+, ensure we have alarm permission
      fullScreenIntent: true,
    );

    final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Calculate the time to schedule
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    debugPrint("Current time: $now");
    debugPrint("Current timezone: ${tz.local}");
    
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      notificationTime.hour,
      notificationTime.minute,
      0, // Seconds parameter for precision
    );

    debugPrint("Initial scheduled date: $scheduledDate");

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      debugPrint("Time already passed today, rescheduled for tomorrow: $scheduledDate");
    }

    // Cancel any existing one first to prevent duplicates
    await _notificationsPlugin.cancel(scheduledNotificationId);
    debugPrint("Cancelled any existing scheduled notifications");

    try {
      // Schedule the daily notification
      await _notificationsPlugin.zonedSchedule(
        scheduledNotificationId,
        'Futapedia Daily Reminder', 
        'Time to check out your study materials!',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'scheduled:daily',
      );
      debugPrint("✓ Notification successfully scheduled for: $scheduledDate");
      
      // Add this to verify the scheduling worked
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();
      debugPrint("Number of pending notifications after scheduling: ${pendingNotifications.length}");
      for (var notification in pendingNotifications) {
        debugPrint("Pending notification ID: ${notification.id}, Title: ${notification.title}");
      }
    } catch (e) {
      debugPrint("❌ Error scheduling notification: $e");
    }
  }

  // Check if we have permission to schedule exact alarms (Android 12+)
  Future<bool> checkAlarmPermission() async {
    if (Platform.isAndroid) {
      return await Permission.scheduleExactAlarm.isGranted;
    }
    return true; // iOS doesn't need this specific permission
  }

  // Request permission to schedule exact alarms (Android 12+)
  Future<bool> requestAlarmPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.request();
      return status.isGranted;
    }
    return true; // iOS doesn't need this specific permission
  }

  // Cancel the scheduled notification
  Future<void> cancelScheduledNotification() async {
    // Ensure initialization is done FIRST
    await initialize(); // <--- ADD THIS

    await _notificationsPlugin.cancel(scheduledNotificationId);
     debugPrint("Cancelled scheduled notification ($scheduledNotificationId)");
  }

  // Method to display a one-time immediate notification (for testing)
  Future<void> showTestNotification() async {
    // Ensure initialization is done FIRST
    await initialize(); // <--- Already correctly placed here

    // Check permission before sending test notification
    final hasPermission = await checkNotificationPermission(); // Safe now
    if (!hasPermission) {
      final granted = await requestNotificationPermission(); // Safe now
      if (!granted) {
         debugPrint("Permission denied, cannot show test notification.");
        return; // Can't show notification without permission
      }
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      scheduledChannelId, // Use the same channel
      scheduledChannelName,
      channelDescription: scheduledChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // sound: RawResourceAndroidNotificationSound('notification_sound'), // Optional: Add sound for test too
    );

    final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        // sound: 'notification_sound.aiff', // Optional: Add sound for test too
      );


    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails
    );

    await _notificationsPlugin.show(
      scheduledNotificationId + 1, // Use a different ID for test notification
      'Test Notification',
      'This is a test notification from ScheduledNotificationManager',
      notificationDetails,
      payload: 'scheduled:test',
    );
    debugPrint("Test notification shown.");
  }

  // Dispose is not standard in Dart singletons like this,
  // but if you needed cleanup, you'd check initialization.
  // void dispose() {
  //   if (_isInitialized) {
  //      _notificationsPlugin.cancel(scheduledNotificationId); // Example cleanup
  //   }
  // }
}