/// Where a hadith text can come from, in the order they are tried.
///
/// The chain is offline-first because it has to be: a citation must render on a
/// train. A numbered citation resolves against the local database, then the
/// bundle, then UmmahAPI, then any separately configured endpoint — and when none
/// of them has it, the screen says the text has not been downloaded instead of
/// pretending the citation is broken.
///
/// [BundledHadithSource] reads `assets/data/hadith/{collection}.json` if such a
/// file exists. None ships today. That is not a stub — it is the drop-in point:
/// put a verified collection file in that folder and every citation to it starts
/// resolving offline, with no code change.
///
/// [UmmahHadithSource] is the live one: it goes through [HadithSearchRepository]
/// so the collection-slug translation and the "not carried" short-circuit live in
/// exactly one place. [RemoteHadithSource] stays behind it, inert unless
/// `HADITH_API_BASE_URL` is set, because a second endpoint remains a legitimate
/// configuration and removing it would be a regression for anyone using it.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/config/hadith_api_config.dart';
import '../../../core/knowledge/hadith_ref.dart';
import 'hadith_record.dart';
import 'hadith_search_repository.dart';

abstract class HadithSource {
  const HadithSource();

  /// The record, or null when this source does not have it. Never throws: a
  /// source that fails is a source that does not have it.
  Future<HadithRecord?> fetch(HadithRef ref);
}

/// Verified collections shipped inside the app.
///
/// Nothing is shipped there today, so this source always misses and the chain
/// falls through to UmmahAPI. It exists so that a collection *can* be shipped —
/// add `assets/data/hadith/{collection}.json`, add the matching
/// `- assets/data/hadith/` line to `pubspec.yaml`, and that collection becomes
/// available with no network at all. The pubspec line is absent on purpose:
/// Flutter fails the build on a declared asset directory that does not exist.
///
/// Expected shape, either form:
///
/// ```json
/// { "3326": { "arabic": "…", "english": "…", "narrator": "…", "book": "…" } }
/// [ { "number": "3326", "arabic": "…", "english": "…" } ]
/// ```
class BundledHadithSource extends HadithSource {
  const BundledHadithSource();

  static const String _dir = 'assets/data/hadith';

  /// collection slug → number → record.
  static final Map<String, Map<String, HadithRecord>> _cache = {};

  /// Collections already looked for and not found, so a missing file is asked
  /// for once per run rather than on every citation.
  static final Set<String> _absent = {};

  @override
  Future<HadithRecord?> fetch(HadithRef ref) async {
    final byNumber = await _load(ref.collection);
    return byNumber?[ref.number];
  }

  static Future<Map<String, HadithRecord>?> _load(String collection) async {
    if (_absent.contains(collection)) return null;
    final cached = _cache[collection];
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString('$_dir/$collection.json');
      final decoded = json.decode(raw);
      final out = <String, HadithRecord>{};

      void add(String? number, Map<String, dynamic> body) {
        if (number == null || number.isEmpty) return;
        final record = HadithRecord.fromJson(
          body,
          collection: collection,
          number: number,
          origin: HadithOrigin.bundled,
        );
        if (record != null) out[number] = record;
      }

      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          if (entry.key.startsWith('_')) continue;
          final value = entry.value;
          if (value is Map<String, dynamic>) add(entry.key, value);
        }
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          final number = item['number'] ?? item['hadith_number'] ?? item['id'];
          add(number?.toString(), item);
        }
      }

      _cache[collection] = out;
      return out;
    } catch (_) {
      // Absent is the normal state right now; there is nothing to warn about.
      _absent.add(collection);
      return null;
    }
  }
}

/// UmmahAPI, through the shared client.
///
/// Thin on purpose. The slug translation, the "not carried" short-circuit and the
/// tolerant field reading all belong to [HadithSearchRepository], which the topic
/// screens use too — so a hadith fetched by citation and a hadith fetched by topic
/// are parsed by the same code and cannot disagree about what a narrator field is
/// called.
class UmmahHadithSource extends HadithSource {
  UmmahHadithSource({HadithSearchRepository? search})
      : _search = search ?? HadithSearchRepository();

  final HadithSearchRepository _search;

  @override
  Future<HadithRecord?> fetch(HadithRef ref) => _search.byRef(ref);
}

/// The configured endpoint, if there is one.
///
/// Inert until `HADITH_API_BASE_URL` is set in `.env` — [HadithApiConfig] decides
/// that, and nothing in the UI changes when it flips. The response parser accepts
/// the field spellings hadith APIs actually use, because the endpoint is the
/// user's choice and its shape is not knowable from here.
class RemoteHadithSource extends HadithSource {
  const RemoteHadithSource({this.client, this.timeout = const Duration(seconds: 12)});

  final http.Client? client;
  final Duration timeout;

  bool get isConfigured => HadithApiConfig.isConfigured;

  @override
  Future<HadithRecord?> fetch(HadithRef ref) async {
    final uri = HadithApiConfig.uriFor(ref.collection, ref.number);
    if (uri == null) return null;

    final owned = client == null;
    final http.Client c = client ?? http.Client();
    try {
      final response =
          await c.get(uri, headers: HadithApiConfig.headers()).timeout(timeout);
      if (response.statusCode != 200) {
        if (kDebugMode) {
          // Host and status only. Never the query string, which can carry a key.
          debugPrint(
            '[hadith] ${uri.host} returned ${response.statusCode} for ${ref.canonical}',
          );
        }
        return null;
      }
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return HadithRecord.fromJson(
        decoded,
        collection: ref.collection,
        number: ref.number,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[hadith] fetch failed for ${ref.canonical}: $e');
      return null;
    } finally {
      if (owned) c.close();
    }
  }
}
