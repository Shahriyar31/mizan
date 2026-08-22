/// Vocabulary Bank Screen
/// Lives inside the Growth tab
/// Shows all saved Quranic words with spaced repetition status
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vocab_providers.dart';
import '../../../shared/models/vocab_word.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class VocabBankScreen extends ConsumerWidget {
  const VocabBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(vocabWordsProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _VocabHeader(wordsAsync: wordsAsync),

          // ── Word List ────────────────────────────────────────
          Expanded(
            child: wordsAsync.when(
              loading: () =>  Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load vocabulary',
                  style: AppTypography.bodyMedium(color: AppColors.muted),
                ),
              ),
              data: (words) {
                if (words.isEmpty) return const _EmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return _VocabWordCard(
                      word: words[index],
                      onDelete: () => ref
                          .read(vocabWordsProvider.notifier)
                          .deleteWord(words[index].id!),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _VocabHeader extends StatelessWidget {
  const _VocabHeader({required this.wordsAsync});
  final AsyncValue<List<VocabWord>> wordsAsync;

  @override
  Widget build(BuildContext context) {
    final count = wordsAsync.valueOrNull?.length ?? 0;

    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 16,
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
                'Vocabulary Bank',
                style: AppTypography.displaySmall(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              '$count words saved · spaced repetition active',
              style: AppTypography.bodySmall(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single Word Card ──────────────────────────────────────────
class _VocabWordCard extends StatelessWidget {
  const _VocabWordCard({
    required this.word,
    required this.onDelete,
  });

  final VocabWord word;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDue = word.isDueForReview;

    return Dismissible(
      // Swipe left to delete
      key: Key('vocab_${word.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(14),
          border: isDue
              ? Border.all(color: AppColors.gold.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            // Arabic word
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    word.arabic,
                    style: AppTypography.arabicBody(color: AppColors.textPrimary),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    word.transliteration,
                    style: AppTypography.caption(color: AppColors.gold),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Divider
            Container(width: 1, height: 40, color: AppColors.border),

            const SizedBox(width: 14),

            // Meaning + reference
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.meaning,
                    style: AppTypography.labelMedium(color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.reference,
                    style: AppTypography.caption(),
                  ),
                  const SizedBox(height: 4),
                  // Review status badge
                  _ReviewBadge(word: word),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review Status Badge ───────────────────────────────────────
class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.word});
  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    if (word.reviewCount == 0) {
      return _badge('New', AppColors.jade);
    }
    if (word.isDueForReview) {
      return _badge('Due for review', AppColors.gold);
    }
    // Calculate days until next review
    final daysLeft = word.nextReviewAt!
        .difference(DateTime.now())
        .inDays;
    return _badge(
      'Review in $daysLeft day${daysLeft == 1 ? '' : 's'}',
      AppColors.muted,
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ٱقْرَأْ',
              style: AppTypography.arabicHero(
                color: AppColors.muted,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No words saved yet',
              style: AppTypography.labelLarge(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap any Arabic word while reading\nto save it here',
              style: AppTypography.bodySmall(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
