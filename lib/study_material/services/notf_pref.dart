
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

enum RepeatInterval {
  daily,
  weekly,
  monthly,
  none
}

extension RepeatIntervalExtension on RepeatInterval {
  String get friendlyName {
    switch (this) {
      case RepeatInterval.daily: return 'Daily';
      case RepeatInterval.weekly: return 'Weekly';
      case RepeatInterval.monthly: return 'Monthly';
      case RepeatInterval.none: return 'One-time';
    }
  }
  
  DateTimeComponents? get dateTimeComponents {
    switch (this) {
      case RepeatInterval.daily: return DateTimeComponents.time;
      case RepeatInterval.weekly: return DateTimeComponents.dayOfWeekAndTime;
      case RepeatInterval.monthly: return DateTimeComponents.dayOfMonthAndTime;
      case RepeatInterval.none: return null;
    }
  }
}

class StudyReminderNotification {
  final int id;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final bool isRepeating;
  final RepeatInterval repeatInterval;
  final String? subjectColor; // Added for color coding subjects

  StudyReminderNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledTime,
    this.isRepeating = false,
    this.repeatInterval = RepeatInterval.none,
    this.subjectColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'isRepeating': isRepeating,
      'repeatInterval': repeatInterval.index,
      'subjectColor': subjectColor,
    };
  }

  factory StudyReminderNotification.fromMap(Map<String, dynamic> map) {
    return StudyReminderNotification(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(map['scheduledTime']),
      isRepeating: map['isRepeating'] ?? false,
      repeatInterval: map['repeatInterval'] != null 
          ? RepeatInterval.values[map['repeatInterval']] 
          : RepeatInterval.none,
      subjectColor: map['subjectColor'],
    );
  }
  
  // Helper to get color based on stored hex value
  Color get color {
    if (subjectColor == null) return Colors.blue;
    try {
      return Color(int.parse(subjectColor!.replaceAll('#', '0xff')));
    } catch (e) {
      return Colors.blue;
    }
  }
  
  // Check if the reminder is active based on its scheduled time and repeat settings
  bool get isActive {
    if (isRepeating) return true;
    return scheduledTime.isAfter(DateTime.now());
  }
  
  // Returns a formatted string of the time
  String get formattedTime {
    final hour = scheduledTime.hour.toString().padLeft(2, '0');
    final minute = scheduledTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // Returns a formatted string of the date
  String get formattedDate {
    final day = scheduledTime.day.toString().padLeft(2, '0');
    final month = scheduledTime.month.toString().padLeft(2, '0');
    return '$day/$month/${scheduledTime.year}';
  }
}

class StudyReminderManager {
  static final StudyReminderManager _instance = StudyReminderManager._internal();
  factory StudyReminderManager() => _instance;
  
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final List<StudyReminderNotification> _scheduledReminders = [];
  final String _storageKey = 'scheduled_reminders_v2'; // Updated key to avoid conflicts
  
  // Improved reminder templates with more student-focused content
  final List<Map<String, dynamic>> reminderTemplates = [
    {
      'title': 'Study Session',
      'message': 'Time to focus! Your planned study session is starting now.',
      'color': '#4285F4' // Blue
    },
    {
      'title': 'Test Prep',
      'message': 'Don\'t forget to review your notes for the upcoming test!',
      'color': '#EA4335' // Red
    },
    {
      'title': 'Study Break',
      'message': 'Study break time - take 5 minutes to refresh your mind.',
      'color': '#34A853' // Green
    },
    {
      'title': 'Assignment Deadline',
      'message': 'Quick reminder to check your assignment deadlines.',
      'color': '#FBBC05' // Yellow
    },
    {
      'title': 'Focus Time',
      'message': 'Time for your scheduled study session. You\'ve got this!',
      'color': '#9C27B0' // Purple
    },
    {
      'title': 'Reading Session',
      'message': 'Time to complete your assigned reading for class.',
      'color': '#FF9800' // Orange
    },
    {
      'title': 'Group Study',
      'message': 'Your group study session is about to begin.',
      'color': '#795548' // Brown
    },
  ];

