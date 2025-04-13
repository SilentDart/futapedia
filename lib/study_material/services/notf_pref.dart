import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// --- Main Function ---
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the reminder manager (includes permission checks/requests)
  await StudyReminderManager().initialize();

  // Run the app
  runApp(const StudyReminderApp());
}

// --- Enums and Extensions ---
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

  // Get NotificationRepeatInterval for Awesome Notifications
  NotificationCalendar getAwesomeSchedule(RepeatInterval interval) {
    final now = DateTime.now();

    switch (interval) {
      case RepeatInterval.daily:
        return NotificationCalendar(
          hour: now.hour,
          minute: now.minute,
          second: now.second,
          repeats: true,
        );
      case RepeatInterval.weekly:
        return NotificationCalendar(
          weekday: now.weekday,
          hour: now.hour,
          minute: now.minute,
          second: now.second,
          repeats: true,
        );
      case RepeatInterval.monthly:
        return NotificationCalendar(
          day: now.day,
          hour: now.hour,
          minute: now.minute,
          second: now.second,
          repeats: true,
        );
      case RepeatInterval.none:
      return NotificationCalendar(
          year: now.year,
          month: now.month,
          day: now.day,
          hour: now.hour,
          minute: now.minute,
          second: now.second,
          repeats: false,
        );
    }
  }

}

// --- Data Class ---
class StudyReminderNotification {
  final int id;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final bool isRepeating;
  final RepeatInterval repeatInterval;
  final String? subjectColor;

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

  Color get color {
    if (subjectColor == null) return Colors.blue;
    try {
      final hex = subjectColor!.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xff$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
      return Colors.blue;
    } catch (e) {
      debugPrint("Error parsing color: $subjectColor, Error: $e");
      return Colors.blue;
    }
  }

  bool get isActive {
    if (isRepeating) return true;
    // Check if the one-time scheduled time is in the future
    return scheduledTime.isAfter(DateTime.now());
  }

  String get formattedTime {
    return DateFormat('h:mm a').format(scheduledTime);
  }

  String get formattedDate {
     return DateFormat('MMM d, y').format(scheduledTime);
  }

  String get repeatingInfo {
    if (!isRepeating) return 'One-time';
    return repeatInterval.friendlyName;
  }
}

// --- Reminder Management Logic ---
class StudyReminderManager {
  static final StudyReminderManager _instance = StudyReminderManager._internal();
  factory StudyReminderManager() => _instance;

  final List<StudyReminderNotification> _scheduledReminders = [];
  final String _storageKey = 'scheduled_reminders_v2';

  final List<Map<String, dynamic>> reminderTemplates = [
    {'title': 'Study Session', 'message': 'Time to focus! Your planned study session is starting now.', 'color': '#4285F4'},
    {'title': 'Test Prep', 'message': 'Don\'t forget to review your notes for the upcoming test!', 'color': '#EA4335'},
    {'title': 'Study Break', 'message': 'Study break time - take 5 minutes to refresh your mind.', 'color': '#34A853'},
    {'title': 'Assignment Deadline', 'message': 'Quick reminder to check your assignment deadlines.', 'color': '#FBBC05'},
    {'title': 'Focus Time', 'message': 'Time for your scheduled study session. You\'ve got this!', 'color': '#9C27B0'},
    {'title': 'Reading Session', 'message': 'Time to complete your assigned reading for class.', 'color': '#FF9800'},
    {'title': 'Group Study', 'message': 'Your group study session is about to begin.', 'color': '#795548'},
  ];

  final _reminderStreamController = StreamController<List<StudyReminderNotification>>.broadcast();
  Stream<List<StudyReminderNotification>> get remindersStream => _reminderStreamController.stream;

