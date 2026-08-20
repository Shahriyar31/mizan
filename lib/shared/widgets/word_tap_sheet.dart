/// Word Tap Bottom Sheet
///
/// Appears when a user taps any Arabic word in the ayah.
/// Shows: Arabic word large, transliteration, root, meaning, insight.
/// Action: Save to Vocabulary Bank.
///
/// Why a bottom sheet and not a dialog:
/// Bottom sheets feel native on mobile — they emerge from the content
/// area, can be dismissed by swiping down, and don't block the full
/// screen. Dialogs feel like interruptions. This should feel like
/// leaning in to look closer.
library;

import 'package:flutter/material.dart';
import '../models/ayah.dart';
import '../models/ayah_word.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../features/quran/data/word_roots_data.dart';

/// Shows the word tap bottom sheet for a given word.
/// Call this from any word tap gesture in the ayah reader.
void showWordSheet(BuildContext context, AyahWord word) {
  final rootData = WordRootsData.lookup(word.arabic);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // allows taller sheet
    backgroundColor: Colors.transparent,
    builder: (_) => WordTapSheet(
      word: word,
      rootData: rootData,
    ),
  );
}

class WordTapSheet extends StatefulWidget {
  const WordTapSheet({
    super.key,
    required this.word,
    this.rootData,
  });

  final AyahWord word;
  final WordData? rootData;

  @override
  State<WordTapSheet> createState() => _WordTapSheetState();
}

class _WordTapSheetState extends State<WordTapSheet> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // ── Arabic word — hero ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.word.arabic,
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
          if (widget.word.transliteration.isNotEmpty)
            Text(
              widget.word.transliteration,
              style: AppTypography.bodySmall(
                color: AppColors.gold,
              ),
            ),

          const SizedBox(height: 20),

          // ── Divider ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              color: AppColors.white.withOpacity(0.08),
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
                if (widget.word.translation.isNotEmpty) ...[
                  _InfoRow(
                    label: 'MEANING',
                    value: widget.word.translation,
                    valueColor: AppColors.white,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Root from curated data ────────────────────
                if (widget.rootData != null) ...[
                  _InfoRow(
                    label: 'ROOT',
                    value: widget.rootData!.root.isNotEmpty
                        ? widget.rootData!.root
                        : 'No root (function word)',
                    valueColor: AppColors.gold,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'ROOT MEANING',
                    value: widget.rootData!.meaning,
                    valueColor: AppColors.white,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Scholarly insight ─────────────────────────
                if (widget.rootData?.insight.isNotEmpty == true) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.night,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: AppColors.jade,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡  INSIGHT',
                          style: AppTypography.caption(
                            color: AppColors.jade,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.rootData!.insight,
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
                if (widget.rootData == null) ...[
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
                      style: AppTypography.bodySmall(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Save to Vocabulary Bank ───────────────────
                GestureDetector(
                  onTap: _saved
                      ? null
                      : () {
                          // TODO Phase 4: save to SQLite vocabulary bank
                          // For now show visual confirmation
                          setState(() => _saved = true);

                          // Show snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"${widget.word.arabic}" saved to Vocabulary Bank',
                                style: AppTypography.bodySmall(
                                  color: AppColors.white,
                                ),
                              ),
                              backgroundColor: AppColors.jade,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _saved ? AppColors.jade : AppColors.night,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _saved
                            ? AppColors.jade
                            : AppColors.jade.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _saved
                              ? Icons.check_rounded
                              : Icons.bookmark_add_outlined,
                          color: _saved ? AppColors.white : AppColors.jade,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _saved
                              ? 'Saved to Vocabulary Bank'
                              : '+ Save to Vocabulary Bank',
                          style: AppTypography.labelLarge(
                            color: _saved ? AppColors.white : AppColors.jade,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
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
        Text(
          label,
          style: AppTypography.caption(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.labelLarge(color: valueColor),
        ),
      ],
    );
  }
}
