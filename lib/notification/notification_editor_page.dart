import 'package:flutter/material.dart';
import 'package:futapedia/notification/scheduled_notification.dart';

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

class _NotificationEditorPageState extends State<NotificationEditorPage> {
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  late TextEditingController _messageController;
  final List<String> _categories = ['Study', 'Assignment', 'Test', 'Study Break', 'Reading Session', 'Group Study'];
  
  // Default notification messages for each category
  final Map<String, String> _defaultMessages = {
    'Study': 'Time to study! Focus on your material for better understanding.',
    'Assignment': 'Don\'t forget to work on your assignment. Deadline is approaching!',
    'Test': 'Prepare for your upcoming test. Review your notes!',
    'Study Break': 'Take a break! Relax and recharge for better productivity.',
    'Reading Session': 'Time to read! Dive into your favorite book or article.',
    'Group Study': 'Join your friends for a group study session. Collaboration is key!',
  };

  // New color map for visual consistency
  final Map<String, Color> _categoryColors = {
    'Study': Colors.blue,
    'Assignment': Colors.orange,
    'Test': Colors.red,
    'Study Break': Colors.green,
    'Reading Session': Colors.purple,
    'Group Study': Colors.teal,
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
      _selectedTime = const TimeOfDay(hour: 20, minute: 0);
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
        leading: IconButton(
            icon: Icon(Icons.chevron_left, size: 35,),
            onPressed: () => Navigator.pop(context),
            color: Colors.white,
        ),
        title: Center(child: Text(widget.existingSchedule == null ? 'New Reminder' : 'Edit Reminder', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
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