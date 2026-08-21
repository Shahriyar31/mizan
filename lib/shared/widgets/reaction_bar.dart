/// ReactionBar — the three-reaction footer shared by Halaqa and Al-Minbar.
///
/// Your README allows exactly three responses and no text replies. This widget
/// is the physical embodiment of that rule: three tappable pills, each showing
/// its icon, label, and count. The one(s) the current user has left glow in the
/// accent colour. Tapping toggles — the parent decides what that means (which
/// feed/provider), so this widget stays pure and reusable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../models/reaction_type.dart';

class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.counts,
    required this.mine,
    required this.onTap,
    this.compact = false,
  });

  /// How many of each reaction the item has.
  final Map<ReactionType, int> counts;

  /// The reactions the current user has toggled on (highlighted).
  final Set<ReactionType> mine;

  /// Called when a reaction pill is tapped.
  final ValueChanged<ReactionType> onTap;

  /// Slightly tighter spacing for dense lists.
  final bool compact;

  static IconData _icon(ReactionType r) => switch (r) {
        ReactionType.dua => Icons.volunteer_activism_rounded,
        ReactionType.resonated => Icons.graphic_eq_rounded,
        ReactionType.moved => Icons.favorite_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in ReactionTypeX.ordered) ...[
          _ReactionPill(
            icon: _icon(r),
            label: r.label,
            count: counts[r] ?? 0,
            active: mine.contains(r),
            compact: compact,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(r);
            },
          ),
          if (r != ReactionTypeX.ordered.last)
            SizedBox(width: compact ? 6 : 8),
        ],
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = active ? AppColors.gold : AppColors.navInactive;
    final Color bg =
        active ? AppColors.gold.withValues(alpha: 0.14) : Colors.transparent;
    final Color border = active
        ? AppColors.gold.withValues(alpha: 0.35)
        : AppColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 15, color: fg),
            const SizedBox(width: 5),
            Text(
              count > 0 ? '$label · $count' : label,
              style: AppTypography.caption(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
