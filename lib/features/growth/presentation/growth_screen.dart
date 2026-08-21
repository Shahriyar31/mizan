/// Growth Tab — Personal knowledge and progress space
///
/// Phase 3: Shows Vocabulary Bank entry point + word count
/// Phase 5: Adds Growth Map constellation, Seerah Timeline, Scholar AI
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/vocab_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordCountAsync = ref.watch(vocabCountProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _GrowthHeader(),
          ),

          // ── Feature Cards ────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Vocabulary Bank card
                _GrowthCard(
                  icon: Icons.bookmark_rounded,
                  iconColor: AppColors.jade,
                  title: 'Vocabulary Bank',
                  subtitle: wordCountAsync.when(
                    data: (count) => count == 0
                        ? 'No words saved yet — tap words while reading'
                        : '$count word${count == 1 ? '' : 's'} saved · spaced repetition active',
                    loading: () => 'Loading...',
                    error: (_, __) => 'Tap words while reading to save them',
                  ),
                  badge: wordCountAsync.maybeWhen(
                    data: (count) => count > 0 ? '$count' : null,
                    orElse: () => null,
                  ),
                  onTap: () => context.push('/growth/vocab'),
                ),

                const SizedBox(height: 12),

                // Growth Map — coming Phase 5
                const _GrowthCard(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.gold,
                  title: 'Growth Map',
                  subtitle:
                      'Visual constellation of your knowledge — coming soon',
                  isLocked: true,
                  onTap: null,
                ),

                const SizedBox(height: 12),

                // Scholar AI — coming Phase 2
                _GrowthCard(
                  icon: Icons.school_rounded,
                  iconColor: AppColors.violet,
                  title: 'Scholar AI',
                  subtitle:
                      'Ask questions — every answer cites a verified source',
                  isLocked: true,
                  onTap: null,
                ),

                const SizedBox(height: 12),

                // Muhasabah record — coming Phase 3
                const _GrowthCard(
                  icon: Icons.nights_stay_rounded,
                  iconColor: AppColors.navInactive,
                  title: 'Muhasabah',
                  subtitle:
                      'Nightly 3-question self-reckoning — private forever',
                  isLocked: true,
                  onTap: null,
                ),

                const SizedBox(height: 12),

                // Al-Meezan — coming Phase 3
                _GrowthCard(
                  icon: Icons.balance_rounded,
                  iconColor: AppColors.amber,
                  title: 'Al-Meezan',
                  subtitle: 'Days lived, Fridays passed, Ramadans witnessed',
                  isLocked: true,
                  onTap: null,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _GrowthHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'النُّمُوّ',
            style: AppTypography.arabicDisplay(color: AppColors.gold, size: 20),
          ),
          Text(
            'Growth',
            style: AppTypography.displayLarge(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Your personal knowledge and transformation record',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Growth Feature Card ───────────────────────────────────────
class _GrowthCard extends StatelessWidget {
  const _GrowthCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isLocked = false,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isLocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? AppColors.slate
                        : iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isLocked ? AppColors.navInactive : iconColor,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: AppTypography.labelLarge(
                              color: isLocked
                                  ? AppColors.navInactive
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                          if (isLocked) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.lock_rounded,
                              size: 12,
                              color: AppColors.navInactive,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall(color: AppColors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Arrow — only for unlocked cards
                if (!isLocked)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
