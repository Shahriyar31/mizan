/// The evidence sheet — what opens when a citation is tapped.
///
/// One sheet, five bodies, chosen by an exhaustive switch over [Evidence]:
///
///   • Qur'an  — the ayah in Arabic with its translation, the fragment the corpus
///               quoted, and a way through to the five layers on that ayah.
///   • Hadith  — the text if we have it (bundle, device, or the configured
///               endpoint), otherwise the citation laid out with the collection
///               named and an honest word about why there is no text.
///   • Tafsir  — the Ibn Kathir passage on that ayah, read from the bundle.
///   • Scholar — who they are and what was attributed to them here.
///   • Citation — never reaches this sheet; a prose citation is not tappable.
///
/// Nothing here paraphrases a source. Either the passage is shown as written or
/// the sheet says it is not available.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/knowledge/entity_ref.dart';
import '../../../../core/knowledge/evidence.dart';
import '../../../../core/knowledge/hadith_ref.dart';
import '../../../../core/theme/mizan_tokens.dart';
import '../../../../core/theme/mizan_typography.dart';
import '../../../../features/quran/domain/quran_providers.dart';
import '../../../../shared/widgets/mizan/mizan_components.dart';
import '../../data/tafsir_source.dart';
import '../../domain/hadith_providers.dart';
import '../knowledge_routes.dart';

Future<void> showEvidenceSheet(BuildContext context, Evidence evidence) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EvidenceSheet(evidence: evidence),
  );
}

class _EvidenceSheet extends StatelessWidget {
  const _EvidenceSheet({required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.all(MizanGeometry.gutter),
      child: ConstrainedBox(
        // Tall enough for a tafsir passage, short enough that the page behind
        // stays visible — this is a look at a source, not a new screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: MizanSurface(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Expanded(child: MizanSectionLabel(_kindLabel(evidence))),
                    Text(
                      evidence.label,
                      style: MizanType.body(color: p.muted)
                          .copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              MizanRule(color: p.hairline),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: switch (evidence) {
                    QuranEvidence e => _QuranBody(evidence: e),
                    HadithEvidence e => _HadithBody(evidence: e),
                    TafsirEvidence e => _TafsirBody(evidence: e),
                    ScholarEvidence e => _ScholarBody(evidence: e),
                    CitationEvidence e => _CitationBody(evidence: e),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _kindLabel(Evidence e) => switch (e) {
        QuranEvidence() => 'QUR\'AN',
        HadithEvidence() => 'HADITH',
        TafsirEvidence() => 'TAFSIR',
        ScholarEvidence() => 'SCHOLAR',
        CitationEvidence() => 'SOURCE',
      };
}

// ══════════════════════════════════════════════════════════════════════
//  QUR'AN
// ══════════════════════════════════════════════════════════════════════

class _QuranBody extends ConsumerWidget {
  const _QuranBody({required this.evidence});

  final QuranEvidence evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final ayat = ref.watch(ayatProvider(evidence.surah));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ayat.when(
          data: (list) {
            final match = list.where(
              (a) => a.ayahNumber == evidence.ayah,
            );
            if (match.isEmpty) {
              return _Unavailable(
                message:
                    'Ayah ${evidence.reference} could not be loaded from this '
                    'surah.',
              );
            }
            final ayah = match.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ayah.arabicText,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: MizanType.arabic(color: p.ink, fontSize: 27)
                      .copyWith(height: 1.9),
                ),
                const SizedBox(height: 16),
                Text(
                  ayah.translation,
                  style: MizanType.translation(color: p.ink),
                ),
              ],
            );
          },
          // The ayah text comes from the network; the sheet degrades to the
          // reference and the quoted fragment rather than to an error.
          loading: () => const _Loading(),
          error: (_, __) => _Unavailable(
            message:
                'The ayah text needs a connection. The reference is '
                '${evidence.label}.',
          ),
        ),
        if (evidence.quotedText != null &&
            evidence.quotedText!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          _QuotedFragment(text: evidence.quotedText!),
        ],
        if (evidence.isRange) ...[
          const SizedBox(height: 14),
          Text(
            'The citation covers ${evidence.surah}:${evidence.ayah}–'
            '${evidence.throughAyah}. The reader opens at the first ayah.',
            style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
          ),
        ],
        const SizedBox(height: 20),
        MizanButton(
          label: 'Open in the reader',
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/quran/${evidence.surah}?ayah=${evidence.ayah}');
          },
          expand: true,
        ),
        const SizedBox(height: 10),
        Text(
          // Named exactly as the control on the reader is named. There are six
          // layers, and they are called "Six layers" wherever they are mentioned.
          'The six layers for this ayah live on the reader screen.',
          textAlign: TextAlign.center,
          style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HADITH
// ══════════════════════════════════════════════════════════════════════

class _HadithBody extends ConsumerWidget {
  const _HadithBody({required this.evidence});

  final HadithEvidence evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final hadithRef = evidence.ref;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CollectionHeader(collection: evidence.collection, number: evidence.number),
        if (evidence.bookName != null) ...[
          const SizedBox(height: 12),
          _Field(label: 'Book', value: evidence.bookName!),
        ],
        if (evidence.narrator != null) ...[
          const SizedBox(height: 12),
          _Field(label: 'Narrator', value: evidence.narrator!),
        ],
        if (evidence.detail != null) ...[
          const SizedBox(height: 12),
          _Field(label: 'Cited for', value: evidence.detail!),
        ],
        if (evidence.quotedText != null &&
            evidence.quotedText!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          _QuotedFragment(text: evidence.quotedText!),
        ],
        const SizedBox(height: 18),
        if (hadithRef == null)
          // The honest case, and by far the common one: 395 of the corpus's 408
          // hadith references name a collection and describe the hadith without
          // giving a number. We do not guess numbers.
          const _Unavailable(
            message:
                'This citation names the collection but not a hadith number, so '
                'the text cannot be looked up. It is shown exactly as the source '
                'wrote it.',
          )
        else
          _HadithText(hadithRef: hadithRef),
        if (evidence.gradeNote != null) ...[
          const SizedBox(height: 16),
          Text(
            evidence.gradeNote!,
            style: MizanType.body(color: p.sage).copyWith(fontSize: 13.5),
          ),
        ],
        if (hadithRef != null) ...[
          const SizedBox(height: 20),
          MizanButton.secondary(
            label: 'Open hadith',
            onPressed: () {
              Navigator.of(context).pop();
              KnowledgeRoutes.open(context, hadithRef.entityRef);
            },
            expand: true,
          ),
        ],
      ],
    );
  }
}

