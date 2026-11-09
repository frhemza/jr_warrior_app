import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class AdminWarriorLeaderboardScreen extends StatefulWidget {
  const AdminWarriorLeaderboardScreen({super.key});

  @override
  State<AdminWarriorLeaderboardScreen> createState() => _AdminWarriorLeaderboardScreenState();
}

class _AdminWarriorLeaderboardScreenState extends State<AdminWarriorLeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to handle drag-and-drop reordering
  void _updateWarriorOrder(List<DocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    // Reorder locally for immediate UI feedback
    final item = docs.removeAt(oldIndex);
    docs.insert(newIndex, item);

    // Batch update ranking/order field in Firestore
    WriteBatch batch = _firestore.batch();
    for (int i = 0; i < docs.length; i++) {
      DocumentReference docRef = _firestore.collection('children').doc(docs[i].id);
      batch.update(docRef, {'leaderboardRank': i + 1});
    }
    await batch.commit();
  }

  // Dialog to Add or Remove Custom Trophies for a Specific Warrior
  void _showManageTrophiesDialog(String warriorId, String warriorName, List currentTrophies) {
    final TextEditingController trophyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kWarmCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Manage Trophies: $warriorName',
            style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Trophies / Awards:',
                  style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 13, color: kDeepOlive),
                ),
                const SizedBox(height: 8),
                currentTrophies.isEmpty
                    ? Text('No custom trophies assigned yet.', style: GoogleFonts.sourceSans3(color: Colors.grey))
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: currentTrophies.length,
                          itemBuilder: (context, index) {
                            final trophy = currentTrophies[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                              title: Text(trophy.toString(), style: GoogleFonts.sourceSans3(color: kDeepOlive)),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                onPressed: () async {
                                  List updatedList = List.from(currentTrophies);
                                  updatedList.removeAt(index);
                                  await _firestore.collection('children').doc(warriorId).update({
                                    'trophiesEarned': updatedList,
                                  });
                                  setDialogState(() {
                                    currentTrophies = updatedList;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                const Divider(height: 24),
                TextField(
                  controller: trophyController,
                  decoration: InputDecoration(
                    labelText: 'Add Custom Trophy Name',
                    labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kTerracotta)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Done', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTerracotta, foregroundColor: Colors.white),
              onPressed: () async {
                final newTrophy = trophyController.text.trim();
                if (newTrophy.isNotEmpty) {
                  List updatedList = List.from(currentTrophies)..add(newTrophy);
                  await _firestore.collection('children').doc(warriorId).update({
                    'trophiesEarned': updatedList,
                  });
                  trophyController.clear();
                  setDialogState(() {
                    currentTrophies = updatedList;
                  });
                }
              },
              child: const Text('Add Trophy'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        backgroundColor: kWarmCream,
        elevation: 0,
        title: Text(
          'Warrior Leaderboard & Management',
          style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: kDeepOlive),
        ),
        iconTheme: const IconThemeData(color: kDeepOlive),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('children').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kTerracotta));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No warriors available on the leaderboard.', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
            );
          }

          final docs = snapshot.data!.docs;

          // Automatically sort documents by total trophies and completed codes descending (real-time updates)
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final trophiesA = (dataA['trophiesEarned'] ?? []) as List;
            final codesA = (dataA['codesCompleted'] ?? []) as List;
            final totalA = trophiesA.length + codesA.length;

            final trophiesB = (dataB['trophiesEarned'] ?? []) as List;
            final codesB = (dataB['codesCompleted'] ?? []) as List;
            final totalB = trophiesB.length + codesB.length;

            // Primary sort: Highest total trophies/codes first (descending)
            if (totalA != totalB) {
              return totalB.compareTo(totalA);
            }

            // Secondary sort: manual leaderboardRank fallback if totals are equal
            final rankA = dataA['leaderboardRank'] ?? 999;
            final rankB = dataB['leaderboardRank'] ?? 999;
            return rankA.compareTo(rankB);
          });

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Tip: Hold and drag the grip handles to manually adjust warrior rankings. Tap a warrior to manage trophies.',
                  style: GoogleFonts.sourceSans3(fontSize: 13, color: kDeepOlive.withOpacity(0.7)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: docs.length,
                    onReorder: (oldIndex, newIndex) => _updateWarriorOrder(docs, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String name = data['name'] ?? 'Unnamed Warrior';
                      final List trophies = data['trophiesEarned'] ?? [];
                      final List codesCompleted = data['codesCompleted'] ?? [];
                      final int totalTrophies = trophies.length + codesCompleted.length;
                      final int rank = index + 1;

                      return Card(
                        key: ValueKey(doc.id),
                        color: Colors.white,
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: rank == 1 ? Colors.amber : kDeepOlive.withOpacity(0.1),
                            child: Text(
                              '$rank',
                              style: GoogleFonts.sourceSans3(
                                fontWeight: FontWeight.bold,
                                color: rank == 1 ? Colors.white : kDeepOlive,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 16, color: kDeepOlive),
                          ),
                          subtitle: Text(
                            'Total Trophies: $totalTrophies (Custom: ${trophies.length}, Codes: ${codesCompleted.length})',
                            style: GoogleFonts.sourceSans3(fontSize: 12, color: kDeepOlive.withOpacity(0.6)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 26),
                                tooltip: 'Add/Remove Trophies',
                                onPressed: () => _showManageTrophiesDialog(doc.id, name, trophies),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                          onTap: () => _showManageTrophiesDialog(doc.id, name, trophies),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}