/// LayerRepository — unlock tracking and reflection storage
library;

import 'package:sqflite/sqflite.dart';
import '../../../services/database/database_service.dart';
import '../../../core/utils/logger.dart';
import '../models/layer_unlock.dart';

class LayerRepository {
  LayerRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  static const String _tag = 'LayerRepository';

  // ── Unlock tracking ───────────────────────────────────────────

  /// Records that a user opened a specific layer for the first time.
  /// Ignored if already recorded (UNIQUE constraint).
  Future<void> recordUnlock(
      int surahNumber, int ayahNumber, int layerIndex) async {
    final db = await _db.database;
    await db.insert(
      'layer_unlocks',
      {
        'surah_number': surahNumber,
        'ayah_number': ayahNumber,
        'layer_index': layerIndex,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    AppLogger.info(
      'Recorded unlock: $surahNumber:$ayahNumber layer $layerIndex',
      tag: _tag,
    );
  }

  /// Returns all unlock records for a specific ayah.
  /// Used to determine which layers are available.
  Future<List<LayerUnlock>> getUnlocksForAyah(
      int surahNumber, int ayahNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'layer_unlocks',
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surahNumber, ayahNumber],
      orderBy: 'layer_index ASC',
    );
    return maps.map(LayerUnlock.fromMap).toList();
  }

  /// Checks if a specific layer is unlocked for an ayah.
  Future<bool> isLayerUnlocked(
      int surahNumber, int ayahNumber, int layerIndex) async {
    if (layerIndex == 0) return true; // Words always unlocked
    final db = await _db.database;
    final maps = await db.query(
      'layer_unlocks',
      where:
          'surah_number = ? AND ayah_number = ? AND layer_index = ?',
      whereArgs: [surahNumber, ayahNumber, layerIndex],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Returns when the next layer becomes available, or null if already unlocked.
  /// Logic: previous layer must be unlocked, then +24 hours.
  Future<DateTime?> getNextUnlockTime(
      int surahNumber, int ayahNumber, int layerIndex) async {
    if (layerIndex == 0) return null; // Words always available
    final previousLayerIndex = layerIndex - 1;
    final db = await _db.database;
    final maps = await db.query(
      'layer_unlocks',
      where:
          'surah_number = ? AND ayah_number = ? AND layer_index = ?',
      whereArgs: [surahNumber, ayahNumber, previousLayerIndex],
      limit: 1,
    );
    if (maps.isEmpty) return null; // previous layer not even opened
    final previousUnlock = LayerUnlock.fromMap(maps.first);
    return previousUnlock.unlockedAt.add(LayerMeta.unlockInterval);
  }

  // ── Reflections ───────────────────────────────────────────────

  /// Saves the user's personal reflection for an ayah.
  /// Replaces existing reflection if one exists.
  Future<void> saveReflection(
      int surahNumber, int ayahNumber, String reflection) async {
    final db = await _db.database;
    await db.insert(
      'reflections',
      {
        'surah_number': surahNumber,
        'ayah_number': ayahNumber,
        'reflection': reflection,
        'saved_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.info(
      'Saved reflection for $surahNumber:$ayahNumber',
      tag: _tag,
    );
  }

  /// Returns the user's saved reflection for an ayah, or null.
  Future<String?> getReflection(
      int surahNumber, int ayahNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'reflections',
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surahNumber, ayahNumber],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['reflection'] as String;
  }

  // ── Aggregate stats (for the Growth Map) ──────────────────────
  // Read-only roll-ups over the same tables. Kept here (rather than in a
  // separate stats class) so the SQL lives next to the schema it depends on.

  /// Total tafseer layers the user has opened across every ayah — one row per
  /// (surah, ayah, layer) that was ever unlocked. This is the "depth of
  /// engagement" signal: reading five layers of one ayah counts as five.
  Future<int> countUnlocks() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM layer_unlocks',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Distinct ayahs the user has opened at least one tafseer layer on — the
  /// "breadth" companion to [countUnlocks], used only for the stat-card detail.
  Future<int> countAyahsTouched() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(DISTINCT surah_number || ':' || ayah_number) AS c "
      'FROM layer_unlocks',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Personal ayah reflections written. Excludes the Muhasabah sentinel row,
  /// which the Muhasabah screen stores at (surah_number = 0, ayah_number = 0).
  Future<int> countReflections() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM reflections WHERE surah_number != 0',
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
