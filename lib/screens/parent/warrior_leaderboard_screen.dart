import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/child.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class WarriorLeaderboardScreen extends StatelessWidget {
  const WarriorLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        backgroundColor: kWarmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kDeepOlive),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.amber, Colors.orangeAccent],
              ).createShader(bounds),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 8),
            Text(
              'Warrior Leaderboard',
              style: GoogleFonts.sourceSans3(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: kDeepOlive,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('children').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kTerracotta));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No warriors found.',
                style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Map docs to include custom coach trophies, parentId, and manual leaderboardRank
          final warriorsData = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final child = Child.fromMap(doc.id, data);
            final int leaderboardRank = data['leaderboardRank'] ?? 999;
            final List customTrophies = data['trophiesEarned'] ?? [];
            final int totalTrophies = child.codesCompleted.length + customTrophies.length;
            final String parentId = data['parentId'] ?? '';
            
            return {
              'child': child,
              'leaderboardRank': leaderboardRank,
              'totalTrophies': totalTrophies,
              'parentId': parentId,
            };
          }).toList();

          // Sort warriors: prioritize total trophies/codes descending first, then fall back to manual rank
          warriorsData.sort((a, b) {
            int trophiesA = a['totalTrophies'] as int;
            int trophiesB = b['totalTrophies'] as int;
            if (trophiesA != trophiesB) {
              return trophiesB.compareTo(trophiesA); // Highest trophies first
            }
            int rankA = a['leaderboardRank'] as int;
            int rankB = b['leaderboardRank'] as int;
            return rankA.compareTo(rankB);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: warriorsData.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = warriorsData[index];
              final Child warrior = item['child'] as Child;
              final int totalTrophies = item['totalTrophies'] as int;
              final String parentId = item['parentId'] as String;
              final rank = index + 1;

              // Check if this warrior belongs to the currently logged-in parent
              final bool isMyWarrior = currentUserId != null && parentId == currentUserId;

              Color rankColor = kDeepOlive.withOpacity(0.1);
              Color textColor = kDeepOlive;
              if (rank == 1) {
                rankColor = const Color(0xFFFFD700); // Gold
                textColor = const Color(0xFF78350F);
              } else if (rank == 2) {
                rankColor = const Color(0xFFC0C0C0); // Silver
                textColor = const Color(0xFF374151);
              } else if (rank == 3) {
                rankColor = const Color(0xFFCD7F32); // Bronze
                textColor = const Color(0xFF7C2D12);
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // Highlight parent's warriors with a soft green tint, otherwise white
                  color: isMyWarrior ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMyWarrior
                        ? Colors.green.shade400
                        : (rank <= 3 ? rankColor.withOpacity(0.6) : kDeepOlive.withOpacity(0.1)),
                    width: isMyWarrior ? 2 : (rank <= 3 ? 1.5 : 1),
                  ),
                  boxShadow: [
                    if (isMyWarrior)
                      BoxShadow(
                        color: Colors.green.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      )
                    else
                      BoxShadow(
                        color: kDeepOlive.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rankColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: GoogleFonts.sourceSans3(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: rank <= 3 ? textColor : kDeepOlive,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                warrior.name,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kDeepOlive,
                                ),
                              ),
                              if (isMyWarrior) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Your Warrior',
                                    style: GoogleFonts.sourceSans3(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Age: ${warrior.age}',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 12,
                              color: kDeepOlive.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '$totalTrophies Trophies',
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFF78350F),
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