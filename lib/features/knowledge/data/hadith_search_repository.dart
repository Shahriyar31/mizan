/// Topic search over the hadith collections.
///
/// This is the engine behind topic-based discovery: a topic is a set of search
/// terms, and this repository turns terms into citable records. Three things in
/// here are worth knowing before changing it.
///
/// **The query parameter name is not documented.** The PDF gives the path
/// `/api/hadith/search` and no parameter names, so the name is *discovered*: `q`
/// is tried first, then the four other spellings these services use, and the one
/// that answers is remembered for the rest of the session. Discovery costs at
/// most four extra requests once, ever — and it is the alternative to shipping a
/// guess that silently returns nothing.
///
/// **A result without a resolvable collection and number is dropped.** Not shown
/// without a citation, not given a made-up one. A hadith the reader cannot check
/// is exactly what the Citation Lock exists to prevent, and search payloads do
/// sometimes carry a database `id` where a hadith number should be — binding that
/// to "Sahih al-Bukhari 84712" would be a fabricated reference, so `id` is
/// deliberately not among the accepted number fields.
///
/// **Results are cached like searches, not like texts.** Twelve hours: the index
/// can grow, and a stale result list is more confusing than a slow one. The
/// individual hadith texts that come back are handed to [HadithRepository] and
/// cached there as immutable, because a hadith's text does not change even when
/// the search that found it does.
library;

import 'package:flutter/foundation.dart';

import '../../../core/knowledge/hadith_ref.dart';
import '../../../core/network/ummah_api_client.dart';
import 'hadith_record.dart';
import 'hadith_topic.dart';
import 'ummah_hadith_collections.dart';

class HadithSearchRepository {
  HadithSearchRepository({UmmahApiClient? client})
      : _client = client ?? UmmahApiClient.instance;

  final UmmahApiClient _client;

  static const String searchPath = '/api/hadith/search';

  /// Spellings to try, best guess first.
  static const List<String> _queryParamCandidates = [
    'q',
    'query',
    'keyword',
    'search',
    'text',
  ];

  /// The spelling that worked, remembered for the session. Static so every
  /// topic search after the first one goes straight to the right parameter.
  static String? _queryParam;

  static String? get discoveredQueryParam => _queryParam;

  // ── Catalogue ───────────────────────────────────────────────────────

  /// Fetches the collection catalogue once and teaches
  /// [UmmahHadithCollections] the API's own slugs.
  ///
  /// Failure is not an error: [UmmahHadithCollections.apiSlugFor] falls back to
  /// its candidate spellings, so hadith fetching works whether or not this
  /// succeeds.
  Future<void> ensureCatalogue() async {
    if (UmmahHadithCollections.catalogueSeen) return;
    try {
      final list = await _client.fetchList(
        UmmahHadithCollections.collectionsPath,
        maxAge: CachePolicy.catalogue,
        nestedKeys: const ['collections', 'data', 'items'],
      );
      UmmahHadithCollections.learn(list);
    } on UmmahApiException catch (e) {
      if (kDebugMode) debugPrint('[hadith] catalogue unavailable: $e');
      UmmahHadithCollections.learn(const []);
    }
  }

  // ── Search ──────────────────────────────────────────────────────────

  /// Every hadith the service returns for [topic], first term that yields any.
  ///
  /// The terms are tried in order rather than merged, because a merged result set
  /// would have to be re-ranked by us — and "which hadith is most about
  /// patience" is a judgement we are not sourced to make. The collection's own
  /// ordering, for the term that matched, is the honest answer.
  Future<List<HadithRecord>> forTopic(HadithTopic topic, {int limit = 40}) async {
    await ensureCatalogue();
    for (final term in topic.queries) {
      final results = await search(term, limit: limit);
      if (results.isNotEmpty) return results;
    }
    return const [];
  }

  /// One search term. Returns citable records only; never throws.
  Future<List<HadithRecord>> search(String term, {int limit = 40}) async {
    final query = term.trim();
    if (query.isEmpty) return const [];

    // Once the parameter name is known, only that one is used.
    final names = _queryParam != null ? [_queryParam!] : _queryParamCandidates;

    for (final name in names) {
      final List<Map<String, dynamic>> raw;
      try {
        raw = await _client.fetchList(
          searchPath,
          query: {name: query, 'limit': '$limit'},
          cacheKey: '$searchPath?$name=${_slugForKey(query)}&limit=$limit',
          maxAge: CachePolicy.search,
          nestedKeys: const ['hadiths', 'results', 'data', 'items'],
        );
      } on UmmahApiException catch (e) {
        if (kDebugMode) {
          debugPrint('[hadith] search "$name" failed: ${e.failure.name}');
        }
        continue;
      }

      final records = _recordsFrom(raw);
      if (records.isEmpty) continue;

      _queryParam = name;
      return records;
    }

    return const [];
  }

  /// Turns a raw search payload into records, dropping anything uncitable.
  List<HadithRecord> _recordsFrom(List<Map<String, dynamic>> raw) {
    final out = <HadithRecord>[];
    final seen = <String>{};

    for (final item in raw) {
      final apiCollection = UmmahApiClient.stringAt(item, const [
        'collection',
        'collection_id',
        'collectionName',
        'book_slug',
        'bookSlug',
        'source',
      ]);
      final slug = UmmahHadithCollections.appSlugFor(apiCollection);
      if (slug == null) continue;

      // `id` is intentionally absent: it is a row identifier on some services,
      // and a row identifier printed as a hadith number is a false citation.
      final number = UmmahApiClient.stringAt(item, const [
        'number',
        'hadith_number',
        'hadithNumber',
        'hadith_no',
        'hadithNo',
        'reference_number',
      ]);
      if (number == null || number.trim().isEmpty) continue;

      final record = HadithRecord.fromJson(
        item,
        collection: slug,
        number: number.trim(),
      );
      if (record == null || !record.hasText) continue;

      final key = record.ref.canonical;
      if (!seen.add(key)) continue;
      out.add(record);
    }

    out.sort((a, b) => a.ref.compareTo(b.ref));
    return out;
  }

  /// A cache key fragment that is safe as a filename.
  static String _slugForKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  // ── One hadith, by reference ────────────────────────────────────────

  /// `/api/hadith/{collection}/{number}` — used by [UmmahHadithSource].
  ///
  /// Returns null without making a request when the collection is one UmmahAPI
  /// does not carry, which is the difference between a quiet miss and a page of
  /// 404s for a story citing Musnad Ahmad eight times.
  Future<HadithRecord?> byRef(HadithRef ref) async {
    final apiSlug = UmmahHadithCollections.apiSlugFor(ref.collection);
    if (apiSlug == null) return null;

    final path = '/api/hadith/$apiSlug/${Uri.encodeComponent(ref.number)}';
    try {
      final map = await _client.fetchMap(path, maxAge: CachePolicy.immutable);
      if (map == null) return null;
      return HadithRecord.fromJson(
        map,
        collection: ref.collection,
        number: ref.number,
      );
    } on UmmahApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[hadith] ${ref.canonical} unavailable: ${e.failure.name}');
      }
      return null;
    }
  }
}
