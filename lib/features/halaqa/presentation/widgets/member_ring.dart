/// MemberRing — the horizontal row of faces at the top of a circle.
///
/// It answers "who is in here with me?" at a glance. The creator gets a small
/// star; members who've gone quiet (no activity for [AppConstants.daysBeforeNudge]
/// days) are dimmed, which visually sets up the nudge card below. Tapping a
/// member is a no-op for now — profiles arrive with real accounts later.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/initial_avatar.dart';
import '../../models/halaqa_models.dart';

class MemberRing extends StatelessWidget {
  const MemberRing({
    super.key,
    required this.members,
    required this.createdBy,
    required this.currentUserId,
  });

  final List<HalaqaMember> members;
  final String createdBy;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final m = members[i];
          final isCreator = m.userId == createdBy;
          final isMe = m.userId == currentUserId;
          final quiet = m.isQuiet(days: AppConstants.daysBeforeNudge);

          return SizedBox(
            width: 56,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InitialAvatar(name: m.displayName, size: 44, dimmed: quiet),
                    if (isCreator)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.night,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.gold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isMe ? 'You' : m.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(
                    color: quiet ? AppColors.muted : AppColors.textSecondary,
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
