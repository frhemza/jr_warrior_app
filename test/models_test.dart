import 'package:flutter_test/flutter_test.dart';
import 'package:jr_warrior_app/models/child.dart';
import 'package:jr_warrior_app/models/warrior_code.dart';

void main() {
  test('Child flags inactivity after 14 days', () {
    final child = Child(
      childId: 'c1',
      parentId: 'p1',
      fullName: 'Amina',
      currentCodeId: 'respect',
      status: 'in_progress',
      trophiesEarned: const ['honesty'],
      lastProgressUpdate: DateTime(2026, 1, 1),
    );

    expect(
      child.isInactive(now: DateTime(2026, 1, 20)),
      isTrue,
    );
    expect(
      child.isInactive(now: DateTime(2026, 1, 10)),
      isFalse,
    );
  });

  test('WarriorCode parses newline instructions', () {
    final code = WarriorCode.fromMap({
      'codeId': 'respect',
      'order': 1,
      'title': 'Respect',
      'imageUrl': '',
      'description': 'Treat others well.',
      'instructions': 'Talk about respect.\nPractice at home.',
      'milestoneReward': 'Respect badge',
    });

    expect(code.instructions, ['Talk about respect.', 'Practice at home.']);
    expect(code.order, 1);
  });
}
