// ─────────────────────────────────────────────────────────────────────────────
// discover_repository.dart
// Loads JSON content from assets, caches in memory.
// Single source of truth for all Discover content.
//
// Scale note: at full content (25 prophets + 100 sahabah + 99 names + seerah)
// this is ~230 asset reads. They are loaded with Future.wait so the platform
// channel pipelines them instead of doing one round-trip at a time, and the
// parsed result is cached for the process lifetime. Riverpod rebuilds must
// never trigger a reload — call clearCache() explicitly if content changes.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/discover_models.dart';

class DiscoverRepository {
  // ── In-memory cache ────────────────────────────────────────────────────────
  static List<ProphetEntry>? _prophets;
  static List<SahabiEntry>? _sahabah;
  static List<DivineName>? _names;
  static List<SeerahEntry>? _seerah;

  // In-flight futures: if two providers ask at once we must not run the whole
  // load twice — both await the same Future.
  static Future<List<ProphetEntry>>? _prophetsFuture;
  static Future<List<SahabiEntry>>? _sahabahFuture;
  static Future<List<DivineName>>? _namesFuture;
  static Future<List<SeerahEntry>>? _seerahFuture;

  // ── Generic loader ─────────────────────────────────────────────────────────

  /// Reads `<folder>/index.json` (an array of filenames), loads every file in
  /// parallel and maps it through [fromJson]. A single malformed file is
  /// skipped and reported in debug rather than taking down the whole section.
  static Future<List<T>> _loadFolder<T>(
    String folder,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final base = 'assets/data/discover/$folder';
    final indexRaw = await rootBundle.loadString('$base/index.json');
    final filenames = (json.decode(indexRaw) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    final raws = await Future.wait(
      filenames.map((f) => rootBundle.loadString('$base/$f')),
    );

    final entries = <T>[];
    for (var i = 0; i < raws.length; i++) {
      try {
        entries.add(fromJson(json.decode(raws[i]) as Map<String, dynamic>));
      } catch (e) {
        assert(() {
          debugPrint('Discover: skipped $base/${filenames[i]} — $e');
          return true;
        }());
      }
    }
    return entries;
  }

  // ── Prophets ───────────────────────────────────────────────────────────────

  static Future<List<ProphetEntry>> getProphets() {
    if (_prophets != null) return Future.value(_prophets!);
    return _prophetsFuture ??= _loadFolder(
      'prophets',
      ProphetEntry.fromJson,
    ).then((entries) {
      entries.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      _prophets = entries;
      _prophetsFuture = null;
      return entries;
    });
  }

  static Future<ProphetEntry?> getProphetById(String id) async {
    final all = await getProphets();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── Sahabah ────────────────────────────────────────────────────────────────

  static Future<List<SahabiEntry>> getSahabah() {
    if (_sahabah != null) return Future.value(_sahabah!);
    return _sahabahFuture ??= _loadFolder(
      'sahabah',
      SahabiEntry.fromJson,
    ).then((entries) {
      entries.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      _sahabah = entries;
      _sahabahFuture = null;
      return entries;
    });
  }

  static Future<SahabiEntry?> getSahabiById(String id) async {
    final all = await getSahabah();
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── 99 Names ───────────────────────────────────────────────────────────────

  static Future<List<DivineName>> getNames() {
    if (_names != null) return Future.value(_names!);
    return _namesFuture ??= _loadFolder(
      'names',
      DivineName.fromJson,
    ).then((entries) {
      entries.sort((a, b) => a.number.compareTo(b.number));
      _names = entries;
      _namesFuture = null;
      return entries;
    });
  }

  static Future<DivineName?> getNameById(String id) async {
    final all = await getNames();
    for (final n in all) {
      if (n.id == id) return n;
    }
    return null;
  }

  // ── Seerah ─────────────────────────────────────────────────────────────────

  static Future<List<SeerahEntry>> getSeerah() {
    if (_seerah != null) return Future.value(_seerah!);
    return _seerahFuture ??= _loadFolder(
      'seerah',
      SeerahEntry.fromJson,
    ).then((entries) {
      entries.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      _seerah = entries;
      _seerahFuture = null;
      return entries;
    });
  }

  static Future<SeerahEntry?> getSeerahById(String id) async {
    final all = await getSeerah();
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Clears in-memory cache (useful for hot reload in dev, or after content
  /// files are regenerated). Every cached list must be listed here.
  static void clearCache() {
    _prophets = null;
    _sahabah = null;
    _names = null;
    _seerah = null;
    _prophetsFuture = null;
    _sahabahFuture = null;
    _namesFuture = null;
    _seerahFuture = null;
  }
}
