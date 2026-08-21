// ─────────────────────────────────────────────────────────────────────────────
// entry_card.dart
// Cards for Prophet / Sahabi / DivineName in the Discover list views.
// Shows: name, teaser, layer progress dots, lock state, era/tribe tag.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:taddabur/core/theme/app_colors.dart';
import 'package:taddabur/core/theme/app_typography.dart';
import '../models/discover_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Prophet Card
// ─────────────────────────────────────────────────────────────────────────────

class ProphetCard extends StatelessWidget {
  final ProphetEntry entry;
  final DiscoverProgress? progress;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const ProphetCard({
    super.key,
    required this.entry,
    required this.progress,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final layersUnlocked = progress?.layersUnlocked ?? 0;
    final isCompleted = progress?.entryCompleted ?? false;

    return _EntryCardShell(
      isUnlocked: isUnlocked,
      isCompleted: isCompleted,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sequence number
          _SequenceBadge(
            number: entry.sequenceNumber,
            isUnlocked: isUnlocked,
            isCompleted: isCompleted,
          ),
          const SizedBox(width: 16),
          // Name + metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      entry.nameArabic,
                      style: AppTypography.arabicDisplay(
                          color: isUnlocked ? AppColors.gold : AppColors.muted,
                          size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.nameEnglish,
                        style: AppTypography.displaySmall(
                            color: isUnlocked
                                ? AppColors.textPrimary
                                : AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.era,
                  style: AppTypography.labelSmall(
                      color: AppColors.gold.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 8),
                if (isUnlocked) ...[
                  Text(
                    entry.teaser,
                    style: AppTypography.bodySmall(color: AppColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _LayerProgressDots(layersUnlocked: layersUnlocked),
                ] else
                  _LockedHint(quranicMention: entry.quranicMention),
              ],
            ),
          ),
          if (!isUnlocked) const _LockIcon(),
          if (isCompleted) const _CheckIcon(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sahabi Card
// ─────────────────────────────────────────────────────────────────────────────

class SahabiCard extends StatelessWidget {
  final SahabiEntry entry;
  final DiscoverProgress? progress;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const SahabiCard({
    super.key,
    required this.entry,
    required this.progress,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final layersUnlocked = progress?.layersUnlocked ?? 0;
    final isCompleted = progress?.entryCompleted ?? false;

    return _EntryCardShell(
      isUnlocked: isUnlocked,
      isCompleted: isCompleted,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SequenceBadge(
            number: entry.sequenceNumber,
            isUnlocked: isUnlocked,
            isCompleted: isCompleted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.nameArabic,
                      style: AppTypography.arabicDisplay(
                          color: isUnlocked ? AppColors.gold : AppColors.muted,
                          size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.kunyah.isNotEmpty
                                ? entry.kunyah
                                : entry.nameEnglish,
                            style: AppTypography.displaySmall(
                                color: isUnlocked
                                    ? AppColors.textPrimary
                                    : AppColors.muted),
                          ),
                          Text(
                            entry.tribe,
                            style: AppTypography.labelSmall(
                                color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isUnlocked) ...[
                  Text(
                    entry.teaser,
                    style: AppTypography.bodySmall(color: AppColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _LayerProgressDots(layersUnlocked: layersUnlocked),
                ],
              ],
            ),
          ),
          if (!isUnlocked) const _LockIcon(),
          if (isCompleted) const _CheckIcon(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Divine Name Card
// ─────────────────────────────────────────────────────────────────────────────

class DivineNameCard extends StatelessWidget {
  final DivineName entry;
  final DiscoverProgress? progress;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const DivineNameCard({
    super.key,
    required this.entry,
    required this.progress,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final layersUnlocked = progress?.layersUnlocked ?? 0;
    final isCompleted = progress?.entryCompleted ?? false;

    return _EntryCardShell(
      isUnlocked: isUnlocked,
      isCompleted: isCompleted,
      onTap: onTap,
      // Black card with large background Arabic calligraphy — per Minbar spec
      backgroundDecoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFF0A0A0A) : AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? AppColors.gold.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Large background calligraphy
          if (isUnlocked)
            Positioned(
              right: -10,
              top: -10,
              child: Text(
                entry.arabic,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 80,
                  color: AppColors.gold.withValues(alpha: 0.08),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Number badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.surfaceDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.gold
                        : AppColors.muted.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${entry.number}',
                    style: AppTypography.labelSmall(
                        color: isUnlocked
                            ? AppColors.gold
                            : AppColors.muted.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.arabic,
                      style: AppTypography.arabicDisplay(
                          color: isUnlocked ? AppColors.gold : AppColors.muted,
                          size: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.translit,
                      style: AppTypography.bodySmall(color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.meaningBrief,
                      style: AppTypography.bodyMedium(
                          color:
                              isUnlocked ? AppColors.white : AppColors.muted),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(height: 10),
                      _LayerProgressDots(layersUnlocked: layersUnlocked),
                    ],
                  ],
                ),
              ),
              if (!isUnlocked) const _LockIcon(),
              if (isCompleted) const _CheckIcon(),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EntryCardShell extends StatelessWidget {
  final Widget child;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback? onTap;
  final BoxDecoration? backgroundDecoration;

  const _EntryCardShell({
    required this.child,
    required this.isUnlocked,
    required this.isCompleted,
    this.onTap,
    this.backgroundDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = backgroundDecoration ??
        BoxDecoration(
          color: isUnlocked ? AppColors.surface : AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? AppColors.gold.withValues(alpha: 0.6)
                : isUnlocked
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : Colors.transparent,
            width: 1,
          ),
        );

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SequenceBadge extends StatelessWidget {
  final int number;
  final bool isUnlocked;
  final bool isCompleted;

  const _SequenceBadge({
    required this.number,
    required this.isUnlocked,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.gold
            : isUnlocked
                ? AppColors.gold.withValues(alpha: 0.12)
                : AppColors.surfaceDim,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUnlocked
              ? AppColors.gold.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '$number',
          style: AppTypography.labelSmall(
              color: isCompleted
                  ? AppColors.night
                  : isUnlocked
                      ? AppColors.gold
                      : AppColors.muted),
        ),
      ),
    );
  }
}

class _LayerProgressDots extends StatelessWidget {
  final int layersUnlocked;

  const _LayerProgressDots({required this.layersUnlocked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < layersUnlocked;
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: filled ? 20 : 8,
          height: 4,
          decoration: BoxDecoration(
            color:
                filled ? AppColors.gold : AppColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.lock_outline_rounded,
      size: 18,
      color: AppColors.muted.withValues(alpha: 0.4),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
    );
  }
}

class _LockedHint extends StatelessWidget {
  final String quranicMention;
  const _LockedHint({required this.quranicMention});

  @override
  Widget build(BuildContext context) {
    return Text(
      quranicMention,
      style: AppTypography.labelSmall(
          color: AppColors.muted.withValues(alpha: 0.5)),
    );
  }
}
