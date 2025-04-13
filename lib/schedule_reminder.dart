import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class StudyReminderManager {
  static final StudyReminderManager _instance = StudyReminderManager._internal();
  factory StudyReminderManager() => _instance;
  
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  
  // Channel and notification IDs
  static const String _channelId = 'study_reminder_channel';
  static const int _notificationId = 1001;
  
  // SharedPreferences keys
  static const String _timeHourKey = 'reminder_time_hour';
  static const String _timeMinuteKey = 'reminder_time_minute';
  static const String _messageKey = 'reminder_message';
  static const String _enabledKey = 'reminder_enabled';
  
  // Default values
  static const int _defaultHour = 20; // 8 PM
  static const int _defaultMinute = 0;
  static const String _defaultMessage = 'Ready a topic today. We\'re waiting for you';
  
  bool _isInitialized = false;
  
  StudyReminderManager._internal();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz_data.initializeTimeZones();
    
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Request permissions on iOS
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Removed onDidReceiveLocalNotification as it is no longer supported
    );
    
    // Setup Android settings with icon
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize settings for all platforms
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Initialize the plugin with settings
    bool? result = await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked: ${details.payload}');
        // Handle notification tap here
      },
    );
    
    debugPrint('Notification plugin initialized: $result');
    
    // Create notification channel for Android
    await _setupNotificationChannel();
    
    // Check if reminders are enabled and schedule if needed
    final isEnabled = await isReminderEnabled();
    if (isEnabled) {
      await scheduleReminder();
    }
    
    _isInitialized = true;
  }
  
  Future<void> _setupNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
      _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
    if (androidPlugin != null) {
      // No explicit permission request is needed for Android notifications
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        'Study Reminders',
        description: 'Daily reminders to help you study',
        importance: Importance.high,
        enableLights: true,
        enableVibration: true,
        showBadge: true,
      );
      
      await androidPlugin.createNotificationChannel(channel);
      debugPrint('Android notification channel created');
    }
  }
  
  // Get current reminder time
  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_timeHourKey) ?? _defaultHour;
    final minute = prefs.getInt(_timeMinuteKey) ?? _defaultMinute;
    return TimeOfDay(hour: hour, minute: minute);
  }
  
  // Save reminder time
  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeHourKey, time.hour);
    await prefs.setInt(_timeMinuteKey, time.minute);
    
    final isEnabled = await isReminderEnabled();
    if (isEnabled) {
      await scheduleReminder();
    }
  }
  
  // Get current reminder message
  Future<String> getReminderMessage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_messageKey) ?? _defaultMessage;
  }
  
  // Save reminder message
  Future<void> setReminderMessage(String message) async {
    if (message.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_messageKey, message);
    
    final isEnabled = await isReminderEnabled();
    if (isEnabled) {
      await scheduleReminder();
    }
  }
  
  // Check if reminders are enabled
  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
  
  // Enable or disable reminders
  Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    
    if (enabled) {
      await scheduleReminder();
    } else {
      await cancelReminder();
    }
  }
  
  // Schedule the daily reminder notification
  Future<void> scheduleReminder() async {
    // Cancel any existing reminders first
    await cancelReminder();
    
    // Get saved time and message
    final reminderTime = await getReminderTime();
    final message = await getReminderMessage();
    
    // Calculate next occurrence time
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );
    
    // If time already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Convert to timezone-aware datetime
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    debugPrint('Scheduling notification for: ${scheduledTzDate.toString()}');
    
    // Create notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      'Study Reminders',
      channelDescription: 'Daily reminders to help you study',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableLights: true,
      enableVibration: true,
      color: Color.fromARGB(255, 33, 150, 243), // Blue color
      ledColor: Color.fromARGB(255, 255, 0, 0), // Red LED
      ledOnMs: 1000,
      ledOffMs: 500,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.wav',
      badgeNumber: 1,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Schedule the notification
    try {
      await _notificationsPlugin.zonedSchedule(
        _notificationId,
        'Study Reminder',
        message,
        scheduledTzDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'study_reminder',
      );
      debugPrint('Reminder scheduled successfully');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      // Fall back to a simpler notification method if needed
      await _scheduleBackupReminder();
    }
  }
  
  // Fallback method for scheduling in case the primary method fails
  Future<void> _scheduleBackupReminder() async {
    debugPrint('Attempting backup scheduling method');
    final reminderTime = await getReminderTime();
    // final message = await getReminderMessage();
    
    // Use the Android alarm manager package or a simple timer for backup
    // This is just a placeholder - you'll need to implement a robust backup
    // scheduling mechanism if needed
    
    // For demonstration, we'll just show a notification immediately
    await showNotificationNow('Reminder system initialized', 
      'Daily reminders will appear at ${reminderTime.hour}:${reminderTime.minute}');
  }
  
  // Cancel the reminder
  Future<void> cancelReminder() async {
    await _notificationsPlugin.cancel(_notificationId);
    debugPrint('Study reminder cancelled');
  }
  
  // Show a notification immediately (for testing)
  Future<void> showNotificationNow(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      'Study Reminders',
      channelDescription: 'Daily reminders to help you study',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    
    await _notificationsPlugin.show(
      _notificationId + 1, // Use a different ID to not conflict with the scheduled notification
      title,
      body,
      notificationDetails,
    );
    
    debugPrint('Test notification displayed');
  }
  
  // Reset to defaults
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_timeHourKey);
    await prefs.remove(_timeMinuteKey);
    await prefs.remove(_messageKey);
    
    await cancelReminder();
    await scheduleReminder();
  }
}

