import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class CoachArchiveScreen extends StatefulWidget {
  const CoachArchiveScreen({super.key});

  @override
  State<CoachArchiveScreen> createState() => _CoachArchiveScreenState();
}

class _CoachArchiveScreenState extends State<CoachArchiveScreen> {
  // Helper method to open WhatsApp with a pre-filled personalized message
  Future<void> _openWhatsAppForParent({
    required String parentPhone,
    required String childName,
    required String parentName,
    required int daysInactive,
  }) async {
    String phoneToUse = parentPhone.trim();

    // If no phone number stored directly on child record, try querying parent document
    if (phoneToUse.isEmpty) {
      try {
        final parentQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: parentName)
            .limit(1)
            .get();

        if (parentQuery.docs.isNotEmpty) {
          final parentData = parentQuery.docs.first.data();
          phoneToUse = (parentData['phone'] ?? parentData['parentPhone'] ?? '').toString().trim();
        }
      } catch (_) {}
    }

    if (phoneToUse.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone number recorded for this parent in Firestore.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Format phone to international digits (e.g. 03001234567 -> 923001234567)
    String cleanPhone = phoneToUse.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '92${cleanPhone.substring(1)}';
    }

    // Pre-written text draft
    final String messageText =
        'Hi $parentName! This is Coach from Jr. Warrior App. 👋\n\n'
        'We noticed that $childName hasn\'t completed a Warrior Code in over $daysInactive days. '
        'Is everything okay? Let me know if you need any guidance with home practice!';

