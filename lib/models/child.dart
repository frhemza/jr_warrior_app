import 'package:cloud_firestore/cloud_firestore.dart';

class Child {
  final String childId;
  final String parentId;
  final String fullName;
  final String currentCodeId;
  final String status; // 'in_progress' | 'pending_approval' | 'completed'
  final List<String> trophiesEarned;
  final DateTime lastProgressUpdate;

  Child({
    required this.childId,
    required this.parentId,
    required this.fullName,
    required this.currentCodeId,
    required this.status,
    required this.trophiesEarned,
    required this.lastProgressUpdate,
  });

  // Helper Getters expected by UI Screens
  bool get isInProgress => status == 'in_progress';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isCompleted => status == 'completed';

  bool isInactive({int thresholdDays = 14}) {
    return DateTime.now().difference(lastProgressUpdate).inDays >= thresholdDays;
  }

  factory Child.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Child(
      childId: doc.id,
      parentId: data['parentId'] ?? '',
      fullName: data['fullName'] ?? '',
      currentCodeId: data['currentCodeId'] ?? '',
      status: data['status'] ?? 'in_progress',
      trophiesEarned: List<String>.from(data['trophiesEarned'] ?? []),
      lastProgressUpdate: _parseDateTime(data['lastProgressUpdate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parentId': parentId,
      'fullName': fullName,
      'currentCodeId': currentCodeId,
      'status': status,
      'trophiesEarned': trophiesEarned,
      'lastProgressUpdate': Timestamp.fromDate(lastProgressUpdate),
    };
  }

  static DateTime _parseDateTime(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    } else if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }
}