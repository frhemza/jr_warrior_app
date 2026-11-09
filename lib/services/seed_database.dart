import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Call this function to seed complete mock data into Firestore.
Future<void> seedJrWarriorCompleteDatabase() async {
  final firestore = FirebaseFirestore.instance;
  final WriteBatch batch = firestore.batch();

  debugPrint('Starting Firestore database seeding...');

  try {
    // ----------------------------------------------------
    // 1. Users Collection (Parents)
    // ----------------------------------------------------
    final List> parents = [
      {
        'id': 'parent_001',
        'name': 'Tariq Mahmood',
        'fullName': 'Tariq Mahmood',
        'email': 'tariq.m@example.com',
        'phone': '+923001234567',
        'role': 'parent',
      },
      {
        'id': 'parent_002',
        'name': 'Fatima Hassan',
        'fullName': 'Fatima Hassan',
        'email': 'fatima.h@example.com',
        'phone': '+923219876543',
        'role': 'parent',
      },
      {
        'id': 'parent_003',
        'name': 'Bilal Ahmed',
        'fullName': 'Bilal Ahmed',
        'email': 'bilal.a@example.com',
        'phone': '+923335557788',
        'role': 'parent',
      },
      {
        'id': 'parent_004',
        'name': 'Usman Khan',
        'fullName': 'Usman Khan',
        'email': 'usman.k@example.com',
        'phone': '+923018889900',
        'role': 'parent',
      },
      {
        'id': 'parent_005',
        'name': 'Zainab Raza',
        'fullName': 'Zainab Raza',
        'email': 'zainab.r@example.com',
        'phone': '+923451122334',
        'role': 'parent',
      },
      {
        'id': 'parent_006',
        'name': 'Kamran Siddiqui',
        'fullName': 'Kamran Siddiqui',
        'email': 'kamran.s@example.com',
        'phone': '+923124455667',
        'role': 'parent',
      },
      {
        'id': 'parent_007',
        'name': 'Saima Malik',
        'fullName': 'Saima Malik',
        'email': 'saima.m@example.com',
        'phone': '+923029988776',
        'role': 'parent',
      },
      {
        'id': 'parent_008',
        'name': 'Fahad Mustafa',
        'fullName': 'Fahad Mustafa',
        'email': 'fahad.m@example.com',
        'phone': '+923347766554',
        'role': 'parent',
      },
      {
        'id': 'parent_009',
        'name': 'Nida Yasir',
        'fullName': 'Nida Yasir',
        'email': 'nida.y@example.com',
        'phone': '+923223344556',
        'role': 'parent',
      },
      {
        'id': 'parent_010',
        'name': 'Asad Umar',
        'fullName': 'Asad Umar',
        'email': 'asad.u@example.com',
        'phone': '+923156677889',
        'role': 'parent',
      },
    ];

    for (var parent in parents) {
      final docRef = firestore.collection('users').doc(parent['id']);
      batch.set(docRef, parent, SetOptions(merge: true));
    }

    // ----------------------------------------------------
    // 2. Children Collection (22 Warriors)
    // ----------------------------------------------------
    final List> children = [
      {'id': 'child_001', 'name': 'Zaid Mahmood', 'age': 10, 'parentId': 'parent_001', 'parentName': 'Tariq Mahmood', 'feeStatus': 'paid', 'currentCodeId': 'code_002', 'status': 'in_progress', 'codesCompleted': ['code_001']},
      {'id': 'child_002', 'name': 'Rayyan Mahmood', 'age': 7, 'parentId': 'parent_001', 'parentName': 'Tariq Mahmood', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_003', 'name': 'Ayesha Hassan', 'age': 8, 'parentId': 'parent_002', 'parentName': 'Fatima Hassan', 'feeStatus': 'due', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_004', 'name': 'Mustafa Hassan', 'age': 11, 'parentId': 'parent_002', 'parentName': 'Fatima Hassan', 'feeStatus': 'due', 'currentCodeId': 'code_003', 'status': 'in_progress', 'codesCompleted': ['code_001', 'code_002']},
      {'id': 'child_005', 'name': 'Hamza Bilal', 'age': 12, 'parentId': 'parent_003', 'parentName': 'Bilal Ahmed', 'feeStatus': 'due', 'currentCodeId': 'code_001', 'status': 'pending_coach_approval', 'codesCompleted': []},
      {'id': 'child_006', 'name': 'Yousuf Bilal', 'age': 6, 'parentId': 'parent_003', 'parentName': 'Bilal Ahmed', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_007', 'name': 'Inaya Khan', 'age': 9, 'parentId': 'parent_004', 'parentName': 'Usman Khan', 'feeStatus': 'paid', 'currentCodeId': 'code_002', 'status': 'in_progress', 'codesCompleted': ['code_001']},
      {'id': 'child_008', 'name': 'Ibrahim Khan', 'age': 13, 'parentId': 'parent_004', 'parentName': 'Usman Khan', 'feeStatus': 'paid', 'currentCodeId': 'code_003', 'status': 'in_progress', 'codesCompleted': ['code_001', 'code_002']},
      {'id': 'child_009', 'name': 'Omar Khan', 'age': 5, 'parentId': 'parent_004', 'parentName': 'Usman Khan', 'feeStatus': 'due', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_010', 'name': 'Maryam Raza', 'age': 8, 'parentId': 'parent_005', 'parentName': 'Zainab Raza', 'feeStatus': 'paid', 'currentCodeId': 'code_002', 'status': 'in_progress', 'codesCompleted': ['code_001']},
      {'id': 'child_011', 'name': 'Hassan Raza', 'age': 10, 'parentId': 'parent_005', 'parentName': 'Zainab Raza', 'feeStatus': 'paid', 'currentCodeId': 'code_003', 'status': 'in_progress', 'codesCompleted': ['code_001', 'code_002']},
      {'id': 'child_012', 'name': 'Daniel Siddiqui', 'age': 11, 'parentId': 'parent_006', 'parentName': 'Kamran Siddiqui', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_013', 'name': 'Sara Siddiqui', 'age': 7, 'parentId': 'parent_006', 'parentName': 'Kamran Siddiqui', 'feeStatus': 'due', 'currentCodeId': 'code_002', 'status': 'in_progress', 'codesCompleted': ['code_001']},
      {'id': 'child_014', 'name': 'Ali Malik', 'age': 9, 'parentId': 'parent_007', 'parentName': 'Saima Malik', 'feeStatus': 'paid', 'currentCodeId': 'code_003', 'status': 'in_progress', 'codesCompleted': ['code_001', 'code_002']},
      {'id': 'child_015', 'name': 'Zainab Malik', 'age': 6, 'parentId': 'parent_007', 'parentName': 'Saima Malik', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_016', 'name': 'Anaya Malik', 'age': 12, 'parentId': 'parent_007', 'parentName': 'Saima Malik', 'feeStatus': 'due', 'currentCodeId': 'code_002', 'status': 'in_progress', 'codesCompleted': ['code_001']},
      {'id': 'child_017', 'name': 'Saad Mustafa', 'age': 10, 'parentId': 'parent_008', 'parentName': 'Fahad Mustafa', 'feeStatus': 'paid', 'currentCodeId': 'code_003', 'status': 'in_progress', 'codesCompleted': ['code_001', 'code_002']},
      {'id': 'child_018', 'name': 'Mirha Mustafa', 'age': 8, 'parentId': 'parent_008', 'parentName': 'Fahad Mustafa', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_019', 'name': 'Yahya Yasir', 'age': 9, 'parentId': 'parent_009', 'parentName': 'Nida Yasir', 'feeStatus': 'due', 'currentCodeId': 'code_002', 'status': 'in_progress', 'codesCompleted': ['code_001']},
      {'id': 'child_020', 'name': 'Eshal Yasir', 'age': 6, 'parentId': 'parent_009', 'parentName': 'Nida Yasir', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
      {'id': 'child_021', 'name': 'Ahmed Umar', 'age': 11, 'parentId': 'parent_010', 'parentName': 'Asad Umar', 'feeStatus': 'paid', 'currentCodeId': 'code_003', 'status': 'in_progress', 'codesCompleted': ['code_001', 'code_002']},
      {'id': 'child_022', 'name': 'Bilal Umar', 'age': 7, 'parentId': 'parent_010', 'parentName': 'Asad Umar', 'feeStatus': 'paid', 'currentCodeId': 'code_001', 'status': 'in_progress', 'codesCompleted': []},
    ];

    for (var child in children) {
      final docRef = firestore.collection('children').doc(child['id']);
      batch.set(docRef, child, SetOptions(merge: true));
    }

    // ----------------------------------------------------
    // 3. Announcements Collection
    // ----------------------------------------------------
    final List> announcements = [
      {
        'id': 'announcement_001',
        'title': 'Winter Training Schedule & Uniform Update',
        'content': 'Starting next Monday, all evening training sessions will begin 15 minutes earlier (5:15 PM). Please ensure warriors wear full tracksuits over their uniforms during warm-ups.',
        'category': 'Schedule',
        'createdAt': Timestamp.fromDate(DateTime.parse('2026-11-04T09:00:00Z')),
        'isUrgent': false,
      },
      {
        'id': 'announcement_002',
        'title': 'Monthly Belt Assessment Ceremony',
        'content': 'Our upcoming Stripe & Belt Qualification Ceremony will take place on Saturday, Nov 21st. Parents are invited to attend and present stripes to their warriors!',
        'category': 'Event',
        'createdAt': Timestamp.fromDate(DateTime.parse('2026-11-02T11:30:00Z')),
        'isUrgent': true,
      },
    ];

    for (var item in announcements) {
      final docRef = firestore.collection('announcements').doc(item['id']);
      batch.set(docRef, item, SetOptions(merge: true));
    }

    // ----------------------------------------------------
    // 4. Parenting Articles Collection
    // ----------------------------------------------------
    final List> articles = [
      {
        'id': 'article_001',
        'title': 'Building Discipline Without Conflict at Home',
        'subtitle': 'How everyday home codes translate into lifelong athletic focus.',
        'readTime': '4 min read',
        'author': 'Coach Team',
        'category': 'Child Psychology',
        'content': 'Consistency is key when developing physical and mental discipline in young athletes. When parents enforce morning routines and self-care codes at home, warriors display 40% higher focus during agility drills...',
        'publishedAt': Timestamp.fromDate(DateTime.parse('2026-10-28T08:00:00Z')),
      },
      {
        'id': 'article_002',
        'title': 'Nutrition for Young Athletes: Pre-Workout Fuel',
        'subtitle': 'Simple home snacks that prevent fatigue during intensive sessions.',
        'readTime': '3 min read',
        'author': 'Nutrition Advisory',
        'category': 'Health & Diet',
        'content': 'Carbohydrates mixed with light protein 45 minutes before practice give young warriors sustained stamina without stomach heavy discomfort...',
        'publishedAt': Timestamp.fromDate(DateTime.parse('2026-11-01T10:00:00Z')),
      },
    ];

    for (var item in articles) {
      final docRef = firestore.collection('parenting_articles').doc(item['id']);
      batch.set(docRef, item, SetOptions(merge: true));
    }

    // ----------------------------------------------------
    // 5. Class Moments Collection
    // ----------------------------------------------------
    final List> moments = [
      {
        'id': 'moment_001',
        'title': 'Agility Ladder Challenge Winner',
        'caption': 'Warriors showing incredible footwork and speed during today\'s ladder drills!',
        'mediaType': 'photo',
        'likesCount': 24,
        'createdAt': Timestamp.fromDate(DateTime.parse('2026-11-05T17:45:00Z')),
      },
      {
        'id': 'moment_002',
        'title': 'Teamwork Stance Drills',
        'caption': 'Focus, stance, and respect. Great energy from the junior squad this afternoon.',
        'mediaType': 'photo',
        'likesCount': 18,
        'createdAt': Timestamp.fromDate(DateTime.parse('2026-11-03T16:20:00Z')),
      },
    ];

    for (var item in moments) {
      final docRef = firestore.collection('class_moments').doc(item['id']);
      batch.set(docRef, item, SetOptions(merge: true));
    }

    // ----------------------------------------------------
    // 6. Upcoming Events Collection
    // ----------------------------------------------------
    final List> events = [
      {
        'id': 'event_001',
        'title': 'Jr. Warrior Inter-Academy Tournament',
        'date': Timestamp.fromDate(DateTime.parse('2026-11-28T09:00:00Z')),
        'location': 'Main Athletic Arena, Karachi',
        'description': 'Friendly sparring and obstacle course competition across age divisions.',
        'registrationOpen': true,
      },
      {
        'id': 'event_002',
        'title': 'Parent-Warrior Outdoor Bootcamp',
        'date': Timestamp.fromDate(DateTime.parse('2026-12-05T07:30:00Z')),
        'location': 'Hill Park Grounds',
        'description': 'A fun morning fitness obstacle session for warriors and parents together.',
        'registrationOpen': true,
      },
    ];

    for (var item in events) {
      final docRef = firestore.collection('upcoming_events').doc(item['id']);
      batch.set(docRef, item, SetOptions(merge: true));
    }

    // Commit all changes in a single operation
    await batch.commit();
    debugPrint('Database seeding completed successfully!');
  } catch (e) {
    debugPrint('Error seeding database: $e');
  }
}

// ============================================================================
// EXECUTION RUNNER LINE
// Run via CLI: flutter pub run path/to/seed_file.dart
// Or execute `seedJrWarriorCompleteDatabase()` directly from a UI Button tap.
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await seedJrWarriorCompleteDatabase();
}