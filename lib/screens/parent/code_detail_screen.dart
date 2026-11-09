import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/child.dart';
import '../../models/warrior_code.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class CodeDetailScreen extends StatefulWidget {
  final String childId;
  final String? codeId;

  const CodeDetailScreen({
    super.key,
    required this.childId,
    this.codeId,
  });

  @override
  State<CodeDetailScreen> createState() => _CodeDetailScreenState();
}

class _CodeDetailScreenState extends State<CodeDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _photoBase64;
  bool _isSubmitting = false;

  Future<void> _pickPhotoProof() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _photoBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _markAsPracticed(Child child, WarriorCode code) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Use a deterministic document ID `${child.id}_${code.id}` to prevent duplicates
      await _firestore.collection('approvals_queue').doc('${child.id}_${code.id}').set({
        'childId': child.id,
        'childName': child.name,
        'codeId': code.id,
        'codeTitle': code.title,
        'parentId': child.parentId,
        'photoBase64': _photoBase64 ?? '',
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('children').doc(child.id).update({
        'lastActive': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.name}\'s practice sent to Coach for approval!'),
            backgroundColor: kDeepOlive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('children').doc(widget.childId).snapshots(),
      builder: (context, childSnap) {
        if (!childSnap.hasData || !childSnap.data!.exists) {
          return const Scaffold(
            backgroundColor: kWarmCream,
            body: Center(child: CircularProgressIndicator(color: kTerracotta)),
          );
        }

        final child = Child.fromDoc(childSnap.data!);
        final targetCodeId = (widget.codeId != null && widget.codeId!.isNotEmpty)
            ? widget.codeId!
            : child.currentCodeId;

        return StreamBuilder<DocumentSnapshot>(
          // Listen to the specific approval document for this child & code
          stream: _firestore
              .collection('approvals_queue')
              .doc('${child.id}_$targetCodeId')
              .snapshots(),
          builder: (context, approvalSnap) {
            String approvalStatus = '';
            if (approvalSnap.hasData && approvalSnap.data!.exists) {
              final data = approvalSnap.data!.data() as Map<String, dynamic>?;
              approvalStatus = (data?['status'] ?? '').toString().toLowerCase();
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('warrior_codes')
                  .doc(targetCodeId)
                  .snapshots(),
              builder: (context, codeSnap) {
                if (codeSnap.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    backgroundColor: kWarmCream,
                    appBar: AppBar(title: const Text('Warrior Code')),
                    body: const Center(child: CircularProgressIndicator(color: kTerracotta)),
                  );
                }

                if (!codeSnap.hasData || !codeSnap.data!.exists) {
                  return Scaffold(
                    backgroundColor: kWarmCream,
                    appBar: AppBar(title: const Text('Warrior Code')),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Warrior Code details are currently unavailable.',
                          style: GoogleFonts.sourceSans3(color: kDeepOlive, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }

                final code = WarriorCode.fromDoc(codeSnap.data!);
                final bool isCompletedInChild = child.codesCompleted.contains(code.id);
                final bool isApproved = approvalStatus == 'approved' || isCompletedInChild;
                final bool isPending = approvalStatus == 'pending' || _isSubmitting;

                return Scaffold(
                  backgroundColor: kWarmCream,
                  appBar: AppBar(
                    title: Text(code.title),
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (code.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            code.imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 160,
                              color: kDeepOlive.withOpacity(0.1),
                              child: const Icon(Icons.shield, size: 64, color: kDeepOlive),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        code.title,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kDeepOlive,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        code.description,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 16,
                          color: kDeepOlive.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'How to Practise at Home',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kDeepOlive,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (code.instructions.isEmpty)
                        Text(
                          'Practice the key habit daily with focus and respect.',
                          style: GoogleFonts.sourceSans3(fontSize: 15, color: kDeepOlive),
                        )
                      else
                        ...code.instructions.map(
                          (inst) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline, color: kTerracotta, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    inst,
                                    style: GoogleFonts.sourceSans3(
                                      fontSize: 15,
                                      color: kDeepOlive,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (!isApproved && !isPending) ...[
                        Text(
                          'Attach Photo Proof (Optional)',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kDeepOlive,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickPhotoProof,
                          child: Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kDeepOlive.withOpacity(0.2)),
                            ),
                            child: _selectedImageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo_outlined, color: kTerracotta, size: 32),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap to select a photo of home practice',
                                        style: GoogleFonts.sourceSans3(
                                          fontSize: 13,
                                          color: kDeepOlive.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                      _buildBottomActionButton(
                        child: child,
                        code: code,
                        isPending: isPending,
                        isApproved: isApproved,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActionButton({
    required Child child,
    required WarriorCode code,
    required bool isPending,
    required bool isApproved,
  }) {
    if (isApproved) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Code Completed!!',
              style: GoogleFonts.sourceSans3(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (isPending) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kTerracotta.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kTerracotta),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: kTerracotta),
            ),
            const SizedBox(width: 12),
            Text(
              'Pending...',
              style: GoogleFonts.sourceSans3(
                fontWeight: FontWeight.bold,
                color: kTerracotta,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _markAsPracticed(child, code),
      icon: const Icon(Icons.verified),
      label: Text(
        'Mark as Practised',
        style: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kTerracotta,
        foregroundColor: kWarmCream,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}