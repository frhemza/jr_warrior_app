import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

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
              'Crop Profile Photo',
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

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;

  String? _photoBase64;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      if (data.containsKey('photoBase64')) {
        final base64Str = data['photoBase64'] as String?;
        if (base64Str != null && base64Str.isNotEmpty) {
          setState(() {
            _photoBase64 = base64Str;
            _imageBytes = base64Decode(
              base64Str.contains(',') ? base64Str.split(',').last : base64Str,
            );
          });
        }
      }
    }
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      final Uint8List rawBytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      final Uint8List? croppedBytes = await showDialog<Uint8List>(
        context: context,
        builder: (_) => _NativeCropDialog(imageBytes: rawBytes),
      );

      if (croppedBytes != null) {
        final base64String = base64Encode(croppedBytes);

        setState(() {
          _imageBytes = croppedBytes;
          _photoBase64 = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick or crop image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
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
                _pickProfileImage(ImageSource.gallery);
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
                _pickProfileImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await user.updateDisplayName(newName);
      await _firestore.collection('users').doc(user.uid).set({
        'name': newName,
        'fullName': newName,
        'photoBase64': _photoBase64 ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: kDeepOlive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
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
    }
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool isDeleting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: kWarmCream,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Delete Account?',
              style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action is permanent. All associated warrior profiles and data will be removed. Enter your password to confirm.',
                  style: GoogleFonts.sourceSans3(color: kDeepOlive, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isDeleting,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: GoogleFonts.sourceSans3(color: kDeepOlive),
                    errorText: errorMessage,
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
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
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: GoogleFonts.sourceSans3(color: kDeepOlive.withOpacity(0.7))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: kWarmCream,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        final password = passwordController.text.trim();
                        if (password.isEmpty) {
                          setDialogState(() => errorMessage = 'Password is required');
                          return;
                        }

                        setDialogState(() {
                          isDeleting = true;
                          errorMessage = null;
                        });

                        final error = await _deleteParentAccount(password);

                        if (error != null) {
                          setDialogState(() {
                            isDeleting = false;
                            errorMessage = error;
                          });
                        } else {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kWarmCream),
                      )
                    : const Text('Delete Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _deleteParentAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'No user currently signed in.';

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final batch = _firestore.batch();

      final userDocRef = _firestore.collection('users').doc(user.uid);
      batch.delete(userDocRef);

      final childrenSnap = await _firestore
          .collection('children')
          .where('parentId', isEqualTo: user.uid)
          .get();

      for (var doc in childrenSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect password. Please try again.';
      } else if (e.code == 'requires-recent-login') {
        return 'Please sign out and sign back in before deleting your account.';
      }
      return e.message ?? 'An authentication error occurred.';
    } catch (e) {
      return 'Failed to delete account: $e';
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: kTerracotta,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: kWarmCream,
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: kDeepOlive,
                  backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                  child: _imageBytes == null
                      ? Text(
                          (user?.displayName?.isNotEmpty ?? false)
                              ? user!.displayName![0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: kWarmCream,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _showImageSourceSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: kTerracotta,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: kWarmCream,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Information',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepOlive,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline, color: kDeepOlive),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: user?.email ?? '',
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined, color: kDeepOlive),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTerracotta,
                      foregroundColor: kWarmCream,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kWarmCream),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: kDeepOlive.withOpacity(0.12)),
            ),
            child: ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: kTerracotta),
              title: Text(
                'Reset Password',
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.bold,
                  color: kDeepOlive,
                ),
              ),
              subtitle: Text(
                'Send a password reset link to your email',
                style: GoogleFonts.sourceSans3(),
              ),
              onTap: _sendPasswordReset,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: Text(
                'Delete Account',
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              subtitle: Text(
                'Permanently remove account and warrior data',
                style: GoogleFonts.sourceSans3(fontSize: 12, color: Colors.grey.shade700),
              ),
              onTap: _showDeleteAccountDialog,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.shade300),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Sign Out',
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              subtitle: Text(
                'Log out of your account on this device',
                style: GoogleFonts.sourceSans3(),
              ),
              onTap: _signOut,
            ),
          ),
        ],
      ),
    );
  }
}