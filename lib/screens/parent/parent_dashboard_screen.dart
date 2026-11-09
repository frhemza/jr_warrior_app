import '../settings/account_settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jr_warrior_app/screens/parent/parent_fee_challans_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'warrior_leaderboard_screen.dart';

import '../../models/child.dart';
import '../../models/event.dart';
import '../../models/family_analytics.dart';
import '../../models/notice.dart';
import 'code_detail_screen.dart';
import 'editorial_library_screen.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class _NativeCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const _NativeCropDialog({required this.imageBytes});

  @override
  State<_NativeCropDialog> createState() => _NativeCropDialogState();
}

class _NativeCropDialogState extends State<_NativeCropDialog> {
  final CropController _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kWarmCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Crop Warrior Photo',
              style: GoogleFonts.sourceSans3(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: (croppedData) {
                    Navigator.pop(context, croppedData);
                  },
                  aspectRatio: 1 / 1,
                  withCircleUi: true,
                  baseColor: kDeepOlive,
                  maskColor: kDeepOlive.withOpacity(0.6),
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCropping ? null : () => Navigator.pop(context, null),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.sourceSans3(color: kDeepOlive),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isCropping
                      ? null
                      : () {
                          setState(() {
                            _isCropping = true;
                          });
                          _cropController.crop();
                        },
                  child: _isCropping
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Crop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedChildId;
  int _currentBottomNavIndex = 0;

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

  void _openNotificationsFeed(List<Notice> notices) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsFeedScreen(notices: notices),
      ),
    );
  }

  void _showAllCodesModal({
    required BuildContext context,
    required List<QueryDocumentSnapshot> docs,
    required List completedCodes,
    required Set<String> pendingCodeIds,
    required int activeIndex,
    required String childId,
    required String childName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWarmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kDeepOlive.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Code Progress & History',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kDeepOlive),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final codeData = doc.data() as Map<String, dynamic>;
                  final codeId = doc.id;
                  final title = codeData['title'] ?? 'Warrior Code';
                  final reward = codeData['milestoneReward'] ?? '';

                  final isCompleted = completedCodes.contains(codeId);
                  final isPending = pendingCodeIds.contains(codeId);
                  final isCurrent = !isCompleted && index == activeIndex;
                  final isUnlocked = isCompleted || isPending || isCurrent;

                  Color cardBg = Colors.white;
                  Color borderColor = kDeepOlive.withOpacity(0.12);
                  Color statusBg = const Color(0xFFE8F5E9);
                  Color statusTextColor = Colors.green.shade700;
                  String statusText = 'Completed';
                  Widget leadingIcon = const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                  );

                  if (isCompleted) {
                    statusBg = const Color(0xFFE8F5E9);
                    statusTextColor = Colors.green.shade700;
                    statusText = 'Completed';
                    leadingIcon = const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                    );
                  } else if (isPending) {
                    borderColor = Colors.orange.shade300;
                    statusBg = Colors.orange.withOpacity(0.15);
                    statusTextColor = Colors.orange.shade800;
                    statusText = 'Pending Review';
                    leadingIcon = CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange.withOpacity(0.15),
                      child: Icon(Icons.hourglass_top, color: Colors.orange.shade800, size: 20),
                    );
                  } else if (isCurrent) {
                    borderColor = kTerracotta;
                    statusBg = const Color(0xFFFDE8E4);
                    statusTextColor = kTerracotta;
                    statusText = 'In Progress (Active)';
                    leadingIcon = const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFFDE8E4),
                      child: Icon(Icons.play_arrow_rounded, color: kTerracotta, size: 24),
                    );
                  } else {
                    statusBg = Colors.grey.shade100;
                    statusTextColor = Colors.grey.shade600;
                    statusText = 'Locked';
                    leadingIcon = CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade100,
                      child: Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      if (!isUnlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Complete previous Warrior Codes to unlock $title.'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CodeDetailScreen(
                            childId: childId,
                            codeId: codeId,
                          ),
                        ),
                      );
                    },
                    child: Opacity(
                      opacity: isUnlocked ? 1.0 : 0.6,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            leadingIcon,
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.sourceSans3(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: kDeepOlive,
                                    ),
                                  ),
                                  if (reward.isNotEmpty)
                                    Text(
                                      'Reward: $reward',
                                      style: GoogleFonts.sourceSans3(
                                        fontSize: 12,
                                        color: kDeepOlive.withOpacity(0.65),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: statusTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetailModal(UpcomingEvent event) {
    showDialog(
      context: context,
      builder: (modalCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kWarmCream,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kTerracotta.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: GoogleFonts.sourceSans3(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: kTerracotta,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kDeepOlive),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: GoogleFonts.sourceSans3(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kDeepOlive,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                event.description,
                style: GoogleFonts.sourceSans3(
                  fontSize: 15,
                  color: kDeepOlive.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(modalCtx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showParentMediaViewerModal({
    required String title,
    required String caption,
    required String? photoBase64,
    required String? videoUrl,
  }) {
    final bool hasImage = photoBase64 != null && photoBase64.isNotEmpty;
    final bool hasVideoUrl = videoUrl != null && videoUrl.isNotEmpty;
    final bool isInstagramReel =
        hasVideoUrl && videoUrl.toLowerCase().contains('instagram.com');

    showDialog(
      context: context,
      builder: (modalCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          decoration: BoxDecoration(
            color: kWarmCream,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kDeepOlive,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: kDeepOlive),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    color: Colors.black,
                    width: double.infinity,
                    child: hasImage
                        ? Image.memory(
                            base64Decode(
                              photoBase64.contains(',')
                                  ? photoBase64.split(',').last
                                  : photoBase64,
                            ),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white, size: 48),
                            ),
                          )
                        : hasVideoUrl
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isInstagramReel
                                              ? Colors.pink.shade700
                                              : kTerracotta,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isInstagramReel
                                              ? Icons.camera_alt_outlined
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        isInstagramReel
                                            ? 'Instagram Reel'
                                            : 'Watch Class Video',
                                        style: GoogleFonts.sourceSans3(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        videoUrl,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.sourceSans3(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isInstagramReel
                                              ? Colors.pink.shade600
                                              : kTerracotta,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        icon: const Icon(Icons.open_in_new, size: 18),
                                        label: Text(
                                          isInstagramReel
                                              ? 'Open Reel on Instagram'
                                              : 'Watch Video',
                                          style: GoogleFonts.sourceSans3(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () async {
                                          final Uri uri = Uri.parse(videoUrl);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri,
                                                mode: LaunchMode.externalApplication);
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Could not open link: $videoUrl'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.movie_outlined,
                                    color: Colors.white54, size: 48),
                              ),
                  ),
                ),
              ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    caption,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      color: kDeepOlive.withOpacity(0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext dialogContext, String childId, String childName) {
    showDialog(
      context: dialogContext,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: kWarmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Warrior Profile',
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade800,
          ),
        ),
        content: Text(
          'Are you sure you want to delete $childName\'s profile? This action cannot be undone.',
          style: GoogleFonts.sourceSans3(
            color: kDeepOlive,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: Text(
              'Cancel',
              style: GoogleFonts.sourceSans3(color: kDeepOlive),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(confirmCtx);
              try {
                await _firestore.collection('children').doc(childId).delete();
                if (mounted) {
                  setState(() {
                    if (_selectedChildId == childId) {
                      _selectedChildId = null;
                    }
                  });
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$childName\'s profile has been deleted.'),
                      backgroundColor: Colors.red.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete warrior: $e'),
                      backgroundColor: Colors.red,
                    ),
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

  void _showEditWarriorDialog({
    required String childId,
    required String currentName,
    required dynamic currentAge,
    required String? currentPhotoBase64,
  }) {
    final nameController = TextEditingController(text: currentName);
    final ageController = TextEditingController(text: currentAge?.toString() ?? '');
    String? updatedBase64 = currentPhotoBase64;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickAndCropImage(ImageSource source) async {
            if (isSaving) return;
            try {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: source,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 75,
              );

              if (image == null) return;

              final Uint8List rawBytes = await image.readAsBytes();

              if (!dialogCtx.mounted) return;

              final Uint8List? croppedBytes = await showDialog<Uint8List>(
                context: dialogCtx,
                builder: (_) => _NativeCropDialog(imageBytes: rawBytes),
              );

              if (croppedBytes != null) {
                setDialogState(() {
                  updatedBase64 = base64Encode(croppedBytes);
                });
              }
            } catch (e) {
              if (dialogCtx.mounted) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(
                    content: Text('Failed to pick or crop image: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          void showSourceSelectionSheet() {
            if (isSaving) return;
            showModalBottomSheet(
              context: dialogCtx,
              backgroundColor: kWarmCream,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (sheetCtx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined, color: kDeepOlive),
                      title: Text(
                        'Choose from Gallery',
                        style: GoogleFonts.sourceSans3(color: kDeepOlive, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        pickAndCropImage(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined, color: kDeepOlive),
                      title: Text(
                        'Take a Photo',
                        style: GoogleFonts.sourceSans3(color: kDeepOlive, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        pickAndCropImage(ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: kWarmCream,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Warrior Profile',
                  style: GoogleFonts.sourceSans3(
                    fontWeight: FontWeight.bold,
                    color: kDeepOlive,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  tooltip: 'Delete Warrior',
                  onPressed: isSaving
                      ? null
                      : () => _showDeleteConfirmationDialog(dialogCtx, childId, currentName),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: showSourceSelectionSheet,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: kDeepOlive,
                          backgroundImage: (updatedBase64 != null && updatedBase64!.isNotEmpty)
                              ? MemoryImage(base64Decode(
                                  updatedBase64!.contains(',')
                                      ? updatedBase64!.split(',').last
                                      : updatedBase64!,
                                ))
                              : null,
                          child: (updatedBase64 == null || updatedBase64!.isEmpty)
                              ? Text(
                                  nameController.text.isNotEmpty
                                      ? nameController.text[0].toUpperCase()
                                      : 'W',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: kWarmCream,
                                  ),
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: kTerracotta,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'Warrior Name',
                      labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: kTerracotta, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ageController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: kTerracotta, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kDeepOlive.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.sourceSans3(
                    color: isSaving ? kDeepOlive.withOpacity(0.3) : kDeepOlive.withOpacity(0.7),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTerracotta,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        final newAge = int.tryParse(ageController.text.trim()) ?? 0;

                        if (newName.isNotEmpty) {
                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await _firestore.collection('children').doc(childId).update({
                              'name': newName,
                              'age': newAge,
                              'photoBase64': updatedBase64 ?? '',
                              'photoUrl': updatedBase64 ?? '',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Warrior profile updated successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setDialogState(() {
                                isSaving = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update warrior: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(kWarmCream),
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddChildDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: kWarmCream,
            title: Text(
              'Add New Warrior',
              style: GoogleFonts.sourceSans3(
                color: kDeepOlive,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Child Name',
                    hintText: 'Enter name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    hintText: 'Enter age',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.sourceSans3(
                    color: isSubmitting ? kDeepOlive.withOpacity(0.3) : kDeepOlive,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final age = int.tryParse(ageController.text.trim()) ?? 0;
                        final user = _auth.currentUser;

                        if (name.isNotEmpty && user != null) {
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            final parentDoc = await _firestore.collection('users').doc(user.uid).get();
                            final parentData = parentDoc.data();

                            String parentName = user.displayName ?? '';
                            if (parentName.isEmpty) {
                              parentName = parentData?['name'] ?? 'Parent';
                            }

                            final String parentPhone = parentData?['parentPhone'] ??
                                parentData?['phone'] ??
                                parentData?['phoneNumber'] ??
                                user.phoneNumber ??
                                '';

                            final childDocRef = _firestore.collection('children').doc();

                            await childDocRef.set({
                              'id': childDocRef.id,
                              'parentId': user.uid,
                              'parentName': parentName,
                              'parentPhone': parentPhone,
                              'name': name,
                              'age': age,
                              'feeStatus': 'due',
                              'status': 'pending_coach_approval',
                              'currentCodeId': 'code_1',
                              'codesCompleted': [],
                              'trophiesEarned': [],
                              'lastActive': FieldValue.serverTimestamp(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Warrior registered! Awaiting coach approval.'),
                                  backgroundColor: kDeepOlive,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add warrior: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTerracotta,
                  foregroundColor: kWarmCream,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  disabledBackgroundColor: kTerracotta.withOpacity(0.6),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(kWarmCream),
                        ),
                      )
                    : const Text('Add Warrior'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        backgroundColor: kWarmCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: kDeepOlive),
        title: Text(
          'Parent Dashboard',
          style: GoogleFonts.sourceSans3(
            color: kDeepOlive,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('notices')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final notices = (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                  ? snapshot.data!.docs
                      .map((d) => Notice.fromMap(d.id, d.data() as Map<String, dynamic>))
                      .toList()
                  : <Notice>[];

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: kDeepOlive, size: 26),
                    onPressed: () => _openNotificationsFeed(notices),
                  ),
                  if (notices.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: kTerracotta,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${notices.length}',
                          style: GoogleFonts.sourceSans3(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please sign in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('children')
                  .where('parentId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kTerracotta),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final childrenDocs = snapshot.data!.docs;

                final children = childrenDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Child.fromMap(doc.id, data);
                }).toList();

                if (_selectedChildId == null ||
                    !children.any((c) => c.id == _selectedChildId)) {
                  _selectedChildId = children.first.id;
                }

                final selectedIndex = children.indexWhere((c) => c.id == _selectedChildId);
                final selectedChild = children[selectedIndex];
                final selectedDocData = childrenDocs[selectedIndex].data() as Map<String, dynamic>;

                return Column(
                  children: [
                    _buildChildSelectorBar(children),
                    const Divider(height: 1, color: Color(0x221A2F25)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildRecentNotificationBanner(),
                          const SizedBox(height: 16),
                          _buildLeaderboardBanner(),
                          const SizedBox(height: 16),
                          _buildWarriorProfileCard(selectedChild, selectedDocData),
                          const SizedBox(height: 20),
                          _buildAnalyticsCard(children),
                          const SizedBox(height: 20),
                          _buildEditorialLibraryBanner(),
                          const SizedBox(height: 20),
                          _buildEventsSection(),
                          const SizedBox(height: 16),
                          _buildHighlightsSection(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: user == null
            ? const Stream.empty()
            : _firestore
                .collection('fee_challans')
                .where('parentId', isEqualTo: user.uid)
                .snapshots(),
        builder: (context, snapshot) {
          int unpaidCount = 0;
          if (snapshot.hasData) {
            unpaidCount = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString().toLowerCase();
              return status != 'paid';
            }).length;
          }

          return BottomNavigationBar(
            currentIndex: _currentBottomNavIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: kTerracotta,
            unselectedItemColor: kDeepOlive.withOpacity(0.6),
            selectedLabelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.sourceSans3(fontSize: 12),
            onTap: (index) async {
              setState(() {
                _currentBottomNavIndex = index;
              });

              if (index == 1) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ParentFeeChallansScreen(),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                }
              } else if (index == 2) {
                _showAddChildDialog();
                if (mounted) {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                }
              } else if (index == 3) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _currentBottomNavIndex = 0;
                  });
                }
              }
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, color: kDeepOlive),
                activeIcon: Icon(Icons.home, color: kTerracotta),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: kDeepOlive),
                    if (unpaidCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unpaidCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.receipt_long, color: kTerracotta),
                    if (unpaidCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unpaidCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Fee Status',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_add_alt_1_outlined, color: kDeepOlive),
                activeIcon: Icon(Icons.person_add_alt_1, color: kTerracotta),
                label: 'Add Warrior',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined, color: kDeepOlive),
                activeIcon: Icon(Icons.account_circle, color: kTerracotta),
                label: 'Account',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardBanner() {
    return Card(
      color: const Color(0xFFFFFBEB),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFDE68A), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WarriorLeaderboardScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF08A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFEAB308),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFCA8A04),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Warrior Leaderboard',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF78350F),
                      ),
                    ),
                    Text(
                      'Check rankings & top-performing warriors.',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF92400E),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentNotificationBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final notices = snapshot.data!.docs
            .map((d) => Notice.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();

        final latestNotice = notices.first;
        final timeAgo = _getRelativeTime(latestNotice.createdAt);

        return Material(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _openNotificationsFeed(notices),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: kTerracotta,
                  radius: 18,
                  child: Icon(Icons.campaign, color: Colors.white, size: 20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kTerracotta.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LATEST ANNOUNCEMENT',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: kTerracotta,
                        ),
                      ),
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kDeepOlive.withOpacity(0.55),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestNotice.title,
                        style: GoogleFonts.sourceSans3(
                          fontWeight: FontWeight.bold,
                          color: kDeepOlive,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        latestNotice.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sourceSans3(
                          color: kDeepOlive.withOpacity(0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: kDeepOlive),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWarriorProfileCard(Child child, Map<String, dynamic> childData) {
    final String parentName = childData['parentName'] ?? _auth.currentUser?.displayName ?? 'Parent';
    final String feeStatus = (childData['feeStatus'] ?? child.feeStatus ?? 'due').toString().toLowerCase();
    final String? photoBase64 = (childData['photoBase64'] as String?) ?? (childData['photoUrl'] as String?);
    final List completedCodes = (childData['codesCompleted'] as List?) ?? child.codesCompleted;
    final List customTrophies = (childData['trophiesEarned'] as List?) ?? [];
    final isPaid = feeStatus == 'paid';
    final isPendingApproval = child.status == 'pending_coach_approval';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kDeepOlive.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: kDeepOlive.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: kDeepOlive,
                backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                    ? MemoryImage(base64Decode(
                        photoBase64.contains(',') ? photoBase64.split(',').last : photoBase64,
                      ))
                    : null,
                child: (photoBase64 == null || photoBase64.isEmpty)
                    ? Text(
                        child.name.isNotEmpty ? child.name[0].toUpperCase() : 'W',
                        style: GoogleFonts.sourceSans3(
                          color: kWarmCream,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  child.name,
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: kDeepOlive,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                tooltip: 'Edit Warrior Profile',
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: kTerracotta,
                                ),
                                onPressed: () => _showEditWarriorDialog(
                                  childId: child.id,
                                  currentName: child.name,
                                  currentAge: childData['age'] ?? child.age,
                                  currentPhotoBase64: photoBase64,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPendingApproval)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kTerracotta.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Awaiting Approval',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kTerracotta,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Parent: $parentName',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        color: kDeepOlive.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Fee Status: ${isPaid ? "PAID" : "DUE"}',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: kDeepOlive.withOpacity(0.15), height: 1),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('warrior_codes').snapshots(),
            builder: (context, snapshot) {
              final unlockedCodesDocs = snapshot.hasData
                  ? snapshot.data!.docs.where((d) => completedCodes.contains(d.id)).toList()
                  : [];
              
              unlockedCodesDocs.sort((a, b) {
                final orderA = (a.data() as Map<String, dynamic>)['order'] ?? 0;
                final orderB = (b.data() as Map<String, dynamic>)['order'] ?? 0;
                return orderB.compareTo(orderA);
              });

              final List<Widget> trophyCards = [];

              for (var cDoc in unlockedCodesDocs) {
                final cData = cDoc.data() as Map<String, dynamic>;
                final codeTitle = cData['title'] ?? 'Code';
                final reward = (cData['milestoneReward'] != null && cData['milestoneReward'].toString().isNotEmpty)
                    ? cData['milestoneReward'].toString()
                    : codeTitle;
                final String? trophyImageUrl = cData['trophyImageUrl'] as String?;

                trophyCards.add(
                  Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (trophyImageUrl != null && trophyImageUrl.isNotEmpty)
                          Image.network(
                            trophyImageUrl,
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildDefaultTrophyIcon(),
                          )
                        else
                          _buildDefaultTrophyIcon(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                reward,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: const Color(0xFF78350F),
                                ),
                              ),
                              Text(
                                codeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 11,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              for (var trophyItem in customTrophies.reversed) {
                final String trophyTitle = trophyItem is Map
                    ? (trophyItem['title'] ?? trophyItem['name'] ?? 'Custom Trophy')
                    : trophyItem.toString();
                final String trophySubtitle = trophyItem is Map
                    ? (trophyItem['subtitle'] ?? trophyItem['description'] ?? 'Milestone Award')
                    : 'Milestone Award';
                final String? customImageUrl = trophyItem is Map ? trophyItem['imageUrl'] : null;

                trophyCards.add(
                  Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (customImageUrl != null && customImageUrl.isNotEmpty)
                          Image.network(
                            customImageUrl,
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildDefaultTrophyIcon(),
                          )
                        else
                          _buildDefaultTrophyIcon(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                trophyTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: const Color(0xFF78350F),
                                ),
                              ),
                              Text(
                                trophySubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 11,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final totalTrophyCount = trophyCards.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trophies & Milestone Awards ($totalTrophyCount)',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  const SizedBox(height: 12),
                  totalTrophyCount == 0
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'No trophies earned yet. Complete Warrior Codes to unlock awards!',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 13,
                              color: kDeepOlive.withOpacity(0.6),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 64,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: trophyCards.length,
                            itemBuilder: (context, index) {
                              return trophyCards[index];
                            },
                          ),
                        ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Code Progress & History',
                style: GoogleFonts.sourceSans3(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kDeepOlive,
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('warrior_codes').snapshots(),
                builder: (context, codeSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('approvals_queue')
                        .where('childId', isEqualTo: child.id)
                        .snapshots(),
                    builder: (context, approvalsSnapshot) {
                      return TextButton(
                        onPressed: (!codeSnapshot.hasData || codeSnapshot.data!.docs.isEmpty)
                            ? null
                            : () {
                                final docs = List<QueryDocumentSnapshot>.from(codeSnapshot.data!.docs);
                                docs.sort((a, b) {
                                  final orderA = (a.data() as Map<String, dynamic>)['order'] ?? 0;
                                  final orderB = (b.data() as Map<String, dynamic>)['order'] ?? 0;
                                  return orderA.compareTo(orderB);
                                });

                                final pendingCodeIds = <String>{};
                                if (approvalsSnapshot.hasData) {
                                  for (var doc in approvalsSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    if ((data['status'] ?? '').toString().toLowerCase() == 'pending') {
                                      final codeId = (data['codeId'] ?? '').toString();
                                      if (codeId.isNotEmpty) pendingCodeIds.add(codeId);
                                    }
                                  }
                                }

                                int activeIndex = docs.indexWhere((doc) => !completedCodes.contains(doc.id));
                                if (activeIndex == -1 && docs.isNotEmpty) {
                                  activeIndex = docs.length - 1;
                                }

                                _showAllCodesModal(
                                  context: context,
                                  docs: docs,
                                  completedCodes: completedCodes,
                                  pendingCodeIds: pendingCodeIds,
                                  activeIndex: activeIndex,
                                  childId: child.id,
                                  childName: child.name,
                                );
                              },
                        child: Text(
                          'View All',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kTerracotta,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('approvals_queue')
                .where('childId', isEqualTo: child.id)
                .snapshots(),
            builder: (context, approvalsSnapshot) {
              final pendingCodeIds = <String>{};
              if (approvalsSnapshot.hasData) {
                for (var doc in approvalsSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if ((data['status'] ?? '').toString().toLowerCase() == 'pending') {
                    final codeId = (data['codeId'] ?? '').toString();
                    if (codeId.isNotEmpty) pendingCodeIds.add(codeId);
                  }
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('warrior_codes').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: kTerracotta));
                  }

                  final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                  docs.sort((a, b) {
                    final orderA = (a.data() as Map<String, dynamic>)['order'] ?? 0;
                    final orderB = (b.data() as Map<String, dynamic>)['order'] ?? 0;
                    return orderA.compareTo(orderB);
                  });

                  if (docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  int activeIndex = docs.indexWhere((doc) => !completedCodes.contains(doc.id));
                  if (activeIndex == -1) {
                    activeIndex = docs.length - 1;
                  }

                  int prevIndex = activeIndex - 1;
                  int currIndex = activeIndex;
                  int nextIndex = activeIndex + 1;

                  if (prevIndex < 0 && docs.length >= 3) {
                    prevIndex = 0;
                    currIndex = 1;
                    nextIndex = 2;
                  } else if (nextIndex >= docs.length && docs.length >= 3) {
                    nextIndex = docs.length - 1;
                    currIndex = docs.length - 2;
                    prevIndex = docs.length - 3;
                  }

                  final displayIndices = <int>[];
                  if (prevIndex >= 0 && prevIndex < docs.length) displayIndices.add(prevIndex);
                  if (currIndex >= 0 && currIndex < docs.length && !displayIndices.contains(currIndex)) displayIndices.add(currIndex);
                  if (nextIndex >= 0 && nextIndex < docs.length && !displayIndices.contains(nextIndex)) displayIndices.add(nextIndex);

                  if (displayIndices.length < 3) {
                    displayIndices.clear();
                    for (int i = 0; i < docs.length && i < 3; i++) {
                      displayIndices.add(i);
                    }
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayIndices.length,
                    itemBuilder: (context, listIndex) {
                      final index = displayIndices[listIndex];
                      final doc = docs[index];
                      final codeData = doc.data() as Map<String, dynamic>;
                      final codeId = doc.id;
                      final title = codeData['title'] ?? 'Warrior Code';
                      final reward = codeData['milestoneReward'] ?? '';

                      final isCompleted = completedCodes.contains(codeId);
                      final isPending = pendingCodeIds.contains(codeId);
                      final isCurrent = !isCompleted && index == activeIndex;
                      final isUnlocked = isCompleted || isPending || isCurrent;

                      Color cardBg = Colors.white;
                      Color borderColor = kDeepOlive.withOpacity(0.12);
                      Color statusBg = const Color(0xFFE8F5E9);
                      Color statusTextColor = Colors.green.shade700;
                      String statusText = 'Completed';
                      Widget leadingIcon = const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                      );

                      if (isCompleted) {
                        statusBg = const Color(0xFFE8F5E9);
                        statusTextColor = Colors.green.shade700;
                        statusText = 'Completed';
                        leadingIcon = const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                        );
                      } else if (isPending) {
                        borderColor = Colors.orange.shade300;
                        statusBg = Colors.orange.withOpacity(0.15);
                        statusTextColor = Colors.orange.shade800;
                        statusText = 'Pending Review';
                        leadingIcon = CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.orange.withOpacity(0.15),
                          child: Icon(Icons.hourglass_top, color: Colors.orange.shade800, size: 20),
                        );
                      } else if (isCurrent) {
                        borderColor = kTerracotta;
                        statusBg = const Color(0xFFFDE8E4);
                        statusTextColor = kTerracotta;
                        statusText = 'In Progress (Active)';
                        leadingIcon = const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFFDE8E4),
                          child: Icon(Icons.play_arrow_rounded, color: kTerracotta, size: 24),
                        );
                      } else {
                        statusBg = Colors.grey.shade100;
                        statusTextColor = Colors.grey.shade600;
                        statusText = 'Locked';
                        leadingIcon = CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade100,
                          child: Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          if (!isUnlocked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Complete previous Warrior Codes to unlock $title.'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CodeDetailScreen(
                                childId: child.id,
                                codeId: codeId,
                              ),
                            ),
                          );
                        },
                        child: Opacity(
                          opacity: isUnlocked ? 1.0 : 0.6,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
                            ),
                            child: Row(
                              children: [
                                leadingIcon,
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.sourceSans3(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: kDeepOlive,
                                        ),
                                      ),
                                      if (reward.isNotEmpty)
                                        Text(
                                          'Reward: $reward',
                                          style: GoogleFonts.sourceSans3(
                                            fontSize: 12,
                                            color: kDeepOlive.withOpacity(0.65),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: GoogleFonts.sourceSans3(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTrophyIcon() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF08A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFACC15).withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEAB308),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFCA8A04),
        size: 20,
      ),
    );
  }

  Widget _buildEventsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('events').snapshots(),
      builder: (context, snapshot) {
        final events = (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
            ? snapshot.data!.docs
                .map((d) => UpcomingEvent.fromMap(d.id, d.data() as Map<String, dynamic>))
                .toList()
            : <UpcomingEvent>[];

        // Safe sort by document index/order or fallback
        events.sort((a, b) => 0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Events & Guests',
              style: GoogleFonts.sourceSans3(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 8),
            events.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kDeepOlive.withOpacity(0.12)),
                    ),
                    child: Text(
                      'No scheduled upcoming events or guest sessions.',
                      style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
                    ),
                  )
                : SizedBox(
                    height: 115,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return GestureDetector(
                          onTap: () => _showEventDetailModal(event),
                          child: Container(
                            width: 210,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kDeepOlive.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.category.toUpperCase(),
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: kTerracotta,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sourceSans3(
                                    fontWeight: FontWeight.bold,
                                    color: kDeepOlive,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12,
                                    color: kDeepOlive.withOpacity(0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('highlights').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.hasData ? List<QueryDocumentSnapshot>.from(snapshot.data!.docs) : [];

        // Sort highlights descending by timestamp/createdAt so the most recent appears on the far left
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          
          final timeA = (dataA['createdAt'] is Timestamp) 
              ? (dataA['createdAt'] as Timestamp).toDate() 
              : DateTime(0);
          final timeB = (dataB['createdAt'] is Timestamp) 
              ? (dataB['createdAt'] as Timestamp).toDate() 
              : DateTime(0);

          return timeB.compareTo(timeA);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class Moments & Highlights',
              style: GoogleFonts.sourceSans3(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 8),
            docs.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kDeepOlive.withOpacity(0.12)),
                    ),
                    child: Text(
                      'No class highlights or moment clips posted yet.',
                      style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.6)),
                    ),
                  )
                : SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final String title = data['title'] ?? 'Class Moment';
                        final String caption = data['caption'] ?? '';
                        final String? photoBase64 = data['photoBase64'] as String?;
                        final String? videoUrl = data['videoUrl'] as String?;
                        final bool hasImage = photoBase64 != null && photoBase64.isNotEmpty;
                        final bool hasVideoUrl = videoUrl != null && videoUrl.isNotEmpty;
                        final bool isInstagramReel =
                            hasVideoUrl && videoUrl.toLowerCase().contains('instagram.com');

                        return GestureDetector(
                          onTap: () {
                            _showParentMediaViewerModal(
                              title: title,
                              caption: caption,
                              photoBase64: photoBase64,
                              videoUrl: videoUrl,
                            );
                          },
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kDeepOlive.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 60,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: kDeepOlive.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: hasImage
                                        ? Image.memory(
                                            base64Decode(
                                              photoBase64.contains(',')
                                                  ? photoBase64.split(',').last
                                                  : photoBase64,
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Center(
                                              child: Icon(Icons.broken_image,
                                                  color: Colors.grey),
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              isInstagramReel
                                                  ? Icons.camera_alt
                                                  : Icons.play_circle_fill,
                                              color: isInstagramReel
                                                  ? Colors.pink.shade700
                                                  : kTerracotta,
                                              size: 32,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sourceSans3(
                                    fontWeight: FontWeight.bold,
                                    color: kDeepOlive,
                                  ),
                                ),
                                Text(
                                  caption.isNotEmpty
                                      ? caption
                                      : (isInstagramReel ? 'Instagram Reel' : 'Class Moment'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12,
                                    color: kDeepOlive.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildEditorialLibraryBanner() {
    return Card(
      color: kDeepOlive,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditorialLibraryScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kWarmCream.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: kWarmCream,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parenting a Warrior',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kWarmCream,
                      ),
                    ),
                    Text(
                      'Read articles on character, discipline & home focus.',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        color: kWarmCream.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: kWarmCream,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(List<Child> children) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('warrior_codes').snapshots(),
      builder: (context, snapshot) {
        final totalAvailableCodes = snapshot.hasData ? snapshot.data!.docs.length : 1;
        final analytics = FamilyAnalytics.fromChildren(children, totalAvailableCodes);

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Family Progress & Analytics',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kDeepOlive,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kTerracotta.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(analytics.overallProgressPercentage * 100).toStringAsFixed(0)}% Mastered',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kTerracotta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: analytics.overallProgressPercentage,
                    minHeight: 10,
                    backgroundColor: kDeepOlive.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(kTerracotta),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Warriors', '${analytics.totalChildren}', Icons.groups),
                    _buildStatColumn('Codes Mastered', '${analytics.totalCodesCompleted}', Icons.verified),
                    _buildStatColumn('Trophies', '${analytics.totalTrophiesEarned}', Icons.emoji_events),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kDeepOlive, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.sourceSans3(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kDeepOlive,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.sourceSans3(
            fontSize: 12,
            color: kDeepOlive.withOpacity(0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0x14C85A32),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.face,
                size: 48,
                color: kTerracotta,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No warriors yet',
              style: GoogleFonts.sourceSans3(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kDeepOlive,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to add your child to your dashboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                color: kDeepOlive.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddChildDialog,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Warrior'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kDeepOlive,
                foregroundColor: kWarmCream,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelectorBar(List<Child> children) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final child = children[index];
          final isSelected = child.id == _selectedChildId;

          return ChoiceChip(
            label: Text(child.name),
            selected: isSelected,
            selectedColor: kTerracotta,
            backgroundColor: Colors.white,
            labelStyle: GoogleFonts.sourceSans3(
              color: isSelected ? kWarmCream : kDeepOlive,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedChildId = child.id;
                });
              }
            },
          );
        },
      ),
    );
  }
}

class NotificationsFeedScreen extends StatelessWidget {
  final List<Notice> notices;

  const NotificationsFeedScreen({super.key, required this.notices});

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
    final sortedNotices = List<Notice>.from(notices)
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

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
        title: Text(
          'Notifications',
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: kDeepOlive,
          ),
        ),
      ),
      body: sortedNotices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: kDeepOlive.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedNotices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notice = sortedNotices[index];
                final timeAgo = _getRelativeTime(notice.createdAt);

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
                              children: [
                                Expanded(
                                  child: Text(
                                    notice.title,
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
                              notice.content,
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
            ),
    );
  }
}