  Timer? _cleanupTimer;
  StudyReminderManager._internal();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      // Use the IANA identifier for Nigeria (WAT)
      final location = tz.getLocation('Africa/Lagos');
      tz.setLocalLocation(location);
      debugPrint("Timezone set to: ${tz.local.name}");
    } catch (e) {
      debugPrint("Error setting local location: $e. Using default local.");
      tz.setLocalLocation(tz.local); // Fallback
    }

    // Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      // Set the default notification icon if needed
      'resource://drawable/ic_notification', 
      [
        NotificationChannel(
          channelGroupKey: 'study_reminder_group',
          channelKey: 'study_reminders_channel_id_v1',
          channelName: 'Study Reminders',
          channelDescription: 'Notifications for scheduled study sessions and deadlines',
          defaultColor: Colors.indigo,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          defaultPrivacy: NotificationPrivacy.Public,
          // defaultRingtoneType: DefaultRingtoneType.Notification,
          enableVibration: true,
          // Add additional channel configurations as needed
        ),
        NotificationChannel(
          channelGroupKey: 'study_reminder_group',
          channelKey: 'snooze_channel_id_v1',
          channelName: 'Snoozed Reminders',
          channelDescription: 'Notifications for snoozed study reminders',
          defaultColor: Colors.orange,
          ledColor: Colors.white,
          importance: NotificationImportance.High
        )
      ],
      // Optional: Channel groups if you want to organize your notifications
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'study_reminder_group',
          channelGroupName: 'Study Reminders'
        )
      ],
      debug: true
    );

    // Request permissions
    await _requestNotificationPermissions();

    // Set global action handler for background actions
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _handleNotificationAction,
    );
    await _loadReminders();
    _startCleanupTimer();
  }

  Future<void> _requestNotificationPermissions() async {
    // Request notification permissions
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // For Android 13+, request precise scheduling permissions
    if (Platform.isAndroid) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> _handleNotificationAction(ReceivedAction receivedAction) async {
    debugPrint('Notification action received: ${receivedAction.actionType} - ${receivedAction.payload}');
    
    if (receivedAction.actionType == ActionType.SilentAction || 
        receivedAction.actionType == ActionType.SilentBackgroundAction) {
      // Handle background actions here
      if (receivedAction.buttonKeyPressed == 'snooze') {
        _snoozeReminder(int.parse(receivedAction.payload?['id'] ?? '0'));
      } else if (receivedAction.buttonKeyPressed == 'dismiss') {
        _dismissReminder(int.parse(receivedAction.payload?['id'] ?? '0'));
      }
    } else {
      // Default tap action
      debugPrint('Notification tapped (default action) for ID: ${receivedAction.payload?['id'] ?? 'unknown'}');
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
          final reminder = StudyReminderNotification.fromMap(map);
          if (reminder.isActive) { // Only load active reminders
             _scheduledReminders.add(reminder);
          } else {
            debugPrint("Filtered out past/inactive reminder on load: ID ${reminder.id}");
          }
        } catch (e) {
          debugPrint('Error loading individual reminder: $e');
        }
      }
      // Sort reminders by time for display consistency
      _scheduledReminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      _notifyListeners();
      debugPrint('Loaded ${_scheduledReminders.length} active reminders.');
      // Re-schedule after loading (essential for persistence after restart)
      await _rescheduleActiveReminders();
    } catch (e) {
      debugPrint('Error in _loadReminders: $e');
    }
  }

  Future<void> _rescheduleActiveReminders() async {
    int rescheduledCount = 0;
    // Create a copy to iterate over, as scheduling might involve async gaps
    List<StudyReminderNotification> currentActive = List.from(_scheduledReminders);
    debugPrint("Attempting to re-schedule ${currentActive.length} loaded reminders...");
    for (final reminder in currentActive) {
      if (reminder.isActive) { // Double check activity status
        bool success = await _scheduleNotification(reminder);
        if (success) rescheduledCount++;
        // Optional delay if needed
        // await Future.delayed(Duration(milliseconds: 20));
      }
    }
    debugPrint("Finished re-scheduling. $rescheduledCount reminders successfully re-scheduled.");
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    // Run cleanup periodically (e.g., every hour) and once on startup
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) => _cleanupPastReminders());
    _cleanupPastReminders();
  }

  Future<void> _cleanupPastReminders() async {
    bool changed = false;
    _scheduledReminders.removeWhere((reminder) {
      if (!reminder.isRepeating && reminder.scheduledTime.isBefore(DateTime.now())) {
        debugPrint("Cleaning up past non-repeating reminder ID: ${reminder.id}");
        // No need to cancel notification here, it should be past
        changed = true;
        return true;
      }
      return false;
    });
    if (changed) {
      await _saveReminders(); // Save the cleaned list
    }
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sort before saving to maintain order potentially
      _scheduledReminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      final reminderJsonList = _scheduledReminders
          .map((reminder) => jsonEncode(reminder.toMap()))
          .toList();
      await prefs.setStringList(_storageKey, reminderJsonList);
      _notifyListeners(); // Notify after saving
      debugPrint('Saved ${_scheduledReminders.length} reminders.');
    } catch (e) {
      debugPrint('Error in _saveReminders: $e');
    }
  }

  void _notifyListeners() {
    // Ensure list passed to stream is unmodifiable and sorted
    final sortedList = List<StudyReminderNotification>.from(_scheduledReminders)
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _reminderStreamController.add(List.unmodifiable(sortedList));
  }

  Future<bool> scheduleStudyReminder({
    required String title,
    required String message,
    required DateTime scheduledTime,
    bool isRepeating = false,
    RepeatInterval repeatInterval = RepeatInterval.none,
    String? subjectColor,
  }) async {
    if (!isRepeating && scheduledTime.isBefore(DateTime.now())) {
      debugPrint('Cannot schedule one-time reminder in the past.');
      return false;
    }

    bool permissionsOk = await _checkExactAlarmPermission();
    if (!permissionsOk) {
      debugPrint("Cannot schedule: Exact Alarm permission not granted.");
      // Consider triggering UI feedback or permission request from the calling widget
      return false;
    }

    final id = DateTime.now().microsecondsSinceEpoch % 2147483647;
    final reminder = StudyReminderNotification(
      id: id,
      title: title,
      message: message,
      scheduledTime: scheduledTime,
      isRepeating: isRepeating,
      repeatInterval: isRepeating ? repeatInterval : RepeatInterval.none,
      subjectColor: subjectColor,
    );

    _scheduledReminders.add(reminder);
    await _saveReminders(); // Save includes notifyListeners

    bool scheduled = await _scheduleNotification(reminder);
    if (!scheduled) {
      debugPrint("Scheduling failed for ID: ${reminder.id}. Removing from list.");
      _scheduledReminders.removeWhere((r) => r.id == id);
      await _saveReminders(); // Save again after removal
      return false;
    }
    debugPrint("Successfully scheduled and saved reminder ID: ${reminder.id}");
    return true;
  }

  NotificationCalendar getRepeatCalendar(DateTime time, RepeatInterval repeat) {
    switch (repeat) {
      case RepeatInterval.daily:
        return NotificationCalendar(
          hour: time.hour,
          minute: time.minute,
          second: 0,
          repeats: true,
          preciseAlarm: true,
        );
      case RepeatInterval.weekly:
        return NotificationCalendar(
          weekday: time.weekday,
          hour: time.hour,
          minute: time.minute,
          second: 0,
          repeats: true,
          preciseAlarm: true,
        );
      case RepeatInterval.monthly:
        return NotificationCalendar(
          day: time.day,
          hour: time.hour,
          minute: time.minute,
          second: 0,
          repeats: true,
          preciseAlarm: true,
        );
      case RepeatInterval.none:
      // default:
        return NotificationCalendar.fromDate(
          date: time,
          preciseAlarm: true,
        );
    }
  }


  Future<bool> _checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      // This permission is needed for scheduleExactAllowWhileIdle on Android 12+
      // Use permission_handler
      var status = await Permission.scheduleExactAlarm.status;
      debugPrint("Exact Alarm Permission Status: $status");
      return status.isGranted;
    }
    return true; // Not applicable or handled differently on iOS
  }

  Future<bool> _scheduleNotification(StudyReminderNotification reminder) async {
    try {
      // Cancel any existing notification with the same ID
      await AwesomeNotifications().cancel(reminder.id);

      // Check if one-time and in the past
      if (!reminder.isRepeating && reminder.scheduledTime.isBefore(DateTime.now())) {
        debugPrint("Skipping schedule for past non-repeating reminder ID ${reminder.id}");
        return false;
      }

      // Convert color to integer format
      // int colorInt = reminder.color.value;
      
      // Convert to payload for action buttons
      Map<String, String> payload = {
        'id': reminder.id.toString(),
        'title': reminder.title,
      };

      // Prepare notification
      bool scheduled;
      
      if (reminder.isRepeating) {
        // For repeating notifications
        scheduled = await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: reminder.id,
            channelKey: 'study_reminders_channel_id_v1',
            title: reminder.title,
            body: reminder.message,
            category: NotificationCategory.Reminder,
            notificationLayout: NotificationLayout.Default,
            // color: ,
            payload: payload,
            wakeUpScreen: true,
          ),
          schedule: getRepeatCalendar(reminder.scheduledTime, reminder.repeatInterval),

          actionButtons: [
            NotificationActionButton(
              key: 'dismiss',
              label: 'Dismiss',
              actionType: ActionType.SilentBackgroundAction,
              isDangerousOption: false
            ),
            NotificationActionButton(
              key: 'snooze',
              label: 'Snooze 10 min',
              actionType: ActionType.SilentBackgroundAction,
              isDangerousOption: false
            ),
          ]
        );
        
        debugPrint("Scheduled REPEATING ID ${reminder.id} for ${reminder.scheduledTime}, interval: ${reminder.repeatInterval.friendlyName}");
      } else {
        // For one-time notifications
        scheduled = await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: reminder.id,
            channelKey: 'study_reminders_channel_id_v1',
            title: reminder.title,
            body: reminder.message,
            category: NotificationCategory.Reminder,
            notificationLayout: NotificationLayout.Default,
            // color: colorInt,
            payload: payload,
            wakeUpScreen: true,
          ),
          schedule: NotificationCalendar.fromDate(
            date: reminder.scheduledTime,
            preciseAlarm: true, // Use precise alarm when possible
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'dismiss',
              label: 'Dismiss',
              actionType: ActionType.SilentBackgroundAction,
              isDangerousOption: false
            ),
            NotificationActionButton(
              key: 'snooze',
              label: 'Snooze 10 min',
              actionType: ActionType.SilentBackgroundAction,
              isDangerousOption: false
            ),
          ]
        );
        
        debugPrint("Scheduled ONE-TIME ID ${reminder.id} for ${reminder.scheduledTime}");
      }
      
      return scheduled;
    } catch (e) {
      debugPrint('Error _scheduleNotification ID ${reminder.id}: $e');
      return false;
    }
  }

  Future<void> _snoozeReminder(int id) async {
    final reminderIndex = _scheduledReminders.indexWhere((r) => r.id == id);
    if (reminderIndex == -1) {
      debugPrint("Cannot snooze: Original reminder ID $id not found.");
      return;
    }
    
    final originalReminder = _scheduledReminders[reminderIndex];
    final snoozedTime = DateTime.now().add(const Duration(minutes: 10));
    final snoozedId = DateTime.now().microsecondsSinceEpoch % 2147483647;

    try {
      // Create a snoozed notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: snoozedId,
          channelKey: 'snooze_channel_id_v1',
          title: '(Snoozed) ${originalReminder.title}',
          body: originalReminder.message,
          category: NotificationCategory.Reminder,
          notificationLayout: NotificationLayout.Default,
          // color: originalReminder.color.value,
          payload: {'id': snoozedId.toString(), 'original_id': id.toString()},
          wakeUpScreen: true,
        ),
        schedule: NotificationCalendar.fromDate(
          date: snoozedTime,
          preciseAlarm: true,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'dismiss',
            label: 'Dismiss',
            actionType: ActionType.SilentBackgroundAction,
            isDangerousOption: false
          ),
        ]
      );
      
      debugPrint("Scheduled SNOOZE notification ID $snoozedId for original ID $id at $snoozedTime.");

      // If original was repeating, reschedule it for its *next* natural occurrence
      if (originalReminder.isRepeating) {
        debugPrint("Re-scheduling original repeating reminder ID $id after snooze action.");
        await _scheduleNotification(originalReminder);
      } else {
        // If original was one-time, remove it from the list as it's been 'actioned'
        _scheduledReminders.removeWhere((r) => r.id == id);
        await _saveReminders();
      }
    } catch (e) {
      debugPrint("Error scheduling snooze notification for original ID $id: $e");
    }
  }

  Future<void> _dismissReminder(int id) async {
    debugPrint("Dismiss action called for reminder ID: $id");
    final reminderIndex = _scheduledReminders.indexWhere((r) => r.id == id);
    if (reminderIndex == -1) return;

    await AwesomeNotifications().cancel(id); // Cancel the notification
    debugPrint("Cancelled notification for ID: $id (Dismiss)");

    // If the reminder is NOT repeating, remove it from the list.
    // If it IS repeating, cancelling stops the *current* alert, but the scheduled
    // notification for the next interval remains active. So we keep it in the list.
    if (!_scheduledReminders[reminderIndex].isRepeating) {
      _scheduledReminders.removeAt(reminderIndex);
      debugPrint("Removed non-repeating reminder ID $id from list after dismiss.");
      await _saveReminders();
    } else {
      debugPrint("Dismissed repeating reminder ID $id. It remains scheduled for future intervals.");
      // To permanently stop a repeating reminder, use cancelReminder from UI.
    }
  }

  Future<void> cancelReminder(int id) async {
    debugPrint("Attempting to cancel and remove reminder ID: $id");
    await AwesomeNotifications().cancel(id); // Cancel notification
    int initialLength = _scheduledReminders.length;
    _scheduledReminders.removeWhere((r) => r.id == id);
    if (_scheduledReminders.length < initialLength) {
      debugPrint("Removed reminder ID $id from list.");
      await _saveReminders(); // Save the change
    } else {
      debugPrint("Reminder ID $id not found in list for cancellation.");
    }
  }

  Future<void> cancelAllReminders() async {
    debugPrint("Cancelling ALL reminders.");
    await AwesomeNotifications().cancelAll();
    if (_scheduledReminders.isNotEmpty) {
      _scheduledReminders.clear();
      await _saveReminders();
    }
    debugPrint("All reminders cancelled and list cleared.");
  }

  List<StudyReminderNotification> get scheduledReminders {
    // Return sorted, unmodifiable list
    final sortedList = List<StudyReminderNotification>.from(_scheduledReminders)
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return List.unmodifiable(sortedList);
  }

  List<StudyReminderNotification> getReminders({bool activeOnly = true}) {
    // Filters based on current time and repeating status
    // final now = DateTime.now();
    final filteredList = _scheduledReminders.where((r) {
      if (activeOnly) {
        return r.isActive; // Use the logic defined in the class
      } else {
        return true; // Return all if activeOnly is false
      }
    }).toList();
    // Sort the filtered list as well
    filteredList.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return List.unmodifiable(filteredList);
  }

  Map<String, dynamic> getTemplate(int index) {
    if (index < 0 || index >= reminderTemplates.length) {
      return reminderTemplates[0]; // Default/fallback template
    }
    return reminderTemplates[index];
  }

  void dispose() {
    // Remove action stream listener
    // AwesomeNotifications().actionSink.close();
    _reminderStreamController.close();
    _cleanupTimer?.cancel();
  }
}

