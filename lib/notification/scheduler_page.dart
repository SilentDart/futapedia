import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:futapedia/notification/notification_editor_page.dart';
import 'package:futapedia/notification/scheduled_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SchedulerPage extends StatefulWidget {
  const SchedulerPage({Key? key}) : super(key: key);

  @override
  _SchedulerPageState createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  List<ScheduledNotification> _schedules = [];
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadSchedules();
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
              if(mounted){
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule deleted')),
                );
              }
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
    if(!mounted) return;
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
      case 'Study Break':
        return Colors.green;
      case 'Reading Session':
        return Colors.purple;
      case 'Group Study': 
        return Colors.brown;
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
      case 'Study Break':
        iconData = Icons.free_breakfast;
        iconColor = Colors.green;
        break;
      case 'Reading Session': 
        iconData = Icons.library_books;
        iconColor = Colors.purple;
        break;
      case 'Group Study':
        iconData = Icons.group;
        iconColor = Colors.brown;
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
        title: const Text('Study Reminders',style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: Icon(Icons.chevron_left, size: 35,),
            onPressed: () => Navigator.pop(context),
        ),
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
        backgroundColor: Colors.grey,
        child: const Icon(Icons.add),
      ),
    );
  }
}