  // Stream controller to notify listeners of changes
  final _reminderStreamController = StreamController<List<StudyReminderNotification>>.broadcast();
  Stream<List<StudyReminderNotification>> get remindersStream => _reminderStreamController.stream;

  StudyReminderManager._internal();
  
  Future<void> initialize() async {
  // Initialize timezone data
  tz_data.initializeTimeZones();
  final local = tz.local;
  tz.setLocalLocation(local);
  
  // Initialize notification plugin
  _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Request notification permissions
  // final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
  //     _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  // // Request notification permission
  // await androidPlugin?.requestPermission();
  
  // For iOS, permissions are part of the initialization settings
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    requestCriticalPermission: true, // Request critical alerts if needed
  );
  
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  
  await _notificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );
  
  // Load saved reminders
  await _loadReminders();
}
  
  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == null) return;
    
    try {
      final data = jsonDecode(response.payload!);
      final id = data['id'];
      final action = response.actionId;
      
      if (action == 'snooze') {
        _snoozeReminder(id);
      } else if (action == 'dismiss') {
        _dismissReminder(id);
      }
    } catch (e) {
      debugPrint('Error handling notification response: $e');
    }
  }
  
  Future<void> _loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedReminders = prefs.getStringList(_storageKey) ?? [];
      
      _scheduledReminders.clear();
      for (final reminderJson in savedReminders) {
        try {
          final map = jsonDecode(reminderJson) as Map<String, dynamic>;
          _scheduledReminders.add(StudyReminderNotification.fromMap(map));
        } catch (e) {
          debugPrint('Error loading reminder: $e');
        }
      }
      
      // Re-schedule all existing reminders (for app restarts)
      for (final reminder in _scheduledReminders) {
        if (reminder.isActive) {
          await _scheduleNotification(reminder);
        }
      }
      
      // Notify listeners
      _reminderStreamController.add(_scheduledReminders);
    } catch (e) {
      debugPrint('Error in _loadReminders: $e');
    }
  }
  
  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderJsonList = _scheduledReminders
          .map((reminder) => jsonEncode(reminder.toMap()))
          .toList();
      await prefs.setStringList(_storageKey, reminderJsonList);
      
      // Notify listeners
      _reminderStreamController.add(_scheduledReminders);
    } catch (e) {
      debugPrint('Error in _saveReminders: $e');
    }
  }
  
  Future<bool> scheduleStudyReminder({
    required String title,
    required String message,
    required DateTime scheduledTime,
    bool isRepeating = false,
    RepeatInterval repeatInterval = RepeatInterval.none,
    String? subjectColor,
  }) async {
    // Don't allow scheduling in the past for non-repeating reminders
    if (scheduledTime.isBefore(DateTime.now()) && !isRepeating) {
      return false;
    }
    
    // Generate a unique ID
    final id = DateTime.now().microsecondsSinceEpoch % 100000;
    
    final reminder = StudyReminderNotification(
      id: id,
      title: title,
      message: message,
      scheduledTime: scheduledTime,
      isRepeating: isRepeating,
      repeatInterval: isRepeating ? repeatInterval : RepeatInterval.none,
      subjectColor: subjectColor,
    );
    
    // Add to our tracking list
    _scheduledReminders.add(reminder);
    await _saveReminders();
    
    // Schedule the actual notification
    return await _scheduleNotification(reminder);
  }
  
  Future<bool> _scheduleNotification(StudyReminderNotification reminder) async {
    try {
      // Define notification details
      final androidDetails = AndroidNotificationDetails(
        'study_reminders_channel',
        'Study Reminders',
        channelDescription: 'Notifications for scheduled study sessions',
        importance: Importance.high,
        priority: Priority.high,
        color: reminder.color,
        icon: '@mipmap/ic_launcher',
        sound: const RawResourceAndroidNotificationSound('study_bell'),
        actions: [
          const AndroidNotificationAction(
            'snooze',
            'Snooze 10 min',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'dismiss',
            'Mark Done',
            showsUserInterface: false,
          ),
        ],
      );
      
      // Define iOS-specific details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'study_bell.aiff',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final payload = jsonEncode({
        'id': reminder.id,
        'title': reminder.title,
        'message': reminder.message,
      });
      
      if (reminder.isRepeating) {
        // For repeating notifications, we use zonedSchedule with matchDateTimeComponents
        final scheduledDate = tz.TZDateTime.from(reminder.scheduledTime, tz.local);
        
        await _notificationsPlugin.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.message,
          scheduledDate,
          notificationDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: reminder.repeatInterval.dateTimeComponents,
        );
      } else {
        // For one-time notifications
        final scheduledDate = tz.TZDateTime.from(reminder.scheduledTime, tz.local);
        
        await _notificationsPlugin.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.message,
          scheduledDate, // This should be a tz.TZDateTime object
          notificationDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          // Replace uiLocalNotificationDateInterpretation with matchDateTimeComponents for iOS/macOS
          matchDateTimeComponents: DateTimeComponents.time, // Or .dayOfWeekAndTime, etc., depending on recurrence
        );
      }
      
      return true;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return false;
    }
  }
  
  Future<void> _snoozeReminder(int id) async {
    // Find the reminder
    final reminderIndex = _scheduledReminders.indexWhere((r) => r.id == id);
    if (reminderIndex == -1) return;
    
    final reminder = _scheduledReminders[reminderIndex];
    
    // Create a new reminder 10 minutes later
    final snoozedTime = DateTime.now().add(const Duration(minutes: 10));
    
    final snoozedReminder = StudyReminderNotification(
      id: reminder.id + 1, // New ID to avoid conflicts
      title: '${reminder.title} (Snoozed)',
      message: reminder.message,
      scheduledTime: snoozedTime,
      isRepeating: false,
      subjectColor: reminder.subjectColor,
    );
    
    _scheduledReminders.add(snoozedReminder);
    await _saveReminders();
    await _scheduleNotification(snoozedReminder);
  }
  
  Future<void> _dismissReminder(int id) async {
    // Find and remove the reminder
    _scheduledReminders.removeWhere((r) => r.id == id);
    await _saveReminders();
    await _notificationsPlugin.cancel(id);
  }
  
  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
    _scheduledReminders.removeWhere((r) => r.id == id);
    await _saveReminders();
  }
  
  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
    _scheduledReminders.clear();
    await _saveReminders();
  }
  
  // Get all scheduled reminders
  List<StudyReminderNotification> get scheduledReminders => 
      List.unmodifiable(_scheduledReminders);
      
  // Filter reminders by active/past
  List<StudyReminderNotification> getReminders({bool activeOnly = false}) {
    if (!activeOnly) return List.unmodifiable(_scheduledReminders);
    return _scheduledReminders.where((r) => r.isActive).toList();
  }
  
  // Get template at index with safety check
  Map<String, dynamic> getTemplate(int index) {
    if (index < 0 || index >= reminderTemplates.length) {
      return reminderTemplates[0];
    }
    return reminderTemplates[index];
  }
  
  // Dispose resources
  void dispose() {
    _reminderStreamController.close();
  }
}