// --- UI Components ---
// App Definition and UI remain largely the same as in your original code
// Just update the StudyReminderScreen to handle permissions appropriately

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
          elevation: 1, // Subtle elevation
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87, // For title/icons
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: Colors.indigo, // Default button color
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.indigo[400]!, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        listTileTheme: ListTileThemeData(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
         bottomSheetTheme: const BottomSheetThemeData(
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
           ),
         ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          elevation: 1,
          centerTitle: true,
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
        ),
         elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: Colors.indigoAccent[100], // Lighter indigo for dark mode
            foregroundColor: Colors.black87,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 1,
           margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
             side: BorderSide(color: Colors.grey[700]!, width: 0.5),
          ),
           color: Colors.grey[850], // Darker card background
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[700]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.indigoAccent[100]!, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
         listTileTheme: ListTileThemeData(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        bottomSheetTheme: BottomSheetThemeData(
           backgroundColor: Colors.grey[850], // Darker bottom sheet
           shape: const RoundedRectangleBorder(
             borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
           ),
         ),
      ),
      themeMode: ThemeMode.light, // Or ThemeMode.light / ThemeMode.dark
      debugShowCheckedModeBanner: false,
      home: const StudyReminderScreen(),
    );
  }
}

// Main Screen
class StudyReminderScreen extends StatefulWidget {
  const StudyReminderScreen({Key? key}) : super(key: key);

