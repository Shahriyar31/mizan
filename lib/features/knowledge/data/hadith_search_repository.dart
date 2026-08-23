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
/// A candidate is judged on the **raw row count**, never on how many rows turned
/// out to be citable. Those are two different questions — "did the service
/// understand the parameter?" and "can we cite what it sent?" — and conflating
/// them is what made every topic report zero: one uncitable payload made all
/// five spellings look wrong, so the loop exhausted and the discovered name was
/// never remembered.
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

import '../../../core/config/ummah_api_config.dart';
import '../../../core/knowledge/hadith_ref.dart';
import '../../../core/network/ummah_api_client.dart';
import 'hadith_record.dart';
import 'hadith_topic.dart';
import 'ummah_hadith_collections.dart';

/// What one search attempt did, stage by stage.
///
/// Kept because "zero narrations" has at least four different causes — the call
/// failed, the service sent no rows, the rows named a collection we could not
/// place, the rows carried no hadith number — and a screen that cannot tell them
/// apart cannot say anything true about which one happened.
class HadithSearchDiagnostics {
  const HadithSearchDiagnostics({
    required this.term,
    required this.queryParam,
    required this.outcome,
    this.status,
    this.rawRows = 0,
    this.droppedNoCollection = 0,
    this.droppedNoNumber = 0,
    this.droppedNoText = 0,
    this.droppedDuplicate = 0,
    this.unresolvedCollections = const {},
    this.records = const [],
  });

  /// The request was never made — an empty term, or no candidate left to try.
  factory HadithSearchDiagnostics.skipped(String term) =>
      HadithSearchDiagnostics(term: term, queryParam: null, outcome: 'skipped');

  factory HadithSearchDiagnostics.failed(
    String term,
    String queryParam,
    UmmahApiException e,
  ) =>
      HadithSearchDiagnostics(
        term: term,
        queryParam: queryParam,
        outcome: e.failure.name,
        status: e.statusCode,
      );

  /// The call succeeded and the body held no rows at all.
  factory HadithSearchDiagnostics.noRows(String term, String queryParam) =>
      HadithSearchDiagnostics(
        term: term,
        queryParam: queryParam,
        outcome: 'ok',
      );

  final String term;

  /// The parameter spelling this attempt used, or null when none was tried.
  final String? queryParam;

  /// `ok`, `skipped`, or the failure name from [UmmahApiFailure].
  final String outcome;

  /// The HTTP status where one was seen. Null on a cache hit or a transport
  /// failure that never got a response.
  final int? status;

  /// Rows in the body before any filtering. The number that decides whether the
  /// parameter spelling was understood.
  final int rawRows;

  final int droppedNoCollection;
  final int droppedNoNumber;
  final int droppedNoText;
  final int droppedDuplicate;

  /// Collection names the rows carried that [UmmahHadithCollections] could not
  /// place. The single most useful thing to read when everything was dropped.
  final Set<String> unresolvedCollections;

  final List<HadithRecord> records;

  bool get ok => outcome == 'ok';

  int get citable => records.length;

  /// The call worked and the service genuinely had nothing for this term.
  bool get serviceReturnedNothing => ok && rawRows == 0;

  /// The service answered with rows and not one of them could be cited. A
  /// different problem, and the only one that is ours to fix.
  bool get allRowsDropped => rawRows > 0 && citable == 0;

  /// One line, safe to log: no key, no URI, no bodies.
  String get summary {
    if (outcome == 'skipped') return 'not attempted';
    if (!ok) return 'FAILED $outcome${status == null ? '' : ' ($status)'}';
    // A cache hit never saw a status, and saying "200" for one would be a small
    // lie in the one place that exists to be trusted.
    final where = status?.toString() ?? '200 or cache';
    if (rawRows == 0) return 'status $where, 0 raw rows';
    final drops = <String>[
      if (droppedNoCollection > 0) 'collection unresolved: $droppedNoCollection',
      if (droppedNoNumber > 0) 'no hadith number: $droppedNoNumber',
      if (droppedNoText > 0) 'no text: $droppedNoText',
      if (droppedDuplicate > 0) 'duplicate: $droppedDuplicate',
    ];
    return 'status $where, $rawRows raw → $citable citable'
        '${drops.isEmpty ? '' : ' (dropped — ${drops.join('; ')})'}'
        '${unresolvedCollections.isEmpty ? '' : ' names seen: ${unresolvedCollections.take(5).join(', ')}'}';
  }
}

