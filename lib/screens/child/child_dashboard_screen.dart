import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child.dart';
import '../../models/warrior_code.dart';
import '../../widgets/badge_card.dart';

class ChildDashboardScreen extends StatelessWidget {
  final String childId;

  const ChildDashboardScreen({
    super.key,
    required this.childId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('children').doc(childId).snapshots(),
      builder: (context, childSnap) {
        if (childSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!childSnap.hasData || !childSnap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Warrior Portal')),
            body: const Center(child: Text('Warrior record not found.')),
          );
        }

        final child = Child.fromDoc(childSnap.data!);

        return Scaffold(
          backgroundColor: const Color(0xFFFBF9F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFBF9F5),
            elevation: 0,
            title: Text(
              '${child.fullName}\'s Portal',
              style: GoogleFonts.sourceSerif4(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2F25),
              ),
            ),
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('codes')
                .doc(child.currentCodeId)
                .snapshots(),
            builder: (context, codeSnap) {
              WarriorCode? currentCode;
              if (codeSnap.hasData && codeSnap.data!.exists) {
                currentCode = WarriorCode.fromDoc(codeSnap.data!);
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  _buildActiveCodeBanner(currentCode, child),
                  const SizedBox(height: 28),
                  Text(
                    'Trophy Case',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A2F25),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earn badges as you practice and complete Warrior Codes.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      color: const Color(0xFF1A2F25).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTrophyGallery(child.trophiesEarned),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveCodeBanner(WarriorCode? code, Child child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F25),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC85A32),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'CURRENT MISSION',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (child.isPendingApproval)
                Text(
                  'Awaiting Review',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF3E2B3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            code?.title ?? 'Active Warrior Code',
            style: GoogleFonts.sourceSerif4(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            code?.description ?? 'Complete practice actions to earn your next badge!',
            style: GoogleFonts.sourceSans3(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyGallery(List<String> trophiesEarned) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('codes').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('No badges available.');
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final code = WarriorCode.fromDoc(docs[index]);
            final isEarned = trophiesEarned.contains(code.codeId);

            return BadgeCard(
              codeId: code.codeId,
              title: code.title,
              rewardName: code.milestoneReward.isNotEmpty
                  ? code.milestoneReward
                  : 'Warrior Shield',
              isEarned: isEarned,
            );
          },
        );
      },
    );
  }
}