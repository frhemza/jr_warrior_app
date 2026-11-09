import 'package:cloud_firestore/cloud_firestore.dart';

class Child {
  final String id;
  final String parentId;
  final String name;
  final int age;
  final String feeStatus;
  final String status; // 'in_progress', 'pending_approval', 'completed'
  final String currentCodeId;
  final List<String> codesCompleted;
  final List<String> trophiesEarned;
  final DateTime? lastActive;

  Child({
    required this.id,
    required this.parentId,
    required this.name,
    required this.age,
    required this.feeStatus,
    required this.status,
    required this.currentCodeId,
    required this.codesCompleted,
    required this.trophiesEarned,
    this.lastActive,
  });

  String get childId => id;
  String get fullName => name;
  bool get isInProgress => status == 'in_progress';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isCompleted => status == 'completed';
  DateTime get lastProgressUpdate => lastActive ?? DateTime.now();

  factory Child.fromMap(String id, Map<String, dynamic> map) {
    return Child(
      id: id,
      parentId: map['parentId'] ?? '',
      name: map['name'] ?? map['fullName'] ?? '',
      age: map['age'] ?? 0,
      feeStatus: map['feeStatus'] ?? 'paid',
      status: map['status'] ?? 'in_progress',
      currentCodeId: map['currentCodeId'] ?? map['codeId'] ?? 'code_1',
      codesCompleted: List<String>.from(map['codesCompleted'] ?? []),
      trophiesEarned: List<String>.from(map['trophiesEarned'] ?? []),
      lastActive: (map['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  factory Child.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Child.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'parentId': parentId,
      'name': name,
      'age': age,
      'feeStatus': feeStatus,
      'status': status,
      'currentCodeId': currentCodeId,
      'codesCompleted': codesCompleted,
      'trophiesEarned': trophiesEarned,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : FieldValue.serverTimestamp(),
    };
  }
}