/// MinbarPostTile — one post in the public Al-Minbar feed.
///
/// A public post is simpler than a circle share: no personal note, just who
/// posted it, the content, and the three reactions. It reuses the exact same
/// [SharedContentCard] and [ReactionBar] as Halaqa, so the two feeds stay
/// visually identical where it matters.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/models/reaction_type.dart';
import '../../../../shared/widgets/initial_avatar.dart';
import '../../../../shared/widgets/reaction_bar.dart';
import '../../../../shared/widgets/shared_content_card.dart';
import '../../models/minbar_models.dart';

class MinbarPostTile extends StatelessWidget {
  const MinbarPostTile({
    super.key,
    required this.view,
    required this.onReact,
    this.onOpen,
  });

  final MinbarShareView view;
  final ValueChanged<ReactionType> onReact;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final share = view.share;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 10),
        SharedContentCard(content: share.content, onOpen: onOpen),
        const SizedBox(height: 10),
        ReactionBar(
          counts: view.counts,
          mine: view.myReactions,
          onTap: onReact,
        ),
      ],
    );
  }
}
