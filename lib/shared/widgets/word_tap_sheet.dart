/// Word Tap Bottom Sheet — updated with real SQLite save
///
/// Changes from previous version:
/// - Save button now calls VocabRepository via Riverpod
/// - Button shows "Already Saved" if word is in database
/// - Tracks save state with isWordSavedProvider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/quran/data/word_roots_data.dart';
import '../../features/growth/domain/vocab_providers.dart';
import '../models/vocab_word.dart';
import '../models/ayah_word.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Shows the word tap bottom sheet for a given word.
void showWordSheet(
  BuildContext context,
  AyahWord word, {
  required int surahNumber,
  required int ayahNumber,
  required String surahName,
}) {
  final rootData = WordRootsData.lookup(word.arabic);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      child: WordTapSheet(
        word: word,
        rootData: rootData,
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        surahName: surahName,
      ),
    ),
  );
}

class WordTapSheet extends ConsumerWidget {
  const WordTapSheet({
    super.key,
    required this.word,
    this.rootData,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
  });

  final AyahWord word;
  final WordData? rootData;
  final int surahNumber;
  final int ayahNumber;
  final String surahName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch whether this word is already saved
    final isSavedAsync = ref.watch(isWordSavedProvider(word.arabic));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ── Drag handle ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // ── Arabic word — hero ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              word.arabic,
              style: AppTypography.arabicHero(
                color: AppColors.white,
                size: 48,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // ── Transliteration ───────────────────────────────────
          if (word.transliteration.isNotEmpty)
            Text(
              word.transliteration,
              style: AppTypography.bodySmall(color: AppColors.gold),
            ),

          const SizedBox(height: 20),

          // ── Divider ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              color: AppColors.white.withValues(alpha: 0.08),
              height: 1,
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Word meaning from API ─────────────────────
                if (word.translation.isNotEmpty) ...[
                  _InfoRow(
                    label: 'MEANING',
                    value: word.translation,
                    valueColor: AppColors.white,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Root + meaning from curated data ──────────
                if (rootData != null) ...[
                  if (rootData!.root.isNotEmpty) ...[
                    _InfoRow(
                      label: 'ROOT',
                      value: rootData!.root,
                      valueColor: AppColors.gold,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _InfoRow(
                    label: 'ROOT MEANING',
                    value: rootData!.meaning,
                    valueColor: AppColors.white,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Scholarly insight ─────────────────────────
                if (rootData?.insight.isNotEmpty == true) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.night,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: const BorderSide(color: AppColors.jade, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡  INSIGHT',
                          style: AppTypography.caption(color: AppColors.jade),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rootData!.insight,
                          style: AppTypography.bodySmall(
                            color: const Color(0xFF9CADB8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── No root data available ────────────────────
                if (rootData == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.night,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Detailed root analysis for this word '
                      'is being curated. More words added '
                      'with each update.',
                      style: AppTypography.bodySmall(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Save to Vocabulary Bank ───────────────────
                isSavedAsync.when(
                  loading: () => const _SaveButton(
                    isSaved: false,
                    isLoading: true,
                    onTap: null,
                  ),
                  error: (_, __) => const _SaveButton(
                    isSaved: false,
                    isLoading: false,
                    onTap: null,
                  ),
                  data: (isSaved) => _SaveButton(
                    isSaved: isSaved,
                    isLoading: false,
                    onTap: isSaved
                        ? null // already saved — button disabled
                        : () async {
                            // Build VocabWord from available data
                            final vocabWord = VocabWord(
                              arabic: word.arabic,
                              transliteration: word.transliteration,
                              meaning: word.translation,
                              root: rootData?.root ?? '',
                              insight: rootData?.insight ?? '',
                              surahNumber: surahNumber,
                              ayahNumber: ayahNumber,
                              surahName: surahName,
                              savedAt: DateTime.now(),
                            );

                            // Save via Riverpod notifier
                            final saved = await ref
                                .read(vocabWordsProvider.notifier)
                                .saveWord(vocabWord);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    saved
                                        ? '"${word.arabic}" saved to Vocabulary Bank'
                                        : 'Already in your Vocabulary Bank',
                                    style: AppTypography.bodySmall(
                                      color: AppColors.white,
                                    ),
                                  ),
                                  backgroundColor: saved
                                      ? AppColors.jade
                                      : AppColors.muted,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Save Button ───────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isSaved,
    required this.isLoading,
    required this.onTap,
  });

  final bool isSaved;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSaved ? AppColors.jade : AppColors.night,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSaved
                ? AppColors.jade
                : AppColors.jade.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.jade,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                isSaved ? Icons.check_rounded : Icons.bookmark_add_outlined,
                color: isSaved ? AppColors.white : AppColors.jade,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              isSaved ? 'Saved to Vocabulary Bank' : '+ Save to Vocabulary Bank',
              style: AppTypography.labelLarge(
                color: isSaved ? AppColors.white : AppColors.jade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.labelLarge(color: valueColor)),
      ],
    );
  }
}
