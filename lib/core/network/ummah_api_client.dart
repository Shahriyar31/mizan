/// UmmahApiClient — every UmmahAPI request in the app goes through this.
///
/// It exists to hold four behaviours that would otherwise be copied into the
/// audio, tafsir, mutashabihat and hadith repositories in four slightly different
/// and slowly diverging forms:
///
///  1. **Envelope unwrapping.** Responses are documented as
///     `{success, service, data, timestamp}`, so `data` is what a caller wants and
///     `success == false` is the error branch rather than a status code. The
///     unwrapping is deliberately forgiving — if a payload arrives without the
///     envelope, the body itself is returned instead of throwing, because a shape
///     that differs from the documentation should degrade to "still works" rather
///     than "shows nothing".
///
///  2. **Cache first, then network, then stale.** A fresh cache hit never touches
///     the network. A network failure falls back to a *stale* cache entry rather
///     than an error, because a month-old tafsir passage is still the same tafsir
///     passage and refusing to show it on a train is a worse outcome than showing
///     it late. This is the whole offline story: anything read once stays readable.
///
///  3. **One retry, then stop.** Transient failures — a timeout, a 5xx, a dropped
///     socket — get exactly one more attempt after a short pause. A 404 or a 400
///     gets none, because retrying a well-answered "no" is just latency.
///
///  4. **Safe logging.** The key travels in a header and never in the URI, so the
///     path can be logged freely. Bodies are never logged: they are large, and a
///     truncated hadith in a log line is no use to anybody.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../services/cache/api_cache.dart';
import '../config/ummah_api_config.dart';

enum UmmahApiFailure {
  /// No connection, DNS failure, dropped socket.
  network,
  timeout,

  /// A 4xx or 5xx that survived the retry.
  http,

  /// 200, but the body was not JSON or not a shape we can use.
  malformed,

  /// 200 and valid JSON, but `success: false`.
  api,
}

class UmmahApiException implements Exception {
  const UmmahApiException(this.failure, this.path, {this.statusCode, this.detail});

  final UmmahApiFailure failure;

  /// Path only, never the full URI and never the key.
  final String path;
  final int? statusCode;
  final String? detail;

  /// True when trying again later might plausibly work — used to decide whether a
  /// screen offers "retry" or states a flat "not available".
  bool get isTransient =>
      failure == UmmahApiFailure.network ||
      failure == UmmahApiFailure.timeout ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() =>
      'UmmahApiException(${failure.name}, $path'
      '${statusCode == null ? '' : ', $statusCode'}'
      '${detail == null ? '' : ', $detail'})';
}

/// How long a cached payload counts as fresh.
///
/// These are content-shaped rather than uniform. Tafsir, word-by-word and
/// mutashabihat are scholarly texts that do not change, so they are cached
/// effectively forever and re-fetched only if the cache is cleared. Reciter and
/// collection lists are catalogues that can gain entries, so they refresh weekly.
class CachePolicy {
  const CachePolicy._();

  /// Fixed texts: tafsir passages, word analyses, similar-verse pairs, hadith.
  static const Duration immutable = Duration(days: 365);

  /// Catalogues: reciters, tafsir sources, hadith collections.
  static const Duration catalogue = Duration(days: 7);

  /// Search results — a query's answer can change as the index grows, and a
  /// stale search is more confusing than a slow one.
  static const Duration search = Duration(hours: 12);
}

class UmmahApiClient {
  UmmahApiClient({
    http.Client? httpClient,
    ApiCache? cache,
    this.timeout = const Duration(seconds: 15),
  })  : _ownsClient = httpClient == null,
        _http = httpClient ?? http.Client(),
        _cache = cache ?? ApiCache.instance;

  static final UmmahApiClient instance = UmmahApiClient();

  static const String _tag = 'ummah-api';

  final http.Client _http;
  final bool _ownsClient;
  final ApiCache _cache;
  final Duration timeout;

  /// In-flight requests keyed by cache key, so eight evidence rows opening at
  /// once make one request rather than eight.
  final Map<String, Future<Object?>> _inflight = {};

  void dispose() {
    if (_ownsClient) _http.close();
  }

  // ── The one entry point ─────────────────────────────────────────────

  /// Fetches [path] and returns the unwrapped `data`, which is a `Map` or a
  /// `List` depending on the endpoint.
  ///
  /// [cacheKey] must identify the request completely — path plus every query
  /// parameter that changes the answer — because it is the filename the payload
  /// is stored under. Passing null disables caching for that call.
  Future<Object?> fetch(
    String path, {
    Map<String, String>? query,
    String? cacheKey,
    Duration maxAge = CachePolicy.immutable,

    /// When true, a stale cache entry is returned immediately and no network
    /// request is made at all. Used by the offline reading mode.
    bool offlineOnly = false,
  }) async {
    final key = cacheKey ?? _keyFor(path, query);

    final fresh = await _cache.read(key, maxAge: maxAge);
    if (fresh != null) return fresh;

    if (offlineOnly) return _cache.read(key);

    final running = _inflight[key];
    if (running != null) return running;

    final future = _fetchNetwork(path, query, key).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  Future<Object?> _fetchNetwork(
    String path,
    Map<String, String>? query,
    String cacheKey,
  ) async {
    UmmahApiException? failure;

    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt == 1) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      try {
        final data = await _attempt(path, query);
        await _cache.write(cacheKey, data);
        return data;
      } on UmmahApiException catch (e) {
        failure = e;
        if (!e.isTransient) break;
      }
    }

