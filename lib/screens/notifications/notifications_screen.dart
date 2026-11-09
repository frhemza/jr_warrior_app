import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kDeepOlive = Color(0xFFFBF9F5);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class ParentNotificationsScreen extends StatelessWidget {
  const ParentNotificationsScreen({super.key});

  String _getRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "min" : "mins"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        backgroundColor: kWarmCream, // Off-white top bar background
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kDeepOlive),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Notifications',
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: kDeepOlive,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kTerracotta),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: kDeepOlive.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      color: kDeepOlive.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Notification';
              final content = data['content'] ?? '';
              final Timestamp? createdTimestamp = data['createdAt'] as Timestamp?;
              final DateTime? createdAt = createdTimestamp?.toDate();
              final timeAgo = _getRelativeTime(createdAt);

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kTerracotta.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: kTerracotta,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.sourceSans3(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: kDeepOlive,
                                  ),
                                ),
                              ),
                              if (timeAgo.isNotEmpty)
                                Text(
                                  timeAgo,
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12,
                                    color: kDeepOlive.withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            content,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 14,
                              color: kDeepOlive.withOpacity(0.75),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}