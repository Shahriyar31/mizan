/// KnowledgeBuilder — derives the graph from the corpus that already ships.
///
/// This is the file that makes the platform possible without writing a single new
/// Islamic claim. The corpus contains 187 entries across prophets, companions,
/// seerah events and divine names, and inside them roughly a thousand citations
/// that a human already wrote and sourced. This builder reads those citations and
/// turns them into nodes and edges.
///
/// **What it derives**
///
/// - An entity per corpus entry, with its five layers as sections.
/// - A `verse:S:A` entity per distinct cited ayah, and a `hadith:coll:num` entity
///   per *numbered* hadith citation.
/// - `mentions` edges from an entry to everything its layers cite, each carrying
///   the layer number and the layer's own `source` string, so any edge can be
///   traced to a file on disk.
/// - `narratedBy` edges where a hadith citation names a narrator who is one of the
///   43 companions in the corpus.
/// - `commentedOnBy` edges to a scholar named in a layer's source.
/// - `relatedTo` edges between two entries that cite the same passage, with that
///   shared citation as the evidence. The row then reads "both discussed at
///   Qur'an 2:30" — the connection is shown, not asserted.
///
/// **The fan-out cap, which is not an optimisation**
///
/// Qur'an 7:180 is cited by nearly all 101 divine names, and the hadith "whoever
/// enumerates them will enter paradise" by most of them too. Pairing every entity
/// that shares such a citation would produce ~5,000 edges saying nothing — "Al-
/// Ghaffar is related to Al-Wadud because both pages quote 7:180" is technically
/// true and useless. So co-citation pairs are only generated for a passage cited
/// by at most [_coCitationFanoutCap] entities. A widely-cited passage still gets
/// its own page listing everyone who cites it, which is the honest place for a
/// list of a hundred.
library;

import '../../features/discover/data/discover_repository.dart';
import '../../features/discover/models/discover_models.dart';
import '../../features/quran/data/surah_metadata.dart';
import 'entity_ref.dart';
import 'evidence.dart';
import 'hadith_ref.dart';
import 'knowledge_assets.dart';
import 'knowledge_entity.dart';
import 'knowledge_graph.dart';
import 'narrator_index.dart';
import 'reference_parser.dart';
import 'relation.dart';

abstract final class KnowledgeBuilder {
  /// A passage cited by more entities than this produces no pairwise edges. Six is
  /// chosen so a verse shared by a handful of prophets still links them, while
  /// 7:180 does not turn the divine names into a clique.
  static const int _coCitationFanoutCap = 6;

