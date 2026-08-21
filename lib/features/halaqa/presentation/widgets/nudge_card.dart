/// NudgeCard — a gentle prompt to reach out to members who've gone quiet.
///
/// The README's idea of a "nudge" is caring, not nagging: if someone hasn't
/// engaged for a few days, the circle can send them a warm reminder. There's no
/// backend or push yet, so tapping is a *symbolic* local gesture — the parent
/// shows a confirmation. When Supabase + notifications land, only the callback's
/// implementation changes; this card stays exactly as is.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/halaqa_models.dart';

class NudgeCard extends StatelessWidget {
  const NudgeCard({
    super.key,
    required this.quiet,
    required this.onNudge,
  });

  final List<HalaqaMember> quiet;
  final ValueChanged<HalaqaMember> onNudge;

  @override
  Widget build(BuildContext context) {
    if (quiet.isEmpty) return const SizedBox.shrink();

    final first = quiet.first;
    final others = quiet.length - 1;
    final who = others == 0
        ? '${first.displayName} has been quiet'
        : '${first.displayName} and $others other${others == 1 ? '' : 's'} have been quiet';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded,
                size: 18, color: AppColors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  who,
                  style: AppTypography.labelLarge(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Send a gentle reminder that they\'re missed.',
                  style: AppTypography.bodySmall(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => onNudge(first),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppColors.amber.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            child: Text('Nudge', style: AppTypography.buttonSecondary(color: AppColors.amber)),
          ),
        ],
      ),
    );
  }
}
