/// SharedContentCard — renders a [SharedContent] snapshot as a tappable card.
///
/// This is the inner "what was shared" block used by BOTH the Halaqa feed and
/// the Al-Minbar feed. Each feed wraps it with its own chrome (who shared it,
/// an optional note, the reaction bar), but the content itself always looks the
/// same — one card, one look, everywhere.
///
/// The card takes its material colour, accent, and icon from [ContentVisuals],
/// so a Qur'an share and a companion's story are visually distinct at a glance.
/// Tapping it calls [onOpen] (the feed passes the router push), and the citation
/// is shown compactly with a verified tick to keep the app's trust cue present
/// without dominating a scrolling feed.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../models/shared_content.dart';
import 'content_visuals.dart';

class SharedContentCard extends StatelessWidget {
  const SharedContentCard({
    super.key,
    required this.content,
    this.onOpen,
  });

  final SharedContent content;

  /// Called when the card is tapped. Null disables the tap affordance (e.g.
  /// for content whose source screen no longer exists).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final v = ContentVisuals.of(content.contentType);
    final tappable = onOpen != null && (content.routePath?.isNotEmpty ?? false);

    return Material(
      color: v.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tappable ? onOpen : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: v.accent.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type badge + open affordance ──────────────────
              Row(
                children: [
                  _TypeBadge(
                    icon: v.icon,
                    label: content.contentType.label,
                    accent: v.accent,
                  ),
                  const Spacer(),
                  if (tappable)
                    Icon(
                      Icons.north_east_rounded,
                      size: 15,
                      color: v.accent.withValues(alpha: 0.7),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Arabic title (if any) ─────────────────────────
              // For Qur'an the Arabic *is* the scripture, so it reads in
              // primary text and is given a little more room; for a name or a
              // person it's a short label and looks better tinted in the accent.
              if ((content.titleArabic?.trim().isNotEmpty ?? false)) ...[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    content.titleArabic!,
                    maxLines: content.contentType == ContentType.quran ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.arabicBody(
                      color: content.contentType == ContentType.quran
                          ? AppColors.textPrimary
                          : v.accent,
                      size: content.contentType == ContentType.quran ? 24 : 22,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],

              // ── English title ────────────────────────────────
              Text(
                content.title,
                style: AppTypography.displaySmall(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              // ── Excerpt ───────────────────────────────────────
              if (content.excerpt.trim().isNotEmpty)
                Text(
                  content.excerpt,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                ),

              const SizedBox(height: 12),

              // ── Compact citation (trust cue) ──────────────────
              _CompactCitation(
                source: content.citationSource,
                detail: content.citationDetail,
                accent: v.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(label.toUpperCase(), style: AppTypography.labelSmall(color: accent)),
        ],
      ),
    );
  }
}

class _CompactCitation extends StatelessWidget {
  const _CompactCitation({
    required this.source,
    required this.detail,
    required this.accent,
  });

  final String source;
  final String? detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasDetail = detail?.trim().isNotEmpty ?? false;
    return Row(
      children: [
        Icon(Icons.menu_book_rounded, size: 12, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hasDetail ? '$source · $detail' : source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
      ],
    );
  }
}
