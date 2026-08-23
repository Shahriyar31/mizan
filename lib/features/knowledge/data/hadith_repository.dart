/// HadithRepository — one place that answers "what is the text of this hadith?"
///
/// Lookup order: memory → local database → bundle → network. The first three
/// need no connection, so a citation that has ever been resolved stays resolved
/// forever. A miss is remembered too (for the session only), so a citation the
/// app cannot resolve does not re-hit the network every time a screen rebuilds.
///
/// Nothing here throws. A hadith is either available or it is not, and the screen
/// says which — an error dialog over a citation would be noise.
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/knowledge/hadith_ref.dart';
import '../../../services/database/database_service.dart';
import 'hadith_record.dart';
import 'hadith_source.dart';

class HadithRepository {
  HadithRepository({
    HadithSource? bundled,
    HadithSource? ummah,
    HadithSource? remote,
    DatabaseService? database,
  })  : _bundled = bundled ?? const BundledHadithSource(),
        _ummah = ummah ?? UmmahHadithSource(),
        _remote = remote ?? const RemoteHadithSource(),
        _db = database ?? DatabaseService.instance;

  static const String table = 'hadith_cache';

  /// Personal reflections on a hadith. Separate table from the ayah
  /// `reflections` one, because a hadith is keyed by collection and number and
  /// squeezing that into two integer columns would be a lie about the schema.
  static const String reflectionTable = 'hadith_reflections';

  final HadithSource _bundled;
  final HadithSource _ummah;
  final HadithSource _remote;
  final DatabaseService _db;

  final Map<String, HadithRecord> _memory = {};

  /// Refs looked for and not found anywhere, this session only. Not persisted:
  /// tomorrow the endpoint may be configured, or a collection file added.
  final Set<String> _missing = {};

  /// In-flight fetches, so ten evidence rows citing Bukhari 3326 make one request.
  final Map<String, Future<HadithRecord?>> _inflight = {};

  // ── Reads ───────────────────────────────────────────────────────────

  /// Whatever is already available without touching the network.
  HadithRecord? cached(HadithRef ref) => _memory[ref.canonical];

  bool isKnownMissing(HadithRef ref) => _missing.contains(ref.canonical);

  Future<HadithRecord?> load(HadithRef ref, {bool allowRemote = true}) {
    final key = ref.canonical;
    final hit = _memory[key];
    if (hit != null) return Future.value(hit);
    if (_missing.contains(key) && !allowRemote) return Future.value(null);

    final running = _inflight[key];
    if (running != null) return running;

    final future = _resolve(ref, allowRemote: allowRemote).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  Future<HadithRecord?> _resolve(HadithRef ref, {required bool allowRemote}) async {
    final key = ref.canonical;

    final stored = await _readRow(ref);
    if (stored != null) {
      _memory[key] = stored;
      _missing.remove(key);
      return stored;
    }

    final bundled = await _bundled.fetch(ref);
    if (bundled != null) {
      _memory[key] = bundled;
      _missing.remove(key);
      // Bundled text is already on the device; caching it again would only
      // duplicate it.
      return bundled;
    }

    if (!allowRemote) {
      return null;
    }

    // UmmahAPI first — it is the app's own configured service, and it declines
    // collections it does not carry without spending a request.
    for (final source in [_ummah, _remote]) {
      final fetched = await source.fetch(ref);
      if (fetched != null) {
        _memory[key] = fetched;
        _missing.remove(key);
        await _writeRow(fetched);
        return fetched;
      }
    }

    _missing.add(key);
    return null;
  }

  /// Several refs at once, in the order given, skipping the ones already held.
  ///
  /// Used when a story opens: its hadith citations are resolved together rather
  /// than one per rebuild.
  Future<Map<HadithRef, HadithRecord>> loadAll(
    Iterable<HadithRef> refs, {
    bool allowRemote = true,
  }) async {
    final unique = <String, HadithRef>{};
    for (final ref in refs) {
      unique.putIfAbsent(ref.canonical, () => ref);
    }
    final out = <HadithRef, HadithRecord>{};
    await Future.wait(unique.values.map((ref) async {
      final record = await load(ref, allowRemote: allowRemote);
      if (record != null) out[ref] = record;
    }));
    return out;
  }

  /// Warm the cache without anybody waiting on it.
  ///
  /// Fire-and-forget by design: called when a story or theme page opens so that
  /// tapping a citation a second later is instant. Failures are silent — this is
  /// an optimisation, not a feature.
  void prefetch(Iterable<HadithRef> refs) {
    for (final ref in refs) {
      final key = ref.canonical;
      if (_memory.containsKey(key) ||
          _missing.contains(key) ||
          _inflight.containsKey(key)) {
        continue;
      }
      load(ref).ignore();
    }
  }

  // ── Local database ──────────────────────────────────────────────────

  Future<HadithRecord?> _readRow(HadithRef ref) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        table,
        where: 'collection = ? AND number = ?',
        whereArgs: [ref.collection, ref.number],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return HadithRecord.fromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRow(HadithRecord record) async {
    try {
      final db = await _db.database;
      await db.insert(
        table,
        record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // A cache that cannot write is still a working app.
    }
  }

  /// How many hadiths are saved on this device — shown on the hadith screens so
  /// the offline state is legible rather than mysterious.
  Future<int> savedCount() async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<HadithRecord>> saved({int limit = 200}) async {
    try {
      final db = await _db.database;
      final rows = await db.query(table, orderBy: 'fetched_at DESC', limit: limit);
      return rows.map(HadithRecord.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearSaved() async {
    try {
      final db = await _db.database;
      await db.delete(table);
      _memory.removeWhere((_, v) => v.origin == HadithOrigin.cached);
    } catch (_) {
      // Nothing to do.
    }
  }

  /// Takes records the topic search already fetched into the same cache a
  /// citation lookup reads from.
  ///
  /// Without this, opening a hadith from a topic list would re-fetch a text that
  /// arrived in the search payload seconds earlier — and would fail offline for a
  /// hadith the reader had, in every sense that matters, already read.
  Future<void> remember(Iterable<HadithRecord> records) async {
    for (final record in records) {
      if (!record.hasText) continue;
      final key = record.ref.canonical;
      _memory[key] = record;
      _missing.remove(key);
      await _writeRow(record);
    }
  }

  // ── Reflections ─────────────────────────────────────────────────────
  //
  // The fifth layer of the hadith page. Stored locally and never uploaded: a
  // reflection is the reader's, and the Halaqa share sheet is the only thing that
  // ever moves one anywhere.

  Future<void> saveReflection(HadithRef ref, String text) async {
    final trimmed = text.trim();
    try {
      final db = await _db.database;
      if (trimmed.isEmpty) {
        await db.delete(
          reflectionTable,
          where: 'collection = ? AND number = ?',
          whereArgs: [ref.collection, ref.number],
        );
        return;
      }
      await db.insert(
        reflectionTable,
        {
          'collection': ref.collection,
          'number': ref.number,
          'reflection': trimmed,
          'saved_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // A reflection that cannot be written must not take the screen down.
    }
  }

  Future<String?> reflection(HadithRef ref) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        reflectionTable,
        where: 'collection = ? AND number = ?',
        whereArgs: [ref.collection, ref.number],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final value = rows.first['reflection'] as String?;
      return (value == null || value.trim().isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  /// Counted into the Growth map alongside ayah reflections.
  Future<int> reflectionCount() async {
    try {
      final db = await _db.database;
      final rows =
          await db.rawQuery('SELECT COUNT(*) AS c FROM $reflectionTable');
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
