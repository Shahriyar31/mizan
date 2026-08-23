/// Hadith providers — the repository, the one-hadith read the UI does, and the
/// topic search behind the learning section.
///
/// The repository is a singleton for the process because its caches are the point.
/// Reads are `FutureProvider.family` keyed on the canonical ref, so ten citations
/// to Bukhari 3326 across a page share one lookup and one row.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/knowledge/entity_ref.dart';
import '../../../core/knowledge/hadith_ref.dart';
import '../../../core/knowledge/knowledge_providers.dart';
import '../../../core/knowledge/narrator_index.dart';
import '../data/hadith_extras.dart';
import '../data/hadith_record.dart';
import '../data/hadith_repository.dart';
import '../data/hadith_search_repository.dart';
import '../data/hadith_topic.dart';

final hadithRepositoryProvider = Provider<HadithRepository>((ref) {
  return HadithRepository();
});

final hadithSearchRepositoryProvider = Provider<HadithSearchRepository>((ref) {
  return HadithSearchRepository();
});

/// One hadith. Null data means "we do not have this text", which is a legitimate
/// answer here, not an error — the screen renders the citation without the text.
final hadithProvider =
    FutureProvider.family<HadithRecord?, HadithRef>((ref, hadithRef) async {
  return ref.watch(hadithRepositoryProvider).load(hadithRef);
});

/// Several at once — the shape a story's evidence list wants.
final hadithBatchProvider = FutureProvider.family<Map<HadithRef, HadithRecord>,
    List<HadithRef>>((ref, refs) async {
  return ref.watch(hadithRepositoryProvider).loadAll(refs);
});

/// How many hadiths are saved on this device. Read by Settings so the cache is
/// visible and clearable rather than invisible storage.
final savedHadithCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(hadithRepositoryProvider).savedCount();
});

// ── Topic discovery ───────────────────────────────────────────────────

/// The hadiths a topic's search terms return, keyed by topic id.
///
/// Results are handed to [HadithRepository.remember] before they are returned, so
/// the text is already cached by the time the reader taps one — the detail page
/// opens with content rather than a spinner, and works offline afterwards.
final hadithTopicProvider =
    FutureProvider.family<List<HadithRecord>, String>((ref, topicId) async {
  final topic = HadithTopics.byId(topicId);
  if (topic == null) return const [];

  final results = await ref.watch(hadithSearchRepositoryProvider).forTopic(topic);
  if (results.isNotEmpty) {
    await ref.watch(hadithRepositoryProvider).remember(results);
  }
  return results;
});

/// The reader's own reflection on one hadith, or null.
final hadithReflectionProvider =
    FutureProvider.family<String?, HadithRef>((ref, hadithRef) async {
  return ref.watch(hadithRepositoryProvider).reflection(hadithRef);
});

/// Bundled vocabulary and scholar commentary for one hadith. Empty until a
/// verified source file is dropped into the bundle — see [HadithExtrasSource].
final hadithExtrasProvider =
    FutureProvider.family<HadithExtras, HadithRef>((ref, hadithRef) async {
  return HadithExtrasSource.load(hadithRef);
});

/// Companion names → their existing biography, built from the graph.
///
/// Built here rather than inside the hadith screen so it is constructed once for
/// the process: the graph holds every companion the app knows, and rebuilding the
/// index per screen would walk that list on every navigation.
///
/// Null until the graph has loaded, which is the honest state — a narrator cannot
/// be made tappable before we know whether we have a biography for him.
final narratorIndexProvider = Provider<NarratorIndex?>((ref) {
  final graph = ref.watch(knowledgeGraphOrNullProvider);
  if (graph == null) return null;

  final index = NarratorIndex();
  for (final entity in graph.ofType(EntityType.sahabi)) {
    index.add(entity.ref, [entity.title, entity.metadata['kunyah']]);
  }
  return index.isEmpty ? null : index;
});