/// The text of one numbered hadith, or a plain word about why there is none.
class _HadithText extends ConsumerWidget {
  const _HadithText({required this.hadithRef});

  final HadithRef hadithRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final record = ref.watch(hadithProvider(hadithRef));

    return record.when(
      loading: () => const _Loading(),
      error: (_, __) => _Unavailable(
        message: 'The text of ${hadithRef.display} could not be loaded.',
      ),
      data: (value) {
        if (value == null) {
          return const _Unavailable(
            message:
                'The text of this hadith is not on this device yet. The citation '
                'is complete — collection and number — so it can be checked in '
                'any copy of the collection.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.arabic != null && value.arabic!.trim().isNotEmpty) ...[
              Text(
                value.arabic!,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: MizanType.arabic(color: p.ink, fontSize: 24)
                    .copyWith(height: 1.9),
              ),
              const SizedBox(height: 16),
            ],
            if (value.english != null && value.english!.trim().isNotEmpty)
              Text(
                value.english!,
                style: MizanType.body(color: p.ink).copyWith(height: 1.6),
              ),
            if (value.narrator != null) ...[
              const SizedBox(height: 12),
              _Field(label: 'Narrator', value: value.narrator!),
            ],
            if (value.grade != null) ...[
              const SizedBox(height: 12),
              _Field(label: 'Grade', value: value.grade!),
            ],
            const SizedBox(height: 14),
            Text(
              value.origin.label,
              style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
            ),
          ],
        );
      },
    );
  }
}

