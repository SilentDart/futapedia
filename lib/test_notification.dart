// import 'package:flutter/material.dart';
// import 'package:awesome_notifications/awesome_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
  
//   // Initialize the notification service
//   await initializeNotifications();
  
//   runApp(const MyApp());
// }

// Future<void> initializeNotifications() async {
//   await AwesomeNotifications().initialize(
//     null, // notification icon - null for default app icon
//     [
//       NotificationChannel(
//         channelKey: 'scheduled_channel',
//         channelName: 'Scheduled Notifications',
//         channelDescription: 'Channel for scheduled notifications',
//         defaultColor: Colors.blue,
//         ledColor: Colors.blue,
//         importance: NotificationImportance.High,
//         locked: false,
//         defaultRingtoneType: DefaultRingtoneType.Notification,
//       )
//     ],
//     debug: true,
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Notification Demo',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: const NotificationPage(),
//     );
//   }
// }

// class NotificationPage extends StatefulWidget {
//   const NotificationPage({Key? key}) : super(key: key);

//   @override
//   _NotificationPageState createState() => _NotificationPageState();
// }

// class _NotificationPageState extends State<NotificationPage> {
//   TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0); // Default time: 20:00
//   bool _notificationsEnabled = false;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _checkPermissions();
//     _loadSavedTime();
//   }

//   Future<void> _loadSavedTime() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hour = prefs.getInt('notification_hour') ?? 20;
//     final minute = prefs.getInt('notification_minute') ?? 0;
    
//     setState(() {
//       _selectedTime = TimeOfDay(hour: hour, minute: minute);
//       _isLoading = false;
//     });
//   }

//   Future<void> _saveSelectedTime() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('notification_hour', _selectedTime.hour);
//     await prefs.setInt('notification_minute', _selectedTime.minute);
//   }

//   Future<void> _checkPermissions() async {
//     final isAllowed = await AwesomeNotifications().isNotificationAllowed();
//     setState(() {
//       _notificationsEnabled = isAllowed;
//     });
    
//     if (!isAllowed) {
//       _requestPermissions();
//     }
//   }

//   Future<void> _requestPermissions() async {
//     await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Allow Notifications'),
//         content: const Text(
//           'Our app would like to send you notifications to keep you updated.'
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Don\'t Allow', style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               await AwesomeNotifications().requestPermissionToSendNotifications();
//               final isAllowed = await AwesomeNotifications().isNotificationAllowed();
//               setState(() {
//                 _notificationsEnabled = isAllowed;
//               });
//             },
//             child: const Text('Allow', style: TextStyle(color: Colors.blue)),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _selectTime(BuildContext context) async {
//     final TimeOfDay? pickedTime = await showTimePicker(
//       context: context,
//       initialTime: _selectedTime,
//       builder: (context, child) {
//         return Theme(
//           data: ThemeData.light().copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//               surface: Colors.white,
//               onSurface: Colors.black,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
    
//     if (pickedTime != null && pickedTime != _selectedTime) {
//       setState(() {
//         _selectedTime = pickedTime;
//       });
//       await _saveSelectedTime();
//       await _scheduleNotification();
//     }
//   }

//   Future<void> _scheduleNotification() async {
//     if (!_notificationsEnabled) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Notifications are not enabled')),
//       );
//       return;
//     }

//     // Cancel any existing notifications
//     await AwesomeNotifications().cancelAll();

//     // Get the current date for scheduling
//     final now = DateTime.now();
    
//     // Create a DateTime with the selected time
//     DateTime scheduledDate = DateTime(
//       now.year, 
//       now.month, 
//       now.day, 
//       _selectedTime.hour, 
//       _selectedTime.minute
//     );
    
//     // If the time for today has already passed, schedule for tomorrow
//     if (scheduledDate.isBefore(now)) {
//       scheduledDate = scheduledDate.add(const Duration(days: 1));
//     }

