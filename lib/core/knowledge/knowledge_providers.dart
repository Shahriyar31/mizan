/// Knowledge providers — the graph, and the small reads the UI does against it.
///
/// One `FutureProvider` builds the graph once for the process. Everything else is
/// synchronous and derived, because a connected section must not each own a future:
/// eight sections on a page would mean eight loading spinners for data that is
/// already in memory.
///
/// [knowledgeGraphProvider] is watched by the one widget that gates a page; the
/// sections below it take the resolved graph as a plain argument.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entity_ref.dart';
import 'graph_builder.dart';
import 'knowledge_entity.dart';
import 'knowledge_graph.dart';

/// Built once, cached for the life of the process. `keepAlive` is the default for
/// a `FutureProvider` that nothing invalidates, but it is stated here because the
/// build walks 187 files' worth of citations and doing it twice would be a bug
/// rather than a slowdown.
final knowledgeGraphProvider = FutureProvider<KnowledgeGraph>((ref) async {
  return KnowledgeBuilder.build();
});

/// The graph if it is ready, else null. For screens that already exist and must
/// not gain a loading state: a connected section simply is not there until the
/// graph resolves, which is the correct behaviour for an addition.
final knowledgeGraphOrNullProvider = Provider<KnowledgeGraph?>((ref) {
  return ref.watch(knowledgeGraphProvider).maybeWhen(
        data: (graph) => graph,
        orElse: () => null,
      );
});

/// One entity, or null while loading or if the ref is unknown.
final knowledgeEntityProvider =
    Provider.family<KnowledgeEntity?, EntityRef>((ref, entityRef) {
  return ref.watch(knowledgeGraphOrNullProvider)?[entityRef];
});

/// Neighbours grouped by the type of the other end — one call per page, which is
/// all the "Connected …" sections need.
final connectionsByTypeProvider =
    Provider.family<Map<EntityType, List<Connection>>, EntityRef>((ref, entityRef) {
  final graph = ref.watch(knowledgeGraphOrNullProvider);
  if (graph == null) return const {};
  return graph.connectionsByType(entityRef);
});

/// Neighbours of one type. Used where a page wants a single section rather than
/// all of them — the ayah screen's "Discussed in" list, for instance.
final connectionsOfTypeProvider = Provider.family<List<Connection>,
    ({EntityRef ref, EntityType type})>((ref, args) {
  final graph = ref.watch(knowledgeGraphOrNullProvider);
  if (graph == null) return const [];
  return graph.connections(args.ref, type: args.type);
});

/// Everything of one type, in the corpus's own order.
final entitiesOfTypeProvider =
    Provider.family<List<KnowledgeEntity>, EntityType>((ref, type) {
  final graph = ref.watch(knowledgeGraphOrNullProvider);
  if (graph == null) return const [];
  return graph.ofType(type);
});

/// A live search over titles, tags and metadata. Cheap enough to run per
/// keystroke: it is a substring test over a haystack each entity built once.
final knowledgeSearchProvider =
    Provider.family<List<KnowledgeEntity>, String>((ref, query) {
  final graph = ref.watch(knowledgeGraphOrNullProvider);
  if (graph == null || query.trim().isEmpty) return const [];
  return graph.search(query);
});
