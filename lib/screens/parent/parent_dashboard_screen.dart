import '../child/child_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/child.dart';
import '../../models/warrior_code.dart';
import 'code_detail_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      setState(() => _isSigningOut = false);
    }
  }

  void _showAddChildDialog(BuildContext context, String parentUid) {
    final nameController = TextEditingController();

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
              'Add New Warrior',
              style: GoogleFonts.sourceSerif4(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2F25),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Child\'s Full Name',
                hintText: 'e.g., Leo Arain',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('children').add({
                  'parentId': parentUid,
                  'fullName': name,
                  'currentCodeId': 'code_01',
                  'status': 'in_progress',
                  'trophiesEarned': [],
                  'lastProgressUpdate': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Warrior $name added successfully!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2F25),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Warrior'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Add Child',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => _showAddChildDialog(context, user.uid),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('codes').snapshots(),
        builder: (context, codesSnapshot) {
          final codesById = <String, WarriorCode>{};
          for (final doc in codesSnapshot.data?.docs ?? const []) {
            final code = WarriorCode.fromDoc(doc);
            if (code.codeId.isNotEmpty) {
              codesById[code.codeId] = code;
            }
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('children')
                .where('parentId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, childrenSnapshot) {
              if (childrenSnapshot.connectionState == ConnectionState.waiting &&
                  !childrenSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final children = (childrenSnapshot.data?.docs ?? const [])
                  .map(Child.fromDoc)
                  .toList()
                ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

              if (children.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.child_care_outlined, size: 48, color: colors.secondary),
                        const SizedBox(height: 16),
                        Text(
                          'No warriors yet',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap below to add your child to your dashboard.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sourceSans3(
                            fontSize: 16,
                            color: colors.primary.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddChildDialog(context, user.uid),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Warrior'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final child = children[index];
                  final codeTitle = codesById[child.currentCodeId]?.title ??
                      (child.currentCodeId.isEmpty ? 'No active code' : 'Code in progress');

                  return _ChildSummaryCard(
                    child: child,
                    codeTitle: codeTitle,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CodeDetailScreen(childId: child.childId),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ChildSummaryCard extends StatelessWidget {
  const _ChildSummaryCard({
    required this.child,
    required this.codeTitle,
    required this.onTap,
  });

  final Child child;
  final String codeTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isInactive = child.isInactive();
    final trophyCount = child.trophiesEarned.length;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      child.fullName,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  _ActivityBadge(isInactive: isInactive, status: child.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                codeTitle,
                style: GoogleFonts.sourceSans3(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    trophyCount == 1 ? '1 trophy' : '$trophyCount trophies',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      color: colors.primary.withValues(alpha: 0.75),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: colors.primary.withValues(alpha: 0.45)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChildDashboardScreen(childId: child.childId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: const Text('View Trophy Case'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({
    required this.isInactive,
    required this.status,
  });

  final bool isInactive;
  final String status;

  @override
  Widget build(BuildContext context) {
    if (isInactive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E2B3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag, size: 14, color: Color(0xFFB8860B)),
            const SizedBox(width: 6),
            Text(
              'Needs attention',
              style: GoogleFonts.sourceSans3(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8A6A12),
              ),
            ),
          ],
        ),
      );
    }

    final label = switch (status) {
      'pending_approval' => 'Awaiting coach',
      'completed' => 'Completed',
      _ => 'On track',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}