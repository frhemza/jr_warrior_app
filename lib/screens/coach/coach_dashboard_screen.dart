import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'coach_archive_screen.dart';
import 'coach_fee_verification_screen.dart';
import 'coach_sent_notifications_screen.dart';
import '../settings/account_settings_screen.dart';
import '../../models/child.dart';
import '../../utils/fcm_service.dart';
import 'package:image_picker/image_picker.dart';
import '../coach/AdminWarriorLeaderboardScreen.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentBottomNavIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Track the previous fee count to detect when a *new* pending approval arrives
  int _previousFeeCount = 0;
  int _pendingFeeCount = 0;
  bool _hasViewedFeesTab = false;

  // Track the previous stagnated count or view state if needed
  int _stagnatedCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  // ---------------------------------------------------------------------------
  // Full-Screen Image Viewer Dialog (Zoom & Pan)
  // ---------------------------------------------------------------------------
  void _showFullScreenImage(BuildContext context, String base64Image, String heroTag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: heroTag,
                  child: Image.memory(
                    base64Decode(base64Image),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Coach Management Dialogs: Edit Profile, Assign Parent, Remove Warrior
  // ---------------------------------------------------------------------------
  void _showCoachEditWarriorDialog({
    required String childId,
    required String currentName,
    required dynamic currentAge,
    required String currentStatus,
  }) {
    final nameController = TextEditingController(text: currentName);
    final ageController = TextEditingController(text: currentAge?.toString() ?? '');
    String selectedStatus = currentStatus;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isSaving,
            child: AlertDialog(
              backgroundColor: kWarmCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Edit Warrior Profile',
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'Warrior Name',
                        labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: kTerracotta, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: kTerracotta, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ['in_progress', 'pending_coach_approval', 'stagnated'].contains(selectedStatus)
                          ? selectedStatus
                          : 'in_progress',
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: kTerracotta, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'in_progress', child: Text('Active (In Progress)')),
                        DropdownMenuItem(value: 'pending_coach_approval', child: Text('Pending Approval')),
                        DropdownMenuItem(value: 'stagnated', child: Text('Stagnated')),
                      ],
                      onChanged: isSaving
                          ? null
                          : (val) {
                              if (val != null) setDialogState(() => selectedStatus = val);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.7))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: kWarmCream,
                    disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          final newAge = int.tryParse(ageController.text.trim()) ?? 0;

                          if (newName.isNotEmpty) {
                            setDialogState(() => isSaving = true);
                            try {
                              await _firestore.collection('children').doc(childId).update({
                                'name': newName,
                                'age': newAge,
                                'status': selectedStatus,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Warrior profile updated successfully!')),
                                );
                              }
                            } catch (e) {
                              if (dialogCtx.mounted) {
                                setDialogState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kWarmCream),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAssignParentDialog({
    required String childId,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Assign / Change Parent',
          style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('role', isEqualTo: 'parent')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kTerracotta));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No registered parent accounts found in system.',
                    style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.7)),
                  ),
                );
              }

              final parents = snapshot.data!.docs;

              return ListView.separated(
                shrinkWrap: true,
                itemCount: parents.length,
                separatorBuilder: (_, __) => Divider(color: kDeepOlive.withOpacity(0.1)),
                itemBuilder: (context, index) {
                  final parentDoc = parents[index];
                  final pData = parentDoc.data() as Map<String, dynamic>;
                  final pName = pData['name'] ?? pData['email'] ?? 'Parent';
                  final pUid = parentDoc.id;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      pName,
                      style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
                    ),
                    subtitle: Text(
                      pData['email'] ?? '',
                      style: GoogleFonts.sourceSans3(fontSize: 12, color: kDeepOlive.withOpacity(0.6)),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kTerracotta.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1, color: kTerracotta, size: 20),
                    ),
                    onTap: () async {
                      await _firestore.collection('children').doc(childId).update({
                        'parentId': pUid,
                        'parentName': pName,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Assigned warrior to $pName!')),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveWarrior({
    required String childId,
    required String warriorName,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Warrior?',
          style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: Colors.red.shade800),
        ),
        content: Text(
          'Are you sure you want to remove "$warriorName" from the roster? This operation cannot be undone.',
          style: GoogleFonts.sourceSans3(color: kDeepOlive, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _firestore.collection('children').doc(childId).delete();
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed $warriorName from roster.')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _approveWarriorRegistration(String childId) async {
    try {
      await _firestore.collection('children').doc(childId).update({
        'status': 'in_progress',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warrior approved and added to roster!'),
            backgroundColor: kDeepOlive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving warrior: $e'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    }
  }

  void _rejectWarriorRegistration(String childId) async {
    try {
      await _firestore.collection('children').doc(childId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warrior registration declined.'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining registration: $e'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    }
  }

  Future<void> _revokeApprovedCode({
    required String childId,
    required String codeId,
    required String codeTitle,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text(
          'Revoke Approved Code?',
          style: GoogleFonts.sourceSans3(
            color: kDeepOlive,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to revoke "$codeTitle" for this warrior? It will lock the code again for the warrior until re-submitted.',
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
            child: const Text('Revoke Code', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('children').doc(childId).update({
        'codesCompleted': FieldValue.arrayRemove([codeId]),
        'currentCodeId': codeId,
        'lastActive': FieldValue.serverTimestamp(),
      });

      final approvalDocs = await _firestore
          .collection('approvals_queue')
          .where('childId', isEqualTo: childId)
          .where('codeId', isEqualTo: codeId)
          .get();

      for (final doc in approvalDocs.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'revokedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'Revoked by coach from warrior profile dialog',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revoked "$codeTitle". Code is now relocked.'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error revoking code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showWarriorProfileDialog(Child child, Map<String, dynamic> childData) {
    final String? photoBase64 = childData['photoBase64'] as String?;
    final String parentName = childData['parentName'] ?? 'Parent';
    final List completedCodes = (childData['codesCompleted'] as List?) ?? [];
    final List customTrophies = (childData['trophiesEarned'] as List?) ?? [];
    final String currentCodeId = childData['currentCodeId'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWarmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: (photoBase64 != null && photoBase64.isNotEmpty)
                            ? () => _showFullScreenImage(context, photoBase64, 'profile_${child.id}')
                            : null,
                        child: Hero(
                          tag: 'profile_${child.id}',
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: kDeepOlive,
                            backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                                ? MemoryImage(base64Decode(photoBase64))
                                : null,
                            child: (photoBase64 == null || photoBase64.isEmpty)
                                ? Text(
                                    child.name.isNotEmpty ? child.name[0].toUpperCase() : 'W',
                                    style: GoogleFonts.sourceSans3(
                                      color: kWarmCream,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.name,
                              style: GoogleFonts.sourceSans3(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: kDeepOlive,
                              ),
                            ),
                            Text(
                              'Parent: $parentName',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 14,
                                color: kDeepOlive.withOpacity(0.75),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: child.feeStatus.toLowerCase() == 'paid'
                                    ? Colors.green.withOpacity(0.15)
                                    : kTerracotta.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Fee Status: ${child.feeStatus.toUpperCase()}',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: child.feeStatus.toLowerCase() == 'paid'
                                      ? Colors.green.shade800
                                      : kTerracotta,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    'Trophies & Milestone Awards (${completedCodes.length + customTrophies.length})',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('warrior_codes').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kTerracotta));
                      }

                      final allCodes = snapshot.data!.docs;
                      final completedDocs = allCodes.where((d) => completedCodes.contains(d.id)).toList();

                      if (completedDocs.isEmpty && customTrophies.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kDeepOlive.withOpacity(0.12)),
                          ),
                          child: Text(
                            'No trophies or milestone awards earned yet.',
                            style: GoogleFonts.sourceSans3(
                              color: kDeepOlive.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...customTrophies.map((trophyName) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade400, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.military_tech, color: Colors.amber, size: 22),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trophyName.toString(),
                                        style: GoogleFonts.sourceSans3(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.brown.shade900,
                                        ),
                                      ),
                                      Text(
                                        'Custom Coach Award',
                                        style: GoogleFonts.sourceSans3(
                                          fontSize: 11,
                                          color: Colors.brown.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          ...completedDocs.map((cDoc) {
                            final cData = cDoc.data() as Map<String, dynamic>;
                            final reward = cData['milestoneReward'] ?? 'Warrior Stripe';
                            final codeTitle = cData['title'] ?? 'Code';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reward,
                                        style: GoogleFonts.sourceSans3(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.brown.shade900,
                                        ),
                                      ),
                                      Text(
                                        codeTitle,
                                        style: GoogleFonts.sourceSans3(
                                          fontSize: 11,
                                          color: Colors.brown.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Code Progress & History',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('warrior_codes').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kTerracotta));
                      }

                      final docs = snapshot.data!.docs;
                      docs.sort((a, b) {
                        final orderA = (a.data() as Map<String, dynamic>)['order'] ?? 0;
                        final orderB = (b.data() as Map<String, dynamic>)['order'] ?? 0;
                        return orderA.compareTo(orderB);
                      });

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final codeId = doc.id;
                          final title = data['title'] ?? 'Warrior Code';
                          final isCompleted = completedCodes.contains(codeId);
                          final isCurrent = codeId == currentCodeId;

                          Color statusColor = Colors.grey;
                          IconData statusIcon = Icons.lock_outline;
                          String statusLabel = 'Locked';

                          if (isCompleted) {
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle;
                            statusLabel = 'Completed';
                          } else if (isCurrent) {
                            statusColor = kTerracotta;
                            statusIcon = Icons.play_circle_fill;
                            statusLabel = 'In Progress (Active)';
                          }

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isCurrent ? kTerracotta : kDeepOlive.withOpacity(0.12),
                                width: isCurrent ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.15),
                                child: Icon(statusIcon, color: statusColor, size: 22),
                              ),
                              title: Text(
                                title,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  color: kDeepOlive,
                                ),
                              ),
                              subtitle: Text(
                                'Reward: ${data['milestoneReward'] ?? "Stripe"}',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 12,
                                  color: kDeepOlive.withOpacity(0.7),
                                ),
                              ),
                              trailing: isCompleted
                                  ? TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.red),
                                      label: Text(
                                        'Revoke',
                                        style: GoogleFonts.sourceSans3(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(sheetCtx);
                                        _revokeApprovedCode(
                                          childId: child.id,
                                          codeId: codeId,
                                          codeTitle: title,
                                        );
                                      },
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.sourceSans3(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPostOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWarmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create & Post',
              style: GoogleFonts.sourceSans3(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.campaign, color: kTerracotta),
              title: Text(
                'Announcement',
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
              ),
              subtitle: Text('Post notice to parent dashboard', style: GoogleFonts.sourceSans3()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showPostNoticeDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.article, color: kTerracotta),
              title: Text(
                'Parenting Article',
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
              ),
              subtitle: Text('Publish article to Parenting Editorial Library', style: GoogleFonts.sourceSans3()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showPublishArticleDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.video_library, color: kTerracotta),
              title: Text(
                'Class Moment / Highlight',
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
              ),
              subtitle: Text('Share training video or media moment', style: GoogleFonts.sourceSans3()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddHighlightDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event, color: kTerracotta),
              title: Text(
                'Upcoming Event / Guest Session',
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
              ),
              subtitle: Text('Schedule special sessions or guest coaches', style: GoogleFonts.sourceSans3()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddEventDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPostNoticeDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isPosting = false;

    showDialog(
      context: context,
      barrierDismissible: !isPosting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isPosting,
            child: AlertDialog(
              backgroundColor: kWarmCream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Post Announcement',
                style: GoogleFonts.sourceSans3(color: kDeepOlive, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    enabled: !isPosting,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Schedule Adjustment',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    enabled: !isPosting,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      hintText: 'Announcement details...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isPosting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: kWarmCream,
                    disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  ),
                  onPressed: isPosting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();

                          if (title.isNotEmpty && content.isNotEmpty) {
                            setDialogState(() => isPosting = true);
                            try {
                              final docRef = await _firestore.collection('notices').add({
                                'title': title,
                                'content': content,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              await FcmService.sendAnnouncementNotification(
                                title: title,
                                body: content,
                                announcementId: docRef.id,
                              );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isPosting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to publish: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kWarmCream,
                          ),
                        )
                      : const Text('Publish Notice'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPublishArticleDialog() {
    final titleController = TextEditingController();
    final summaryController = TextEditingController();
    final contentController = TextEditingController();
    bool isPublishing = false;

    showDialog(
      context: context,
      barrierDismissible: !isPublishing,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isPublishing,
            child: AlertDialog(
              backgroundColor: kWarmCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Publish Article',
                style: GoogleFonts.sourceSans3(color: kDeepOlive, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      enabled: !isPublishing,
                      decoration: const InputDecoration(labelText: 'Title', hintText: 'Building Focus at Home'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: summaryController,
                      enabled: !isPublishing,
                      decoration: const InputDecoration(labelText: 'Short Summary'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      enabled: !isPublishing,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Full Article Content'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPublishing ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.7))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: kWarmCream,
                    disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  ),
                  onPressed: isPublishing
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final summary = summaryController.text.trim();
                          final content = contentController.text.trim();

                          if (title.isNotEmpty && content.isNotEmpty) {
                            setDialogState(() => isPublishing = true);
                            try {
                              await _firestore.collection('articles').add({
                                'title': title,
                                'summary': summary,
                                'content': content,
                                'readTime': '3 min read',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Article published successfully!'),
                                    backgroundColor: kDeepOlive,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isPublishing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to publish article: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isPublishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kWarmCream),
                        )
                      : const Text('Publish Article'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddHighlightDialog() {
    final titleController = TextEditingController();
    final captionController = TextEditingController();
    final urlController = TextEditingController();

    String? selectedBase64Image;
    String? selectedFileName;
    bool isPosting = false;

    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: !isPosting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage(ImageSource source) async {
            if (isPosting) return;
            try {
              final XFile? file = await picker.pickImage(
                source: source,
                imageQuality: 70,
              );

              if (file != null) {
                final bytes = await file.readAsBytes();
                final base64Str = base64Encode(bytes);

                setDialogState(() {
                  selectedBase64Image = base64Str;
                  selectedFileName = file.name;
                });
              }
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to pick picture: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          return PopScope(
            canPop: !isPosting,
            child: AlertDialog(
              backgroundColor: kWarmCream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Post Class Moment',
                style: GoogleFonts.sourceSans3(
                  color: kDeepOlive,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      enabled: !isPosting,
                      decoration: const InputDecoration(
                        labelText: 'Highlight Title',
                        hintText: 'e.g., Sparring Drills',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: captionController,
                      enabled: !isPosting,
                      decoration: const InputDecoration(
                        labelText: 'Caption',
                        hintText: 'e.g., Excellent speed today!',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload Photo',
                      style: GoogleFonts.sourceSans3(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: kDeepOlive,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isPosting ? null : () => pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: kTerracotta),
                        label: Text(
                          'Select Picture from Gallery',
                          style: GoogleFonts.sourceSans3(color: kDeepOlive, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: kDeepOlive.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (selectedBase64Image != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.image, color: Colors.green.shade800, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFileName ?? 'Picture Selected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                            if (!isPosting)
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedBase64Image = null;
                                    selectedFileName = null;
                                  });
                                },
                                child: const Icon(Icons.close, size: 16, color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'OR LINK VIDEO / REEL',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: kDeepOlive.withOpacity(0.5),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlController,
                      enabled: !isPosting && selectedBase64Image == null,
                      decoration: InputDecoration(
                        labelText: 'Video or Instagram Reel URL',
                        hintText: 'https://instagram.com/reel/... or video link',
                        prefixIcon: const Icon(Icons.link, color: kTerracotta, size: 20),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPosting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: kWarmCream,
                    disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  ),
                  onPressed: isPosting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final caption = captionController.text.trim();
                          final videoUrl = urlController.text.trim();

                          if (title.isNotEmpty) {
                            setDialogState(() => isPosting = true);
                            try {
                              await _firestore.collection('highlights').add({
                                'title': title,
                                'caption': caption,
                                'videoUrl': videoUrl,
                                'photoBase64': selectedBase64Image ?? '',
                                'isVideo': videoUrl.isNotEmpty,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Class moment posted!')),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isPosting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to post: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kWarmCream,
                          ),
                        )
                      : const Text('Post Moment'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final badgeController = TextEditingController(text: 'Event');
    bool isPublishing = false;

    showDialog(
      context: context,
      barrierDismissible: !isPublishing,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isPublishing,
            child: AlertDialog(
              backgroundColor: kWarmCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Schedule Event',
                style: GoogleFonts.sourceSans3(color: kDeepOlive, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: badgeController,
                      enabled: !isPublishing,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. event, competition, workshop',
                        labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: kTerracotta, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      enabled: !isPublishing,
                      decoration: const InputDecoration(labelText: 'Event Title', hintText: 'e.g., Advanced Sparring & Tech...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      enabled: !isPublishing,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'Details about the session...'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPublishing ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.7))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: kWarmCream,
                    disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  ),
                  onPressed: isPublishing
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final desc = descController.text.trim();
                          final customBadge = badgeController.text.trim().toUpperCase();

                          if (title.isNotEmpty) {
                            setDialogState(() => isPublishing = true);
                            try {
                              await _firestore.collection('events').add({
                                'title': title,
                                'description': desc,
                                'badgeTitle': customBadge.isNotEmpty ? customBadge : 'EVENT',
                                'eventDate': FieldValue.serverTimestamp(),
                              });
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Event scheduled successfully!'),
                                    backgroundColor: kDeepOlive,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isPublishing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to publish event: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isPublishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kWarmCream),
                        )
                      : const Text('Publish Event'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWarriorCodesManagementDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWarmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Warrior Codes',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kDeepOlive,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showWarriorCodeEditorDialog();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTerracotta,
                          foregroundColor: kWarmCream,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('warrior_codes').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: kTerracotta));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No Warrior Codes created yet.',
                              style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        docs.sort((a, b) {
                          final orderA = (a.data() as Map<String, dynamic>)['order'] ?? 0;
                          final orderB = (b.data() as Map<String, dynamic>)['order'] ?? 0;
                          return orderA.compareTo(orderB);
                        });

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final docId = doc.id;
                            final title = data['title'] ?? 'Warrior Code';
                            final description = data['description'] ?? '';
                            final reward = data['milestoneReward'] ?? '';

                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: kDeepOlive,
                                  child: Text(
                                    '${data['order'] ?? (index + 1)}',
                                    style: GoogleFonts.sourceSans3(color: kWarmCream, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
                                ),
                                subtitle: Text(
                                  '$description\nReward: $reward',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sourceSans3(fontSize: 12, color: kDeepOlive.withOpacity(0.7)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: kDeepOlive),
                                      tooltip: 'Edit Code',
                                      onPressed: () {
                                        _showWarriorCodeEditorDialog(codeDoc: doc);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Delete Code',
                                      onPressed: () => _confirmDeleteCode(docId, title),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  void _showWarriorCodeEditorDialog({DocumentSnapshot? codeDoc}) {
    final isEditing = codeDoc != null;
    final data = isEditing ? codeDoc.data() as Map<String, dynamic> : {};

    final instructionsList = data['instructions'] as List?;
    final initialParentInst = data['parentInstructions'] ?? 
        ((instructionsList != null && instructionsList.isNotEmpty) ? instructionsList.first : '');

    final titleController = TextEditingController(text: data['title'] ?? '');
    final descController = TextEditingController(text: data['description'] ?? '');
    final parentInstController = TextEditingController(text: initialParentInst);
    final rewardController = TextEditingController(text: data['milestoneReward'] ?? '');
    final orderController = TextEditingController(text: '${data['order'] ?? 1}');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isSaving,
            child: AlertDialog(
              backgroundColor: kWarmCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEditing ? 'Edit Warrior Code' : 'Create Warrior Code',
                style: GoogleFonts.sourceSans3(color: kDeepOlive, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Code Title', hintText: 'Code #1: Focus & Respect'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      enabled: !isSaving,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: parentInstController,
                      enabled: !isSaving,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Home Practice Instructions'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rewardController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Milestone Reward / Stripe'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orderController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sequence Order Number'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.7))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: kWarmCream,
                    disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final desc = descController.text.trim();
                          final parentInst = parentInstController.text.trim();
                          final reward = rewardController.text.trim();
                          final order = int.tryParse(orderController.text.trim()) ?? 1;

                          if (title.isNotEmpty) {
                            setDialogState(() => isSaving = true);
                            try {
                              final payload = {
                                'title': title,
                                'description': desc,
                                'parentInstructions': parentInst,
                                'instructions': parentInst.isNotEmpty ? [parentInst] : [],
                                'milestoneReward': reward,
                                'order': order,
                                'imageUrl': '',
                              };

                              if (isEditing) {
                                await _firestore.collection('warrior_codes').doc(codeDoc.id).update(payload);
                              } else {
                                payload['createdAt'] = FieldValue.serverTimestamp();
                                await _firestore.collection('warrior_codes').add(payload);
                              }

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEditing ? 'Warrior Code updated!' : 'Warrior Code published!'),
                                    backgroundColor: kDeepOlive,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save code: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kWarmCream),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Publish Code'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteCode(String docId, String title) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete Warrior Code', style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('warrior_codes').doc(docId).delete();
              if (mounted) Navigator.pop(dialogCtx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleFeeStatus(Child child) async {
    final newStatus = child.feeStatus.toLowerCase() == 'due' ? 'paid' : 'due';

    await _firestore.collection('children').doc(child.id).update({
      'feeStatus': newStatus,
    });

    if (newStatus == 'due' && child.parentId.isNotEmpty) {
      try {
        final parentDoc = await _firestore.collection('users').doc(child.parentId).get();
        final fcmToken = parentDoc.data()?['fcmToken'] ?? '';

        if (fcmToken.isNotEmpty) {
          await FcmService.sendFeeChallanNotification(
            parentFcmToken: fcmToken,
            childName: child.name,
          );
        }
      } catch (e) {
        debugPrint('Error sending fee notification: $e');
      }
    }
  }

  void _approveSubmission(String approvalId, String childId, String codeId) async {
    if (codeId.isEmpty) return;

    final currentCodeSnap = await _firestore.collection('warrior_codes').doc(codeId).get();
    String? nextCodeId;
    int pointsEarned = 100;

    if (currentCodeSnap.exists) {
      final codeData = currentCodeSnap.data() as Map<String, dynamic>;
      final currentOrder = (codeData['order'] as num?)?.toInt() ?? 1;
      pointsEarned = (codeData['points'] as num?)?.toInt() ?? 100;

      final nextCodeQuery = await _firestore
          .collection('warrior_codes')
          .where('order', isGreaterThan: currentOrder)
          .orderBy('order')
          .limit(1)
          .get();

      if (nextCodeQuery.docs.isNotEmpty) {
        nextCodeId = nextCodeQuery.docs.first.id;
      }
    }

    final Map<String, dynamic> childUpdates = {
      'codesCompleted': FieldValue.arrayUnion([codeId]),
      'lastActive': FieldValue.serverTimestamp(),
      'points': FieldValue.increment(pointsEarned),
    };

    if (nextCodeId != null) {
      childUpdates['currentCodeId'] = nextCodeId;
    } else {
      childUpdates['status'] = 'completed';
    }

    await _firestore.collection('children').doc(childId).update(childUpdates);

    await _firestore.collection('approvals_queue').doc(approvalId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    final childDoc = await _firestore.collection('children').doc(childId).get();
    if (childDoc.exists) {
      final childData = childDoc.data() as Map<String, dynamic>;
      final updatedTotalPoints = (childData['points'] as num?)?.toInt() ?? pointsEarned;
      final warriorName = childData['name'] ?? 'Warrior';
      final parentName = childData['parentName'] ?? '';
      final photoBase64 = childData['photoBase64'] ?? '';

      final leaderboardRef = _firestore.collection('leaderboard').doc(childId);
      await leaderboardRef.set({
        'childId': childId,
        'name': warriorName,
        'parentName': parentName,
        'points': updatedTotalPoints,
        'photoBase64': photoBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _rejectSubmission(String approvalId, String childId, String codeId) async {
    try {
      await _firestore.collection('approvals_queue').doc(approvalId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Practice submission rejected.'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting submission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('fee_challans')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, feeSnapshot) {
        int pendingFeeCount = 0;
        if (feeSnapshot.hasData) {
          pendingFeeCount = feeSnapshot.data!.docs.length;
        }

        if (pendingFeeCount != _previousFeeCount) {
          if (pendingFeeCount > _previousFeeCount) {
            _hasViewedFeesTab = false;
          }
          _previousFeeCount = pendingFeeCount;
          _pendingFeeCount = pendingFeeCount;
        }

        final showFeeBadge = !_hasViewedFeesTab && _pendingFeeCount > 0;

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('children').snapshots(),
          builder: (context, childrenSnapshot) {
            int stagnatedCount = 0;
            if (childrenSnapshot.hasData) {
              final now = DateTime.now();
              stagnatedCount = childrenSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'in_progress';
                if (status == 'pending_coach_approval') return false;
                if (status == 'stagnated') return true;
                final Timestamp? lastActive = data['lastActive'] as Timestamp?;
                if (lastActive != null) {
                  final difference = now.difference(lastActive.toDate());
                  if (difference.inDays >= 7) return true;
                }
                return false;
              }).length;
            }
            _stagnatedCount = stagnatedCount;
            final showHistoryBadge = _stagnatedCount > 0;

            return Scaffold(
              backgroundColor: kWarmCream,
              appBar: AppBar(
                title: const Text('Coach Portal'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.shield_outlined),
                    tooltip: 'Warrior Codes',
                    onPressed: _showWarriorCodesManagementDialog,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: TextButton.icon(
                      onPressed: _showPostOptionsModal,
                      icon: const Icon(Icons.add_circle_outline, color: kWarmCream, size: 20),
                      label: Text(
                        'Post',
                        style: GoogleFonts.sourceSans3(
                          color: kWarmCream,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: kTerracotta,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPendingWarriorsSection(),
                  _buildApprovalsSection(),
                  const SizedBox(height: 24),
                  _buildCoachPostsSection(),
                  const SizedBox(height: 16),
                  _buildLeaderboardManagementCard(context),
                  const SizedBox(height: 24),
                  _buildWarriorRosterSection(),
                ],
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: kDeepOlive.withOpacity(0.12))),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentBottomNavIndex,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  selectedItemColor: kTerracotta,
                  unselectedItemColor: kDeepOlive,
                  selectedLabelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle: GoogleFonts.sourceSans3(fontSize: 12, color: kDeepOlive),
                  onTap: (index) {
                    setState(() {
                      _currentBottomNavIndex = index;
                      if (index == 1) {
                        _hasViewedFeesTab = true;
                        _pendingFeeCount = 0;
                      }
                    });

                    if (index == 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CoachFeeVerificationScreen()),
                      );
                    } else if (index == 2) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CoachArchiveScreen()),
                      );
                    } else if (index == 3) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                      );
                    }
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined, color: kDeepOlive.withOpacity(0.7)),
                      activeIcon: const Icon(Icons.dashboard, color: kTerracotta),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.payments_outlined, color: kDeepOlive.withOpacity(0.7)),
                          if (showFeeBadge)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$_pendingFeeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      activeIcon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.payments, color: kTerracotta),
                          if (showFeeBadge)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$_pendingFeeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      label: 'Fees',
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.history_edu_outlined, color: kDeepOlive.withOpacity(0.7)),
                          if (showHistoryBadge)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$_stagnatedCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      activeIcon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.history_edu, color: kTerracotta),
                          if (showHistoryBadge)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$_stagnatedCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      label: 'History',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.account_circle_outlined, color: kDeepOlive.withOpacity(0.7)),
                      activeIcon: const Icon(Icons.account_circle, color: kTerracotta),
                      label: 'Account',
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

  Widget _buildLeaderboardManagementCard(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF8E1),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFE082)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.amber.shade700,
          radius: 18,
          child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
        ),
        title: Text(
          'Warrior Leaderboard Management',
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.bold,
            color: kDeepOlive,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Manage rankings, points, and badge awards',
            style: GoogleFonts.sourceSans3(
              color: kDeepOlive.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kDeepOlive),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminWarriorLeaderboardScreen()),
          );
        },
      ),
    );
  }

  Widget _buildCoachPostsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title'] ?? 'Announcement';
        final content = data['content'] ?? '';
        final Timestamp? createdTimestamp = data['createdAt'] as Timestamp?;
        final timeAgo = _getRelativeTime(createdTimestamp?.toDate());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest Announcement Sent',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kDeepOlive,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CoachSentNotificationsScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All History',
                    style: GoogleFonts.sourceSans3(
                      color: kTerracotta,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Card(
              color: const Color(0xFFFFF8E1),
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFE082)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: kTerracotta,
                  radius: 18,
                  child: Icon(Icons.campaign, color: Colors.white, size: 20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.sourceSans3(
                          fontWeight: FontWeight.bold,
                          color: kDeepOlive,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kDeepOlive.withOpacity(0.55),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sourceSans3(
                      color: kDeepOlive.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                  onPressed: () async {
                    await _firestore.collection('notices').doc(doc.id).delete();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovalsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('approvals_queue')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No pending practice approvals.',
                style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Approvals (${docs.length})',
              style: GoogleFonts.sourceSans3(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final approvalId = docs[index].id;
                final childName = data['childName'] ?? 'Warrior';
                final codeTitle = data['codeTitle'] ?? 'Warrior Code';
                final childId = data['childId'] ?? '';
                final codeId = data['codeId'] ?? '';
                final String? photoBase64 = data['photoBase64'] as String?;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
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
                              childName,
                              style: GoogleFonts.sourceSans3(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kDeepOlive,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kTerracotta.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Pending Review',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kTerracotta,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Practiced: $codeTitle',
                          style: GoogleFonts.sourceSans3(
                            color: kDeepOlive.withOpacity(0.8),
                          ),
                        ),
                        if (photoBase64 != null && photoBase64.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context, photoBase64, 'approval_$approvalId'),
                            child: Hero(
                              tag: 'approval_$approvalId',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(photoBase64),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: kDeepOlive.withOpacity(0.08),
                                    child: Center(
                                      child: Text(
                                        'Unable to load photo proof',
                                        style: GoogleFonts.sourceSans3(
                                          color: kDeepOlive.withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _rejectSubmission(approvalId, childId, codeId),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kTerracotta,
                                  side: const BorderSide(color: kTerracotta, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _approveSubmission(approvalId, childId, codeId),
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text('Approve Practice'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kDeepOlive,
                                  foregroundColor: kWarmCream,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingWarriorsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('children')
          .where('status', isEqualTo: 'pending_coach_approval')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingDocs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Registration Requests (${pendingDocs.length})',
              style: GoogleFonts.sourceSans3(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTerracotta,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingDocs.length,
              itemBuilder: (context, index) {
                final doc = pendingDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final childName = data['name'] ?? 'Warrior';
                final age = data['age'] ?? 0;
                final parentName = data['parentName'] ?? 'Parent';

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: kTerracotta, width: 1.5),
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
                              childName,
                              style: GoogleFonts.sourceSans3(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kDeepOlive,
                              ),
                            ),
                            Text(
                              'Age: $age',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: kDeepOlive.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Parent: $parentName',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 13,
                            color: kDeepOlive.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rejectWarriorRegistration(doc.id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _approveWarriorRegistration(doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kDeepOlive,
                                  foregroundColor: kWarmCream,
                                ),
                                child: const Text('Approve Warrior'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildWarriorRosterSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('children').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kTerracotta));
        }

        final now = DateTime.now();
        final allDocs = snapshot.data!.docs;

        // Filter active roster view, keeping both normal and stagnated warriors for highlighting
        final childrenDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'in_progress';

          // Exclude pending registrations
          if (status == 'pending_coach_approval') return false;

          // Apply search query filter if active
          if (_searchQuery.isNotEmpty) {
            final childName = (data['name'] ?? '').toString().toLowerCase();
            final parentName = (data['parentName'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return childName.contains(query) || parentName.contains(query);
          }

          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Warrior Roster (${childrenDocs.length})',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kDeepOlive,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _isSearching ? 220 : 40,
                  height: 40,
                  alignment: Alignment.centerRight,
                  child: _isSearching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: GoogleFonts.sourceSans3(fontSize: 14, color: kDeepOlive),
                          decoration: InputDecoration(
                            hintText: 'Search warrior...',
                            hintStyle: GoogleFonts.sourceSans3(fontSize: 14, color: kDeepOlive.withOpacity(0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: kTerracotta),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim();
                            });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.search, color: kDeepOlive),
                          tooltip: 'Search Warrior',
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (childrenDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No warriors matching "$_searchQuery"'
                        : 'No active warriors on roster.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      color: kDeepOlive.withOpacity(0.6),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: childrenDocs.length,
                itemBuilder: (context, index) {
                  final doc = childrenDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final child = Child.fromDoc(doc);
                  final isDue = child.feeStatus.toLowerCase() == 'due';
                  final String? photoBase64 = data['photoBase64'] as String?;
                  final parentName = data['parentName'] ?? 'Parent';
                  final currentCodeId = data['currentCodeId'] ?? '';
                  final status = data['status'] ?? 'in_progress';
                  final age = data['age'] ?? 0;

                  // Check if warrior is stagnated (status == 'stagnated' or inactive for 7+ days)
                  bool isStagnated = status == 'stagnated';
                  final Timestamp? lastActive = data['lastActive'] as Timestamp?;
                  if (lastActive != null) {
                    final difference = now.difference(lastActive.toDate());
                    if (difference.inDays >= 7) {
                      isStagnated = true;
                    }
                  }

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isStagnated ? Colors.red : kDeepOlive.withOpacity(0.12),
                        width: isStagnated ? 2.5 : 1,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isStagnated
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: ListTile(
                        onTap: () => _showWarriorProfileDialog(child, data),
                        leading: GestureDetector(
                          onTap: (photoBase64 != null && photoBase64.isNotEmpty)
                              ? () => _showFullScreenImage(context, photoBase64, 'roster_${child.id}')
                              : null,
                          child: Hero(
                            tag: 'roster_${child.id}',
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: isStagnated ? Colors.red.shade800 : kDeepOlive,
                              backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                                  ? MemoryImage(base64Decode(photoBase64))
                                  : null,
                              child: (photoBase64 == null || photoBase64.isEmpty)
                                  ? Text(
                                      child.name.isNotEmpty ? child.name[0].toUpperCase() : 'W',
                                      style: GoogleFonts.sourceSans3(
                                        color: kWarmCream,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                child.name,
                                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isStagnated)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'STAGNATED',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Parent: $parentName',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 13,
                                color: kDeepOlive.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            FutureBuilder<DocumentSnapshot>(
                              future: currentCodeId.isNotEmpty
                                  ? _firestore.collection('warrior_codes').doc(currentCodeId).get()
                                  : _firestore
                                      .collection('warrior_codes')
                                      .orderBy('order')
                                      .limit(1)
                                      .get()
                                      .then((q) => q.docs.first),
                              builder: (context, codeSnap) {
                                String codeTitle = 'Warrior Hasnt Started Any Code Yet';
                                if (codeSnap.hasData && codeSnap.data!.exists) {
                                  final codeData = codeSnap.data!.data() as Map<String, dynamic>?;
                                  codeTitle = codeData?['title'] ?? codeTitle;
                                }
                                return Text(
                                  'Current: $codeTitle',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kTerracotta,
                                  ),
                                );
                              },
                            ),
                            Text(
                              'Status: ${child.status}',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 12,
                                color: kDeepOlive.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _toggleFeeStatus(child),
                              style: TextButton.styleFrom(
                                foregroundColor: isDue ? kTerracotta : Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Text(isDue ? 'FEE DUE' : 'PAID'),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: kDeepOlive, size: 20),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showCoachEditWarriorDialog(
                                    childId: child.id,
                                    currentName: child.name,
                                    currentAge: age,
                                    currentStatus: status,
                                  );
                                } else if (value == 'assign_parent') {
                                  _showAssignParentDialog(
                                    childId: child.id,
                                  );
                                } else if (value == 'remove') {
                                  _confirmRemoveWarrior(
                                    childId: child.id,
                                    warriorName: child.name,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18, color: kDeepOlive),
                                      SizedBox(width: 8),
                                      Text('Edit Profile'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'assign_parent',
                                  child: Row(
                                    children: [
                                      Icon(Icons.supervisor_account_outlined, size: 18, color: kTerracotta),
                                      SizedBox(width: 8),
                                      Text('Assign / Change Parent'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_forever_outlined, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Remove Warrior', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}