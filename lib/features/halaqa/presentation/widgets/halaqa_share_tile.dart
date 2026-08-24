/// HalaqaShareTile — one item in a circle's feed.
///
/// Layout, top to bottom: who shared it and when, their optional ≤100-char
/// note, the [SharedContentCard] itself, and the [ReactionBar]. The tile is
/// "dumb": it takes a [HalaqaShareView] and two callbacks and renders. All the
/// state (optimistic reactions, persistence) lives in the feed provider, so
/// this widget never touches the repository.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/models/reaction_type.dart';
import '../../../../shared/widgets/initial_avatar.dart';
import '../../../../shared/widgets/reaction_bar.dart';
import '../../../../shared/widgets/shared_content_card.dart';
import '../../models/halaqa_models.dart';

class HalaqaShareTile extends StatelessWidget {
  const HalaqaShareTile({
    super.key,
    required this.view,
    required this.onReact,
    this.onOpen,
    this.onDelete,
  });

  final HalaqaShareView view;
  final ValueChanged<ReactionType> onReact;
  final VoidCallback? onOpen;

  /// Removes this share. Null on every share the viewer did not write.
  ///
  /// The tile does not compare ids to work that out, and deliberately never
  /// learns who is looking: [HalaqaCircleScreen] owns the one ownership check
  /// and passes null for other people's shares, so the rule that decides who may
  /// delete lives in exactly one place instead of being restated by every widget
  /// that draws a share.
  ///
  /// Null draws no control rather than a disabled one — "you may not delete this"
  /// is not information another member needs about a reflection that was never
  /// theirs.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final share = view.share;
    final hasNote = share.personalNote?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sharer + time ─────────────────────────────────────
        Row(
          children: [
            InitialAvatar(name: share.sharedByName, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                share.sharedByName,
                style: AppTypography.labelLarge(color: AppColors.textPrimary),
              ),
            ),
            Text(
              RelativeTime.short(share.sharedAt),
              style: AppTypography.caption(color: AppColors.muted),
            ),
            // The one way to remove a share, beside the time that says when it
            // arrived. Error-coloured like the "Leave circle" row in the circle
            // menu, so the destructive controls in this feature look alike, and
            // labelled the same two words on every share it appears on — a
            // control that renamed itself per item ("Remove ayah", "Remove
            // story") would read as several different features.
            if (onDelete != null) ...[
              const SizedBox(width: 2),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.error),
                tooltip: 'Delete share',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ],
          ],
        ),

        // ── Personal note (the sharer's own words) ────────────
        if (hasNote) ...[
          const SizedBox(height: 8),
          Text(
            share.personalNote!.trim(),
            style: AppTypography.quoteItalic(color: AppColors.textSecondary),
          ),
        ],

        const SizedBox(height: 10),

        // ── The shared content ────────────────────────────────
        SharedContentCard(content: share.content, onOpen: onOpen),

        const SizedBox(height: 10),

        // ── Reactions (the only response) ─────────────────────
        ReactionBar(
          counts: view.counts,
          mine: view.myReactions,
          onTap: onReact,
        ),
      ],
    );
  }
}
