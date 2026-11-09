import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/child.dart';
import '../../models/warrior_code.dart';
import '../../widgets/badge_card.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;

  const ChildDashboardScreen({
    super.key,
    required this.childId,
  });

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .update({
        'photoBase64': base64Image,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .snapshots(),
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

        final childData = childSnap.data!.data() as Map<String, dynamic>? ?? {};
        final child = Child.fromDoc(childSnap.data!);
        final String? photoBase64 = childData['photoBase64'] as String?;

        return Scaffold(
          backgroundColor: const Color(0xFFFBF9F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFBF9F5),
            elevation: 0,
            title: Row(
              children: [
                GestureDetector(
                  onTap: _pickAndUploadPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF1A2F25),
                        backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                            ? MemoryImage(base64Decode(photoBase64))
                            : null,
                        child: (photoBase64 == null || photoBase64.isEmpty)
                            ? Text(
                                child.fullName.isNotEmpty ? child.fullName[0].toUpperCase() : 'W',
                                style: GoogleFonts.sourceSans3(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC85A32),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${child.fullName}\'s Portal',
                  style: GoogleFonts.sourceSerif4(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A2F25),
                  ),
                ),
              ],
            ),
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('warrior_codes')
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
                      color: const Color(0xFF1A2F25).withOpacity(0.7),
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
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyGallery(List<String> trophiesEarned) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('warrior_codes')
          .orderBy('order')
          .snapshots(),
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