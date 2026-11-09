import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/coach/coach_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parent/parent_dashboard_screen.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background notification handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const JrWarriorApp());
}

// Function to request permissions, subscribe to topic, and save FCM device token in Firestore
Future<void> saveParentFcmToken(String userId) async {
  try {
    final messaging = FirebaseMessaging.instance;

    // Request notification permissions (required for Web/PWA, iOS, and Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Subscribe device to the global announcements FCM topic
      await messaging.subscribeToTopic('announcements');

      // Get current FCM device token
      final token = await messaging.getToken();

      if (token != null) {
        // Save token to user's document in Firestore for 1-on-1 notifications (e.g. Fee Challans)
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Listen to token refreshes to keep Firestore up to date
      messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    }
  } catch (e) {
    debugPrint('Error setting up FCM Token / Topic: $e');
  }
}

class JrWarriorApp extends StatelessWidget {
  const JrWarriorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jr. Warrior',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kWarmCream,
        colorScheme: const ColorScheme.light(
          primary: kDeepOlive,
          onPrimary: kWarmCream,
          secondary: kTerracotta,
          onSecondary: kWarmCream,
          surface: kWarmCream,
          onSurface: kDeepOlive,
          error: Color(0xFF8C2F1B),
          onError: kWarmCream,
        ),
        fontFamily: GoogleFonts.sourceSans3().fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: kWarmCream,
          foregroundColor: kDeepOlive,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.sourceSans3(
            color: kDeepOlive,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kWarmCream,
            body: Center(child: CircularProgressIndicator(color: kTerracotta)),
          );
        }

        final user = authSnapshot.data;
        // When user signs out or account gets deleted, automatically fall back to LoginScreen
        if (user == null) {
          return const LoginScreen();
        }

        // Save FCM token & subscribe to announcements whenever an authenticated session is active
        saveParentFcmToken(user.uid);

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: kWarmCream,
                body: Center(child: CircularProgressIndicator(color: kTerracotta)),
              );
            }

            if (docSnapshot.hasData && docSnapshot.data!.exists) {
              final data = docSnapshot.data!.data() as Map<String, dynamic>?;
              final role = (data?['role'] ?? '').toString().toLowerCase();

              if (role == 'coach') {
                return const CoachDashboardScreen();
              }
            }

            return const ParentDashboardScreen();
          },
        );
      },
    );
  }
}