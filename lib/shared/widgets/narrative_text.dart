library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'fade_slide_in.dart';

/// Turns existing newline-separated lesson content into an editorial reading
/// rhythm without changing the source data.
///
/// Beats are no longer treated uniformly: a beat that reads as a direct
/// quote gets pull-quote treatment, the opening beat gets a labelled framing
/// box, and the closing beat gets a "chapter end" weight. Each beat also
/// fades/slides in with a short stagger so a layer feels like it's being
/// told rather than dumped on screen.
class NarrativeText extends StatelessWidget {
  const NarrativeText({
    super.key,
    required this.content,
    this.accent = AppColors.gold,
    this.momentLabel = 'THE MOMENT',
  });

  final String content;
  final Color accent;

  /// Label for the opening framing box — pass the layer's own title
  /// (e.g. "THE CALL", "THE TRIAL") so five layers don't all say the same
  /// thing.
  final String momentLabel;

  static final RegExp _quotePattern = RegExp(r'''[:]\s*['"‘“]|^['"‘“]''');

  bool _looksLikeQuote(String beat) {
    // A beat reads as a quote when it contains a "said: '...'" style
    // narration and the quoted span covers most of the beat — not just an
    // aside that happens to use quotation marks.
    final quoteStart = beat.indexOf(RegExp(r'''['"‘“]'''));
    if (quoteStart == -1) return false;
    if (!_quotePattern.hasMatch(beat)) return false;
    final quotedSpan = beat.length - quoteStart;
    return quotedSpan / beat.length > 0.45;
  }

  @override
  Widget build(BuildContext context) {
    final beats = content
        .split(RegExp(r'\n\s*\n'))
        .map((beat) => beat.trim())
        .where((beat) => beat.isNotEmpty)
        .toList();

    if (beats.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];

    // Opening beat — framing box, labelled per-layer instead of a fixed tag.
    widgets.add(FadeSlideIn(
      index: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(momentLabel.toUpperCase(),
                style: AppTypography.labelSmall(color: accent)),
            const SizedBox(height: 8),
            SelectableText(
              beats.first,
              style: AppTypography.bodyLarge(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    ));

    final middleBeats = beats.length > 2 ? beats.sublist(1, beats.length - 1) : <String>[];
    final closingBeat = beats.length > 1 ? beats.last : null;

    for (var i = 0; i < middleBeats.length; i++) {
      final beat = middleBeats[i];
      widgets.add(const SizedBox(height: 18));
      widgets.add(FadeSlideIn(
        index: i + 1,
        child: _looksLikeQuote(beat)
            ? _PullQuote(text: beat, accent: accent)
            : _MarkedParagraph(text: beat, accent: accent),
      ));
    }

    if (closingBeat != null) {
      widgets.add(const SizedBox(height: 22));
      widgets.add(FadeSlideIn(
        index: middleBeats.length + 1,
        child: _looksLikeQuote(closingBeat)
            ? _PullQuote(text: closingBeat, accent: accent)
            : _ClosingBeat(text: closingBeat, accent: accent),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// A regular narrative paragraph — gold bar + body text, as before.
class _MarkedParagraph extends StatelessWidget {
  const _MarkedParagraph({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 28,
          margin: const EdgeInsets.only(top: 4, right: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Expanded(
          child: SelectableText(
            text,
            style: AppTypography.bodyLarge(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// A beat that reads as a direct narration/quote — set apart with a large
/// opening glyph and italic serif so it feels spoken, not reported.
class _PullQuote extends StatelessWidget {
  const _PullQuote({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 40,
                height: 0.4,
                color: accent.withValues(alpha: 0.55),
              )),
          const SizedBox(height: 2),
          SelectableText(
            text,
            style: AppTypography.quoteItalic(color: AppColors.parchment)
                .copyWith(fontSize: 15.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// The final beat of a layer — given a little more air so a story lands
/// instead of just stopping.
class _ClosingBeat extends StatelessWidget {
  const _ClosingBeat({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 1.5,
          margin: const EdgeInsets.only(bottom: 14),
          color: accent.withValues(alpha: 0.4),
        ),
        SelectableText(
          text,
          style: AppTypography.bodyLarge(color: AppColors.textPrimary)
              .copyWith(height: 1.85),
        ),
      ],
    );
  }
}

class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.subtitle,
    this.accent = AppColors.gold,
  });

  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Text('PAUSE WITH THIS',
                  style: AppTypography.labelSmall(color: accent)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: AppTypography.quoteItalic(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'What does this invite you to notice in your own life?',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