  /// Reads the corpus and the curated files, then assembles the graph.
  ///
  /// Runs once; the provider caches the result. Corpus loading goes through
  /// [DiscoverRepository], which already has its own static cache, so this shares
  /// whatever Discover has loaded rather than re-reading the bundle.
  static Future<KnowledgeGraph> build() async {
    final loaded = await Future.wait([
      DiscoverRepository.getProphets(),
      DiscoverRepository.getSahabah(),
      DiscoverRepository.getSeerah(),
      DiscoverRepository.getNames(),
      KnowledgeAssets.load(),
    ]);

    final prophets = loaded[0] as List<ProphetEntry>;
    final sahabah = loaded[1] as List<SahabiEntry>;
    final seerah = loaded[2] as List<SeerahEntry>;
    final names = loaded[3] as List<DivineName>;
    final curated = loaded[4] as KnowledgeAssets;

    final entities = <String, KnowledgeEntity>{};
    final relations = <Relation>[];

    void put(KnowledgeEntity e) => entities.putIfAbsent(e.ref.canonical, () => e);

    // Which entities cite which passage. Keyed by canonical ref so verses and
    // hadith share one index.
    final citedBy = <String, Set<String>>{};
    // Kept so a co-citation edge can name the citation it came from.
    final citationSample = <String, Evidence>{};

    final narratorIndex = NarratorIndex();
    for (final s in sahabah) {
      narratorIndex.add(
        EntityRef(EntityType.sahabi, s.id),
        [s.nameEnglish, s.kunyah],
      );
    }

    void record({
      required KnowledgeEntity owner,
      required List<Evidence> evidence,
      required int? layerNumber,
      required String? layerTitle,
      required String? sourceText,
    }) {
      final provenance = RelationProvenance(
        entityRef: owner.ref,
        layerNumber: layerNumber,
        layerTitle: layerTitle,
        sourceText: sourceText,
      );

      for (final ev in evidence) {
        switch (ev) {
          case QuranEvidence():
            // A range becomes one node per ayah, so a reader arriving from any of
            // them finds this entry.
            for (final ayah in ev.ayatCovered) {
              final ref = EntityRef.verse(ev.surah, ayah);
              put(_verseEntity(ev.surah, ayah));
              relations.add(
                Relation(
                  from: owner.ref,
                  to: ref,
                  kind: RelationKind.mentions,
                  note: ev.quotedText,
                  evidence: [ev],
                  derived: true,
                  provenance: provenance,
                ),
              );
              citedBy.putIfAbsent(ref.canonical, () => <String>{})
                  .add(owner.ref.canonical);
              citationSample.putIfAbsent(ref.canonical, () => ev);
            }

          case HadithEvidence():
            final hadithRef = ev.ref;
            if (hadithRef != null) {
              // Numbered: a real node, fetchable and openable.
              put(_hadithEntity(hadithRef, ev));
              relations.add(
                Relation(
                  from: owner.ref,
                  to: hadithRef.entityRef,
                  kind: RelationKind.mentions,
                  note: ev.detail ?? ev.quotedText,
                  evidence: [ev],
                  derived: true,
                  provenance: provenance,
                ),
              );
              citedBy
                  .putIfAbsent(hadithRef.canonical, () => <String>{})
                  .add(owner.ref.canonical);
              citationSample.putIfAbsent(hadithRef.canonical, () => ev);
            }
            // Numbered or not, a named narrator is a link worth having.
            final narrator = narratorIndex.match(ev.narrator);
            if (narrator != null && narrator != owner.ref) {
              relations.add(
                Relation(
                  from: narrator,
                  to: owner.ref,
                  kind: RelationKind.narrates,
                  note: 'Narrated the hadith cited here from '
                      '${ev.collectionTitle}',
                  evidence: [ev],
                  derived: true,
                  provenance: provenance,
                ),
              );
            }

          case TafsirEvidence():
            final slug = ev.scholarId;
            if (slug != null) {
              relations.add(
                Relation(
                  from: owner.ref,
                  to: EntityRef(EntityType.scholar, slug),
                  kind: RelationKind.commentedOnBy,
                  note: 'Commentary on ${ev.surah}:${ev.ayah}',
                  evidence: [ev],
                  derived: true,
                  provenance: provenance,
                ),
              );
            }

          case ScholarEvidence():
            final slug = ev.scholarId;
            if (slug != null) {
              relations.add(
                Relation(
                  from: owner.ref,
                  to: EntityRef(EntityType.scholar, slug),
                  kind: RelationKind.commentedOnBy,
                  note: ev.work,
                  evidence: [ev],
                  derived: true,
                  provenance: provenance,
                ),
              );
            }

          case CitationEvidence():
            // Nothing to link — it stays on the section as a named source, which
            // is the whole of what it honestly supports.
            break;
        }
      }
    }

    // ── The four corpus types ────────────────────────────────────────
    for (final p in prophets) {
      final e = _fromProphet(p);
      put(e);
      _walkLayers(e, p.layers, record);
    }
    for (final s in sahabah) {
      final e = _fromSahabi(s);
      put(e);
      _walkLayers(e, s.layers, record);
    }
    for (final s in seerah) {
      final e = _fromSeerah(s);
      put(e);
      _walkLayers(e, s.layers, record);
    }
    for (final n in names) {
      final e = _fromDivineName(n);
      put(e);
      _walkLayers(e, n.layers, record);
    }

    // ── Chronology, straight from the corpus's own sequence numbers ──
    //
    // Nothing is asserted here that the files do not already state: the prophet
    // entries are numbered 1..n in the traditional order and the seerah entries in
    // the order the events happened. Consecutive numbers become an edge, which is
    // what makes "read the next event" possible without a hand-written list.
    relations.addAll(
      _chronology(
        prophets.map((p) => EntityRef(EntityType.prophet, p.id)).toList(),
        prophets.map((p) => p.sequenceNumber).toList(),
        'Next in the traditional order of the prophets',
      ),
    );
    relations.addAll(
      _chronology(
        seerah.map((s) => EntityRef(EntityType.seerah, s.id)).toList(),
        seerah.map((s) => s.sequenceNumber).toList(),
        'The next event in the seerah',
      ),
    );

    // ── Co-citation ─────────────────────────────────────────────────
    for (final entry in citedBy.entries) {
      final owners = entry.value.toList()..sort();
      if (owners.length < 2 || owners.length > _coCitationFanoutCap) continue;
      final shared = citationSample[entry.key];
      final label = shared?.label ?? entry.key;
      for (var i = 0; i < owners.length; i++) {
        for (var j = i + 1; j < owners.length; j++) {
          final a = EntityRef.parse(owners[i]);
          final b = EntityRef.parse(owners[j]);
          if (a == null || b == null) continue;
          relations.add(
            Relation(
              from: a,
              to: b,
              kind: RelationKind.relatedTo,
              note: 'Both are discussed at $label',
              evidence: shared == null ? const [] : [shared],
              derived: true,
            ),
          );
        }
      }
    }

    // ── Curated: themes, scholars, places, journeys, hand-stated edges ──
    for (final t in curated.themes) {
      put(_fromTheme(t));
      for (final member in t.members) {
        relations.add(
          Relation(
            from: member,
            to: t.ref,
            kind: RelationKind.aboutTheme,
            note: t.definition,
          ),
        );
      }
      relations.addAll(_deriveThemeMembers(t, entities.values));
    }

    for (final s in curated.scholars) {
      // Overwrites any stub the parser implied, because a real file always wins.
      entities[s.ref.canonical] = _fromScholar(s);
    }

    for (final pl in curated.places) {
      put(_fromPlace(pl));
      for (final event in pl.events) {
        relations.add(
          Relation(
            from: event,
            to: pl.ref,
            kind: RelationKind.occurredAt,
            note: pl.subtitle,
          ),
        );
      }
    }

    for (final j in curated.journeys) {
      put(_fromJourney(j));
      for (var i = 0; i < j.steps.length; i++) {
        final step = j.steps[i];
        relations.add(
          Relation(
            from: j.ref,
            to: step.ref,
            kind: RelationKind.journeyIncludes,
            // The note is the step's own position plus, where the curator left it
            // null, the entity's own teaser — added later by the journey screen so
            // this stays free of copied prose.
            note: step.note ?? 'Step ${i + 1} of ${j.steps.length}',
          ),
        );
      }
      for (final theme in j.themes) {
        relations.add(
          Relation(from: j.ref, to: theme, kind: RelationKind.aboutTheme),
        );
      }
    }

    for (final edge in curated.edges) {
      relations.add(edge.relation);
    }

    // Any scholar cited by the corpus but absent from `scholars.json` still needs
    // a node, or the commentary edges dangle and the sections vanish.
    for (final r in relations) {
      if (r.to.type == EntityType.scholar &&
          !entities.containsKey(r.to.canonical)) {
        put(_scholarStub(r.to));
      }
    }

    return KnowledgeGraph.build(
      entities: entities.values,
      relations: relations,
    );
  }