  @override
  State<StudyReminderScreen> createState() => _StudyReminderScreenState();
}

class _StudyReminderScreenState extends State<StudyReminderScreen> {
  // final StudyReminderManager _reminderManager = StudyReminderManager();
  // State to track permission status for UI feedback (optional)
  // Permissions are checked/requested during manager initialization now.
  // bool _permissionsChecked = false;
  // bool _permissionsGranted = false; // Might not be needed if relying on manager logic

  @override
  void initState() {
    super.initState();
    // Initialization happens in main() before runApp()
    // _initializeAndCheckPermissions();
     _requestPermissionsIfNeeded(); // Request exact alarm if needed
  }

  // Future<void> _initializeAndCheckPermissions() async {
  //   await _reminderManager.initialize(); // Already called in main
  //   _checkNotificationPermissions(); // Check again or rely on initialization
  // }

  Future<void> _requestPermissionsIfNeeded() async {
     if (Platform.isAndroid) {
        var status = await Permission.scheduleExactAlarm.status;
        if (!status.isGranted) {
          _showPermissionDialog(
             'Schedule Exact Alarms',
             'This app needs permission to schedule precise alarms for timely reminders, especially on newer Android versions. Please grant this permission.',
             Permission.scheduleExactAlarm,
          );
        }
     }
     // Notification permission is requested by flutter_local_notifications during init
  }


