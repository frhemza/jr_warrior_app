import 'child.dart';

class FamilyAnalytics {
  final int totalChildren;
  final int totalCodesCompleted;
  final int totalTrophiesEarned;
  final double overallProgressPercentage;

  FamilyAnalytics({
    required this.totalChildren,
    required this.totalCodesCompleted,
    required this.totalTrophiesEarned,
    required this.overallProgressPercentage,
  });

  factory FamilyAnalytics.fromChildren(List<Child> children, int totalAvailableCodes) {
    if (children.isEmpty) {
      return FamilyAnalytics(
        totalChildren: 0,
        totalCodesCompleted: 0,
        totalTrophiesEarned: 0,
        overallProgressPercentage: 0.0,
      );
    }

    final totalCompleted = children.fold<int>(0, (sum, c) => sum + c.codesCompleted.length);
    final totalTrophies = children.fold<int>(0, (sum, c) => sum + c.trophiesEarned.length);
    final maxPossible = children.length * (totalAvailableCodes > 0 ? totalAvailableCodes : 1);
    final percentage = (totalCompleted / maxPossible).clamp(0.0, 1.0);

    return FamilyAnalytics(
      totalChildren: children.length,
      totalCodesCompleted: totalCompleted,
      totalTrophiesEarned: totalTrophies,
      overallProgressPercentage: percentage,
    );
  }
}   