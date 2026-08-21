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
  });

  final HalaqaShareView view;
  final ValueChanged<ReactionType> onReact;
  final VoidCallback? onOpen;

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