// Modern UI Components

class StudyReminderApp extends StatelessWidget {
  const StudyReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Buddy',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.indigo[400]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.indigoAccent),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const StudyReminderScreen(),
    );
  }
}

// Example usage in your app
class StudyReminderScreen extends StatefulWidget {
  const StudyReminderScreen({Key? key}) : super(key: key);

  @override
  State<StudyReminderScreen> createState() => _StudyReminderScreenState();
}

class _StudyReminderScreenState extends State<StudyReminderScreen> {
  final StudyReminderManager _reminderManager = StudyReminderManager();
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    // Initialize the reminder manager
    _initializeAndCheckPermissions();
  }
  
  Future<void> _initializeAndCheckPermissions() async {
    await _reminderManager.initialize();
    _checkNotificationPermissions();
  }
  
  Future<void> _checkNotificationPermissions() async {
    // Check if permissions are granted
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _reminderManager._notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    // For Android 13+ (API level 33+)
    bool? areNotificationsEnabled = await androidPlugin?.areNotificationsEnabled();
    
    // Check for SCHEDULE_EXACT_ALARM permission manually
    bool hasExactAlarmPermission = false;
    if (Platform.isAndroid) {
      // For Android 12+ we need to check for SCHEDULE_EXACT_ALARM permission
      if (await Permission.scheduleExactAlarm.isGranted) {
        hasExactAlarmPermission = true;
      }
    } else {
      // On iOS this isn't needed in the same way
      hasExactAlarmPermission = true;
    }
    
    setState(() {
      _permissionsGranted = (areNotificationsEnabled ?? false) && hasExactAlarmPermission;
    });
    
    // Request permissions if not granted
    if (!_permissionsGranted) {
      _showPermissionDialog();
    }
  }
  
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app needs permission to send notifications and schedule exact alarms to remind you of your study sessions. Please grant these permissions to use all features.'
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Request notification permission
              // final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
              //     _reminderManager._notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              
              // await androidPlugin?.requestPermission();
              
              // Request exact alarm permission using permission_handler
              if (Platform.isAndroid) {
                if (await Permission.scheduleExactAlarm.isDenied) {
                  await Permission.scheduleExactAlarm.request();
                }
              }
              
              // Open app settings if necessary
              final openSettings = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Open Settings?'),
                  content: const Text('You may need to enable permissions in your device settings.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Not Now'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
              
              if (openSettings == true) {
                await openAppSettings();
              }
              
              // Re-check permissions
              _checkNotificationPermissions();
            },
            child: const Text('GRANT PERMISSIONS'),
          ),
        ],
      ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Reminders?'),
                  content: const Text(
                    'Are you sure you want to delete all scheduled reminders?'
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: const Text('Delete All'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await StudyReminderManager().cancelAllReminders();
                setState(() {}); // Refresh the UI
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Reminder creation form
          StudyReminderPickerWidget(
            onReminderScheduled: (_) => setState(() {}),
          ),
          
          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(thickness: 1),
          ),
          
          // Scheduled reminders list title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your Scheduled Reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          
          // List of scheduled reminders
          const Expanded(
            child: ScheduledRemindersListWidget(),
          ),
        ],
      ),
    );
  }
}