// UI Widget to manage study reminders
class StudyReminderSettingsWidget extends StatefulWidget {
  const StudyReminderSettingsWidget({Key? key}) : super(key: key);

  @override
  State<StudyReminderSettingsWidget> createState() => _StudyReminderSettingsWidgetState();
}

class _StudyReminderSettingsWidgetState extends State<StudyReminderSettingsWidget> {
  final StudyReminderManager _reminderManager = StudyReminderManager();
  bool _isLoading = true;
  bool _isEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  late TextEditingController _messageController;
  
  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    await _reminderManager.initialize();
    
    final isEnabled = await _reminderManager.isReminderEnabled();
    final reminderTime = await _reminderManager.getReminderTime();
    final message = await _reminderManager.getReminderMessage();
    
    setState(() {
      _isEnabled = isEnabled;
      _reminderTime = reminderTime;
      _messageController.text = message;
      _isLoading = false;
    });
  }
  
  Future<void> _showTimePicker() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && pickedTime != _reminderTime) {
      setState(() {
        _reminderTime = pickedTime;
      });
      
      await _reminderManager.setReminderTime(pickedTime);
      
      if (_isEnabled) {
        await _reminderManager.scheduleReminder();
        _showSnackBar('Reminder time updated to ${pickedTime.format(context)}');
      }
    }
  }
  
  Future<void> _toggleReminder(bool value) async {
    setState(() {
      _isEnabled = value;
    });
    
    await _reminderManager.setReminderEnabled(value);
    
    _showSnackBar(value 
      ? 'Daily reminder enabled for ${_reminderTime.format(context)}'
      : 'Daily reminder disabled');
  }
  
  Future<void> _saveMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Message cannot be empty');
      return;
    }
    
    await _reminderManager.setReminderMessage(message);
    
    if (_isEnabled) {
      await _reminderManager.scheduleReminder();
    }
    
    _showSnackBar('Reminder message updated');
  }
  
  Future<void> _testNotification() async {
    await _reminderManager.showNotificationNow(
      'Test Reminder',
      _messageController.text.isEmpty 
        ? 'Ready a topic today. We\'re waiting for you'
        : _messageController.text,
    );
    
    _showSnackBar('Test notification sent');
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Study Reminder Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          
          // Enable/Disable Switch
          SwitchListTile(
            title: const Text('Enable Daily Reminder'),
            subtitle: Text(_isEnabled 
              ? 'Reminder set for ${_reminderTime.format(context)}'
              : 'No reminder scheduled'),
            value: _isEnabled,
            onChanged: _toggleReminder,
            secondary: Icon(
              _isEnabled ? Icons.notifications_active : Icons.notifications_off,
              color: _isEnabled ? Colors.blue : Colors.grey,
            ),
          ),
          const Divider(),
          
          // Time Picker
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Reminder Time'),
            subtitle: Text('Daily at ${_reminderTime.format(context)}'),
            trailing: ElevatedButton(
              onPressed: _isEnabled ? _showTimePicker : null,
              child: const Text('Change'),
            ),
          ),
          const Divider(),
          
          // Message Editor
          const Text('Reminder Message:'),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Enter reminder message',
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveMessage,
                tooltip: 'Save Message',
              ),
            ),
            maxLines: 2,
            enabled: _isEnabled,
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _isEnabled ? _testNotification : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Notification'),
              ),
              TextButton.icon(
                onPressed: _isEnabled 
                  ? () async {
                      await _reminderManager.resetToDefaults();
                      await _loadSettings();
                      _showSnackBar('Reset to default settings');
                    }
                  : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to Default'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}