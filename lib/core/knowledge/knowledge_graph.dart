/// KnowledgeGraph — the in-memory index every connected section reads from.
///
/// Built once, cached in a provider, never mutated. Construction inserts the
/// inverse of every edge, which is what makes navigation endless without anybody
/// hand-writing a thousand mirrored relationships: declaring "Bukhari 3326
/// mentions Adam" is enough for Adam's page to list that hadith.
///
/// Edges that join the same pair the same way are merged rather than duplicated,
/// so an ayah cited by four of Adam's five layers produces one connection
/// carrying four pieces of evidence — not four identical rows.
///
/// Everything here is pure Dart: no Flutter, no I/O, no async. Loading is the
/// builder's job, so the graph stays testable and cheap to reason about.
library;

import 'entity_ref.dart';
import 'evidence.dart';
import 'knowledge_entity.dart';
import 'relation.dart';

/// A neighbour paired with the edge that reaches it — what a connected row needs
/// to render: a title from [entity], and a reason from [relation].
class Connection {
  const Connection({required this.relation, required this.entity});

  final Relation relation;
  final KnowledgeEntity entity;

  EntityRef get ref => entity.ref;
  RelationKind get kind => relation.kind;

  /// The subtitle for a connected row: the edge's own note if it has one
  /// ("both discussed at Qur'an 2:30"), else the entity's teaser. Preferring the
  /// note means the row explains the *connection*, which is the thing the reader
  /// tapped for.
  String? get reason => relation.note ?? entity.teaser;

  List<Evidence> get evidence => relation.evidence;
}

class KnowledgeGraph {
  KnowledgeGraph._({
    required Map<String, KnowledgeEntity> byId,
    required Map<EntityType, List<KnowledgeEntity>> byType,
    required Map<String, List<Relation>> adjacency,
  })  : _byId = byId,
        _byType = byType,
        _adjacency = adjacency;

  /// Assembles a graph from entities and edges.
  ///
  /// Edges pointing at an entity that does not exist are kept in the adjacency map
  /// but skipped by [connections], so a curated `edges.json` entry that references
  /// a not-yet-written theme degrades to nothing visible instead of crashing. The
  /// [danglingRefs] getter reports them for the analyzer pass.
  factory KnowledgeGraph.build({
    required Iterable<KnowledgeEntity> entities,
    required Iterable<Relation> relations,
  }) {
    final byId = <String, KnowledgeEntity>{};
    for (final e in entities) {
      // Last write wins, and a curated entity is loaded after a derived one on
      // purpose: a hand-written theme file should beat a stub the builder made.
      byId[e.ref.canonical] = e;
    }

    final byType = <EntityType, List<KnowledgeEntity>>{};
    for (final e in byId.values) {
      byType.putIfAbsent(e.type, () => <KnowledgeEntity>[]).add(e);
    }
    for (final list in byType.values) {
      list.sort((a, b) {
        final sa = a.sequence, sb = b.sequence;
        if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
        if (sa != null && sb == null) return -1;
        if (sa == null && sb != null) return 1;
        return a.ref.compareTo(b.ref);
      });
    }

    // Both directions, de-duplicated by (from, kind, to) with evidence merged.
    final merged = <String, Relation>{};
    void insert(Relation r) {
      if (r.from == r.to) return; // A self-edge is always a builder bug.
      final existing = merged[r.key];
      merged[r.key] = existing == null ? r : existing.mergedWith(r);
    }

    for (final r in relations) {
      insert(r);
      insert(r.reversed);
    }

    final adjacency = <String, List<Relation>>{};
    for (final r in merged.values) {
      adjacency.putIfAbsent(r.from.canonical, () => <Relation>[]).add(r);
    }

    return KnowledgeGraph._(
      byId: byId,
      byType: byType,
      adjacency: adjacency,
    );
  }

  static final KnowledgeGraph empty =
      KnowledgeGraph.build(entities: const [], relations: const []);

  final Map<String, KnowledgeEntity> _byId;
  final Map<EntityType, List<KnowledgeEntity>> _byType;
  final Map<String, List<Relation>> _adjacency;

  int get entityCount => _byId.length;

  /// Directed edge count, so it is twice the number of declared relationships.
  int get edgeCount =>
      _adjacency.values.fold<int>(0, (sum, list) => sum + list.length);

  KnowledgeEntity? operator [](EntityRef ref) => _byId[ref.canonical];

  KnowledgeEntity? byCanonical(String canonical) => _byId[canonical];

  bool contains(EntityRef ref) => _byId.containsKey(ref.canonical);

  List<KnowledgeEntity> ofType(EntityType type) =>
      List.unmodifiable(_byType[type] ?? const <KnowledgeEntity>[]);

  Iterable<KnowledgeEntity> get allEntities => _byId.values;

  /// Every edge leaving [ref], including the mirrored ones.
  List<Relation> relationsFor(EntityRef ref) =>
      List.unmodifiable(_adjacency[ref.canonical] ?? const <Relation>[]);