// StudyReminderPickerWidget - For creating new reminders
class StudyReminderPickerWidget extends StatefulWidget {
  final Function(StudyReminderNotification) onReminderScheduled;
  
  const StudyReminderPickerWidget({
    Key? key,
    required this.onReminderScheduled,
  }) : super(key: key);

  @override
  State<StudyReminderPickerWidget> createState() => _StudyReminderPickerWidgetState();
}

class _StudyReminderPickerWidgetState extends State<StudyReminderPickerWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  bool _isRepeating = false;
  RepeatInterval _repeatInterval = RepeatInterval.daily;
  int _selectedTemplateIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Set initial values from the first template
    final template = StudyReminderManager().getTemplate(0);
    _titleController.text = template['title'];
    _messageController.text = template['message'];
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  void _selectTemplate(int index) {
    final template = StudyReminderManager().getTemplate(index);
    setState(() {
      _selectedTemplateIndex = index;
      _titleController.text = template['title'];
      _messageController.text = template['message'];
    });
  }
  
  Future<void> _selectDateTime(BuildContext context) async {
    // Pick date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate == null) return;
    
    // Pick time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime == null) return;
    
    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }
  
  Future<void> _scheduleReminder() async {
    if (!_formKey.currentState!.validate()) return;
    
    final template = StudyReminderManager().getTemplate(_selectedTemplateIndex);
    
    final result = await StudyReminderManager().scheduleStudyReminder(
      title: _titleController.text,
      message: _messageController.text,
      scheduledTime: _selectedDate,
      isRepeating: _isRepeating,
      repeatInterval: _isRepeating ? _repeatInterval : RepeatInterval.none,
      subjectColor: template['color'],
    );
    
    if (result) {
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder scheduled for ${DateFormat('MMM d, y • h:mm a').format(_selectedDate)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      
      // Reset form
      _titleController.text = template['title'];
      _messageController.text = template['message'];
      setState(() {
        _selectedDate = DateTime.now().add(const Duration(hours: 1));
        _isRepeating = false;
      });
      
      // Notify parent
      final reminders = StudyReminderManager().scheduledReminders;
      if (reminders.isNotEmpty) {
        widget.onReminderScheduled(reminders.last);
      }
    } else {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to schedule reminder. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Template selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    StudyReminderManager().reminderTemplates.length,
                    (index) {
                      final template = StudyReminderManager().getTemplate(index);
                      final color = Color(int.parse(template['color'].replaceAll('#', '0xff')));
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _selectTemplate(index),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedTemplateIndex == index
                                  ? color.withOpacity(0.2)
                                  : isDarkMode ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedTemplateIndex == index
                                    ? color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  template['title'],
                                  style: TextStyle(
                                    fontWeight: _selectedTemplateIndex == index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Message field
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Message',
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Date and time picker
              InkWell(
                onTap: () => _selectDateTime(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, y • h:mm a').format(_selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Repeating option
              SwitchListTile(
                title: const Text('Repeating Reminder'),
                subtitle: Text(_isRepeating
                    ? 'Repeats ${_repeatInterval.friendlyName.toLowerCase()}'
                    : 'One-time reminder'),
                value: _isRepeating,
                onChanged: (value) {
                  setState(() {
                    _isRepeating = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).primaryColor,
              ),
              
              // Repeat interval selection
              if (_isRepeating)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: SegmentedButton<RepeatInterval>(
                    segments: [
                      ButtonSegment(
                        value: RepeatInterval.daily,
                        label: const Text('Daily'),
                        icon: const Icon(Icons.calendar_today),
                      ),
                      ButtonSegment(
                        value: RepeatInterval.weekly,
                        label: const Text('Weekly'),
                        icon: const Icon(Icons.calendar_view_week),
                      ),
                      ButtonSegment(
                        value: RepeatInterval.monthly,
                        label: const Text('Monthly'),
                        icon: const Icon(Icons.calendar_month),
                      ),
                    ],
                    selected: {_repeatInterval},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _repeatInterval = selection.first;
                      });
                    },
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Schedule button
              ElevatedButton.icon(
                onPressed: _scheduleReminder,
                icon: const Icon(Icons.notifications_active),
                label: const Text('SCHEDULE REMINDER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ScheduledRemindersListWidget - For displaying existing reminders
class ScheduledRemindersListWidget extends StatefulWidget {
  const ScheduledRemindersListWidget({super.key});

  @override
  State<ScheduledRemindersListWidget> createState() => _ScheduledRemindersListWidgetState();
}

class _ScheduledRemindersListWidgetState extends State<ScheduledRemindersListWidget> {
  List<StudyReminderNotification> _reminders = [];
  bool _showPastReminders = false;
  
  @override
  void initState() {
    super.initState();
    _loadReminders();
    
    // Listen for changes in reminders
    StudyReminderManager().remindersStream.listen((reminders) {
      setState(() {
        _reminders = reminders;
      });
    });
  }
  
  void _loadReminders() {
    setState(() {
      _reminders = StudyReminderManager().scheduledReminders;
    });
  }
  
  // Future<void> _deleteReminder(StudyReminderNotification reminder) async {
  //   // Confirm before deleting
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Delete Reminder'),
  //       content: Text('Are you sure you want to delete "${reminder.title}"?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(false),
  //           child: const Text('CANCEL'),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(true),
  //           child: const Text('DELETE'),
  //         ),
  //       ],
  //     ),
  //   );
    
  //   if (confirmed == true) {
  //     await StudyReminderManager().cancelReminder(reminder.id);
  //     _loadReminders();
  //   }
  // }
  
  @override
  Widget build(BuildContext context) {
    final activeReminders = _reminders.where((r) => r.isActive).toList();
    final pastReminders = _reminders.where((r) => !r.isActive).toList();
    
    final displayedReminders = _showPastReminders ? _reminders : activeReminders;
    
    if (_reminders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No reminders scheduled',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create one using the form above',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Toggle switch for past reminders
        if (pastReminders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Show past reminders',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _showPastReminders,
                  onChanged: (value) {
                    setState(() {
                      _showPastReminders = value;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
          
        Expanded(
          child: displayedReminders.isEmpty
              ? Center(
                  child: Text(
                    _showPastReminders
                        ? 'No reminders to show'
                        : 'No active reminders\nTurn on "Show past reminders" to see previous ones',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: displayedReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = displayedReminders[index];
                    final isPast = !reminder.isActive;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Dismissible(
                        key: Key('reminder-${reminder.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          StudyReminderManager().cancelReminder(reminder.id);
                        },
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Reminder'),
                              content: Text('Are you sure you want to delete "${reminder.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('DELETE'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              // Show reminder details
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => _ReminderDetailsSheet(reminder: reminder),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPast
                                      ? Colors.grey.withOpacity(0.3)
                                      : reminder.color.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: reminder.color.withOpacity(isPast ? 0.5 : 1),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          reminder.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isPast
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (reminder.isRepeating)
                                        Tooltip(
                                          message: '${reminder.repeatInterval.friendlyName} reminder',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPast
                                                  ? Colors.grey.withOpacity(0.2)
                                                  : reminder.color.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  reminder.repeatInterval == RepeatInterval.daily
                                                      ? Icons.calendar_today
                                                      : reminder.repeatInterval == RepeatInterval.weekly
                                                          ? Icons.calendar_view_week
                                                          : Icons.calendar_month,
                                                  size: 14,
                                                  color: isPast ? Colors.grey : reminder.color,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  reminder.repeatInterval.friendlyName,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isPast ? Colors.grey : reminder.color,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 32),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        Text(
                                          reminder.message,
                                          style: TextStyle(
                                            color: isPast ? Colors.grey : null,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: isPast
                                                  ? Colors.grey
                                                  : Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('MMM d, y • h:mm a').format(reminder.scheduledTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isPast
                                                    ? Colors.grey
                                                    : Theme.of(context).textTheme.bodySmall?.color,
                                              ),
                                            ),
                                            if (isPast)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PAST',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Reminder details bottom sheet
class _ReminderDetailsSheet extends StatelessWidget {
  final StudyReminderNotification reminder;
  
  const _ReminderDetailsSheet({
    Key? key,
    required this.reminder,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPast = !reminder.isActive;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with close button
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: reminder.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reminder Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Text(
            'Title',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reminder.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Message
          Text(
            'Message',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reminder.message,
            style: const TextStyle(fontSize: 16),
          ),
          
          const SizedBox(height: 16),
          
          // Date and time
          Text(
            'Scheduled For',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.event,
                size: 18,
                color: reminder.color,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, MMMM d, y').format(reminder.scheduledTime),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: reminder.color,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('h:mm a').format(reminder.scheduledTime),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Repeat info
          Text(
            'Repeat',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                reminder.isRepeating
                    ? Icons.repeat
                    : Icons.repeat_one,
                size: 18,
                color: reminder.color,
              ),
              const SizedBox(width: 8),
              Text(
                reminder.isRepeating
                    ? 'Repeats ${reminder.repeatInterval.friendlyName.toLowerCase()}'
                    : 'One-time reminder',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              // Edit button - Disabled for now
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null, // Disabled for now
                  icon: const Icon(Icons.edit),
                  label: const Text('EDIT'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Delete button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Close the bottom sheet
                    Navigator.of(context).pop();
                    
                    // Delete the reminder
                    await StudyReminderManager().cancelReminder(reminder.id);
                    
                    // Show confirmation
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reminder deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('DELETE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          // If past, show recreate button
          if (isPast) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Close the bottom sheet
                Navigator.of(context).pop();
                
                // TODO: Open create reminder form with this reminder's data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This feature is coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('RECREATE REMINDER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}