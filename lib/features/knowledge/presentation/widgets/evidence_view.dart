/// Evidence Mode — the display layer for "why does this say that?"
///
/// Every narrative section that carries citations renders them here, in the same
/// visual language the layer reader already uses: stacked full-width rows, the
/// Qur'an reference filled navy, hadith and tafsir outlined, a bare prose citation
/// marked in sage as provenance. Full-width because a citation is somebody else's
/// sentence and its length is not ours to predict — a pill overflowed by 156px
/// once and will not get the chance again.
///
/// What is new here over the reader's private version is that a row can be
/// *opened*. Tapping the Qur'an row shows the ayah with its translation and a way
/// into the five layers; tapping a numbered hadith fetches and shows it; tapping a
/// tafsir row reads the bundled Ibn Kathir passage; tapping a scholar shows what
/// was attributed to them. A prose citation stays flat and unpressable, because
/// there is nothing behind it we could honestly show.
library;

import 'package:flutter/material.dart';

import '../../../../core/knowledge/evidence.dart';
import '../../../../core/theme/mizan_tokens.dart';
import '../../../../core/theme/mizan_typography.dart';
import '../../../../shared/widgets/mizan/mizan_components.dart';
import '../../../../shared/widgets/mizan/mizan_pressable.dart';
import 'evidence_sheet.dart';

/// The icon for each kind of evidence. One glyph per kind, everywhere, so a
/// reader learns them once.
IconData evidenceIcon(Evidence e) => switch (e) {
      QuranEvidence() => Icons.menu_book_outlined,
      HadithEvidence() => Icons.format_quote_rounded,
      TafsirEvidence() => Icons.auto_stories_outlined,
      ScholarEvidence() => Icons.account_balance_outlined,
      CitationEvidence() => Icons.verified_outlined,
    };

/// Whether tapping leads anywhere honest.
///
/// An unnumbered hadith citation is openable: the sheet shows the collection, the
/// book, the narrator and the description the corpus gave, and says plainly that
/// there is no number to fetch. That is not a claim about which hadith it is — it
/// is the citation, laid out, with the collection identified. A [CitationEvidence]
/// is not openable, because the row already shows the whole of what we have.
bool evidenceIsOpenable(Evidence e) => switch (e) {
      QuranEvidence() => true,
      HadithEvidence() => true,
      TafsirEvidence() => true,
      ScholarEvidence() => true,
      CitationEvidence() => false,
    };

/// A titled block of evidence rows.
///
/// Renders nothing at all when the list is empty — a section with no citations
/// shows no heading, rather than an empty "Evidence" label that reads like a
/// missing feature.
class EvidenceRows extends StatelessWidget {
  const EvidenceRows({
    super.key,
    required this.evidence,
    this.label,
    this.showLabel = true,
  });

  final List<Evidence> evidence;

  /// Defaults to "EVIDENCE". Overridden where the surrounding page says it
  /// better — "SOURCES" under a theme description.
  final String? label;

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) return const SizedBox.shrink();

    // De-duplicated and ordered: Qur'an, hadith, tafsir, scholar, then prose.
    final seen = <String>{};
    final items = <Evidence>[];
    for (final e in evidence) {
      if (seen.add(e.key)) items.add(e);
    }
    items.sort(Evidence.compare);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          MizanSectionLabel(label ?? 'EVIDENCE'),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          EvidenceRow(evidence: items[i]),
        ],
      ],
    );
  }
}

/// One citation.
class EvidenceRow extends StatelessWidget {
  const EvidenceRow({super.key, required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final e = evidence;
    final openable = evidenceIsOpenable(e);
    final onTap = openable ? () => showEvidenceSheet(context, e) : null;

    // The Qur'an reference is the primary evidence, so it takes the filled navy
    // row and everything else stays outlined.
    final filled = e is QuranEvidence;

    final secondary = switch (e) {
      QuranEvidence(:final quotedText) => quotedText,
      HadithEvidence(:final detail, :final quotedText, :final narrator) =>
        detail ?? quotedText ?? narrator,
      TafsirEvidence() => null,
      ScholarEvidence(:final remark) => remark,
      CitationEvidence() => null,
    };

    final glyphColor = filled
        ? p.accent // gold on navy: the one place gold is free to go
        : (e is CitationEvidence ? p.sage : p.muted);

    final titleColor = filled ? MizanTone.inverse.onColor(p) : p.ink;
    final subtitleColor =
        filled ? MizanTone.inverse.mutedOn(p) : p.muted;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(evidenceIcon(e), size: 17, color: glyphColor),
        ),
        const SizedBox(width: 9),
        // Expanded, not Flexible: the row owns the full width, so a long
        // citation wraps instead of running off the screen.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.label,
                style: MizanType.bodyStrong(color: titleColor)
                    .copyWith(fontSize: 14.5, height: 1.35),
              ),
              if (secondary != null && secondary.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  secondary.trim(),
                  style: MizanType.body(color: subtitleColor)
                      .copyWith(fontSize: 13.5, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        if (openable) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: filled ? MizanTone.inverse.mutedOn(p) : p.muted,
            ),
          ),
        ],
      ],
    );

    const padding = EdgeInsets.symmetric(horizontal: 15, vertical: 11);

    // Unpressable evidence stays flat with a hairline; a tappable row gets the
    // press treatment, per the one shadow rule.
    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: MizanGeometry.rowBorderRadius,
          border:
              Border.all(color: p.hairline, width: MizanGeometry.hairlineWidth),
        ),
        child: Padding(padding: padding, child: content),
      );
    }

    return MizanPressable(
      onTap: onTap,
      borderRadius: MizanGeometry.rowBorderRadius,
      fill: filled ? (p.isLight ? p.ink : p.card) : p.card,
      border: BorderSide(
        color: filled ? p.accent.withValues(alpha: 0.36) : p.hairline,
        width: MizanGeometry.hairlineWidth,
      ),
      padding: padding,
      semanticLabel: e.label,
      child: content,
    );
  }
}
