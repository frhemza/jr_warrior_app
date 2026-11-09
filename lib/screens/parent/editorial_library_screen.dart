import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/article.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class EditorialLibraryScreen extends StatefulWidget {
  const EditorialLibraryScreen({super.key});

  @override
  State<EditorialLibraryScreen> createState() => _EditorialLibraryScreenState();
}

class _EditorialLibraryScreenState extends State<EditorialLibraryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showArticleDetail(Article article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWarmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kDeepOlive.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kTerracotta.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    article.category.toUpperCase(),
                    style: GoogleFonts.sourceSans3(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: kTerracotta,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  ${article.readTime}',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    color: kDeepOlive.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: GoogleFonts.sourceSans3(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              article.content,
              style: GoogleFonts.sourceSans3(
                fontSize: 16,
                height: 1.6,
                color: kDeepOlive.withOpacity(0.85),
              ),
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
        title: const Text('Parenting a Warrior'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('articles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kTerracotta),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No articles published yet.',
                  style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
                ),
              ),
            );
          }

          final articles = snapshot.data!.docs
              .map((d) => Article.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    article.title,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 14,
                        color: kDeepOlive.withOpacity(0.7),
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTerracotta),
                  onTap: () => _showArticleDetail(article),
                ),
              );
            },
          );
        },
      ),
    );
  }
}