  void _showPermissionDialog(String title, String content, Permission permission) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$title Permission Required'),
        content: Text(content),
        actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(), // Close dialog
             child: const Text('LATER'),
           ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog first
              // Request the specific permission
              final status = await permission.request();

              if (status.isPermanentlyDenied || status.isDenied) {
                // If denied or permanently denied, prompt to open settings
                _showOpenSettingsDialog(title);
              } else if (status.isGranted) {
                 // Optional: Show success feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title permission granted!')),
                  );
              }
              // Refresh UI or re-check state if needed
              // setState(() {});
            },
            child: const Text('GRANT PERMISSION'),
          ),
        ],
      ),
    );
  }

 void _showOpenSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Denied'),
        content: Text('You have denied the $permissionName permission. To enable reminders, please grant the permission in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings(); // From permission_handler
            },
            child: const Text('OPEN SETTINGS'),
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
            icon: const Icon(Icons.delete_sweep_outlined),
             tooltip: 'Delete All Reminders',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Reminders?'),
                  content: const Text('Are you sure you want to delete ALL scheduled reminders? This action cannot be undone.'),
                  actions: [
                    TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
                    TextButton(child: Text('Delete All', style: TextStyle(color: Colors.red[400])), onPressed: () => Navigator.of(context).pop(true)),
                  ],
                ),
              );
              if (confirm == true) {
                await StudyReminderManager().cancelAllReminders();
                // StreamBuilder will handle the UI update automatically
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Reminder creation form - wrapped in Padding
          Padding(
            padding: const EdgeInsets.only(top: 8.0), // Add padding above the card
            child: StudyReminderPickerWidget(
              // Callback might not be strictly needed if list updates via stream
              onReminderScheduled: (newReminder) {
                 debugPrint("Reminder scheduled callback received in screen.");
                 // Optionally scroll to the new reminder or give feedback
                 // setState(() {}); // StreamBuilder handles list refresh
              },
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(thickness: 1),
          ),

          // Scheduled reminders list title
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Upcoming Reminders',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
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


// Reminder Creation Widget
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

  // Set initial time slightly in the future (e.g., next hour mark or 15 mins from now)
  DateTime _selectedDate = DateTime.now().add(const Duration(minutes: 15));
  bool _isRepeating = false;
  RepeatInterval _repeatInterval = RepeatInterval.daily; // Default repeat if enabled
  int _selectedTemplateIndex = 0;

  @override
  void initState() {
    super.initState();
    // Set initial values from the first template
    final template = StudyReminderManager().getTemplate(0);
    _titleController.text = template['title'];
    _messageController.text = template['message'];

     // Set initial time to be slightly rounded, e.g., next 15-minute interval
     final now = DateTime.now();
     _selectedDate = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15 + 1) * 15);
      // If the calculated time is past, add an hour
     if (_selectedDate.isBefore(now)) {
       _selectedDate = _selectedDate.add(const Duration(hours: 1));
     }
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
    final DateTime initialDatePickerDate = _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate;
    final DateTime firstDatePickerDate = DateTime.now().subtract(const Duration(days: 1)); // Allow yesterday just in case

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDatePickerDate,
      firstDate: firstDatePickerDate, // Allow picking today
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // Allow scheduling up to 2 years ahead
      builder: (context, child) {
        return Theme(
          // Apply theme for consistency
          data: Theme.of(context).copyWith(
             colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).primaryColor, // Use primary color
              ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return; // User cancelled date picker

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

    if (pickedTime == null) return; // User cancelled time picker

     DateTime potentialSelection = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );

     // Basic validation: Prevent selecting a past time for one-off reminders (stricter check here)
      if (!_isRepeating && potentialSelection.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) { // Allow a tiny buffer
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Cannot schedule a one-time reminder in the past.'),
                   backgroundColor: Colors.orangeAccent,
                   behavior: SnackBarBehavior.floating,
                 ),
              );
          }
          return; // Don't update if invalid
      }

    setState(() {
      _selectedDate = potentialSelection;
    });
  }

  Future<void> _scheduleReminder() async {
    if (!_formKey.currentState!.validate()) return; // Form validation failed

     // Additional check: Ensure selected date is not in the past for one-time reminders
     if (!_isRepeating && _selectedDate.isBefore(DateTime.now())) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Please select a future time for one-time reminders.'),
             backgroundColor: Colors.orangeAccent,
             behavior: SnackBarBehavior.floating,
           ),
         );
         return;
     }

    // --- Check for Exact Alarm Permission before scheduling ---
    bool hasPermission = await StudyReminderManager()._checkExactAlarmPermission();
    if (!hasPermission) {
        if(mounted) {
            // Show dialog explaining why and potentially guide to settings
             _showPermissionDialog(
                 'Schedule Exact Alarms',
                 'Timely reminders require the "Alarms & Reminders" permission. Please grant this permission to schedule notifications.',
                 Permission.scheduleExactAlarm,
             );
        }
       return; // Stop scheduling if permission is missing
    }

    final template = StudyReminderManager().getTemplate(_selectedTemplateIndex);

    final result = await StudyReminderManager().scheduleStudyReminder(
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      scheduledTime: _selectedDate,
      isRepeating: _isRepeating,
      repeatInterval: _isRepeating ? _repeatInterval : RepeatInterval.none,
      subjectColor: template['color'],
    );

    if (mounted) { // Check if widget is still in the tree
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder scheduled for ${DateFormat('MMM d, y • h:mm a').format(_selectedDate)}'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );

        // Reset form to initial template state and next available time slot
        _selectTemplate(0); // Reset to first template
        final now = DateTime.now();
         final nextTime = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15 + 1) * 15);
        setState(() {
           _selectedDate = nextTime.isBefore(now) ? nextTime.add(const Duration(hours: 1)) : nextTime;
          _isRepeating = false;
           _repeatInterval = RepeatInterval.daily; // Reset interval too
        });

        // Notify parent widget (StudyReminderScreen)
        final reminders = StudyReminderManager().scheduledReminders;
        if (reminders.isNotEmpty) {
          // Find the newly added reminder (usually the last one, but lookup by time/title is safer if needed)
          // Let's assume the last one is the newly scheduled one for simplicity here.
           final newReminder = reminders.lastWhere(
               (r) => r.title == _titleController.text && r.message == _messageController.text && r.scheduledTime == _selectedDate,
               orElse: () => reminders.last // Fallback
           );
          widget.onReminderScheduled(newReminder);
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to schedule reminder. Check permissions or try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  // --- BUILD METHOD (Completing the UI) ---
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      // Use margin from theme or define specific margin
      // margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Make card wrap content
            children: [
              // --- Template Selector ---
              Text("Choose a Template", style: Theme.of(context).textTheme.labelLarge),
               const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    StudyReminderManager().reminderTemplates.length,
                    (index) {
                      final template = StudyReminderManager().getTemplate(index);
                      final color = Color(int.parse(template['color'].replaceAll('#', '0xff')));
                      final bool isSelected = _selectedTemplateIndex == index;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _selectTemplate(index),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.15) : (isDarkMode ? Colors.grey[800] : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(
                                  template['title'],
                                  style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
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

              // --- Title Field ---
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // --- Message Field ---
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Message (Optional)',
                   prefixIcon: Icon(Icons.message_outlined),
                ),
                 maxLines: 2, // Allow slightly more text
                // No validator, message is optional
              ),

              const SizedBox(height: 20),

              // --- Date and Time Picker Row ---
              InkWell(
                 onTap: () => _selectDateTime(context),
                 borderRadius: BorderRadius.circular(8),
                 child: InputDecorator(
                    decoration: InputDecoration(
                       labelText: 'Date & Time',
                       prefixIcon: Icon(Icons.calendar_today_outlined, color: Theme.of(context).primaryColor),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[400]!)),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                   child: Text(
                     DateFormat('EEE, MMM d, y • h:mm a').format(_selectedDate), // Format for display
                     style: const TextStyle(fontSize: 15),
                   ),
                 ),
              ),


              const SizedBox(height: 12),

              // --- Repeating Options ---
               SwitchListTile(
                 title: const Text('Repeat Reminder'),
                 value: _isRepeating,
                 onChanged: (bool value) {
                   setState(() {
                     _isRepeating = value;
                     // If turning off repeat, ensure date is not in the past
                     if (!_isRepeating && _selectedDate.isBefore(DateTime.now())) {
                         final now = DateTime.now();
                         _selectedDate = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15 + 1) * 15);
                         if (_selectedDate.isBefore(now)) {
                            _selectedDate = _selectedDate.add(const Duration(hours: 1));
                         }
                     }
                   });
                 },
                 secondary: Icon(_isRepeating ? Icons.repeat_on_rounded : Icons.repeat_rounded),
                  contentPadding: EdgeInsets.zero, // Use padding from parent/SwitchListTile itself
                  dense: true,
                  activeColor: Theme.of(context).primaryColor,
               ),


              // --- Repeat Interval Dropdown (Conditional) ---
              AnimatedSwitcher(
                 duration: const Duration(milliseconds: 300),
                 transitionBuilder: (Widget child, Animation<double> animation) {
                    return SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child);
                 },
                 child: _isRepeating
                     ? Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: DropdownButtonFormField<RepeatInterval>(
                            value: _repeatInterval,
                            items: RepeatInterval.values
                                .where((interval) => interval != RepeatInterval.none) // Exclude 'none' from repeating options
                                .map((RepeatInterval interval) {
                              return DropdownMenuItem<RepeatInterval>(
                                value: interval,
                                child: Text(interval.friendlyName),
                              );
                            }).toList(),
                            onChanged: (RepeatInterval? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _repeatInterval = newValue;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              prefixIcon: Icon(Icons.timer_outlined),
                              border: OutlineInputBorder(),
                               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Match other fields
                            ),
                          ),
                        )
                      : const SizedBox.shrink(), // Show nothing if not repeating
               ),


              const SizedBox(height: 24),

              // --- Schedule Button ---
              ElevatedButton.icon(
                onPressed: _scheduleReminder,
                icon: const Icon(Icons.alarm_add_rounded),
                label: const Text('SCHEDULE REMINDER'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                   textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper to show permission dialog (used in _scheduleReminder) ---
  void _showPermissionDialog(String title, String content, Permission permission) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$title Permission Required'),
        content: Text(content),
        actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(),
             child: const Text('LATER'),
           ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final status = await permission.request();
              if (status.isPermanentlyDenied || status.isDenied) {
                 if(mounted) _showOpenSettingsDialog(title);
              } else if (status.isGranted) {
                 if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title permission granted!')));
                 // Attempt to schedule again after granting
                 await _scheduleReminder();
              }
            },
            child: const Text('GRANT PERMISSION'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: Text('Please grant the $permissionName permission in your device settings to enable this feature.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          TextButton(onPressed: () async { Navigator.of(context).pop(); await openAppSettings(); }, child: const Text('OPEN SETTINGS')),
        ],
      ),
    );
  }
}