//     await AwesomeNotifications().createNotification(
//       content: NotificationContent(
//         id: 1,
//         channelKey: 'scheduled_channel',
//         title: 'Important Reminder',
//         body: 'This is your daily notification. Stay productive!', // Placeholder message
//         notificationLayout: NotificationLayout.Default,
//       ),
//       schedule: NotificationCalendar(
//         year: scheduledDate.year,
//         month: scheduledDate.month,
//         day: scheduledDate.day,
//         hour: scheduledDate.hour,
//         minute: scheduledDate.minute,
//         second: 0,
//         repeats: true, // Repeat daily
//       ),
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           'Notification scheduled for ${_selectedTime.format(context)} daily',
//         ),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
    
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Notification Settings'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 4,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Notification Status',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           _notificationsEnabled 
//                               ? 'Notifications are enabled' 
//                               : 'Notifications are disabled',
//                           style: TextStyle(
//                             color: _notificationsEnabled ? Colors.green : Colors.red,
//                           ),
//                         ),
//                         if (!_notificationsEnabled)
//                           ElevatedButton(
//                             onPressed: _requestPermissions,
//                             child: const Text('Enable'),
//                           ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//             Card(
//               elevation: 4,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Schedule Notification Time',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Current time: ${_selectedTime.format(context)}',
//                           style: const TextStyle(fontSize: 16),
//                         ),
//                         ElevatedButton(
//                           onPressed: () => _selectTime(context),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.blue,
//                             foregroundColor: Colors.white,
//                           ),
//                           child: const Text('Change Time'),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     const Divider(),
//                     const SizedBox(height: 16),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _scheduleNotification,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green,
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         child: const Text(
//                           'Save & Schedule Notification',
//                           style: TextStyle(fontSize: 16),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//             const Card(
//               elevation: 4,
//               child: Padding(
//                 padding: EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'About Notifications',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Notifications will be sent daily at your selected time. '
//                       'You can change the time at any point.',
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Don't forget to listen to notification actions if needed:
// // AwesomeNotifications().actionStream.listen((ReceivedNotification receivedNotification) {
// //   // Handle notification actions
// // });




import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the notification service
  await initializeNotifications();
  
  // Register notification background handler
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onActionReceivedMethod,
  );
  
  runApp(const MyApp());
}

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
  
  // Request notification permissions on app start
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      // This will be handled in the SchedulerHomePage
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add this line
      title: 'Student Scheduler',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SchedulerHomePage(),
    );
  }
}

// Model for scheduled notifications
class ScheduledNotification {
  final int id;
  final String category;
  final String message;
  final TimeOfDay time;

  ScheduledNotification({
    required this.id,
    required this.category,
    required this.message,
    required this.time,
  });

  // Convert to map for SharedPreferences
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'message': message,
      'hour': time.hour,
      'minute': time.minute,
    };
  }

  // Create from map for SharedPreferences
  factory ScheduledNotification.fromMap(Map<String, dynamic> map) {
    return ScheduledNotification(
      id: map['id'],
      category: map['category'],
      message: map['message'],
      time: TimeOfDay(hour: map['hour'], minute: map['minute']),
    );
  }
}

class SchedulerHomePage extends StatefulWidget {
  const SchedulerHomePage({Key? key}) : super(key: key);

  @override
  _SchedulerHomePageState createState() => _SchedulerHomePageState();
}

class _SchedulerHomePageState extends State<SchedulerHomePage> {
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  List<ScheduledNotification> _schedules = [];
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadSchedules();
    
