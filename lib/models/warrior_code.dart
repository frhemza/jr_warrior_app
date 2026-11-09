import 'package:cloud_firestore/cloud_firestore.dart';

class WarriorCode {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String parentInstructions;
  final List<String> instructionsList;
  final String milestoneReward;
  final int order;

  WarriorCode({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.parentInstructions,
    required this.instructionsList,
    required this.milestoneReward,
    required this.order,
  });

  String get codeId => id;

  List<String> get instructions => instructionsList.isNotEmpty
      ? instructionsList
      : (parentInstructions.isNotEmpty ? [parentInstructions] : const <String>[]);

  factory WarriorCode.fromMap(String id, Map<String, dynamic> map) {
    final rawInstructions = map['instructions'];
    List<String> parsedInstructions = [];
    if (rawInstructions is List) {
      parsedInstructions = List<String>.from(rawInstructions);
    }

    return WarriorCode(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      parentInstructions: map['parentInstructions'] ?? '',
      instructionsList: parsedInstructions,
      milestoneReward: map['milestoneReward'] ?? '',
      order: map['order'] ?? 0,
    );
  }

  factory WarriorCode.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return WarriorCode.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'parentInstructions': parentInstructions,
      'instructions': instructionsList,
      'milestoneReward': milestoneReward,
      'order': order,
    };
  }
}