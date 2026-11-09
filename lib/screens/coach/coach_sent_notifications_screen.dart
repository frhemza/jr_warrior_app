import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class CoachSentNotificationsScreen extends StatefulWidget {
  const CoachSentNotificationsScreen({super.key});

  @override
  State<CoachSentNotificationsScreen> createState() =>
      _CoachSentNotificationsScreenState();
}

class _CoachSentNotificationsScreenState
    extends State<CoachSentNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isSortDescending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _editNotice(String docId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final contentController = TextEditingController(text: data['content'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text('Edit Announcement',
            style: GoogleFonts.sourceSans3(
                color: kDeepOlive, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTerracotta, foregroundColor: kWarmCream),
            onPressed: () async {
              try {
                await _firestore.collection('notices').doc(docId).update({
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Announcement updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _editHighlight(String docId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final captionController = TextEditingController(text: data['caption'] ?? '');
    final videoUrlController = TextEditingController(text: data['videoUrl'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text('Edit Class Moment',
            style: GoogleFonts.sourceSans3(
                color: kDeepOlive, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: videoUrlController,
              decoration: const InputDecoration(labelText: 'Media / Video URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTerracotta, foregroundColor: kWarmCream),
            onPressed: () async {
              try {
                await _firestore.collection('highlights').doc(docId).update({
                  'title': titleController.text.trim(),
                  'caption': captionController.text.trim(),
                  'videoUrl': videoUrlController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class moment updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _editArticle(String docId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final categoryController = TextEditingController(text: data['category'] ?? 'Discipline');
    final summaryController = TextEditingController(text: data['summary'] ?? '');
    final contentController = TextEditingController(text: data['content'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text('Edit Parenting Article',
            style: GoogleFonts.sourceSans3(
                color: kDeepOlive, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                decoration: const InputDecoration(labelText: 'Summary'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Full Content'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTerracotta, foregroundColor: kWarmCream),
            onPressed: () async {
              try {
                await _firestore.collection('articles').doc(docId).update({
                  'title': titleController.text.trim(),
                  'category': categoryController.text.trim(),
                  'summary': summaryController.text.trim(),
                  'content': contentController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Article updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _editEvent(String docId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final descController = TextEditingController(text: data['description'] ?? '');
    final categoryController = TextEditingController(text: data['category'] ?? 'Guest Session');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text('Edit Event',
            style: GoogleFonts.sourceSans3(
                color: kDeepOlive, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTerracotta, foregroundColor: kWarmCream),
            onPressed: () async {
              try {
                await _firestore.collection('events').doc(docId).update({
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'category': categoryController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event updated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String collection, String docId, String itemTitle) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        title: Text('Delete Post?',
            style: GoogleFonts.sourceSans3(
                color: Colors.red.shade800, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$itemTitle"?',
            style: GoogleFonts.sourceSans3(color: kDeepOlive)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _firestore.collection(collection).doc(docId).delete();
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted "$itemTitle"')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: kWarmCream,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.sourceSans3(fontSize: 14, color: kDeepOlive),
              decoration: InputDecoration(
                hintText: 'Search history by keyword...',
                hintStyle: GoogleFonts.sourceSans3(
                  fontSize: 14,
                  color: kDeepOlive.withOpacity(0.5),
                ),
                prefixIcon: const Icon(Icons.search, color: kDeepOlive, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kDeepOlive.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kDeepOlive.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kTerracotta, width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              setState(() {
                _isSortDescending = !_isSortDescending;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kDeepOlive.withOpacity(0.15)),
              ),
              child: Icon(
                _isSortDescending ? Icons.sort_by_alpha : Icons.swap_vert,
                color: kTerracotta,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList({
    required String collection,
    required String timestampField,
    required IconData leadIcon,
    required void Function(String docId, Map<String, dynamic> data) onEdit,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading content:',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kTerracotta));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No posts found in this section.',
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                color: kDeepOlive.withOpacity(0.6),
              ),
            ),
          );
        }

        final rawDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

        rawDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          final tsA = (dataA[timestampField] ?? dataA['createdAt'] ?? dataA['eventDate']) as Timestamp?;
          final tsB = (dataB[timestampField] ?? dataB['createdAt'] ?? dataB['eventDate']) as Timestamp?;

          final dtA = tsA?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = tsB?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

          return _isSortDescending ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
        });

        final docs = rawDocs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final String title = (data['title'] ?? '').toString().toLowerCase();
          final String content = (data['content'] ?? '').toString().toLowerCase();
          final String caption = (data['caption'] ?? '').toString().toLowerCase();
          final String summary = (data['summary'] ?? '').toString().toLowerCase();
          final String desc = (data['description'] ?? '').toString().toLowerCase();
          final String category = (data['category'] ?? '').toString().toLowerCase();

          return title.contains(_searchQuery) ||
              content.contains(_searchQuery) ||
              caption.contains(_searchQuery) ||
              summary.contains(_searchQuery) ||
              desc.contains(_searchQuery) ||
              category.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No results matching "$_searchQuery".',
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                color: kDeepOlive.withOpacity(0.6),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final String title = data['title'] ?? 'Untitled';
            final String subtext = data['content'] ??
                data['caption'] ??
                data['summary'] ??
                data['description'] ??
                '';
            final Timestamp? ts = (data[timestampField] ?? data['createdAt'] ?? data['eventDate']) as Timestamp?;
            final String timeAgo = _getRelativeTime(ts?.toDate());

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: kTerracotta.withOpacity(0.12),
                  child: Icon(leadIcon, color: kTerracotta, size: 22),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.sourceSans3(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: kDeepOlive,
                        ),
                      ),
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          color: kDeepOlive.withOpacity(0.55),
                        ),
                      ),
                  ],
                ),
                subtitle: subtext.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtext,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sourceSans3(
                            fontSize: 13,
                            color: kDeepOlive.withOpacity(0.75),
                          ),
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: kDeepOlive, size: 20),
                      tooltip: 'Edit',
                      onPressed: () => onEdit(doc.id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(collection, doc.id, title),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kDeepOlive),
        title: Text(
          'Published Content History',
          style: GoogleFonts.sourceSans3(
            color: kDeepOlive,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: kTerracotta,
          labelColor: kTerracotta,
          unselectedLabelColor: Colors.grey.shade700,
          labelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Announcements'))),
            Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Class Moments'))),
            Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Parenting Articles'))),
            Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Events'))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildContentList(
                  collection: 'notices',
                  timestampField: 'createdAt',
                  leadIcon: Icons.campaign,
                  onEdit: _editNotice,
                ),
              ),
            ],
          ),
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildContentList(
                  collection: 'highlights',
                  timestampField: 'createdAt',
                  leadIcon: Icons.video_library,
                  onEdit: _editHighlight,
                ),
              ),
            ],
          ),
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildContentList(
                  collection: 'articles',
                  timestampField: 'createdAt',
                  leadIcon: Icons.article,
                  onEdit: _editArticle,
                ),
              ),
            ],
          ),
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildContentList(
                  collection: 'events',
                  timestampField: 'eventDate',
                  leadIcon: Icons.event,
                  onEdit: _editEvent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}