    // The point of the cache: a failed refresh is not a failed read.
    final stale = await _cache.read(cacheKey);
    if (stale != null) {
      if (kDebugMode) {
        debugPrint('[$_tag] $path failed (${failure?.failure.name}); '
            'served stale cache');
      }
      return stale;
    }

    throw failure ??
        UmmahApiException(UmmahApiFailure.network, path);
  }

  Future<Object?> _attempt(String path, Map<String, String>? query) async {
    final uri = UmmahApiConfig.uri(path, query);
    http.Response response;
    try {
      response = await _http
          .get(uri, headers: UmmahApiConfig.headers())
          .timeout(timeout);
    } on TimeoutException {
      throw UmmahApiException(UmmahApiFailure.timeout, path);
    } on SocketException catch (e) {
      throw UmmahApiException(UmmahApiFailure.network, path, detail: e.osError?.message);
    } on http.ClientException catch (e) {
      throw UmmahApiException(UmmahApiFailure.network, path, detail: e.message);
    }

    if (response.statusCode != 200) {
      throw UmmahApiException(
        UmmahApiFailure.http,
        path,
        statusCode: response.statusCode,
      );
    }

    Object? decoded;
    try {
      decoded = json.decode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw UmmahApiException(UmmahApiFailure.malformed, path);
    }

    return _unwrap(decoded, path);
  }

  /// Pulls `data` out of the documented envelope.
  ///
  /// Tolerant on purpose. `success: false` is a real error and is reported as
  /// one, but a body that simply has no envelope is passed through — the
  /// documented shape is a promise about today, and a client that hard-fails the
  /// moment a field is renamed is a client that breaks on somebody else's
  /// deployment.
  static Object? _unwrap(Object? decoded, String path) {
    if (decoded is List) return decoded;
    if (decoded is! Map) {
      throw UmmahApiException(UmmahApiFailure.malformed, path);
    }

    final map = decoded.cast<String, dynamic>();
    final success = map['success'];
    if (success == false) {
      final detail = map['error'] ?? map['message'];
      throw UmmahApiException(
        UmmahApiFailure.api,
        path,
        detail: detail is String ? detail : null,
      );
    }

    final data = map['data'];
    if (data is Map || data is List) return data;

    // No envelope, or `data` holds a scalar. Either way the body is the payload.
    return map;
  }

  static String _keyFor(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final parts = query.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
    return '$path?${parts.join('&')}';
  }

  // ── Typed conveniences ──────────────────────────────────────────────

  /// A `Map` payload, or null when the endpoint answered with something else.
  /// Never throws for shape — callers treat null as "not available".
  Future<Map<String, dynamic>?> fetchMap(
    String path, {
    Map<String, String>? query,
    String? cacheKey,
    Duration maxAge = CachePolicy.immutable,
    bool offlineOnly = false,
  }) async {
    final data = await fetch(path,
        query: query, cacheKey: cacheKey, maxAge: maxAge, offlineOnly: offlineOnly);
    if (data is Map) return data.cast<String, dynamic>();
    // Some endpoints answer with a single-element list where a map was expected.
    if (data is List && data.length == 1 && data.first is Map) {
      return (data.first as Map).cast<String, dynamic>();
    }
    return null;
  }

  /// A `List` payload. Handles the common case of a list nested one level deeper
  /// than expected — `data: {reciters: [...]}` — by looking for the first list
  /// value when [nestedKeys] are given.
  Future<List<Map<String, dynamic>>> fetchList(
    String path, {
    Map<String, String>? query,
    String? cacheKey,
    Duration maxAge = CachePolicy.immutable,
    bool offlineOnly = false,
    List<String> nestedKeys = const [],
  }) async {
    final data = await fetch(path,
        query: query, cacheKey: cacheKey, maxAge: maxAge, offlineOnly: offlineOnly);
    return listFrom(data, nestedKeys: nestedKeys);
  }

  /// Extracts a list of maps from whatever shape arrived.
  ///
  /// Public and static because the same tolerance is needed when digging into a
  /// nested field of an already-fetched payload, and one implementation of
  /// "find the list" is better than five.
  static List<Map<String, dynamic>> listFrom(
    Object? data, {
    List<String> nestedKeys = const [],
  }) {
    if (data is List) {
      return [
        for (final item in data)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      for (final key in nestedKeys) {
        final value = map[key];
        if (value is List) return listFrom(value);
      }
      // Fall back to the first list-valued field, which is how these payloads
      // are almost always shaped even when the field name is a surprise.
      for (final value in map.values) {
        if (value is List && value.isNotEmpty && value.first is Map) {
          return listFrom(value);
        }
      }
    }
    return const [];
  }

  /// Reads a string from the first key present, trying several spellings.
  ///
  /// Field names across these endpoints are not knowable from the PDF, which
  /// documents paths but no schemas. Rather than guess one spelling and render an
  /// empty screen when it is wrong, every plausible spelling is tried.
  static String? stringAt(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return null;
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
      if (value is Map) {
        for (final inner in const ['text', 'value', 'name', 'en', 'english']) {
          final v = value[inner];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
        if (first is Map) {
          for (final inner in const ['text', 'value', 'name', 'grade']) {
            final v = first[inner];
            if (v is String && v.trim().isNotEmpty) return v.trim();
          }
        }
      }
    }
    return null;
  }

  static int? intAt(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return null;
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
