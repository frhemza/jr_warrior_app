import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory Notice.fromMap(String id, Map<String, dynamic> map) {
    return Notice(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}