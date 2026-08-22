/// Growth Map Screen — the user's practice, drawn as a night sky.
///
/// A constellation hero (see [ConstellationView]) sits above four "grounded"
/// stat cards. The picture is the feeling; the cards are the truth. Every
/// number comes from the user's own local data via [growthMapProvider], so the
/// map can never show progress that wasn't earned.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/growth_map_models.dart';
import '../domain/growth_map_providers.dart';
import 'widgets/constellation_view.dart';

class GrowthMapScreen extends ConsumerWidget {
  const GrowthMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapAsync = ref.watch(growthMapProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Column(
        children: [
          const _MapHeader(),
          Expanded(
            child: mapAsync.when(
              loading: () =>  Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not draw your map right now.',
                    style: AppTypography.bodyMedium(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (map) => _MapBody(map: map),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────
class _MapHeader extends StatelessWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child:  Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Growth Map',
                style: AppTypography.displaySmall(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              'Your knowledge and practice, as a night sky',
              style: AppTypography.bodySmall(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ────────────────────────────────────────────────────────────
class _MapBody extends StatelessWidget {
  const _MapBody({required this.map});
  final GrowthMapData map;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _HeroSummary(map: map),
        const SizedBox(height: 16),
        _SkyCard(map: map),
        const SizedBox(height: 24),
        Text(
          'YOUR GROWTH AREAS',
          style: AppTypography.labelSmall(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final c in map.constellations) ...[
          _AreaStatCard(constellation: c),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Icon(Icons.verified_outlined,
                size: 14, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Every star reflects something you have truly done — nothing '
                'here is decorative.',
                style: AppTypography.caption(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Hero summary ──────────────────────────────────────────────────────
class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.map});
  final GrowthMapData map;

  String get _contextLine {
    if (map.isEmpty) {
      return 'Your sky is still dark — but not for long. Open an ayah, save a '
          'word, or reflect tonight; each act lights a star.';
    }
    if (map.starsLit == map.starsTotal) {
      return 'Every star is lit. May Allah accept it and raise you higher.';
    }
    return 'Your sky is taking shape. Keep going — the next star is close.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${map.starsLit}',
                style: AppTypography.displayLarge(color: AppColors.gold)
                    .copyWith(fontSize: 42, height: 1.0),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'of ${map.starsTotal}\nstars lit',
                  style: AppTypography.bodySmall(color: AppColors.muted),
                ),
              ),
              const Spacer(),
              _StreakChip(streak: map.streak),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _contextLine,
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    final color = active ? AppColors.gold : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            active ? '$streak-day streak' : 'No streak yet',
            style: AppTypography.caption(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Sky card (wraps the constellation canvas) ─────────────────────────
class _SkyCard extends StatelessWidget {
  const _SkyCard({required this.map});
  final GrowthMapData map;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: ConstellationView(constellations: map.constellations),
    );
  }
}

// ── Per-area stat card ────────────────────────────────────────────────
class _AreaStatCard extends StatelessWidget {
  const _AreaStatCard({required this.constellation});
  final GrowthConstellation constellation;

  IconData get _icon => switch (constellation.area) {
        GrowthArea.quran => Icons.auto_stories_rounded,
        GrowthArea.vocabulary => Icons.bookmark_rounded,
        GrowthArea.reflection => Icons.nights_stay_rounded,
        GrowthArea.discover => Icons.explore_rounded,
      };

  String get _nextLabel => constellation.isComplete
      ? 'All ${constellation.total} stars lit'
      : 'Next star at ${constellation.nextStar!.threshold} · '
          '${constellation.toNextStar} to go';

  @override
  Widget build(BuildContext context) {
    final c = constellation;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: c.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          c.name,
                          style: AppTypography.labelLarge(
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.arabicName,
                          style: AppTypography.arabicSmall(
                              color: c.color, size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.headline,
                      style:
                          AppTypography.labelMedium(color: AppColors.textPrimary),
                    ),
                    Text(
                      c.detail,
                      style: AppTypography.caption(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StarPips(constellation: c),
          const SizedBox(height: 8),
          Text(
            _nextLabel,
            style: AppTypography.caption(
              color: c.isComplete ? c.color : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of small stars — filled for earned milestones, outlined for the rest.
class _StarPips extends StatelessWidget {
  const _StarPips({required this.constellation});
  final GrowthConstellation constellation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < constellation.total; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              constellation.isLit(i)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 16,
              color: constellation.isLit(i)
                  ? constellation.color
                  : AppColors.muted.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}
