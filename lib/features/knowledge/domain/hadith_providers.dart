/// Hadith providers — the repository, and the one-hadith read the UI does.
///
/// The repository is a singleton for the process because its caches are the point.
/// Reads are `FutureProvider.family` keyed on the canonical ref, so ten citations
/// to Bukhari 3326 across a page share one lookup and one row.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/knowledge/hadith_ref.dart';
import '../data/hadith_record.dart';
import '../data/hadith_repository.dart';

final hadithRepositoryProvider = Provider<HadithRepository>((ref) {
  return HadithRepository();
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