  // ── Derived structure ─────────────────────────────────────────────

  /// `predecessorOf` edges between entries with consecutive sequence numbers.
  ///
  /// Only consecutive ones: a gap in the numbering means an entry has not been
  /// written yet, and jumping the gap would claim an adjacency the corpus does not.
  static List<Relation> _chronology(
    List<EntityRef> refs,
    List<int> sequences,
    String note,
  ) {
    final ordered = <({int seq, EntityRef ref})>[
      for (var i = 0; i < refs.length; i++)
        (seq: sequences[i], ref: refs[i]),
    ]..sort((a, b) => a.seq.compareTo(b.seq));

    final out = <Relation>[];
    for (var i = 0; i + 1 < ordered.length; i++) {
      if (ordered[i + 1].seq - ordered[i].seq != 1) continue;
      out.add(
        Relation(
          from: ordered[i].ref,
          to: ordered[i + 1].ref,
          kind: RelationKind.predecessorOf,
          note: note,
          derived: true,
          provenance: RelationProvenance(entityRef: ordered[i].ref),
        ),
      );
    }
    return out;
  }

  /// Theme membership by keyword frequency over an entry's own layers.
  ///
  /// The edge points at the layer where the discussion is densest and carries that
  /// layer's citations, so a theme page's rows read "Discussed in layer 3 — The
  /// Fall and the Return" with the layer's own sources attached. That is a claim
  /// the reader can check in two taps, which a hand-picked membership list is not.
  ///
  /// Divine names dominate some themes — Ar-Rahman is the densest entry for Mercy
  /// by a wide margin — and that is the correct answer, not noise.
  static List<Relation> _deriveThemeMembers(
    ThemeDoc theme,
    Iterable<KnowledgeEntity> all,
  ) {
    if (theme.keywords.isEmpty) return const [];

    final patterns = [
      for (final k in theme.keywords)
        RegExp('\\b${RegExp.escape(k)}', caseSensitive: false),
    ];

    final out = <Relation>[];
    for (final entity in all) {
      // Only the four corpus types carry layers; a verse or a scholar node has
      // nothing to match against.
      switch (entity.type) {
        case EntityType.prophet:
        case EntityType.sahabi:
        case EntityType.seerah:
        case EntityType.divineName:
          break;
        default:
          continue;
      }

      var total = 0;
      KnowledgeSection? best;
      var bestHits = 0;
      for (final section in entity.sections) {
        var hits = 0;
        for (final p in patterns) {
          hits += p.allMatches(section.body).length;
        }
        total += hits;
        if (hits > bestHits) {
          bestHits = hits;
          best = section;
        }
      }

      if (total < theme.minHits || best == null) continue;

      out.add(
        Relation(
          from: entity.ref,
          to: theme.ref,
          kind: RelationKind.aboutTheme,
          note: best.layerNumber == null
              ? 'Discussed in "${best.title}"'
              : 'Discussed in layer ${best.layerNumber} — ${best.title}',
          evidence: best.evidence,
          derived: true,
          provenance: RelationProvenance(
            entityRef: entity.ref,
            layerNumber: best.layerNumber,
            layerTitle: best.title,
            sourceText: best.sourceText,
          ),
        ),
      );
    }
    return out;
  }

