import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'coach/coach_dashboard_screen.dart';
import 'parent/parent_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  String _dashboardTitle(String? role) {
    switch (role) {
      case 'coach':
        return 'Coach Portal';
      case 'parent':
        return 'Parent Dashboard';
      default:
        return 'Jr. Warrior';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: _HomeBody(
              title: 'Unable to load profile',
              subtitle: user.email ?? user.uid,
              role: null,
              errorMessage: 'We could not load your profile. Pull to retry after signing back in.',
              isSigningOut: _isSigningOut,
              onSignOut: _signOut,
            ),
          );
        }

        final data = snapshot.data?.data();
        final role = data?['role'] as String?;
        final fullName = (data?['fullName'] as String?)?.trim();
        final displayName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (user.email ?? 'Warrior'));

        // Route directly based on user role
        if (role == 'coach') {
          return const CoachDashboardScreen();
        }

        if (role == 'parent') {
          return const ParentDashboardScreen();
        }

        return Scaffold(
          appBar: AppBar(title: Text(_dashboardTitle(role))),
          body: _HomeBody(
            title: 'Welcome, $displayName',
            subtitle: user.email ?? user.uid,
            role: role,
            isSigningOut: _isSigningOut,
            onSignOut: _signOut,
          ),
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.title,
    required this.subtitle,
    required this.role,
    required this.isSigningOut,
    required this.onSignOut,
    this.errorMessage,
  });

  final String title;
  final String subtitle;
  final String? role;
  final bool isSigningOut;
  final VoidCallback onSignOut;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCoach = role == 'coach';
    final isParent = role == 'parent';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCoach || isParent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isCoach ? colors.primary : colors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isCoach ? 'Coach Portal' : 'Parent Dashboard',
                  style: GoogleFonts.sourceSans3(
                    color: isCoach ? colors.onPrimary : colors.onSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Profile pending',
                  style: GoogleFonts.sourceSans3(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSerif4(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                fontSize: 16,
                color: colors.primary.withValues(alpha: 0.75),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceSans3(color: colors.error),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: isSigningOut ? null : onSignOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.secondary,
                  foregroundColor: colors.onSecondary,
                ),
                child: isSigningOut
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onSecondary,
                        ),
                      )
                    : const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}