    final String encodedMsg = Uri.encodeComponent(messageText);
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch WhatsApp for $cleanPhone. Ensure WhatsApp is installed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEnlargedImage(BuildContext context, String base64Str) {
    final cleanBase64 = base64Str.contains(',') ? base64Str.split(',').last : base64Str;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  base64Decode(cleanBase64),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to revoke code approval from the Approved Codes tab
  Future<void> _revokeApprovedCode({
    required BuildContext context,
    required String approvalDocId,
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
      if (childId.isNotEmpty) {
        final childDocRef = firestore.collection('children').doc(childId);
        final childSnap = await childDocRef.get();

        if (childSnap.exists) {
          await childDocRef.update({
            'codesCompleted': FieldValue.arrayRemove([codeId]),
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }

      await firestore.collection('approvals_queue').doc(approvalDocId).update({
        'status': 'rejected',
        'revokedAt': FieldValue.serverTimestamp(),
        'rejectionReason': 'Revoked by coach from history tab',
      });

      if (childId.isNotEmpty && codeId.isNotEmpty) {
        final matchingDocs = await firestore
            .collection('approvals_queue')
            .where('childId', isEqualTo: childId)
            .where('codeId', isEqualTo: codeId)
            .get();

        for (final d in matchingDocs.docs) {
          if (d.id != approvalDocId) {
            await d.reference.update({
              'status': 'rejected',
              'revokedAt': FieldValue.serverTimestamp(),
            });
          }
        }
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kWarmCream,
        appBar: AppBar(
          backgroundColor: kWarmCream,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kDeepOlive),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'History & Archives',
            style: GoogleFonts.sourceSans3(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: kDeepOlive,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: kDeepOlive.withOpacity(0.12), width: 1),
                ),
              ),
              child: TabBar(
                indicatorColor: kTerracotta,
                indicatorWeight: 3,
                labelColor: kTerracotta,
                unselectedLabelColor: kDeepOlive.withOpacity(0.6),
                labelStyle: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Approved Codes'),
                  Tab(text: 'Inactive & Stagnated Warriors'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildApprovedCodesTab(context),
            _buildStagnatedWarriorsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedCodesTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
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

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kDeepOlive.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: kDeepOlive.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Fetch & display warrior's actual profile picture
                          FutureBuilder<DocumentSnapshot>(
                            future: childId.isNotEmpty
                                ? FirebaseFirestore.instance.collection('children').doc(childId).get()
                                : null,
                            builder: (context, childSnap) {
                              String? pfpBase64;
                              if (childSnap.hasData && childSnap.data != null && childSnap.data!.exists) {
                                final childData = childSnap.data!.data() as Map<String, dynamic>;
                                pfpBase64 = (childData['photoBase64'] as String?) ?? (childData['photoUrl'] as String?);
                              }

                              return CircleAvatar(
                                radius: 18,
                                backgroundColor: kDeepOlive,
                                backgroundImage: (pfpBase64 != null && pfpBase64.isNotEmpty)
                                    ? MemoryImage(
                                        base64Decode(
                                          pfpBase64.contains(',') ? pfpBase64.split(',').last : pfpBase64,
                                        ),
                                      )
                                    : null,
                                child: (pfpBase64 == null || pfpBase64.isEmpty)
                                    ? Text(
                                        childName.isNotEmpty ? childName[0].toUpperCase() : 'W',
                                        style: GoogleFonts.sourceSans3(
                                          color: kWarmCream,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Column(
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
                                'Approved: $codeTitle',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'APPROVED',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (photoBase64 != null && photoBase64.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showEnlargedImage(context, photoBase64),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(
                                photoBase64.contains(',')
                                    ? photoBase64.split(',').last
                                    : photoBase64,
                              ),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 100,
                                color: kDeepOlive.withOpacity(0.08),
                                child: Center(
                                  child: Text(
                                    'Unable to render photo proof',
                                    style: GoogleFonts.sourceSans3(
                                      color: kDeepOlive.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _revokeApprovedCode(
                        context: context,
                        approvalDocId: doc.id,
                        childId: childId,
                        codeId: codeId,
                        warriorName: childName,
                        codeTitle: codeTitle,
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.red),
                      label: Text(
                        'Revoke Approval',
                        style: GoogleFonts.sourceSans3(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStagnatedWarriorsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('children').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kTerracotta));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No warriors found in database.',
              style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
            ),
          );
        }

        final now = DateTime.now();

        final stagnatedDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String status = (data['status'] ?? '').toString().toLowerCase();

          if (status == 'stagnated') return true;

          final Timestamp? lastActiveTS = data['lastActive'] as Timestamp?;
          final Timestamp? updatedAtTS = data['updatedAt'] as Timestamp?;
          final Timestamp? createdAtTS = data['createdAt'] as Timestamp?;

          final DateTime lastActivityDate = lastActiveTS?.toDate() ??
              updatedAtTS?.toDate() ??
              createdAtTS?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final int inactiveDays = now.difference(lastActivityDate).inDays;
          return inactiveDays >= 7;
        }).toList();

        if (stagnatedDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  'No stagnated warriors! All warriors are actively practicing.',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kDeepOlive,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stagnatedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = stagnatedDocs[index].data() as Map<String, dynamic>;
            final childName = data['name'] ?? 'Warrior';
            final parentName = data['parentName'] ?? 'Parent';
            final parentPhone = data['parentPhone'] ?? data['phone'] ?? '';
            final codesCompleted = (data['codesCompleted'] as List?)?.length ?? 0;

            final Timestamp? lastActiveTS = data['lastActive'] as Timestamp?;
            final DateTime? lastActiveDate = lastActiveTS?.toDate();
            final int daysInactive = lastActiveDate != null
                ? now.difference(lastActiveDate).inDays
                : 7;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kTerracotta.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: kTerracotta.withOpacity(0.12),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: kTerracotta,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              childName,
                              style: GoogleFonts.sourceSans3(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: kDeepOlive,
                              ),
                            ),
                            Text(
                              'Parent: $parentName • $codesCompleted codes completed',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 12,
                                color: kDeepOlive.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'STAGNATED',
                              style: GoogleFonts.sourceSans3(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$daysInactive ${daysInactive == 1 ? "day" : "days"} inactive',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kDeepOlive.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: kDeepOlive.withOpacity(0.1)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.chat, size: 18),
                      label: Text(
                        'Message on WhatsApp',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _openWhatsAppForParent(
                        parentPhone: parentPhone,
                        childName: childName,
                        parentName: parentName,
                        daysInactive: daysInactive,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}