// Widget to Display List of Scheduled Reminders
class ScheduledRemindersListWidget extends StatefulWidget {
  const ScheduledRemindersListWidget({Key? key}) : super(key: key);

  @override
  State<ScheduledRemindersListWidget> createState() => _ScheduledRemindersListWidgetState();
}

class _ScheduledRemindersListWidgetState extends State<ScheduledRemindersListWidget> {
  final StudyReminderManager _reminderManager = StudyReminderManager();

  // No need for local list or subscription management if using StreamBuilder directly

  void _showReminderDetails(BuildContext context, StudyReminderNotification reminder) {
    showModalBottomSheet(
      context: context,
       isScrollControlled: true, // Allow sheet to take more height if needed
      builder: (context) => ReminderDetailsBottomSheet(reminder: reminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudyReminderNotification>>(
      stream: _reminderManager.remindersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          // Show loading indicator only if there's no initial data yet
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Error in reminder stream: ${snapshot.error}");
          return Center(child: Text('Error loading reminders: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No reminders scheduled yet.\nUse the form above to add one!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
            ),
          );
        }

        // We have data - display the list
        final reminders = snapshot.data!;

        return ListView.builder(
           padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16), // Add padding around the list
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return ReminderListTile(
              reminder: reminder,
              onTap: () => _showReminderDetails(context, reminder),
              onDelete: () async {
                  // Optional: Confirmation dialog before deleting directly from tile swipe/button
                 final confirm = await showDialog<bool>(
                     context: context,
                     builder: (context) => AlertDialog(
                       title: Text('Delete Reminder?'),
                       content: Text('"${reminder.title}"\n\nAre you sure you want to delete this reminder?'),
                       actions: [
                          TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
                          TextButton(child: Text('Delete', style: TextStyle(color: Colors.red[400])), onPressed: () => Navigator.of(context).pop(true)),
                       ],
                     ),
                  );
                 if (confirm == true) {
                     await _reminderManager.cancelReminder(reminder.id);
                      if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reminder deleted'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating,),
                           );
                      }
                 }
              },
            );
          },
        );
      },
    );
  }
}

