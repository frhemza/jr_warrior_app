import 'package:cloud_firestore/cloud_firestore.dart';

class WarriorCode {
  final String codeId;
  final int order;
  final String title;
  final String imageUrl;
  final String description;
  final List<String> instructions;
  final String milestoneReward;

  WarriorCode({
    required this.codeId,
    required this.order,
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.instructions,
    required this.milestoneReward,
  });

  factory WarriorCode.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WarriorCode(
      codeId: doc.id,
      order: (data['order'] as num?)?.toInt() ?? 0,
      title: data['title'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      instructions: List<String>.from(data['instructions'] ?? []),
      milestoneReward: data['milestoneReward'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'title': title,
      'imageUrl': imageUrl,
      'description': description,
      'instructions': instructions,
      'milestoneReward': milestoneReward,
    };
  }
}