  // ── Corpus adapters ───────────────────────────────────────────────
  //
  // Each returns a KnowledgeEntity *alongside* the existing model, never instead
  // of it. The Discover screens keep reading ProphetEntry and friends exactly as
  // they do now.

  static void _walkLayers(
    KnowledgeEntity owner,
    List<DiscoverLayer> layers,
    void Function({
      required KnowledgeEntity owner,
      required List<Evidence> evidence,
      required int? layerNumber,
      required String? layerTitle,
      required String? sourceText,
    }) record,
  ) {
    for (final layer in layers) {
      record(
        owner: owner,
        evidence: ReferenceParser.parseLayer(
          quranRef: layer.quranRef,
          hadithRef: layer.hadithRef,
          source: layer.source,
        ),
        layerNumber: layer.layerNumber,
        layerTitle: layer.title,
        sourceText: layer.source,
      );
    }
  }

  static List<KnowledgeSection> _sections(List<DiscoverLayer> layers) => [
        for (final l in layers)
          KnowledgeSection(
            title: l.title,
            subtitle: l.subtitle,
            body: l.content,
            layerNumber: l.layerNumber,
            sourceText: l.source,
            evidence: ReferenceParser.parseLayer(
              quranRef: l.quranRef,
              hadithRef: l.hadithRef,
              source: l.source,
            ),
          ),
      ];

  static KnowledgeEntity _fromProphet(ProphetEntry p) => KnowledgeEntity(
        ref: EntityRef(EntityType.prophet, p.id),
        title: p.nameEnglish,
        titleArabic: p.nameArabic,
        transliteration: p.nameTranslit,
        subtitle: p.era,
        teaser: p.teaser,
        sequence: p.sequenceNumber,
        sections: _sections(p.layers),
        evidence: ReferenceParser.parseQuran(p.quranicMention).isEmpty
            ? [CitationEvidence(p.quranicMention)]
            : ReferenceParser.parseQuran(p.quranicMention),
        tags: [if (p.group != null) p.group!.toLowerCase()],
        metadata: {
          'era': p.era,
          'quranic_mention': p.quranicMention,
          if (p.group != null) 'group': p.group!,
        },
      );

  static KnowledgeEntity _fromSahabi(SahabiEntry s) => KnowledgeEntity(
        ref: EntityRef(EntityType.sahabi, s.id),
        title: s.nameEnglish,
        titleArabic: s.nameArabic,
        subtitle: s.era,
        teaser: s.teaser,
        sequence: s.sequenceNumber,
        sections: _sections(s.layers),
        tags: [s.tribe.toLowerCase()],
        metadata: {
          'era': s.era,
          'tribe': s.tribe,
          'kunyah': s.kunyah,
        },
      );

  static KnowledgeEntity _fromSeerah(SeerahEntry s) => KnowledgeEntity(
        ref: EntityRef(EntityType.seerah, s.id),
        title: s.title,
        titleArabic: s.titleArabic,
        subtitle: '${s.era} · ${s.year}',
        teaser: s.teaser,
        sequence: s.sequenceNumber,
        sections: _sections(s.layers),
        tags: [if (s.group != null) s.group!.toLowerCase()],
        metadata: {
          'era': s.era,
          'year': s.year,
          if (s.group != null) 'group': s.group!,
        },
      );

