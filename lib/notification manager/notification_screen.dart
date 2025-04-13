import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:futapedia/notification%20manager/schedule_ntfn.dart'; // Make sure path is correct
// import 'package:permission_handler/permission_handler.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final ScheduledNotificationManager _notificationManager = ScheduledNotificationManager();
  
  // Use nullable types initially or defaults until loaded
  TimeOfDay? _selectedTime;
  bool? _notificationsEnabled;
  bool _isLoading = true; // Add a loading state
  
  // Permission states
  bool _hasNotificationPermission = false;
  bool _hasAlarmPermission = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings(); // Call the async loading method
  }

  void _verifyScheduledNotifications() {
    // Get the pending notifications to verify
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    plugin.pendingNotificationRequests().then((pendingNotifications) {
      if (pendingNotifications.isEmpty) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No scheduled notifications found')),
        );
      } else {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pendingNotifications.length} notifications scheduled')),
        );
      }
    });
  }
  

  // New async method to check and request permissions
  // Future<void> _checkAndRequestPermissions() async {
  //   // Previous implementation - keep this method for button presses and user-initiated requests
  //   // Check notification permission
  //   bool notificationPermission = await _notificationManager.checkNotificationPermission();
    
  //   // If no notification permission, request it
  //   if (!notificationPermission) {
  //     notificationPermission = await _notificationManager.requestNotificationPermission();
  //   }
    
  //   // Check alarm permission (Android only)
  //   bool alarmPermission = true;
  //   if (Platform.isAndroid) {
  //     alarmPermission = await _notificationManager.checkAlarmPermission();
      
  //     // If no alarm permission, request it
  //     if (!alarmPermission) {
  //       alarmPermission = await _notificationManager.requestAlarmPermission();
  //     }
  //   }
    
  //   // Update state with permission results
  //   if (mounted) {
  //     setState(() {
  //       _hasNotificationPermission = notificationPermission;
  //       _hasAlarmPermission = alarmPermission;
  //     });
  //   }
    
  //   // Show permission status to user
  //   if (mounted) {
  //     if (!notificationPermission) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Notification permission denied. Please enable in settings.'),
  //           duration: Duration(seconds: 5),
  //         ),
  //       );
  //     } else if (Platform.isAndroid && !alarmPermission) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Alarm permission denied. Exact notifications may not work properly.'),
  //           duration: Duration(seconds: 5),
  //         ),
  //       );
  //     }
  //   }
  // }

  // New async method to load settings
  Future<void> _loadInitialSettings() async {
    try {
      // Initialize notification manager
      await _notificationManager.initialize();
      
      // Explicitly check and request permissions when page loads
      await _checkAndRequestAllPermissions();
      
      // Now it's safe to get the values
      final initialTime = _notificationManager.getNotificationTime();
      final initialEnabled = _notificationManager.isNotificationEnabled();

      debugPrint("Settings loaded - Time: ${initialTime.hour}:${initialTime.minute}, Enabled: $initialEnabled");

      // Update the state and stop loading
      if (mounted) {
        setState(() {
          _selectedTime = initialTime;
          _notificationsEnabled = initialEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading notification settings: $e");
      // Handle error state
      if (mounted) {
        setState(() {
          _selectedTime = const TimeOfDay(hour: 8, minute: 0);
          _notificationsEnabled = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAndRequestAllPermissions() async {
    // Check notification permission
    bool notificationPermission = await _notificationManager.checkNotificationPermission();
    
    // If no notification permission, request it immediately
    if (!notificationPermission) {
      notificationPermission = await _notificationManager.requestNotificationPermission();
    }
    
    // Check alarm permission (Android only) and request immediately
    bool alarmPermission = true;
    if (Platform.isAndroid) {
      alarmPermission = await _notificationManager.checkAlarmPermission();
      
      // Always request alarm permission on page load if not granted
      if (!alarmPermission) {
        alarmPermission = await _notificationManager.requestAlarmPermission();
      }
    }
    
    // Update state with permission results
    if (mounted) {
      setState(() {
        _hasNotificationPermission = notificationPermission;
        _hasAlarmPermission = alarmPermission;
      });
    }
    
    // Show permission status to user
    if (mounted) {
      if (!notificationPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission denied. Please enable in settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      } else if (Platform.isAndroid && !alarmPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm permission denied. Exact notifications may not work properly.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // Ensure _selectedTime is not null before showing picker
    if (_selectedTime == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime!, // Use ! as it's checked above
      helpText: 'SELECT NOTIFICATION TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerTheme.of(context).copyWith(
              // Customize time picker if needed
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      // Ensure _notificationsEnabled is not null
      final bool isEnabled = _notificationsEnabled ?? false;

      setState(() {
        _selectedTime = pickedTime;
      });

      // Save the new time and schedule/cancel notification
      await _notificationManager.setNotificationTime(
        _selectedTime!, // Use ! as it's assigned above
        enabled: isEnabled, // Use the current enabled state
      );
      _verifyScheduledNotifications();
    }
  }

  // Method to handle requesting alarm permissions
  Future<void> _requestMissingPermissions() async {
    bool permissionsChanged = false;
    
    // Request notification permission if missing
    if (!_hasNotificationPermission) {
      final granted = await _notificationManager.requestNotificationPermission();
      if (granted) {
        permissionsChanged = true;
        _hasNotificationPermission = true;
      }
    }
    
    // Request alarm permission if on Android and missing
    if (Platform.isAndroid && !_hasAlarmPermission) {
      final granted = await _notificationManager.requestAlarmPermission();
      if (granted) {
        permissionsChanged = true;
        _hasAlarmPermission = true;
      }
    }
    
    // If permissions were granted, refresh UI
    if (permissionsChanged && mounted) {
      setState(() {});
      
      // Attempt to schedule notifications again if enabled
      if (_notificationsEnabled == true) {
        await _notificationManager.scheduleNotification();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while settings are being loaded
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification Settings'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Once loaded, build the actual UI
    final TimeOfDay currentTime = _selectedTime ?? const TimeOfDay(hour: 8, minute: 0);
    final bool currentEnabled = _notificationsEnabled ?? false;
    
    // Check if any permissions are missing
    final bool hasMissingPermissions = !_hasNotificationPermission || 
      (Platform.isAndroid && !_hasAlarmPermission);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission warning banner if needed
            if (hasMissingPermissions)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Permission Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Notification permissions are needed for reminders to work properly.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _requestMissingPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                ),
              ),

            // Daily notification switch
            SwitchListTile(
              title: const Text(
                'Daily Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Receive daily reminders'),
              value: currentEnabled, // Use loaded value
              onChanged: (value) async {
                // If enabling notifications, check permissions first
                if (value && hasMissingPermissions) {
                  await _requestMissingPermissions();
                  // If still missing permissions, don't enable
                  if (!_hasNotificationPermission || 
                      (Platform.isAndroid && !_hasAlarmPermission)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cannot enable notifications without required permissions'),
                      ),
                    );
                    return;
                  }
                }
                
                setState(() {
                  _notificationsEnabled = value; // Update local state first
                });
                // Save and schedule/cancel
                await _notificationManager.setNotificationTime(
                  currentTime, // Use the currently selected time
                  enabled: value,
                );
              },
              secondary: const Icon(Icons.notifications),
            ),

            const SizedBox(height: 24),

            // Time picker section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Time',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: (currentEnabled && !hasMissingPermissions)
                        ? () => _selectTime(context)
                        : null, // Disable tap if notifications are off or permissions missing
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: (currentEnabled && !hasMissingPermissions)
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentTime.format(context), // Use loaded value
                            style: TextStyle(
                              fontSize: 18,
                              color: (currentEnabled && !hasMissingPermissions) 
                                ? Colors.black 
                                : Colors.grey,
                            ),
                          ),
                          Icon(
                            Icons.access_time,
                            color: (currentEnabled && !hasMissingPermissions)
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Test notification button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Notification'),
                onPressed: (currentEnabled && !hasMissingPermissions)
                    ? () async {
                        await _notificationManager.showTestNotification();
                      }
                    : null, // Disable if notifications are off or permissions missing
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Verify Scheduled Notifications'),
                onPressed: () {
                  _verifyScheduledNotifications();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
                final pendingNotifications = await plugin.pendingNotificationRequests();
                
                if (pendingNotifications.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No scheduled notifications found')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${pendingNotifications.length} notifications scheduled')),
                  );
                  
                  // Log details of each notification
                  for (var notification in pendingNotifications) {
                    debugPrint("ID: ${notification.id}, Title: ${notification.title}");
                  }
                }
              },
              child: Text('Check Scheduled Notifications'),
            ),

            
            
            const SizedBox(height: 24),
            
            // Information card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'About Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Daily notifications will remind you at your selected time. '
                      'The app requires notification and alarm permissions to function correctly. '
                      'For Android 12+, exact alarm permissions are needed for precise notification timing.',
                    ),

                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}