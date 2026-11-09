import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class CoachApprovedCodesHistoryScreen extends StatelessWidget {
  const CoachApprovedCodesHistoryScreen({super.key});

  Future<void> _revokeApprovedCode({
    required BuildContext context,
    required String childId,
    required String codeId,
    required String warriorName,
    required String codeTitle,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text(
          'Revoke Approval?',
          style: GoogleFonts.sourceSans3(
            color: kDeepOlive,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to reject "$codeTitle" for $warriorName? This code will become locked for the warrior until re-practiced and re-submitted.',
          style: GoogleFonts.sourceSans3(color: kDeepOlive),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoke & Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Remove codeId from child's completed list in Firestore
      await firestore.collection('children').doc(childId).update({
        'codesCompleted': FieldValue.arrayRemove([codeId]),
        'lastActive': FieldValue.serverTimestamp(),
      });

      // 2. Mark approval queue submission doc as rejected
      final approvalDocs = await firestore
          .collection('approvals_queue')
          .where('childId', isEqualTo: childId)
          .where('codeId', isEqualTo: codeId)
          .get();

      for (final doc in approvalDocs.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'revokedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'Revoked by coach from history archive',
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revoked approval for $warriorName ($codeTitle).'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error revoking code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        backgroundColor: kDeepOlive,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Approved Codes & Revocation',
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('approvals_queue')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, approvalsSnapshot) {
          if (approvalsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kTerracotta));
          }

          if (!approvalsSnapshot.hasData || approvalsSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined, size: 64, color: kDeepOlive.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'No previously approved codes found.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      color: kDeepOlive.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final approvedDocs = approvalsSnapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: approvedDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = approvedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final childName = data['childName'] ?? 'Warrior';
              final codeTitle = data['codeTitle'] ?? 'Warrior Code';
              final childId = data['childId'] ?? '';
              final codeId = data['codeId'] ?? '';
              final String? photoBase64 = data['photoBase64'] as String?;

              return Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: kDeepOlive,
                            backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                                ? MemoryImage(base64Decode(photoBase64))
                                : null,
                            child: (photoBase64 == null || photoBase64.isEmpty)
                                ? Text(
                                    childName.isNotEmpty ? childName[0].toUpperCase() : 'W',
                                    style: GoogleFonts.sourceSans3(
                                      color: kWarmCream,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  childName,
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kDeepOlive,
                                  ),
                                ),
                                Text(
                                  'Approved Code: $codeTitle',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 13,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _revokeApprovedCode(
                            context: context,
                            childId: childId,
                            codeId: codeId,
                            warriorName: childName,
                            codeTitle: codeTitle,
                          ),
                          icon: const Icon(Icons.undo_rounded, size: 18, color: Colors.red),
                          label: const Text('Revoke Approval'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
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