  static KnowledgeEntity _fromDivineName(DivineName n) => KnowledgeEntity(
        ref: EntityRef(EntityType.divineName, n.id),
        title: n.translit,
        titleArabic: n.arabic,
        transliteration: n.translit,
        subtitle: n.meaningBrief,
        teaser: n.meaningBrief,
        sequence: n.number,
        sections: _sections(n.layers),
        metadata: {'number': '${n.number}', 'meaning': n.meaningBrief},
      );

  // ── Derived nodes ─────────────────────────────────────────────────

  /// A verse node. No sections: the reader already owns the ayah, its translation
  /// and its five layers, so this page's job is to say which entries cite it and
  /// then get out of the way.
  ///
  /// The subtitle is the surah's theme from [SurahMetadata], which is real local
  /// data. The surah *name* is not available offline anywhere in the app, so the
  /// title stays numeric rather than guessing at a name.
  static KnowledgeEntity _verseEntity(int surah, int ayah) {
    final meta = SurahMetadata.get(surah);
    return KnowledgeEntity(
      ref: EntityRef.verse(surah, ayah),
      title: 'Qur\'an $surah:$ayah',
      subtitle: meta?.theme,
      sequence: surah * 1000 + ayah,
      evidence: [QuranEvidence(surah: surah, ayah: ayah)],
      metadata: {
        'surah': '$surah',
        'ayah': '$ayah',
        if (meta != null) 'revelation': '${meta.location} · ${meta.period}',
      },
    );
  }

  /// A hadith node, built only for citations that gave a number.
  ///
  /// The text is deliberately absent here. It arrives from [HadithRepository] —
  /// cache, bundle or a configured remote — and until it does the page says so
  /// rather than showing a plausible-looking translation.
  static KnowledgeEntity _hadithEntity(HadithRef ref, HadithEvidence ev) =>
      KnowledgeEntity(
        ref: ref.entityRef,
        title: ref.display,
        titleArabic: ev.book?.titleArabic,
        subtitle: ev.bookName,
        teaser: ev.detail ?? ev.quotedText,
        evidence: [ev],
        metadata: {
          'collection': ref.collection,
          'number': ref.number,
          if (ev.narrator != null) 'narrator': ev.narrator!,
          if (ev.gradeNote != null) 'grade': ev.gradeNote!,
        },
      );

  static KnowledgeEntity _fromTheme(ThemeDoc t) => KnowledgeEntity(
        ref: t.ref,
        title: t.title,
        titleArabic: t.titleArabic,
        transliteration: t.transliteration,
        subtitle: t.transliteration,
        teaser: t.definition,
        tags: t.tags,
      );

  static KnowledgeEntity _fromScholar(ScholarDoc s) => KnowledgeEntity(
        ref: s.ref,
        title: s.title,
        titleArabic: s.titleArabic,
        subtitle: [s.dates, s.school].whereType<String>().join(' · '),
        teaser: s.biography,
        sections: [
          if (s.biography != null)
            KnowledgeSection(
              title: 'Life',
              body: s.biography!,
              sourceText: s.descriptionSource,
            ),
          if (s.methodology != null)
            KnowledgeSection(
              title: 'Method',
              body: s.methodology!,
              sourceText: s.descriptionSource,
            ),
        ],
        metadata: {
          if (s.dates != null) 'dates': s.dates!,
          if (s.school != null) 'school': s.school!,
          if (s.origin != null) 'origin': s.origin!,
          if (s.works.isNotEmpty) 'works': s.works.join(' · '),
          if (s.descriptionSource != null) 'source': s.descriptionSource!,
        },
      );

  /// A scholar the corpus cites but `scholars.json` has not described yet. Named,
  /// navigable, and honest about holding nothing but the citations that reached it.
  static KnowledgeEntity _scholarStub(EntityRef ref) => KnowledgeEntity(
        ref: ref,
        title: ref.id
            .split('-')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' '),
        subtitle: 'Cited in this app',
      );

  static KnowledgeEntity _fromPlace(PlaceDoc p) => KnowledgeEntity(
        ref: p.ref,
        title: p.title,
        titleArabic: p.titleArabic,
        subtitle: p.region,
        teaser: p.subtitle,
        metadata: {if (p.region != null) 'region': p.region!},
      );

  static KnowledgeEntity _fromJourney(JourneyDoc j) => KnowledgeEntity(
        ref: j.ref,
        title: j.title,
        titleArabic: j.titleArabic,
        subtitle: j.subtitle ?? '${j.steps.length} steps',
        teaser: j.intro,
        sections: [
          if (j.intro != null) KnowledgeSection(title: 'The path', body: j.intro!),
        ],
        metadata: {'steps': '${j.steps.length}'},
      );
}