  /// Neighbours of [ref], optionally filtered by edge kind and by the type of the
  /// other end. This is the one call every connected section makes.
  ///
  /// Ordering is deliberate and stable: curated edges before derived ones (a
  /// hand-stated relationship is more interesting than a co-citation), then more
  /// evidence before less, then the entity's own sequence. Without this the
  /// sections re-order themselves whenever the Map iteration order shifts.
  List<Connection> connections(
    EntityRef ref, {
    RelationKind? kind,
    Set<RelationKind>? kinds,
    EntityType? type,
    Set<EntityType>? types,
    int? limit,
  }) {
    final out = <Connection>[];
    for (final r in _adjacency[ref.canonical] ?? const <Relation>[]) {
      if (kind != null && r.kind != kind) continue;
      if (kinds != null && !kinds.contains(r.kind)) continue;
      if (type != null && r.to.type != type) continue;
      if (types != null && !types.contains(r.to.type)) continue;
      final entity = _byId[r.to.canonical];
      if (entity == null) continue; // Dangling: nothing to show, so show nothing.
      out.add(Connection(relation: r, entity: entity));
    }

    out.sort((a, b) {
      if (a.relation.derived != b.relation.derived) {
        return a.relation.derived ? 1 : -1;
      }
      final byEvidence =
          b.relation.evidence.length.compareTo(a.relation.evidence.length);
      if (byEvidence != 0) return byEvidence;
      final sa = a.entity.sequence, sb = b.entity.sequence;
      if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
      return a.ref.compareTo(b.ref);
    });

    if (limit != null && out.length > limit) {
      return List.unmodifiable(out.sublist(0, limit));
    }
    return List.unmodifiable(out);
  }

  /// Neighbours grouped by the type of the other end, in [EntityType] declaration
  /// order. One call builds every "Connected …" section on a page.
  Map<EntityType, List<Connection>> connectionsByType(
    EntityRef ref, {
    Set<RelationKind>? kinds,
  }) {
    final grouped = <EntityType, List<Connection>>{};
    for (final c in connections(ref, kinds: kinds)) {
      grouped.putIfAbsent(c.ref.type, () => <Connection>[]).add(c);
    }
    return Map.fromEntries(
      EntityType.values
          .where(grouped.containsKey)
          .map((t) => MapEntry(t, List<Connection>.unmodifiable(grouped[t]!))),
    );
  }

  /// Edges whose far end has no entity. Reported rather than thrown: a curated
  /// file naming a theme that has not been written yet is a to-do, not a crash.
  List<String> get danglingRefs {
    final missing = <String>{};
    for (final list in _adjacency.values) {
      for (final r in list) {
        if (!_byId.containsKey(r.to.canonical)) missing.add(r.to.canonical);
      }
    }
    final out = missing.toList()..sort();
    return out;
  }

  /// Substring search over titles, tags and metadata.
  ///
  /// Not a ranking engine. Exact-prefix hits on the title come first because
  /// typing "adam" should find Adam before it finds an event that mentions him.
  List<KnowledgeEntity> search(
    String query, {
    Set<EntityType>? types,
    int limit = 40,
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    final exact = <KnowledgeEntity>[];
    final prefix = <KnowledgeEntity>[];
    final loose = <KnowledgeEntity>[];

    for (final e in _byId.values) {
      if (types != null && !types.contains(e.type)) continue;
      final title = e.title.toLowerCase();
      if (title == needle) {
        exact.add(e);
      } else if (title.startsWith(needle)) {
        prefix.add(e);
      } else if (e.searchHaystack.contains(needle)) {
        loose.add(e);
      }
    }

    int byTitle(KnowledgeEntity a, KnowledgeEntity b) =>
        a.title.compareTo(b.title);
    exact.sort(byTitle);
    prefix.sort(byTitle);
    loose.sort(byTitle);

    final out = [...exact, ...prefix, ...loose];
    return List.unmodifiable(
      out.length > limit ? out.sublist(0, limit) : out,
    );
  }

  /// Phase 7. One chunk per section, each carrying the canonical refs of what it
  /// cites. Nothing is embedded and nothing leaves the device; this exists so the
  /// day retrieval is added, attribution is already solved.
  List<RetrievalChunk> exportChunks({Set<EntityType>? types}) {
    final chunks = <RetrievalChunk>[];
    for (final e in _byId.values) {
      if (types != null && !types.contains(e.type)) continue;
      for (var i = 0; i < e.sections.length; i++) {
        final s = e.sections[i];
        if (s.body.trim().isEmpty) continue;
        final citations = <String>[];
        for (final ev in [...e.evidence, ...s.evidence]) {
          final target = ev.target;
          citations.add(target?.canonical ?? ev.label);
        }
        if (s.sourceText != null && s.sourceText!.isNotEmpty) {
          citations.add(s.sourceText!);
        }
        chunks.add(
          RetrievalChunk(
            id: '${e.ref.canonical}#$i',
            entityRef: e.ref,
            entityTitle: e.title,
            sectionTitle: s.title,
            text: s.body,
            citations: citations.toSet().toList(),
            tags: e.tags,
            metadata: e.metadata,
          ),
        );
      }
    }
    return chunks;
  }
}
