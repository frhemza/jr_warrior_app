import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String category; // e.g., 'Discipline', 'Mindset', 'Nutrition'
  final String readTime; // e.g., '3 min read'
  final DateTime createdAt;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.readTime,
    required this.createdAt,
  });

  factory Article.fromMap(String id, Map<String, dynamic> map) {
    return Article(
      id: id,
      title: map['title'] ?? '',
      summary: map['summary'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'General',
      readTime: map['readTime'] ?? '2 min read',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Article.fromDoc(DocumentSnapshot doc) {
    return Article.fromMap(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'readTime': readTime,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}