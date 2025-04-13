import 'package:flutter/material.dart';

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