/// Curated knowledge data — the JSON under `assets/data/knowledge/`.
///
/// Everything here is **structure**, not content. A theme is a name and a list of
/// entity refs; a journey is an ordered list of refs; a scholar is a name, dates,
/// a school and a bibliography. The prose that fills those pages comes from the
/// corpus through the graph, which is why adding a theme costs six lines of JSON
/// and no new writing.
///
/// Every file is optional. A missing or malformed file logs in debug and yields an
/// empty list, so the app runs identically whether or not the knowledge folder has
/// been populated. That matters: the graph must never be the reason the app fails
/// to open.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'entity_ref.dart';
import 'relation.dart';

/// A theme or concept — Knowledge, Patience, Repentance, Mercy, Tawheed,
/// Leadership.
///
/// [definition] is the only prose in the file, and it is held to one sentence of
/// the kind that appears in any glossary of Islamic terms. Anything longer waits
/// for a cited source; the page has plenty to say from its members' own layers.
///
/// Membership is **derived, not listed**. [keywords] are the terms the theme is
/// discussed in, and the builder counts them across each entry's layers; an entry
/// that clears [minHits] joins the theme, and the edge points at the layer where
/// the discussion actually is. That way a theme page is never a hand-picked
/// opinion about which prophets are "about patience" — it is a list of entries
/// whose own text you can go and read. [members] stays available for the rare case
/// where an entry belongs and does not use the word.
class ThemeDoc {
  const ThemeDoc({
    required this.id,
    required this.title,
    this.titleArabic,
    this.transliteration,
    this.definition,
    this.members = const <EntityRef>[],
    this.keywords = const <String>[],
    this.minHits = 4,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String? titleArabic;
  final String? transliteration;
  final String? definition;

  /// Entities stated by hand to belong here. Usually empty.
  final List<EntityRef> members;

  /// Terms matched against layer text, lowercased, matched at a word boundary so
  /// "learn" catches "learned" but "ilm" does not catch "film".
  final List<String> keywords;

  /// How many keyword occurrences an entry needs before it joins. Tuned per theme
  /// in the JSON, because "knowledge" is a common word and "tawbah" is not.
  final int minHits;

  final List<String> tags;

  EntityRef get ref => EntityRef(EntityType.theme, id);

  static ThemeDoc? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    return ThemeDoc(
      id: id,
      title: title,
      titleArabic: j['title_arabic'] as String?,
      transliteration: j['transliteration'] as String?,
      definition: j['definition'] as String?,
      members: _refs(j['members']),
      keywords: _strings(j['keywords']).map((k) => k.toLowerCase()).toList(),
      minHits: (j['min_hits'] as num?)?.toInt() ?? 4,
      tags: _strings(j['tags']),
    );
  }
}

/// A scholar or compiler the corpus cites.
///
/// [biography] and [methodology] are nullable and stay null until verified text is
/// supplied. The page is not empty in the meantime: it shows the works, and the
/// verses and topics derived from every layer that cites this scholar, which is
/// real information rather than a paraphrase of an encyclopedia.
class ScholarDoc {
  const ScholarDoc({
    required this.id,
    required this.title,
    this.titleArabic,
    this.dates,
    this.school,
    this.origin,
    this.works = const <String>[],
    this.biography,
    this.methodology,
    this.descriptionSource,
  });

  final String id;
  final String title;
  final String? titleArabic;

  /// "701–774 AH / 1301–1373 CE". Bibliographic, not interpretive.
  final String? dates;
  final String? school;
  final String? origin;

  /// Titles only. A work list is a bibliography, and bibliographies are checkable.
  final List<String> works;

  final String? biography;
  final String? methodology;

  /// Where [biography] and [methodology] came from. Shown on the page whenever
  /// either is present, so a descriptive summary is never mistaken for a sourced
  /// claim.
  final String? descriptionSource;

  EntityRef get ref => EntityRef(EntityType.scholar, id);

  static ScholarDoc? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    return ScholarDoc(
      id: id,
      title: title,
      titleArabic: j['title_arabic'] as String?,
      dates: j['dates'] as String?,
      school: j['school'] as String?,
      origin: j['origin'] as String?,
      works: _strings(j['works']),
      biography: j['biography'] as String?,
      methodology: j['methodology'] as String?,
      descriptionSource: j['description_source'] as String?,
    );
  }
}

/// A place that events happened at.
class PlaceDoc {
  const PlaceDoc({
    required this.id,
    required this.title,
    this.titleArabic,
    this.subtitle,
    this.region,
    this.events = const <EntityRef>[],
  });

  final String id;
  final String title;
  final String? titleArabic;
  final String? subtitle;
  final String? region;

  /// Events that took place here. The graph mirrors these into `siteOf`, so the
  /// place page and the event page both know about each other from one line.
  final List<EntityRef> events;

  EntityRef get ref => EntityRef(EntityType.place, id);

  static PlaceDoc? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    return PlaceDoc(
      id: id,
      title: title,
      titleArabic: j['title_arabic'] as String?,
      subtitle: j['subtitle'] as String?,
      region: j['region'] as String?,
      events: _refs(j['events']),
    );
  }
}

/// One step on a journey. [note] is almost always null on purpose — the step's
/// text is the entity's own teaser, so a journey adds no new prose.
class JourneyStepDoc {
  const JourneyStepDoc({required this.ref, this.note});

  final EntityRef ref;
  final String? note;
}