// Custom List Tile for Reminders
class ReminderListTile extends StatelessWidget {
  final StudyReminderNotification reminder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ReminderListTile({
    Key? key,
    required this.reminder,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isPast = !reminder.isRepeating && reminder.scheduledTime.isBefore(DateTime.now());
     final Color tileColor = isPast ? Colors.grey.withOpacity(0.5) : Theme.of(context).cardColor; // Use theme's card color or grey out if past
     final Color contentColor = isPast ? Colors.grey[700]! : Theme.of(context).textTheme.bodyLarge!.color!;

    return Card( // Wrap ListTile in a Card for better separation and styling
       color: tileColor, // Apply past styling color
       // elevation: 1, // Use elevation from theme
       // margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Use margin from theme
      child: ListTile(
         // leading: CircleAvatar(
         //   backgroundColor: reminder.color.withOpacity(0.2),
         //   child: Icon(Icons.alarm, color: reminder.color, size: 20),
         // ),
         leading: Container(
            width: 5, // Width of the color bar
             decoration: BoxDecoration(
               color: reminder.color,
               borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), // Match card radius
                  bottomLeft: Radius.circular(12),
                ),
             ),
           ),
         title: Text(
           reminder.title,
           style: TextStyle(
             fontWeight: FontWeight.bold,
             decoration: isPast ? TextDecoration.lineThrough : TextDecoration.none,
             color: contentColor,
           ),
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
         ),
        subtitle: Row( // Use Row for time and repeat icon
           children: [
             Icon(reminder.isRepeating ? Icons.repeat : Icons.access_time, size: 14, color: contentColor.withOpacity(0.7)),
             const SizedBox(width: 4),
             Text(
               '${reminder.formattedTime} - ${reminder.repeatingInfo}',
               style: TextStyle(
                  fontSize: 13,
                 decoration: isPast ? TextDecoration.lineThrough : TextDecoration.none,
                 color: contentColor.withOpacity(0.7),
               ),
             ),
           ],
         ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: isPast ? Colors.grey[600] : Colors.red[300]),
          tooltip: 'Delete Reminder',
          onPressed: onDelete, // Call the provided delete callback
        ),
        onTap: onTap, // Call the provided tap callback
         // dense: true, // Make tile more compact
         contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 6, bottom: 6), // Adjust padding: no left padding for the color bar
      ),
    );
  }
}


