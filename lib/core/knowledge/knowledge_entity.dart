/// KnowledgeEntity — one normalised shape for everything the app can open.
///
/// The corpus has four different models (`ProphetEntry`, `SahabiEntry`,
/// `SeerahEntry`, `DivineName`) and the platform adds five more kinds of page
/// (verse, hadith, theme, scholar, place, journey). Rendering nine models with
/// nine screens is how an app ends up with nine slightly different layouts.
///
/// So the graph normalises: every node is a `KnowledgeEntity`, one screen renders
/// any of them, and the existing Discover screens keep their own bespoke layouts
/// untouched. The adapter direction matters — nothing here replaces
/// `ProphetEntry`; the builder reads it and produces this alongside it.
///
/// [RetrievalChunk] lives here too, because a chunk is a slice of an entity and
/// the two must not drift. It is Phase 7 groundwork: no model is called, nothing
/// is embedded. The only claim being made is that when retrieval arrives, the
/// answer can cite the way a layer cites, because the chunk already carries the
/// citation.
library;

import 'entity_ref.dart';
import 'evidence.dart';

/// A titled block of prose on an entity page, with its own evidence.
///
/// For the four corpus types this maps 1:1 onto a `DiscoverLayer` — the five
/// layers become five sections, and the layer's `source`, `quranRef` and
/// `hadithRef` become the section's evidence.
class KnowledgeSection {
  const KnowledgeSection({
    required this.title,
    required this.body,
    this.subtitle,
    this.evidence = const <Evidence>[],
    this.layerNumber,
    this.sourceText,
  });

  final String title;
  final String? subtitle;

  /// The prose, verbatim from the corpus. Never rewritten, never summarised.
  final String body;

  /// What this section rests on. Rendered as the evidence row beneath it.
  final List<Evidence> evidence;

  /// 1–5 where the section came from a layer, so a section can link back into the
  /// layer reader the user already knows.
  final int? layerNumber;

  /// The layer's own `source` string, kept whole even when the parser also turned
  /// it into structured evidence.
  final String? sourceText;
}

/// A node in the graph.
class KnowledgeEntity {
  const KnowledgeEntity({
    required this.ref,
    required this.title,
    this.titleArabic,
    this.transliteration,
    this.subtitle,
    this.teaser,
    this.sections = const <KnowledgeSection>[],
    this.evidence = const <Evidence>[],
    this.tags = const <String>[],
    this.metadata = const <String, String>{},
    this.sequence,
  });

  final EntityRef ref;

  /// English or transliterated name — "Adam", "Abu Bakr as-Siddiq", "The Hijrah".
  final String title;

  /// Arabic, where the corpus has it.
  final String? titleArabic;
  final String? transliteration;

  /// One line under the title: era, tribe, year, meaning. Whatever that type
  /// already shows.
  final String? subtitle;

  /// The corpus's own teaser. Reused verbatim as the row subtitle in connected
  /// sections and as the step note in Journey Mode — which is why journeys need no
  /// new prose written for them.
  final String? teaser;

  final List<KnowledgeSection> sections;

  /// Evidence that belongs to the entity as a whole rather than to one section —
  /// e.g. a prophet's `quranic_mention`.
  final List<Evidence> evidence;

  /// Free tags for search and for theme membership hints. Lowercased by the
  /// builder.
  final List<String> tags;

  /// Type-specific extras kept as strings so this model never needs a subclass:
  /// `era`, `tribe`, `year`, `group`, `kunyah`, `grade`, `narrator`, `school`.
  final Map<String, String> metadata;

  /// Preserves the corpus's own ordering (prophet 1–25, seerah event 1–33) so
  /// lists do not fall back to alphabetical.
  final int? sequence;

  EntityType get type => ref.type;

  String? operator [](String key) => metadata[key];

  /// One line for a row subtitle when there is no teaser: the subtitle, else the
  /// era, else the type.
  String get shortDescription =>
      teaser ?? subtitle ?? metadata['era'] ?? type.label;

  /// Everything searchable about this entity, lowercased and joined once at build
  /// time so `search()` is a substring test rather than a walk over sections.
  String get searchHaystack => [
        title,
        titleArabic ?? '',
        transliteration ?? '',
        subtitle ?? '',
        teaser ?? '',
        ...tags,
        ...metadata.values,
      ].join(' ').toLowerCase();

  KnowledgeEntity copyWith({
    String? subtitle,
    String? teaser,
    List<KnowledgeSection>? sections,
    List<Evidence>? evidence,
    List<String>? tags,
    Map<String, String>? metadata,
  }) =>
      KnowledgeEntity(
        ref: ref,
        title: title,
        titleArabic: titleArabic,
        transliteration: transliteration,
        subtitle: subtitle ?? this.subtitle,
        teaser: teaser ?? this.teaser,
        sections: sections ?? this.sections,
        evidence: evidence ?? this.evidence,
        tags: tags ?? this.tags,
        metadata: metadata ?? this.metadata,
        sequence: sequence,
      );
}

/// One independently attributable slice of the corpus.
///
/// Phase 7 preparation and nothing more. Each chunk knows the entity it came
/// from, the section it came from, and the citations inside it, so a future
/// retrieval answer can name its source instead of asserting. Deliberately not
/// embedded, not chunked by token count, and not shipped to anything.
class RetrievalChunk {
  const RetrievalChunk({
    required this.id,
    required this.entityRef,
    required this.entityTitle,
    required this.sectionTitle,
    required this.text,
    this.citations = const <String>[],
    this.tags = const <String>[],
    this.metadata = const <String, String>{},
  });

  /// `prophet:adam#3` — entity ref plus section index. Stable across rebuilds, so
  /// it can be a primary key later.
  final String id;

  final EntityRef entityRef;
  final String entityTitle;
  final String sectionTitle;

  /// The section body, unmodified.
  final String text;

  /// Canonical refs of everything this chunk cites — `verse:2:30`,
  /// `hadith:bukhari:3326` — plus any prose citation, verbatim. An answer built
  /// from this chunk has its citations already in hand.
  final List<String> citations;

  final List<String> tags;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity': entityRef.canonical,
        'entity_title': entityTitle,
        'section': sectionTitle,
        'text': text,
        'citations': citations,
        'tags': tags,
        'metadata': metadata,
      };
}
