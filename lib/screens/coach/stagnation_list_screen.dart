import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Fix: package: instead of package0:
import '../../models/child.dart';

class StagnationListScreen extends StatelessWidget {
  const StagnationListScreen({super.key});

  Future<void> _sendNudge(BuildContext context, String childName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nudge notification sent for $childName!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 14));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('children')
          .where('status', isEqualTo: 'in_progress')
          .where('lastProgressUpdate', isLessThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_outlined, size: 48, color: Color(0xFF1A2F25)),
                const SizedBox(height: 12),
                Text(
                  'All Warriors Active',
                  style: GoogleFonts.sourceSerif4(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'No children inactive for 14+ days.',
                  style: GoogleFonts.sourceSans3(color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final child = Child.fromDoc(docs[index]);
            final daysInactive = DateTime.now().difference(child.lastProgressUpdate).inDays;

            return Card(
              color: const Color(0xFFFFF8F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFFC85A32).withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3E2B3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFF8A6A12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.fullName,
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2F25),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Inactive for $daysInactive days',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 13,
                              color: const Color(0xFFC85A32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendNudge(context, child.fullName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC85A32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Send Nudge'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}