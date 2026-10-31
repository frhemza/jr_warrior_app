import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BadgeCard extends StatelessWidget {
  final String codeId;
  final String title;
  final String rewardName;
  final bool isEarned;

  const BadgeCard({
    super.key,
    required this.codeId,
    required this.title,
    required this.rewardName,
    required this.isEarned,
  });

  IconData _getBadgeIcon() {
    if (codeId.contains('01')) return Icons.shield_outlined;
    if (codeId.contains('02')) return Icons.military_tech_outlined;
    if (codeId.contains('03')) return Icons.emoji_events_outlined;
    return Icons.workspace_premium_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getBadgeIcon();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEarned ? const Color(0xFFF3E2B3) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEarned
              ? const Color(0xFF8A6A12)
              : const Color(0xFF1A2F25).withValues(alpha: 0.1),
          width: isEarned ? 2 : 1,
        ),
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: const Color(0xFF8A6A12).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEarned
                      ? const Color(0xFFC85A32)
                      : const Color(0xFF1A2F25).withValues(alpha: 0.08),
                ),
                child: Icon(
                  isEarned ? iconData : Icons.lock_outline_rounded,
                  color: isEarned ? Colors.white : const Color(0xFF1A2F25).withValues(alpha: 0.35),
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rewardName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sourceSerif4(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isEarned
                  ? const Color(0xFF1A2F25)
                  : const Color(0xFF1A2F25).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isEarned ? 'Unlocked' : 'Locked Code',
            style: GoogleFonts.sourceSans3(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isEarned
                  ? const Color(0xFFC85A32)
                  : const Color(0xFF1A2F25).withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}