/// The hadith screen — a hadith as a first-class page, not a footnote.
///
/// Reached from any numbered citation, from the evidence sheet, from a Connected
/// Hadith row, and from the topic lists in the learning section. It shows the text
/// where we have it, the collection it belongs to, and — the part that makes it a
/// knowledge page rather than a lookup — everything else in the app that cites the
/// same hadith, plus the hadiths cited alongside it.
///
/// The page is five layers deep, in the order the brief specifies:
///
///  1. **The hadith** — Arabic, translation, narrator, authenticity, collection.
///  2. **Vocabulary** — the words, when a verified glossary is bundled.
///  3. **Context** — the book and chapter it sits in, and what the corpus said
///     when it cited it.
///  4. **Scholar commentary** — named scholar, named work, or nothing at all.
///  5. **Reflection** — the reader's own, kept on the device.
///
/// Layers 2 and 4 have no source shipping today, and they say so rather than
/// disappearing: an empty slot with an honest sentence is information, and a
/// paraphrase generated to fill it would be the one thing this app must never do.
/// See [HadithExtrasSource] for the drop-in that turns them on.
///
/// The narrator is a link. Tapping it opens the companion's existing biography —
/// the same five-layer story the Discover tab opens — because a second, thinner
/// profile of Abu Hurayrah would be a duplicate of content the app already has.
/// [NarratorIndex] does the matching, and refuses ambiguous names.
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
import '../../../core/knowledge/narrator_index.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../data/hadith_extras.dart';
import '../data/hadith_record.dart';
import '../domain/hadith_providers.dart';
import 'knowledge_routes.dart';
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
    final extras = ref.watch(hadithExtrasProvider(hadithRef));
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
        const KnowledgeSectionHeader('THE HADITH', trailingText: '1 OF 5'),
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

        const SizedBox(height: 26),
        const KnowledgeSectionHeader('VOCABULARY', trailingText: '2 OF 5'),
        const SizedBox(height: 12),
        _Vocabulary(extras: extras),

        const SizedBox(height: 26),
        const KnowledgeSectionHeader('CONTEXT', trailingText: '3 OF 5'),
        const SizedBox(height: 12),
        _Context(
          record: record.valueOrNull,
          citedAs: entity?.teaser,
        ),

        const SizedBox(height: 26),
        const KnowledgeSectionHeader('SCHOLAR COMMENTARY', trailingText: '4 OF 5'),
        const SizedBox(height: 12),
        _Commentary(extras: extras),

        const SizedBox(height: 26),
        const KnowledgeSectionHeader('YOUR REFLECTION', trailingText: '5 OF 5'),
        const SizedBox(height: 12),
        _ReflectionCard(hadithRef: hadithRef),

        // Related = the same hadith cited elsewhere; Connected = what it appears
        // beside. Both come from the graph, so no list is maintained by hand.
        ConnectedSections(
          entityRef: hadithRef.entityRef,
          heading: 'CONNECTED',
        ),

        const SizedBox(height: 8),
        Text(
          'Vocabulary and commentary appear here only from verified sources. '
          'Where a source is not available the layer stays empty — the app does '
          'not write either one itself.',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
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

/// Layer 1. Arabic, translation, and the fields the source stated.
class _HadithText extends ConsumerWidget {
  const _HadithText({required this.record});

  final HadithRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    // Null until the graph has loaded, and null for a narrator we have no
    // biography for. Both mean the same thing to this widget: plain text.
    final narrator = ref.watch(narratorIndexProvider)?.match(record.narrator);

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
                if (record.narrator != null &&
                    record.narrator!.trim().isNotEmpty)
                  _FieldRow(
                    label: 'Narrator',
                    value: record.narrator!,
                    // The companion's own page, not a second profile of him.
                    onTap: narrator == null
                        ? null
                        : () => KnowledgeRoutes.open(context, narrator),
                  ),
                for (final field in <(String, String?)>[
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
  const _FieldRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;

  /// Set only for a narrator we can open. A row that does nothing must not look
  /// like a row that does something, so the chevron follows the callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    final body = Padding(
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
              style: MizanType.body(color: onTap == null ? p.ink : p.sage)
                  .copyWith(height: 1.45),
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      child: Semantics(button: true, label: '$label $value', child: body),
    );
  }
}

/// Layer 2. The words, when a glossary is bundled for this collection.
class _Vocabulary extends StatelessWidget {
  const _Vocabulary({required this.extras});

  final AsyncValue<HadithExtras> extras;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final glosses = extras.valueOrNull?.vocabulary ?? const <HadithGloss>[];

    if (glosses.isEmpty) {
      return const _EmptyLayer(
        icon: Icons.translate_outlined,
        title: 'No glossary for this narration',
        message:
            'Word meanings appear here from a verified glossary. The app will '
            'not gloss a word itself — a meaning invented for a hadith is a '
            'claim about revelation, not a convenience.',
      );
    }

    return MizanSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < glosses.length; i++) ...[
            if (i > 0) MizanRule(color: p.hairline, indent: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        glosses[i].arabic,
                        textDirection: TextDirection.rtl,
                        style: MizanType.arabic(color: p.ink, fontSize: 21),
                      ),
                      if (glosses[i].transliteration != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          glosses[i].transliteration!,
                          style: MizanType.body(color: p.muted)
                              .copyWith(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    glosses[i].meaning,
                    style: MizanType.body(color: p.ink).copyWith(height: 1.45),
                  ),
                  if (glosses[i].note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      glosses[i].note!,
                      style: MizanType.body(color: p.muted)
                          .copyWith(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Layer 3. Where the narration sits, and why the app cited it.
///
/// Everything here is quoted, not composed: the book and chapter come from the
/// hadith source, and the description is the sentence the corpus author wrote when
/// they cited it. For many citations that sentence is the only pointer to *which*
/// hadith is meant, which is why it is shown verbatim rather than summarised.
class _Context extends StatelessWidget {
  const _Context({required this.record, required this.citedAs});

  final HadithRecord? record;
  final String? citedAs;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    final book = record?.bookName;
    final chapter = record?.chapter;
    final hasPlacement = (book != null && book.trim().isNotEmpty) ||
        (chapter != null && chapter.trim().isNotEmpty);
    final hasCitedAs = citedAs != null && citedAs!.trim().isNotEmpty;

    if (!hasPlacement && !hasCitedAs) {
      return const _EmptyLayer(
        icon: Icons.account_tree_outlined,
        title: 'No context recorded',
        message:
            'Context here means the book and chapter the narration sits in, and '
            'the words the app used when it cited it. Neither is available for '
            'this one yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPlacement)
          MizanSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where it sits',
                    style: MizanType.bodyStrong(color: p.ink)),
                const SizedBox(height: 8),
                Text(
                  [
                    if (book != null && book.trim().isNotEmpty) book.trim(),
                    if (chapter != null && chapter.trim().isNotEmpty)
                      chapter.trim(),
                  ].join(' · '),
                  style: MizanType.body(color: p.muted).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        if (hasCitedAs) ...[
          if (hasPlacement) const SizedBox(height: 12),
          MizanSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cited in the app as',
                    style: MizanType.bodyStrong(color: p.ink)),
                const SizedBox(height: 8),
                Text(
                  citedAs!,
                  style: MizanType.body(color: p.ink).copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Layer 4. Named scholar, named work, or nothing.
class _Commentary extends StatelessWidget {
  const _Commentary({required this.extras});

  final AsyncValue<HadithExtras> extras;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final items = extras.valueOrNull?.commentary ?? const <HadithCommentary>[];

    if (items.isEmpty) {
      return const _EmptyLayer(
        icon: Icons.menu_book_outlined,
        title: 'No verified commentary',
        message:
            'Commentary appears here only with the scholar and the work it comes '
            'from. Unattributed explanation is opinion, and opinion presented as '
            'scholarship is not something this app will show.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          MizanSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[i].scholar,
                    style: MizanType.bodyStrong(color: p.ink)),
                const SizedBox(height: 3),
                Text(
                  items[i].reference == null
                      ? items[i].work
                      : '${items[i].work} · ${items[i].reference}',
                  style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Text(
                  items[i].text,
                  style: MizanType.body(color: p.ink).copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Layer 5. The reader's own words, on the device only.
class _ReflectionCard extends ConsumerStatefulWidget {
  const _ReflectionCard({required this.hadithRef});

  final HadithRef hadithRef;

  @override
  ConsumerState<_ReflectionCard> createState() => _ReflectionCardState();
}

class _ReflectionCardState extends ConsumerState<_ReflectionCard> {
  final TextEditingController _controller = TextEditingController();

  /// Whether what is in the field is what is in the database. Starts true
  /// because an empty field matches an empty row.
  bool _saved = true;

  /// Set once the stored reflection has been put into the field, so a rebuild
  /// never overwrites what the reader is in the middle of typing.
  bool _seeded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text;
    await ref
        .read(hadithRepositoryProvider)
        .saveReflection(widget.hadithRef, text);
    ref.invalidate(hadithReflectionProvider(widget.hadithRef));
    if (!mounted) return;
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final stored = ref.watch(hadithReflectionProvider(widget.hadithRef));

    if (!_seeded && stored.hasValue) {
      _seeded = true;
      final existing = stored.valueOrNull;
      if (existing != null) _controller.text = existing;
    }

    return MizanSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Private — kept on this device, and shared only if you choose to '
            'share it.',
            style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 3,
            style: MizanType.body(color: p.ink).copyWith(height: 1.5),
            cursorColor: p.accentText,
            // The global input theme is a pill, which is right for a search
            // field and wrong for five lines of writing. This is the same
            // rounded-well shape the ayah reader's inputs use.
            decoration: InputDecoration(
              hintText: 'What does this narration ask of you?',
              hintStyle: MizanType.body(color: p.muted),
              filled: true,
              fillColor: p.sunk,
              border: OutlineInputBorder(
                borderRadius: MizanGeometry.rowBorderRadius,
                borderSide: BorderSide(color: p.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: MizanGeometry.rowBorderRadius,
                borderSide: BorderSide(color: p.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: MizanGeometry.rowBorderRadius,
                borderSide: BorderSide(color: p.accentText),
              ),
            ),
            onChanged: (_) {
              if (_saved) setState(() => _saved = false);
            },
          ),
          const SizedBox(height: 12),
          MizanButton.secondary(
            label: _saved ? 'Saved' : 'Save reflection',
            icon: _saved ? Icons.check_rounded : Icons.edit_outlined,
            onPressed: _saved ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// A layer with nothing in it, said plainly and identically everywhere.
class _EmptyLayer extends StatelessWidget {
  const _EmptyLayer({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: p.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title, style: MizanType.bodyStrong(color: p.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: MizanType.body(color: p.muted).copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

/// The offline / not-configured state, said plainly.
///
/// A numbered citation shows its citation and this note when no source on the
/// chain has the text — the local database, the bundle, UmmahAPI and any
/// separately configured endpoint have all been asked.
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
                    onTap: () =>
                        KnowledgeRoutes.open(context, items[i].ref.entityRef),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Clearing these removes only the saved copies. Every citation '
                  'in the app stays exactly as it is. Reflections you have '
                  'written are never cleared with them.',
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
