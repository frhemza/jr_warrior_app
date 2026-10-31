import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Fix: package: instead of package0:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stagnation_list_screen.dart';

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  int _selectedTab = 0; // 0 = Approval Queue, 1 = Inactive Warriors

  Future<void> _approveSubmission(
    BuildContext context,
    String queueId,
    String childId,
    String codeId,
  ) async {
    final firestore = FirebaseFirestore.instance;

    try {
      await firestore.runTransaction((transaction) async {
        final childRef = firestore.collection('children').doc(childId);
        final queueRef = firestore.collection('approvals_queue').doc(queueId);

        final childSnap = await transaction.get(childRef);
        if (!childSnap.exists) return;

        final currentTrophies = List<String>.from(childSnap.data()?['trophiesEarned'] ?? []);
        if (!currentTrophies.contains(codeId)) {
          currentTrophies.add(codeId);
        }

        // Parse order to increment next code (code_01 -> code_02)
        int currentOrder = 1;
        if (codeId.contains('_')) {
          currentOrder = int.tryParse(codeId.split('_').last) ?? 1;
        }
        final nextCodeId = 'code_${(currentOrder + 1).toString().padLeft(2, '0')}';

        transaction.update(childRef, {
          'status': 'in_progress',
          'currentCodeId': nextCodeId,
          'trophiesEarned': currentTrophies,
          'lastProgressUpdate': FieldValue.serverTimestamp(),
        });

        transaction.update(queueRef, {
          'status': 'approved',
          'processedAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Practice approved! Warrior advanced.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving submission: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showReturnDialog(BuildContext context, String queueId, String childId) {
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFBF9F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send Back with Feedback',
              style: GoogleFonts.sourceSerif4(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2F25),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add encouragement or specific guidance for practice...',
                hintStyle: GoogleFonts.sourceSans3(color: Colors.black38),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF1A2F25).withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final note = noteController.text.trim();
                Navigator.pop(ctx);
                await _returnSubmission(context, queueId, childId, note);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC85A32),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Submit Feedback',
                style: GoogleFonts.sourceSans3(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _returnSubmission(
    BuildContext context,
    String queueId,
    String childId,
    String note,
  ) async {
    final firestore = FirebaseFirestore.instance;

    try {
      await firestore.runTransaction((transaction) async {
        final childRef = firestore.collection('children').doc(childId);
        final queueRef = firestore.collection('approvals_queue').doc(queueId);

        transaction.update(childRef, {
          'status': 'in_progress',
        });

        transaction.update(queueRef, {
          'status': 'returned',
          'coachNote': note,
          'processedAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Returned to parent with guidance note.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error returning submission: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Coach Portal',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Approval Queue',
                    icon: Icons.fact_check_outlined,
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TabButton(
                    label: 'Stagnant Warriors',
                    icon: Icons.report_problem_outlined,
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? _buildApprovalQueueList()
                : const StagnationListScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalQueueList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('approvals_queue')
          .where('status', isEqualTo: 'pending')
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
                const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF1A2F25)),
                const SizedBox(height: 12),
                Text(
                  'Queue Clear',
                  style: GoogleFonts.sourceSerif4(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'No pending practices awaiting review.',
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
            final data = docs[index].data();
            final queueId = docs[index].id;
            final childId = data['childId'] ?? '';
            final codeId = data['codeId'] ?? '';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['childName'] ?? 'Warrior',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A2F25),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC85A32).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pending Approval',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 12,
                              color: const Color(0xFFC85A32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Code: ${data['codeTitle'] ?? codeId}',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showReturnDialog(context, queueId, childId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC85A32),
                              side: const BorderSide(color: Color(0xFFC85A32)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Send Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveSubmission(context, queueId, childId, codeId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A2F25),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Approve'),
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
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A2F25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}