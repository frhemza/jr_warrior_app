import 'package:cloud_firestore/cloud_firestore.dart';

class ClassHighlight {
  final String id;
  final String title;
  final String mediaUrl; // Image or video link
  final String caption;
  final DateTime createdAt;

  ClassHighlight({
    required this.id,
    required this.title,
    required this.mediaUrl,
    required this.caption,
    required this.createdAt,
  });

  factory ClassHighlight.fromMap(String id, Map<String, dynamic> map) {
    return ClassHighlight(
      id: id,
      title: map['title'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      caption: map['caption'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}