/// A curated learning path — an ordered walk through entities that already exist.
///
/// Not a course. No score, no unlocking, no streak. The order is the whole idea:
/// repentance read through Adam, then Yunus, then Ka'b ibn Malik lands differently
/// than the same three pages read at random.
class JourneyDoc {
  const JourneyDoc({
    required this.id,
    required this.title,
    this.titleArabic,
    this.subtitle,
    this.intro,
    this.steps = const <JourneyStepDoc>[],
    this.themes = const <EntityRef>[],
  });

  final String id;
  final String title;
  final String? titleArabic;
  final String? subtitle;

  /// One paragraph framing the path. The only prose in the file.
  final String? intro;

  final List<JourneyStepDoc> steps;

  /// Themes this journey walks through, so a theme page can offer the journey.
  final List<EntityRef> themes;

  EntityRef get ref => EntityRef(EntityType.journey, id);

  static JourneyDoc? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    final steps = <JourneyStepDoc>[];
    for (final raw in (j['steps'] as List<dynamic>? ?? const [])) {
      if (raw is String) {
        final ref = EntityRef.parse(raw);
        if (ref != null) steps.add(JourneyStepDoc(ref: ref));
      } else if (raw is Map<String, dynamic>) {
        final ref = EntityRef.parse(raw['ref'] as String?);
        if (ref != null) {
          steps.add(JourneyStepDoc(ref: ref, note: raw['note'] as String?));
        }
      }
    }
    return JourneyDoc(
      id: id,
      title: title,
      titleArabic: j['title_arabic'] as String?,
      subtitle: j['subtitle'] as String?,
      intro: j['intro'] as String?,
      steps: steps,
      themes: _refs(j['themes']),
    );
  }
}

/// A relationship stated by hand, because it is stated in the corpus text or in a
/// cited source but is not expressible as a shared citation.
///
/// "Adam is the father of humankind" and "Hawwa is his wife" are in the text of
/// the Adam entry; no citation-matching would produce them. What this file must
/// never hold is a connection that merely seems plausible.
class CuratedEdgeDoc {
  const CuratedEdgeDoc({
    required this.relation,
    this.sourceNote,
  });

  final Relation relation;

  /// Where the curator got it. Kept on the edge as the note when no other note is
  /// given, so a curated edge can always be challenged.
  final String? sourceNote;

  static CuratedEdgeDoc? fromJson(Map<String, dynamic> j) {
    final from = EntityRef.parse(j['from'] as String?);
    final to = EntityRef.parse(j['to'] as String?);
    final kind = RelationKind.fromSlug(j['kind'] as String?);
    if (from == null || to == null || kind == null) return null;
    final source = j['source'] as String?;
    return CuratedEdgeDoc(
      sourceNote: source,
      relation: Relation(
        from: from,
        to: to,
        kind: kind,
        note: j['note'] as String? ?? source,
        derived: false,
      ),
    );
  }
}

/// Everything loaded from `assets/data/knowledge/`.
class KnowledgeAssets {
  const KnowledgeAssets({
    this.themes = const <ThemeDoc>[],
    this.scholars = const <ScholarDoc>[],
    this.places = const <PlaceDoc>[],
    this.journeys = const <JourneyDoc>[],
    this.edges = const <CuratedEdgeDoc>[],
  });

  final List<ThemeDoc> themes;
  final List<ScholarDoc> scholars;
  final List<PlaceDoc> places;
  final List<JourneyDoc> journeys;
  final List<CuratedEdgeDoc> edges;

  static const KnowledgeAssets none = KnowledgeAssets();

  static const String _dir = 'assets/data/knowledge';

  /// Loads all five files in parallel. Each one independently degrades to empty,
  /// so a typo in `journeys.json` costs the journeys and nothing else.
  static Future<KnowledgeAssets> load() async {
    final results = await Future.wait([
      _list('$_dir/themes.json', 'themes', ThemeDoc.fromJson),
      _list('$_dir/scholars.json', 'scholars', ScholarDoc.fromJson),
      _list('$_dir/places.json', 'places', PlaceDoc.fromJson),
      _list('$_dir/journeys.json', 'journeys', JourneyDoc.fromJson),
      _list('$_dir/edges.json', 'edges', CuratedEdgeDoc.fromJson),
    ]);

    return KnowledgeAssets(
      themes: results[0].cast<ThemeDoc>(),
      scholars: results[1].cast<ScholarDoc>(),
      places: results[2].cast<PlaceDoc>(),
      journeys: results[3].cast<JourneyDoc>(),
      edges: results[4].cast<CuratedEdgeDoc>(),
    );
  }

  /// Reads `{ "<key>": [ … ] }`, or a bare top-level array, and maps each item.
  /// Items that fail to parse are skipped individually — one bad theme does not
  /// take the other five with it.
  static Future<List<Object>> _list<T extends Object>(
    String path,
    String key,
    T? Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = json.decode(raw);
      final items = decoded is List
          ? decoded
          : (decoded as Map<String, dynamic>)[key] as List<dynamic>? ??
              const <dynamic>[];
      final out = <Object>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final parsed = fromJson(item);
        if (parsed != null) {
          out.add(parsed);
        } else if (kDebugMode) {
          debugPrint('[knowledge] skipped a malformed entry in $path');
        }
      }
      return out;
    } catch (e) {
      // Absent is the normal state before the folder is populated, so this is not
      // an error path — it is the reason the graph works on day one.
      if (kDebugMode) debugPrint('[knowledge] $path not loaded: $e');
      return const <Object>[];
    }
  }
}

List<EntityRef> _refs(Object? raw) {
  if (raw is! List) return const [];
  final out = <EntityRef>[];
  for (final item in raw) {
    final ref = EntityRef.parse(item is String ? item : null);
    if (ref != null) out.add(ref);
  }
  return out;
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}