    // Set up notification action listener
    AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onActionReceivedMethod,
  );
  }

  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesCount = prefs.getInt('schedules_count') ?? 0;
    
    List<ScheduledNotification> loadedSchedules = [];
    
    for (int i = 0; i < schedulesCount; i++) {
      final id = prefs.getInt('schedule_${i}_id');
      final category = prefs.getString('schedule_${i}_category');
      final message = prefs.getString('schedule_${i}_message');
      final hour = prefs.getInt('schedule_${i}_hour');
      final minute = prefs.getInt('schedule_${i}_minute');
      
      // Only add if all required data is available
      if (id != null && category != null && message != null && 
          hour != null && minute != null) {
        loadedSchedules.add(ScheduledNotification(
          id: id,
          category: category,
          message: message,
          time: TimeOfDay(hour: hour, minute: minute),
        ));
      }
    }
    
    setState(() {
      _schedules = loadedSchedules;
      _isLoading = false;
    });
    
    // Make sure notifications are up to date after loading
    await _updateNotifications();
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('schedules_count', _schedules.length);
    
    for (int i = 0; i < _schedules.length; i++) {
      final schedule = _schedules[i];
      await prefs.setInt('schedule_${i}_id', schedule.id);
      await prefs.setString('schedule_${i}_category', schedule.category);
      await prefs.setString('schedule_${i}_message', schedule.message);
      await prefs.setInt('schedule_${i}_hour', schedule.time.hour);
      await prefs.setInt('schedule_${i}_minute', schedule.time.minute);
    }
    
    // Clear any excess saved schedules if items were deleted
    final oldCount = prefs.getInt('schedules_count') ?? 0;
    for (int i = _schedules.length; i < oldCount; i++) {
      await prefs.remove('schedule_${i}_id');
      await prefs.remove('schedule_${i}_category');
      await prefs.remove('schedule_${i}_message');
      await prefs.remove('schedule_${i}_hour');
      await prefs.remove('schedule_${i}_minute');
    }
    
    // Update notifications after saving
    await _updateNotifications();
  }

  Future<void> _checkPermissions() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    setState(() {
      _notificationsEnabled = isAllowed;
    });
    
    if (!isAllowed) {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Notifications'),
        content: const Text(
          'Our app would like to send you notifications to keep you updated on your academic schedule.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Don\'t Allow', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AwesomeNotifications().requestPermissionToSendNotifications();
              final isAllowed = await AwesomeNotifications().isNotificationAllowed();
              setState(() {
                _notificationsEnabled = isAllowed;
              });
            },
            child: const Text('Allow', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _addEditSchedule({ScheduledNotification? schedule}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationEditorPage(
          existingSchedule: schedule,
          scheduleIds: _schedules.map((s) => s.id).toList(),
        ),
      ),
    );
    
    if (result != null && result is ScheduledNotification) {
      setState(() {
        // If editing, replace the existing schedule
        if (schedule != null) {
          final index = _schedules.indexWhere((s) => s.id == schedule.id);
          if (index >= 0) {
            _schedules[index] = result;
          }
        } else {
          // Add new schedule
          _schedules.add(result);
        }
      });
      
      await _saveSchedules();
      await _updateNotifications();
    }
  }

  Future<void> _deleteSchedule(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this scheduled reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _schedules.removeWhere((schedule) => schedule.id == id);
              });
              
              await _saveSchedules();
              await _updateNotifications();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Schedule deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNotifications() async {
    if (!_notificationsEnabled) return;
    
    // Cancel all existing notifications
    await AwesomeNotifications().cancelAll();
    
    // Schedule all current notifications
    for (final schedule in _schedules) {
      await _scheduleNotification(schedule);
    }
    
    // Show a confirmation toast
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminders updated successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }


  Future<void> _scheduleNotification(ScheduledNotification schedule) async {
    // Get the current date for scheduling
    final now = DateTime.now();
    
    // Create a DateTime with the selected time
    DateTime scheduledDate = DateTime(
      now.year, 
      now.month, 
      now.day, 
      schedule.time.hour, 
      schedule.time.minute
    );
    
    // If the time for today has already passed, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Create the notification with improved content
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: schedule.id,
        channelKey: 'scheduled_channel',
        title: '${schedule.category} Reminder',
        body: schedule.message,
        notificationLayout: NotificationLayout.Default,
        color: _getCategoryColor(schedule.category),
        category: NotificationCategory.Reminder,
      ),
      schedule: NotificationCalendar(
        year: scheduledDate.year,
        month: scheduledDate.month,
        day: scheduledDate.day,
        hour: scheduledDate.hour,
        minute: scheduledDate.minute,
        second: 0,
        repeats: true, // Repeat daily
        preciseAlarm: true, // For exact alarm timing
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Study':
        return Colors.blue;
      case 'Assignment':
        return Colors.orange;
      case 'Test':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(TimeOfDay time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _getCategoryIcon(String category) {
    IconData iconData;
    Color iconColor;
    
    switch (category) {
      case 'Study':
        iconData = Icons.book;
        iconColor = Colors.blue;
        break;
      case 'Assignment':
        iconData = Icons.assignment;
        iconColor = Colors.orange;
        break;
      case 'Test':
        iconData = Icons.quiz;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }
    
    return Icon(iconData, color: iconColor);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Scheduler'),
        actions: [
          if (!_notificationsEnabled)
            IconButton(
              icon: const Icon(Icons.notifications_off),
              onPressed: _requestPermissions,
              tooltip: 'Enable Notifications',
            ),
        ],
      ),
      body: _schedules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No reminders scheduled',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to create a new reminder',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: _getCategoryIcon(schedule.category),
                    ),
                    title: Text(
                      schedule.category,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      schedule.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(schedule.time),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _addEditSchedule(schedule: schedule);
                            } else if (value == 'delete') {
                              _deleteSchedule(schedule.id);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _addEditSchedule(schedule: schedule),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEditSchedule(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NotificationEditorPage extends StatefulWidget {
  final ScheduledNotification? existingSchedule;
  final List<int> scheduleIds;

  const NotificationEditorPage({
    Key? key,
    this.existingSchedule,
    required this.scheduleIds,
  }) : super(key: key);

  @override
  _NotificationEditorPageState createState() => _NotificationEditorPageState();
}

// Replace the entire _NotificationEditorPageState class with this improved version
class _NotificationEditorPageState extends State<NotificationEditorPage> {
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  late TextEditingController _messageController;
  final List<String> _categories = ['Study', 'Assignment', 'Test'];
  
  // Default notification messages for each category
  final Map<String, String> _defaultMessages = {
    'Study': 'Time to study! Focus on your material for better understanding.',
    'Assignment': 'Don\'t forget to work on your assignment. Deadline is approaching!',
    'Test': 'Prepare for your upcoming test. Review your notes!',
  };

  // New color map for visual consistency
  final Map<String, Color> _categoryColors = {
    'Study': Colors.blue,
    'Assignment': Colors.orange,
    'Test': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    
    if (widget.existingSchedule != null) {
      // Editing existing schedule
      _selectedTime = widget.existingSchedule!.time;
      _selectedCategory = widget.existingSchedule!.category;
      _messageController = TextEditingController(text: widget.existingSchedule!.message);
    } else {
      // Creating new schedule
      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
      _selectedCategory = 'Study';
      _messageController = TextEditingController(text: _defaultMessages['Study']);
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _categoryColors[_selectedCategory] ?? Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  void _updateCategory(String? category) {
    if (category != null && category != _selectedCategory) {
      setState(() {
        _selectedCategory = category;
        
        // Only update message if it's a default message or empty
        final currentMsg = _messageController.text;
        if (currentMsg.isEmpty || _defaultMessages.values.contains(currentMsg)) {
          _messageController.text = _defaultMessages[category]!;
        }
      });
    }
  }

  void _saveSchedule() {
    // Generate a new unique ID if creating a new schedule
    final int id = widget.existingSchedule?.id ?? 
                  (_getNextAvailableId(widget.scheduleIds));
    
    final schedule = ScheduledNotification(
      id: id,
      category: _selectedCategory,
      message: _messageController.text.isNotEmpty 
              ? _messageController.text 
              : _defaultMessages[_selectedCategory]!,
      time: _selectedTime,
    );
    
    Navigator.pop(context, schedule);
  }
  
  int _getNextAvailableId(List<int> existingIds) {
    if (existingIds.isEmpty) return 1;
    existingIds.sort();
    return existingIds.last + 1;
  }

  @override
  Widget build(BuildContext context) {
    // Get the current primary color based on category
    final Color primaryColor = _categoryColors[_selectedCategory] ?? Colors.blue;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingSchedule == null ? 'New Reminder' : 'Edit Reminder'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Category selector with visual representation
            Container(
              color: primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.2),
                    radius: 24,
                    child: _getCategoryIcon(_selectedCategory),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Reminder Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: _getCategoryIcon(category),
                              ),
                              const SizedBox(width: 8),
                              Text(category),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _updateCategory,
                    ),
                  ),
                ],
              ),
            ),
            
            // Time selector with intuitive display
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
                ),
                child: InkWell(
                  onTap: () => _selectTime(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'When do you want to be reminded?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, color: primaryColor, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedTime.format(context),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.edit, color: Colors.grey.shade600),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Repeats daily',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Message input with improved UI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reminder Message',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'What do you want to remember?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _messageController.text = _defaultMessages[_selectedCategory]!;
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Use default message'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Preview section (NEW)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 1,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: _getCategoryIcon(_selectedCategory),
                          ),
                          title: Text(
                            '${_selectedCategory} Reminder',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _messageController.text.isEmpty 
                                ? _defaultMessages[_selectedCategory]!
                                : _messageController.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _selectedTime.format(context),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.existingSchedule == null ? 'Create Reminder' : 'Save Changes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _getCategoryIcon(String category) {
    IconData iconData;
    Color iconColor = _categoryColors[category] ?? Colors.grey;
    
    switch (category) {
      case 'Study':
        iconData = Icons.book;
        break;
      case 'Assignment':
        iconData = Icons.assignment;
        break;
      case 'Test':
        iconData = Icons.quiz;
        break;
      default:
        iconData = Icons.notifications;
    }
    
    return Icon(iconData, color: iconColor);
  }
}


class NotificationController {
  /// Use this method to detect when the user taps on a notification
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // Navigate to home page or perform other actions when notification is tapped
    if (receivedAction.channelKey == 'scheduled_channel') {
      // For navigation, you'll need to use a navigation key since this 
      // is called outside of the widget context
      MyApp.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SchedulerHomePage()),
        (route) => false,
      );
    }
  }
}