// Bottom Sheet for Reminder Details
class ReminderDetailsBottomSheet extends StatelessWidget {
  final StudyReminderNotification reminder;

  const ReminderDetailsBottomSheet({Key? key, required this.reminder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isPast = !reminder.isRepeating && reminder.scheduledTime.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Make sheet wrap content
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Indicator and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
             children: [
               CircleAvatar(backgroundColor: reminder.color, radius: 10),
               const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reminder.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                     overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPast)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Chip(
                      label: const Text('PAST'),
                      labelStyle: TextStyle(fontSize: 10, color: Colors.grey[800]),
                      backgroundColor: Colors.grey[400],
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
             ],
          ),

          const SizedBox(height: 20),

          // Message
          Text(
            'Message',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reminder.message.isEmpty ? '(No message)' : reminder.message,
            style: TextStyle(fontSize: 16, color: reminder.message.isEmpty ? Colors.grey : null),
          ),

          const SizedBox(height: 16),

          // Date and time
          Text(
            'Scheduled For',
             style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event, size: 18, color: reminder.color.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                // Use a more detailed date format here
                DateFormat('EEEE, MMMM d, y').format(reminder.scheduledTime),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: reminder.color.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                DateFormat('h:mm a').format(reminder.scheduledTime), // Keep time format simple
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
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                reminder.isRepeating ? Icons.repeat_on_rounded : Icons.looks_one_outlined,
                size: 18,
                color: reminder.color.withOpacity(0.8),
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

          // --- Action buttons ---
          Row(
            children: [
              // Edit button - Future Feature
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null, // DISABLED - TODO: Implement Edit Functionality
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('EDIT'),
                  style: OutlinedButton.styleFrom(
                     side: BorderSide(color: Colors.grey[400]!),
                     foregroundColor: Colors.grey[600],
                     padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Delete button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Close the bottom sheet first
                    Navigator.of(context).pop();

                    // Confirm Deletion
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Reminder?'),
                        content: Text('Are you sure you want to delete "${reminder.title}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete', style: TextStyle(color: Colors.red[400]))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                        // Delete the reminder using the manager
                        await StudyReminderManager().cancelReminder(reminder.id);
                         // Show confirmation SnackBar (check if mounted)
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reminder deleted'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                    }
                  },
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text('DELETE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          // If past and non-repeating, show recreate button
          if (isPast) ...[
            const SizedBox(height: 16),
            SizedBox( // Ensure button takes full width
               width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Close the bottom sheet
                  Navigator.of(context).pop();

                  // TODO: Implement Recreate Functionality
                  // Ideally, this would open the StudyReminderPickerWidget
                  // pre-filled with the details of 'reminder', allowing the user
                  // to pick a new date/time.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recreate feature coming soon!'),
                       backgroundColor: Colors.blueAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('RECREATE REMINDER'),
                style: ElevatedButton.styleFrom(
                  // Use primary color from theme
                  // backgroundColor: Theme.of(context).primaryColor,
                  // foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                   elevation: 0,
                ),
              ),
            ),
          ],
           const SizedBox(height: 8), // Add padding at the bottom
        ],
      ),
    );
  }
}