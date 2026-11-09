import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class CoachAccountRequestsScreen extends StatelessWidget {
  const CoachAccountRequestsScreen({super.key});

  void _approveDeletion(BuildContext context, String reqId, String parentId) async {
    try {
      // 1. Delete associated child roster profiles
      final childrenQuery = await FirebaseFirestore.instance
          .collection('children')
          .where('parentId', isEqualTo: parentId)
          .get();

      for (var doc in childrenQuery.docs) {
        await doc.reference.delete();
      }

      // 2. Delete parent user profile record
      await FirebaseFirestore.instance.collection('users').doc(parentId).delete();

      // 3. Mark deletion request completed/approved
      await FirebaseFirestore.instance.collection('account_deletion_requests').doc(reqId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion approved and account removed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _rejectDeletion(BuildContext context, String reqId) async {
    await FirebaseFirestore.instance.collection('account_deletion_requests').doc(reqId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deletion request rejected.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        title: const Text('Account Requests'),
        backgroundColor: kDeepOlive,
        foregroundColor: kWarmCream,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('account_deletion_requests')
            .where('status', isEqualTo: 'pending_coach_approval')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kTerracotta));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No pending account deletion requests.',
                style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final parentName = data['parentName'] ?? 'Parent';
              final parentEmail = data['parentEmail'] ?? '';
              final parentId = data['parentId'] ?? '';

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            parentName,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kDeepOlive,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Deletion Request',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Email: $parentEmail',
                        style: GoogleFonts.sourceSans3(fontSize: 13, color: kDeepOlive.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rejectDeletion(context, doc.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kDeepOlive,
                                side: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approveDeletion(context, doc.id, parentId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade800,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approve & Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}