/// Collection identity — title, Arabic name, and the one grading statement we are
/// entitled to make.
class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({required this.collection, this.number});

  final String collection;
  final String? number;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final book = HadithCollections.bySlug(collection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number == null || number!.isEmpty
              ? (book?.title ?? collection)
              : '${book?.title ?? collection} $number',
          style: MizanType.cardHeadline(color: p.ink),
        ),
        if (book != null) ...[
          const SizedBox(height: 6),
          Text(
            book.titleArabic,
            textDirection: TextDirection.rtl,
            style: MizanType.arabic(color: p.accentText, fontSize: 20),
          ),
          if (book.gradedThroughout) ...[
            const SizedBox(height: 8),
            Text(
              'Every hadith in this collection is sahih by its compiler\'s own '
              'criterion.',
              style: MizanType.body(color: p.sage).copyWith(fontSize: 13),
            ),
          ],
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TAFSIR
// ══════════════════════════════════════════════════════════════════════

class _TafsirBody extends StatefulWidget {
  const _TafsirBody({required this.evidence});

  final TafsirEvidence evidence;

  @override
  State<_TafsirBody> createState() => _TafsirBodyState();
}

class _TafsirBodyState extends State<_TafsirBody> {
  late final Future<TafsirPassage?> _passage;

  @override
  void initState() {
    super.initState();
    _passage = TafsirSource.forAyah(widget.evidence.surah, widget.evidence.ayah);
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final e = widget.evidence;
    final isBundledScholar =
        e.scholarName.toLowerCase().contains('kathir');

    return FutureBuilder<TafsirPassage?>(
      future: _passage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final passage = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              e.scholarName,
              style: MizanType.cardHeadline(color: p.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'On Qur\'an ${e.surah}:${e.ayah}',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            if (passage == null)
              _Unavailable(
                message: isBundledScholar
                    ? 'No passage on this ayah is present in the bundled '
                        'commentary.'
                    : 'This commentary is cited by name. Only Ibn Kathir\'s '
                        'tafsir is bundled with the app, so the passage itself '
                        'is not shown here.',
              )
            else ...[
              Text(
                passage.work,
                style: MizanType.body(color: p.accentText).copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Verbatim. Long passages scroll; they are never trimmed.
              Text(
                passage.text,
                style: MizanType.body(color: p.ink).copyWith(height: 1.65),
              ),
            ],
            const SizedBox(height: 20),
            MizanButton.secondary(
              label: 'Open the ayah',
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/quran/${e.surah}?ayah=${e.ayah}');
              },
              expand: true,
            ),
            if (e.scholarId != null) ...[
              const SizedBox(height: 10),
              MizanButton.quiet(
                label: 'About ${e.scholarName}',
                onPressed: () {
                  Navigator.of(context).pop();
                  KnowledgeRoutes.open(
                    context,
                    EntityRef(EntityType.scholar, e.scholarId!),
                  );
                },
                expand: true,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SCHOLAR
// ══════════════════════════════════════════════════════════════════════

class _ScholarBody extends StatelessWidget {
  const _ScholarBody({required this.evidence});

  final ScholarEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(evidence.scholarName, style: MizanType.cardHeadline(color: p.ink)),
        if (evidence.work != null) ...[
          const SizedBox(height: 6),
          Text(
            evidence.work!,
            style: MizanType.body(color: p.accentText).copyWith(fontSize: 13.5),
          ),
        ],
        if (evidence.remark != null && evidence.remark!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          _QuotedFragment(text: evidence.remark!),
        ],
        if (evidence.scholarId != null) ...[
          const SizedBox(height: 20),
          MizanButton.secondary(
            label: 'About ${evidence.scholarName}',
            onPressed: () {
              Navigator.of(context).pop();
              KnowledgeRoutes.open(
                context,
                EntityRef(EntityType.scholar, evidence.scholarId!),
              );
            },
            expand: true,
          ),
        ] else ...[
          const SizedBox(height: 18),
          const _Unavailable(
            message:
                'This scholar is named in the citation. There is no page for '
                'them in the app yet.',
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  PROSE CITATION
// ══════════════════════════════════════════════════════════════════════

class _CitationBody extends StatelessWidget {
  const _CitationBody({required this.evidence});

  final CitationEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          evidence.text,
          style: MizanType.body(color: p.ink).copyWith(height: 1.6),
        ),
        const SizedBox(height: 14),
        Text(
          'Shown as the source wrote it.',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SHARED PIECES
// ══════════════════════════════════════════════════════════════════════

/// A quotation from the source, set apart by a gold rule rather than by italics —
/// Arabic-adjacent text should not be slanted.
class _QuotedFragment extends StatelessWidget {
  const _QuotedFragment({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.sunk,
        borderRadius: MizanGeometry.rowBorderRadius,
        border: Border(
          left: BorderSide(color: p.accent.withValues(alpha: 0.55), width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Text(
        text.trim(),
        style: MizanType.body(color: p.ink).copyWith(height: 1.55),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: MizanType.sectionLabel(color: p.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: MizanType.body(color: p.ink).copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
        ),
      ),
    );
  }
}

/// The quiet "we do not have this" state. Never styled as an error: a source we
/// cannot display is a limit of the app, not a fault in the citation.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.sunk,
        borderRadius: MizanGeometry.rowBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Text(
          message,
          style: MizanType.body(color: p.muted).copyWith(height: 1.5),
        ),
      ),
    );
  }
}