/// Every attempt made for one topic, so the screen can name the reason rather
/// than print "Nothing returned" over four different situations.
class HadithTopicOutcome {
  const HadithTopicOutcome({required this.topicId, required this.attempts});

  final String topicId;
  final List<HadithSearchDiagnostics> attempts;

  List<HadithRecord> get records {
    for (final a in attempts) {
      if (a.records.isNotEmpty) return a.records;
    }
    return const [];
  }

  bool get isEmpty => records.isEmpty;

  int get rawRows =>
      attempts.fold(0, (sum, a) => sum + a.rawRows);

  /// True when no attempt reached the service at all.
  bool get unreachable => attempts.isNotEmpty && attempts.every((a) => !a.ok);

  /// True when the service answered and sent rows, but none could be cited.
  bool get droppedEverything => isEmpty && rawRows > 0;

  Set<String> get unresolvedCollections => {
        for (final a in attempts) ...a.unresolvedCollections,
      };
}

/// Mutable tally passed down through the filter stages.
class _Drops {
  int noCollection = 0;
  int noNumber = 0;
  int noText = 0;
  int duplicate = 0;
  final Set<String> unresolvedNames = {};
}

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
    final outcome = await outcomeFor(topic, limit: limit);
    return outcome.records;
  }

  /// [forTopic] with the stage counts kept, so a screen can tell "the service
  /// sent nothing" apart from "the service sent rows we cannot cite" instead of
  /// printing one "Nothing returned" over both.
  Future<HadithTopicOutcome> outcomeFor(HadithTopic topic, {int limit = 40}) async {
    await ensureCatalogue();

    final attempts = <HadithSearchDiagnostics>[];
    for (final term in topic.queries) {
      final attempt = await searchDetailed(term, limit: limit);
      attempts.add(attempt);
      if (attempt.records.isNotEmpty) {
        return HadithTopicOutcome(topicId: topic.id, attempts: attempts);
      }
    }
    return HadithTopicOutcome(topicId: topic.id, attempts: attempts);
  }

  /// One search term. Returns citable records only; never throws.
  Future<List<HadithRecord>> search(String term, {int limit = 40}) async {
    final result = await searchDetailed(term, limit: limit);
    return result.records;
  }

  /// One search term, with what happened at every stage.
  Future<HadithSearchDiagnostics> searchDetailed(
    String term, {
    int limit = 40,
  }) async {
    final query = term.trim();
    if (query.isEmpty) {
      return HadithSearchDiagnostics.skipped(term);
    }

    // Once the parameter name is known, only that one is used.
    final names = _queryParam != null ? [_queryParam!] : _queryParamCandidates;

    HadithSearchDiagnostics? last;
    for (final name in names) {
      final List<Map<String, dynamic>> raw;
      try {
        raw = await _client.fetchList(
          searchPath,
          query: {name: query, 'limit': '$limit'},
          cacheKey: '$searchPath?$name=${_slugForKey(query)}&limit=$limit',
          maxAge: CachePolicy.search,
          nestedKeys: const ['hadiths', 'results', 'data', 'items'],
          // A search that answered with nothing must not be remembered for
          // twelve hours: it would keep the screen empty long after whatever
          // caused it was fixed.
          cacheEmpty: false,
        );
      } on UmmahApiException catch (e) {
        last = HadithSearchDiagnostics.failed(term, name, e);
        _log(last);
        continue;
      }

      // The parameter is judged here, on the raw rows, and nowhere else. A
      // payload we cannot cite still proves the service understood the
      // parameter, so the name is remembered either way and the citability
      // question is answered separately below.
      if (raw.isEmpty) {
        last = HadithSearchDiagnostics.noRows(term, name);
        _log(last);
        continue;
      }

      _queryParam = name;
      final drops = _Drops();
      final records = _recordsFrom(raw, drops);
      last = HadithSearchDiagnostics(
        term: term,
        queryParam: name,
        outcome: 'ok',
        rawRows: raw.length,
        droppedNoCollection: drops.noCollection,
        droppedNoNumber: drops.noNumber,
        droppedNoText: drops.noText,
        droppedDuplicate: drops.duplicate,
        unresolvedCollections: drops.unresolvedNames,
        records: records,
      );
      _log(last);
      return last;
    }

    return last ?? HadithSearchDiagnostics.skipped(term);
  }

  /// The request line, the status, the raw row count and what each filter stage
  /// removed. Host and path only — never the key, never the full URI, matching
  /// the rule [UmmahApiConfig] states and `RemoteHadithSource` follows.
  static void _log(HadithSearchDiagnostics d) {
    if (!kDebugMode) return;
    final host = Uri.parse(UmmahApiConfig.baseUrl).host;
    debugPrint('[hadith-search] $host$searchPath param=${d.queryParam ?? '-'} '
        'term="${d.term}" → ${d.summary}');
  }

  /// Turns a raw search payload into records, dropping anything uncitable and
  /// recording why in [drops].
  List<HadithRecord> _recordsFrom(
    List<Map<String, dynamic>> raw,
    _Drops drops,
  ) {
    final out = <HadithRecord>[];
    final seen = <String>{};

    for (final item in raw) {
      final slug = _collectionSlugFrom(item, drops);
      if (slug == null) {
        drops.noCollection++;
        continue;
      }

      final number = _numberFrom(item);
      if (number == null) {
        drops.noNumber++;
        continue;
      }

      final record = HadithRecord.fromJson(
        item,
        collection: slug,
        number: number,
      );
      if (record == null || !record.hasText) {
        drops.noText++;
        continue;
      }

      final key = record.ref.canonical;
      if (!seen.add(key)) {
        drops.duplicate++;
        continue;
      }
      out.add(record);
    }

    out.sort((a, b) => a.ref.compareTo(b.ref));
    return out;
  }

  /// Our slug for whichever field this row names its collection in.
  ///
  /// Every candidate is tried rather than only the first one present, because a
  /// row that carries both `book: 'Book of Faith'` and `source: 'bukhari'` has
  /// the collection in the second field, and stopping at the first non-empty
  /// string would drop the row.
  static String? _collectionSlugFrom(Map<String, dynamic> row, _Drops drops) {
    String? sawRaw;
    for (final name in _collectionFields) {
      final value = _fieldAt(row, name);
      if (value == null) continue;
      sawRaw ??= value;
      final slug = UmmahHadithCollections.appSlugFor(value);
      if (slug != null) return slug;
    }
    if (sawRaw != null) drops.unresolvedNames.add(sawRaw);
    return null;
  }

  /// The hadith number, or null.
  ///
  /// `id` is intentionally absent and stays absent: it is a row identifier on
  /// some services, and a row identifier printed as a hadith number is a false
  /// citation. The names below are matched case- and separator-insensitively, so
  /// `hadithNumber`, `hadith_number` and `hadithnumber` are one name rather than
  /// three spellings to guess at.
  static String? _numberFrom(Map<String, dynamic> row) {
    for (final name in _numberFields) {
      final value = _fieldAt(row, name);
      if (value != null) return value;
    }
    return null;
  }

  static const List<String> _collectionFields = [
    'collection',
    'collection_name',
    'collection_slug',
    'book_slug',
    'source',
    'collection_id',
    'book',
  ];

  static const List<String> _numberFields = [
    'number',
    'hadith_number',
    'hadith_no',
    'hadith_num',
    'reference_number',
    'number_in_book',
  ];

  /// Reads one field by *normalised* name: keys are compared lower-cased with
  /// separators stripped, so a payload's own casing is not a thing we have to
  /// have guessed correctly in advance.
  static String? _fieldAt(Map<String, dynamic> row, String name) {
    final wanted = _normaliseKey(name);
    for (final key in row.keys) {
      if (_normaliseKey(key) != wanted) continue;
      final value = UmmahApiClient.stringAt(row, [key]);
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _normaliseKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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
