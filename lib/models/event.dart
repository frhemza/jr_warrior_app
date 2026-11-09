import 'package:cloud_firestore/cloud_firestore.dart';

class UpcomingEvent {
  final String id;
  final String title;
  final String category; // e.g., "Guest Day - Taekwondo", "Special Class"
  final DateTime eventDate;
  final String description;

  UpcomingEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.eventDate,
    required this.description,
  });

  factory UpcomingEvent.fromMap(String id, Map<String, dynamic> map) {
    return UpcomingEvent(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? 'Event',
      eventDate: (map['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'eventDate': Timestamp.fromDate(eventDate),
      'description': description,
    };
  }
}