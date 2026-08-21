// ─────────────────────────────────────────────────────────────────────────────
// discover_repository.dart
// Loads JSON content from assets, caches in memory.
// Single source of truth for all Discover content.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/discover_models.dart';

class DiscoverRepository {
  // ── In-memory cache ────────────────────────────────────────────────────────
  static List<ProphetEntry>? _prophets;
  static List<SahabiEntry>? _sahabah;
  static List<DivineName>? _names;

  // ── Prophets ───────────────────────────────────────────────────────────────

  static Future<List<ProphetEntry>> getProphets() async {
    if (_prophets != null) return _prophets!;

    final String raw =
        await rootBundle.loadString('assets/data/discover/prophets/index.json');
    final List<dynamic> jsonList = json.decode(raw) as List<dynamic>;

    // index.json contains array of filenames: ["adam.json", "ibrahim.json", ...]
    // Each file is a full ProphetEntry JSON.
    final List<ProphetEntry> entries = [];
    for (final filename in jsonList) {
      final String entryRaw = await rootBundle.loadString(
          'assets/data/discover/prophets/$filename');
      final Map<String, dynamic> entryJson =
          json.decode(entryRaw) as Map<String, dynamic>;
      entries.add(ProphetEntry.fromJson(entryJson));
    }

    // Sort by sequenceNumber ascending
    entries.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    _prophets = entries;
    return _prophets!;
  }

  static Future<ProphetEntry?> getProphetById(String id) async {
    final all = await getProphets();
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Sahabah ────────────────────────────────────────────────────────────────

  static Future<List<SahabiEntry>> getSahabah() async {
    if (_sahabah != null) return _sahabah!;

    final String raw = await rootBundle
        .loadString('assets/data/discover/sahabah/index.json');
    final List<dynamic> jsonList = json.decode(raw) as List<dynamic>;

    final List<SahabiEntry> entries = [];
    for (final filename in jsonList) {
      final String entryRaw = await rootBundle.loadString(
          'assets/data/discover/sahabah/$filename');
      final Map<String, dynamic> entryJson =
          json.decode(entryRaw) as Map<String, dynamic>;
      entries.add(SahabiEntry.fromJson(entryJson));
    }

    entries.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    _sahabah = entries;
    return _sahabah!;
  }

  // ── 99 Names ───────────────────────────────────────────────────────────────

  static Future<List<DivineName>> getNames() async {
    _names = null; // Always reload to pick up new files

    final String raw =
        await rootBundle.loadString('assets/data/discover/names/index.json');
    final List<dynamic> jsonList = json.decode(raw) as List<dynamic>;

    final List<DivineName> entries = [];
    for (final filename in jsonList) {
      final String entryRaw =
          await rootBundle.loadString('assets/data/discover/names/$filename');
      final Map<String, dynamic> entryJson =
          json.decode(entryRaw) as Map<String, dynamic>;
      entries.add(DivineName.fromJson(entryJson));
    }

    entries.sort((a, b) => a.number.compareTo(b.number));
    _names = entries;
    return _names!;
  }

  static Future<DivineName?> getNameById(String id) async {
    final all = await getNames();
    try {
      return all.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clears in-memory cache (useful for hot reload in dev)

  static List<SeerahEntry>? _seerah;

  static Future<List<SeerahEntry>> getSeerah() async {
    _seerah = null; // Always reload
    final indexJson =
        await rootBundle.loadString('assets/data/discover/seerah/index.json');
    final List<String> filenames =
        List<String>.from(jsonDecode(indexJson));
    final entries = <SeerahEntry>[];
    for (final filename in filenames) {
      try {
        final raw = await rootBundle
            .loadString('assets/data/discover/seerah/$filename');
        entries.add(SeerahEntry.fromJson(jsonDecode(raw)));
      } catch (e) {
        // Skip malformed files
      }
    }
    _seerah = entries;
    return _seerah!;
  }

  static Future<SeerahEntry?> getSeerahById(String id) async {
    final all = await getSeerah();
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static void clearCache() {
    _prophets = null;
    _sahabah = null;
    _names = null;
  }
}
