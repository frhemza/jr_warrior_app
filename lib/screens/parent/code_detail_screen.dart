import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/child.dart';
import '../../models/warrior_code.dart';

class CodeDetailScreen extends StatefulWidget {
  const CodeDetailScreen({super.key, required this.childId});

  final String childId;

  @override
  State<CodeDetailScreen> createState() => _CodeDetailScreenState();
}

class _CodeDetailScreenState extends State<CodeDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _markAsPractised(Child child) async {
    if (_isSubmitting || !child.isInProgress) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final firestore = FirebaseFirestore.instance;
    final childRef = firestore.collection('children').doc(child.childId);
    final approvalRef = firestore.collection('approvals_queue').doc();

    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(childRef);
        final latest = snapshot.exists ? Child.fromDoc(snapshot) : child;
        if (!latest.isInProgress) {
          return;
        }

        transaction.update(childRef, {
          'status': 'pending_approval',
          'lastProgressUpdate': FieldValue.serverTimestamp(),
        });
        transaction.set(approvalRef, {
          'childId': child.childId,
          'codeId': child.currentCodeId,
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'coachNote': '',
        });
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${child.fullName} is submitted and awaiting coach approval.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to submit practice. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('children').doc(widget.childId).snapshots(),
      builder: (context, childSnapshot) {
        if (childSnapshot.connectionState == ConnectionState.waiting && !childSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Warrior Code')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!childSnapshot.hasData || childSnapshot.data?.exists != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Warrior Code')),
            body: const Center(child: Text('This warrior could not be found.')),
          );
        }

        final child = Child.fromDoc(childSnapshot.data!);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('warrior_codes')
              .doc(child.currentCodeId)
              .snapshots(),
          builder: (context, codeSnapshot) {
            final code = codeSnapshot.data?.exists == true
                ? WarriorCode.fromDoc(codeSnapshot.data!)
                : null;

            return Scaffold(
              appBar: AppBar(title: Text(child.fullName)),
              body: codeSnapshot.connectionState == ConnectionState.waiting && code == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        _EditorialCodeCard(code: code, childName: child.fullName),
                        const SizedBox(height: 24),
                        _PracticeAction(
                          child: child,
                          isSubmitting: _isSubmitting,
                          onMarkPractised: () => _markAsPractised(child),
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

class _EditorialCodeCard extends StatelessWidget {
  const _EditorialCodeCard({
    required this.code,
    required this.childName,
  });

  final WarriorCode? code;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = code?.title ?? 'Code details unavailable';
    final description = code?.description ??
        'The active warrior code could not be loaded. Ask your coach to check this assignment.';
    final instructions = code?.instructions ?? const <String>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (code != null && code!.imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                code!.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: colors.primary.withValues(alpha: 0.06),
                  child: Icon(Icons.shield_outlined, size: 48, color: colors.secondary),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRACTICE WITH $childName'.toUpperCase(),
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: colors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    height: 1.5,
                    color: colors.primary.withValues(alpha: 0.8),
                  ),
                ),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Parent practice steps',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < instructions.length; i++) ...[
                    _InstructionRow(number: i + 1, text: instructions[i]),
                    if (i != instructions.length - 1) const SizedBox(height: 10),
                  ],
                ],
                if (code != null && code!.milestoneReward.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF9F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.emoji_events_outlined, color: colors.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            code!.milestoneReward,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 15,
                              height: 1.4,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.number,
    required this.text,
  });

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: GoogleFonts.sourceSans3(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.sourceSans3(
              fontSize: 16,
              height: 1.45,
              color: colors.primary.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

class _PracticeAction extends StatelessWidget {
  const _PracticeAction({
    required this.child,
    required this.isSubmitting,
    required this.onMarkPractised,
  });

  final Child child;
  final bool isSubmitting;
  final VoidCallback onMarkPractised;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (child.isPendingApproval) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E2B3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Submitted - Awaiting Coach Approval',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: const Color(0xFF8A6A12),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.secondary.withValues(alpha: 0.45),
                disabledBackgroundColor: colors.secondary.withValues(alpha: 0.45),
                disabledForegroundColor: colors.onSecondary,
              ),
              child: const Text('Submitted - Awaiting Coach Approval'),
            ),
          ],
        ),
      );
    }

    if (child.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'This code is complete.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSans3(
            color: colors.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: isSubmitting ? null : onMarkPractised,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.secondary,
        foregroundColor: colors.onSecondary,
        minimumSize: const Size.fromHeight(56),
      ),
      child: isSubmitting
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onSecondary,
              ),
            )
          : const Text('Mark as Practised'),
    );
  }
}
