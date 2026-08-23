/// Relation — a typed, sourced edge between two entities.
///
/// Every edge in the graph answers three questions: what kind of link is this,
/// where did it come from, and can it be traced back to a file. The third is what
/// [derived] and [provenance] are for.
///
/// A **derived** edge was computed from a citation the corpus already contains —
/// e.g. the Adam file's layer 3 cites Qur'an 2:30, so `prophet:adam --mentions-->
/// verse:2:30` exists and carries that layer's own `source` string. A **curated**
/// edge (`derived: false`) was declared in `assets/data/knowledge/edges.json`,
/// which only ever holds relationships stated in the corpus text or in a cited
/// source.
///
/// Nothing in this system links two people because they feel related. If an edge
/// cannot name where it came from, it is not written.
library;

import 'entity_ref.dart';
import 'evidence.dart';

/// How two entities are connected.
///
/// Each kind knows its own inverse, which is how the graph gets reverse edges for
/// free: declaring "Bukhari 3326 mentions Adam" makes Adam → that hadith
/// navigable without anybody hand-writing the mirror of a thousand edges.
enum RelationKind {
  mentions('mentions', 'Mentions'),
  mentionedIn('mentioned_in', 'Mentioned in'),
  relatedTo('related_to', 'Related'),
  parentOf('parent_of', 'Parent of'),
  childOf('child_of', 'Child of'),
  spouseOf('spouse_of', 'Spouse of'),
  opposedBy('opposed_by', 'Opposed by'),
  opposes('opposes', 'Opposed'),
  successorOf('successor_of', 'Came after'),
  predecessorOf('predecessor_of', 'Came before'),
  narratedBy('narrated_by', 'Narrated by'),
  narrates('narrates', 'Narrated'),
  occurredAt('occurred_at', 'Took place at'),
  siteOf('site_of', 'Site of'),
  aboutTheme('about_theme', 'Theme'),
  themeOf('theme_of', 'Covers'),
  commentedOnBy('commented_on_by', 'Commentary by'),
  commentsOn('comments_on', 'Commentary on'),
  partOfJourney('part_of_journey', 'Part of'),
  journeyIncludes('journey_includes', 'Includes');

  const RelationKind(this.slug, this.label);

  final String slug;

  /// Used as a grouping label where a section shows mixed kinds. Most sections
  /// group by the *type* of the other end instead ("Connected Verses"), because
  /// that is what a reader is looking for.
  final String label;

  RelationKind get inverse => switch (this) {
        RelationKind.mentions => RelationKind.mentionedIn,
        RelationKind.mentionedIn => RelationKind.mentions,
        RelationKind.relatedTo => RelationKind.relatedTo,
        RelationKind.parentOf => RelationKind.childOf,
        RelationKind.childOf => RelationKind.parentOf,
        RelationKind.spouseOf => RelationKind.spouseOf,
        RelationKind.opposedBy => RelationKind.opposes,
        RelationKind.opposes => RelationKind.opposedBy,
        RelationKind.successorOf => RelationKind.predecessorOf,
        RelationKind.predecessorOf => RelationKind.successorOf,
        RelationKind.narratedBy => RelationKind.narrates,
        RelationKind.narrates => RelationKind.narratedBy,
        RelationKind.occurredAt => RelationKind.siteOf,
        RelationKind.siteOf => RelationKind.occurredAt,
        RelationKind.aboutTheme => RelationKind.themeOf,
        RelationKind.themeOf => RelationKind.aboutTheme,
        RelationKind.commentedOnBy => RelationKind.commentsOn,
        RelationKind.commentsOn => RelationKind.commentedOnBy,
        RelationKind.partOfJourney => RelationKind.journeyIncludes,
        RelationKind.journeyIncludes => RelationKind.partOfJourney,
      };

  static RelationKind? fromSlug(String? slug) {
    if (slug == null) return null;
    final needle = slug.toLowerCase();
    for (final k in RelationKind.values) {
      if (k.slug == needle) return k;
    }
    return null;
  }
}

/// Where a derived edge came from, precisely enough to open the file and check.
class RelationProvenance {
  const RelationProvenance({
    required this.entityRef,
    this.layerNumber,
    this.layerTitle,
    this.sourceText,
  });

  /// The entity whose file produced this edge.
  final EntityRef entityRef;

  /// Which of the five layers the citation sat in.
  final int? layerNumber;
  final String? layerTitle;

  /// That layer's own `source` field, verbatim. This is the string a reader would
  /// need to verify the claim independently.
  final String? sourceText;

  /// "Adam · layer 3 · Tafsir Ibn Kathir on 2:30" — shown in the evidence sheet
  /// under "where this connection comes from".
  String get display {
    final parts = <String>[entityRef.id];
    if (layerNumber != null) parts.add('layer $layerNumber');
    if (sourceText != null && sourceText!.isNotEmpty) parts.add(sourceText!);
    return parts.join(' · ');
  }
}

/// One directed edge. The graph stores both directions; a `Relation` is always
/// read from [from]'s point of view.
class Relation {
  const Relation({
    required this.from,
    required this.to,
    required this.kind,
    this.note,
    this.evidence = const <Evidence>[],
    this.derived = false,
    this.provenance,
  });

  final EntityRef from;
  final EntityRef to;
  final RelationKind kind;

  /// A short phrase for the row's subtitle — "both discussed at Qur'an 2:30",
  /// "his wife", "narrated this hadith". Written by the builder from the citation
  /// it used, or supplied by `edges.json`. Never a claim beyond the citation.
  final String? note;

  /// Why this edge exists. A derived edge always has at least one.
  final List<Evidence> evidence;

  /// True when computed from the corpus; false when curated by hand.
  final bool derived;

  /// Set for derived edges. Null for curated ones, whose `edges.json` entry is
  /// itself the record.
  final RelationProvenance? provenance;

  /// The mirrored edge, with the same evidence and provenance. Built by the graph
  /// so callers never write the reverse by hand.
  Relation get reversed => Relation(
        from: to,
        to: from,
        kind: kind.inverse,
        note: note,
        evidence: evidence,
        derived: derived,
        provenance: provenance,
      );

  /// Identity for de-duplication: two edges are the same edge if they join the
  /// same pair the same way, regardless of which citation found them first. The
  /// graph merges their evidence rather than storing the pair twice.
  String get key => '${from.canonical}|${kind.slug}|${to.canonical}';

  Relation mergedWith(Relation other) {
    final seen = <String>{};
    final merged = <Evidence>[];
    for (final e in [...evidence, ...other.evidence]) {
      if (seen.add(e.key)) merged.add(e);
    }
    merged.sort(Evidence.compare);
    return Relation(
      from: from,
      to: to,
      kind: kind,
      note: note ?? other.note,
      evidence: merged,
      // A pair that is both curated and derived counts as curated: the stronger
      // claim wins, and the derived evidence still rides along.
      derived: derived && other.derived,
      provenance: provenance ?? other.provenance,
    );
  }

  @override
  String toString() => key;
}
