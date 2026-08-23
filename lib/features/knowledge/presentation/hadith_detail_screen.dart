/// The hadith screen — a hadith as a first-class page, not a footnote.
///
/// Reached from any numbered citation, from the evidence sheet, and from a
/// Connected Hadith row. It shows the text where we have it, the collection it
/// belongs to, and — the part that makes it a knowledge page rather than a lookup
/// — everything else in the app that cites the same hadith, plus the hadiths cited
/// alongside it.
///
/// When the text is not on the device it says so and shows the citation anyway,
/// because a complete citation is useful on its own: collection plus number can be
/// checked in any copy of the collection. Nothing here fabricates a text, a
/// narrator or a grade.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/knowledge/entity_ref.dart';
import '../../../core/knowledge/hadith_ref.dart';
import '../../../core/knowledge/knowledge_providers.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../data/hadith_record.dart';
import '../domain/hadith_providers.dart';
import 'widgets/connected_sections.dart';
import 'widgets/knowledge_scaffold.dart';

class HadithDetailScreen extends ConsumerWidget {
  const HadithDetailScreen({
    super.key,
    required this.collection,
    required this.number,
  });

  final String collection;
  final String number;

  HadithRef get hadithRef =>
      HadithRef(collection: collection, number: number);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final book = HadithCollections.bySlug(collection);
    final record = ref.watch(hadithProvider(hadithRef));
    final graph = ref.watch(knowledgeGraphOrNullProvider);
    final entity = graph?[hadithRef.entityRef];

    return KnowledgeScaffold(
      hero: KnowledgeHero(
        title: book?.title ?? collection,
        titleArabic: book?.titleArabic,
        eyebrow: 'HADITH',
        meta: 'No. $number',
      ),
      children: [
        // The citation itself, always, above whatever we do or do not have.
        _CitationCard(hadithRef: hadithRef, book: book),

        const SizedBox(height: 26),
        const KnowledgeSectionHeader('TEXT'),
        const SizedBox(height: 12),
        record.when(
          loading: () => const KnowledgePlaceholder(title: '', loading: true),
          error: (_, __) => const KnowledgePlaceholder(
            title: 'Not available',
            message: 'The text could not be loaded.',
          ),
          data: (value) => value == null
              ? _NotDownloaded(hadithRef: hadithRef)
              : _HadithText(record: value),
        ),

        // What the corpus said when it cited this hadith — the description its
        // author wrote, kept because for many citations it is the only pointer to
        // *which* hadith is meant.
        if (entity != null && entity.teaser != null) ...[
          const SizedBox(height: 26),
          const KnowledgeSectionHeader('CITED IN THE APP AS'),
          const SizedBox(height: 12),
          MizanSurface(
            child: Text(
              entity.teaser!,
              style: MizanType.body(color: p.ink).copyWith(height: 1.6),
            ),
          ),
        ],

        // Related = the same hadith cited elsewhere; Connected = what it appears
        // beside. Both come from the graph, so no list is maintained by hand.
        ConnectedSections(
          entityRef: hadithRef.entityRef,
          heading: 'CONNECTED',
        ),
      ],
    );
  }
}

/// Collection, number, Arabic title, and the one grading statement we may make.
class _CitationCard extends StatelessWidget {
  const _CitationCard({required this.hadithRef, this.book});

  final HadithRef hadithRef;
  final HadithCollection? book;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hadithRef.display, style: MizanType.cardHeadline(color: p.ink)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: p.sage),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  book == null
                      ? 'Collection not recognised.'
                      : book!.gradedThroughout
                          ? 'Every hadith in this collection is sahih by its '
                              'compiler\'s own criterion.'
                          : 'Grades in this collection vary by hadith and are '
                              'shown only when the source states one.',
                  style: MizanType.body(color: p.muted).copyWith(
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HadithText extends StatelessWidget {
  const _HadithText({required this.record});

  final HadithRecord record;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (record.arabic != null && record.arabic!.trim().isNotEmpty)
          MizanSurface(
            child: Text(
              record.arabic!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style:
                  MizanType.arabic(color: p.ink, fontSize: 25).copyWith(height: 1.95),
            ),
          ),
        if (record.english != null && record.english!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          MizanSurface(
            child: Text(
              record.english!,
              style: MizanType.translation(color: p.ink),
            ),
          ),
        ],
        if (record.narrator != null ||
            record.grade != null ||
            record.bookName != null ||
            record.chapter != null) ...[
          const SizedBox(height: 12),
          MizanSurface(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in <(String, String?)>[
                  ('Narrator', record.narrator),
                  ('Book', record.bookName),
                  ('Chapter', record.chapter),
                  ('Grade', record.grade),
                ])
                  if (field.$2 != null && field.$2!.trim().isNotEmpty)
                    _FieldRow(label: field.$1, value: field.$2!),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          record.origin.label,
          style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label.toUpperCase(),
              style: MizanType.sectionLabel(color: p.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: MizanType.body(color: p.ink).copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// The offline / not-configured state, said plainly.
///
/// This is the honest default today: no hadith collection is bundled and no
/// endpoint is configured, so a numbered citation shows its citation and this
/// note. Setting `HADITH_API_BASE_URL`, or dropping a verified collection file
/// into `assets/data/hadith/`, turns the text on with no code change.
class _NotDownloaded extends StatelessWidget {
  const _NotDownloaded({required this.hadithRef});

  final HadithRef hadithRef;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 17, color: p.muted),
              const SizedBox(width: 9),
              Text(
                'Text not on this device',
                style: MizanType.bodyStrong(color: p.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The citation is complete — ${hadithRef.display} — so it can be '
            'checked in any copy of the collection. The app does not paraphrase '
            'a hadith it does not have.',
            style: MizanType.body(color: p.muted).copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

/// Everything saved on the device, newest first. Reached from Settings so the
/// hadith cache is inspectable rather than invisible.
class SavedHadithScreen extends ConsumerWidget {
  const SavedHadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final repo = ref.watch(hadithRepositoryProvider);

    return KnowledgeScaffold(
      hero: const KnowledgeHero(
        title: 'Saved hadith',
        eyebrow: 'OFFLINE',
        meta: 'Kept on this device',
      ),
      children: [
        FutureBuilder<List<HadithRecord>>(
          future: repo.saved(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KnowledgePlaceholder(title: '', loading: true);
            }
            final items = snapshot.data ?? const <HadithRecord>[];
            if (items.isEmpty) {
              return const KnowledgePlaceholder(
                title: 'Nothing saved yet',
                message:
                    'Hadith texts are saved here as they are fetched, so they '
                    'stay readable offline.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  MizanRow(
                    title: items[i].display,
                    subtitle: items[i].english,
                    leading: MizanIconTile(
                      icon: knowledgeTypeIcon(EntityType.hadith),
                      circle: false,
                      size: 40,
                      iconSize: 18,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HadithDetailScreen(
                          collection: items[i].collection,
                          number: items[i].number,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Clearing these removes only the saved copies. Every citation '
                  'in the app stays exactly as it is.',
                  style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
