/// ApiCache — every JSON payload the app has ever fetched, kept on the device.
///
/// One generic table rather than a typed table per feature. Tafsir passages,
/// word-by-word analyses, similar-verse pairs, reciter catalogues and Quran text
/// are all "a JSON document identified by a request", and giving each its own
/// schema would mean five migrations, five DAOs and five subtly different
/// staleness rules for no gain — nothing in the app queries *inside* a cached
/// payload, it only asks for it whole.
///
/// This is what makes offline reading true rather than aspirational: the client
/// writes here on every successful fetch and reads here before every request, so
/// anything read once is readable forever, and a failed refresh falls back to the
/// stored copy instead of an error state.
///
/// The key is a request path with its query string. It never contains the API key,
/// because the key travels as a header — see [UmmahApiConfig].
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';

class ApiCache {
  ApiCache({DatabaseService? database}) : _db = database ?? DatabaseService.instance;

  static final ApiCache instance = ApiCache();

  static const String table = 'api_cache';

  final DatabaseService _db;

  /// Decoded payloads for this session. Ten widgets asking for the same tafsir in
  /// one frame should decode the JSON once, not ten times.
  final Map<String, _Entry> _memory = {};

  /// Keys confirmed absent, so a miss does not re-query SQLite on every rebuild.
  final Set<String> _absent = {};

  // ── Read ────────────────────────────────────────────────────────────

  /// The payload for [key], or null.
  ///
  /// With [maxAge] the entry must be that fresh or newer; without it, any stored
  /// copy will do — which is the "serve stale rather than fail" path and the
  /// offline reading path.
  Future<Object?> read(String key, {Duration? maxAge}) async {
    final held = _memory[key];
    if (held != null) {
      if (maxAge == null || held.isFresherThan(maxAge)) return held.payload;
      return null;
    }
    if (_absent.contains(key)) return null;

    try {
      final db = await _db.database;
      final rows = await db.query(
        table,
        columns: const ['payload', 'fetched_at'],
        where: 'cache_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) {
        _absent.add(key);
        return null;
      }
      final fetchedAt = DateTime.tryParse(rows.first['fetched_at'] as String? ?? '');
      final decoded = json.decode(rows.first['payload'] as String);
      final entry = _Entry(decoded, fetchedAt ?? DateTime.now());
      _memory[key] = entry;
      if (maxAge != null && !entry.isFresherThan(maxAge)) return null;
      return entry.payload;
    } catch (_) {
      // A cache that cannot be read is a slow app, not a broken one.
      return null;
    }
  }

  /// When [key] was last written, or null if never. Shown on screens that say
  /// "saved on this device" so the offline state is legible.
  Future<DateTime?> fetchedAt(String key) async {
    final held = _memory[key];
    if (held != null) return held.fetchedAt;
    try {
      final db = await _db.database;
      final rows = await db.query(table,
          columns: const ['fetched_at'],
          where: 'cache_key = ?',
          whereArgs: [key],
          limit: 1);
      if (rows.isEmpty) return null;
      return DateTime.tryParse(rows.first['fetched_at'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  // ── Write ───────────────────────────────────────────────────────────

  Future<void> write(String key, Object? payload) async {
    if (payload == null) return;
    final now = DateTime.now();
    _memory[key] = _Entry(payload, now);
    _absent.remove(key);
    try {
      final db = await _db.database;
      await db.insert(
        table,
        {
          'cache_key': key,
          'payload': json.encode(payload),
          'fetched_at': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Kept in memory for this session even if the write failed.
    }
  }

  // ── Housekeeping, surfaced in Settings ──────────────────────────────

  Future<int> count() async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Total stored payload size in bytes. `length(payload)` counts characters of
  /// the stored TEXT, which for the Arabic in these payloads under-reports the
  /// byte count — it is a size indicator for a settings row, not an accounting
  /// figure, and it is labelled as approximate where it is shown.
  Future<int> approximateBytes() async {
    try {
      final db = await _db.database;
      final rows =
          await db.rawQuery('SELECT SUM(LENGTH(payload)) AS b FROM $table');
      return (rows.first['b'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// How many entries match a prefix — "how much tafsir have I saved?" is
  /// `countWithPrefix('/api/tafsir')`.
  Future<int> countWithPrefix(String prefix) async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table WHERE cache_key LIKE ?',
        ['$prefix%'],
      );
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    _memory.clear();
    _absent.clear();
    try {
      final db = await _db.database;
      await db.delete(table);
    } catch (_) {
      // Nothing to do.
    }
  }

  Future<void> clearPrefix(String prefix) async {
    _memory.removeWhere((k, _) => k.startsWith(prefix));
    _absent.removeWhere((k) => k.startsWith(prefix));
    try {
      final db = await _db.database;
      await db.delete(table, where: 'cache_key LIKE ?', whereArgs: ['$prefix%']);
    } catch (_) {
      // Nothing to do.
    }
  }
}

class _Entry {
  _Entry(this.payload, this.fetchedAt);

  final Object? payload;
  final DateTime fetchedAt;

  bool isFresherThan(Duration maxAge) =>
      DateTime.now().difference(fetchedAt) <= maxAge;
}
