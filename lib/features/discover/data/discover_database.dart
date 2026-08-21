// ─────────────────────────────────────────────────────────────────────────────
// discover_database.dart
// SQLite tables for Discover progress, quiz results, unlock state.
// Uses the sqflite package, same pattern as the app's existing Vocab Bank DB.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/discover_models.dart';

class DiscoverDatabase {
  static const _dbName = 'taddabur_discover_v2.db';
  static const _dbVersion = 1;

  // Table names
  static const _tProgress = 'discover_progress';
  static const _tQuizResults = 'discover_quiz_results';
  static const _tQuizAnswers = 'discover_quiz_answers';

  static Database? _db;

  // ── Singleton ──────────────────────────────────────────────────────────────

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Progress table — one row per entry (prophet / sahabi / name)
    await db.execute('''
      CREATE TABLE $_tProgress (
        entry_id TEXT NOT NULL,
        entry_type TEXT NOT NULL,        -- 'prophet' | 'sahabi' | 'divine_name'
        layers_unlocked INTEGER NOT NULL DEFAULT 0,
        last_layer_unlocked_at TEXT,     -- ISO-8601
        quiz_passed INTEGER NOT NULL DEFAULT 0,  -- 0 | 1
        quiz_passed_at TEXT,             -- ISO-8601
        entry_completed INTEGER NOT NULL DEFAULT 0, -- 0 | 1
        PRIMARY KEY (entry_id, entry_type)
      )
    ''');

    // Quiz results table — one row per completed quiz attempt
    await db.execute('''
      CREATE TABLE $_tQuizResults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        completed_at TEXT NOT NULL,      -- ISO-8601
        factual_score INTEGER NOT NULL,  -- 0–5
        passed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Individual answers per quiz attempt
    await db.execute('''
      CREATE TABLE $_tQuizAnswers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_result_id INTEGER NOT NULL REFERENCES $_tQuizResults(id),
        question_number INTEGER NOT NULL,
        question_type TEXT NOT NULL,     -- 'factual' | 'reflective'
        selected_option_id TEXT,         -- null for slider-only reflective
        slider_value REAL,               -- 0.0–1.0, null for factual
        is_correct INTEGER               -- 1 | 0 | null (for reflective)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_progress_type ON $_tProgress(entry_type)');
    await db.execute(
        'CREATE INDEX idx_quiz_entry ON $_tQuizResults(entry_id, entry_type)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  // ── Progress CRUD ──────────────────────────────────────────────────────────

  static Future<DiscoverProgress?> getProgress(
      String entryId, EntryType type) async {
    final db = await database;
    final rows = await db.query(
      _tProgress,
      where: 'entry_id = ? AND entry_type = ?',
      whereArgs: [entryId, _typeStr(type)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _progressFromRow(rows.first);
  }

  /// Returns all progress rows for a given section (all prophets, etc.)
  static Future<List<DiscoverProgress>> getAllProgress(EntryType type) async {
    final db = await database;
    final rows = await db.query(
      _tProgress,
      where: 'entry_type = ?',
      whereArgs: [_typeStr(type)],
    );
    return rows.map(_progressFromRow).toList();
  }

  /// Creates progress row if not exists (called when user first taps an entry)
  static Future<DiscoverProgress> ensureProgress(
      String entryId, EntryType type) async {
    final existing = await getProgress(entryId, type);
    if (existing != null) return existing;

    final db = await database;
    await db.insert(_tProgress, {
      'entry_id': entryId,
      'entry_type': _typeStr(type),
      'layers_unlocked': 5, // Dev mode: all layers unlocked
      'quiz_passed': 0,
      'entry_completed': 0,
    });

    return DiscoverProgress(
      entryId: entryId,
      entryType: type,
      layersUnlocked: 0,
      quizPassed: false,
      entryCompleted: false,
    );
  }

  /// Call when user reads a layer — increments counter, sets timestamp.
  /// Returns updated progress. Throws if canUnlockNextLayer is false.
  static Future<DiscoverProgress> unlockNextLayer(
      String entryId, EntryType type) async {
    final progress = await ensureProgress(entryId, type);
    if (!progress.canUnlockNextLayer) {
      throw StateError(
          'Cannot unlock next layer for $entryId today — already unlocked one today or all 5 done.');
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();
    final newCount = progress.layersUnlocked + 1;

    await db.update(
      _tProgress,
      {
        'layers_unlocked': newCount,
        'last_layer_unlocked_at': now,
      },
      where: 'entry_id = ? AND entry_type = ?',
      whereArgs: [entryId, _typeStr(type)],
    );

    return progress.copyWith(
      layersUnlocked: newCount,
      lastLayerUnlockedAt: DateTime.now(),
    );
  }

  /// Call when quiz is passed — marks entry complete.
  static Future<DiscoverProgress> markQuizPassed(
      String entryId, EntryType type) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      _tProgress,
      {
        'quiz_passed': 1,
        'quiz_passed_at': now,
        'entry_completed': 1,
      },
      where: 'entry_id = ? AND entry_type = ?',
      whereArgs: [entryId, _typeStr(type)],
    );

    final progress = await getProgress(entryId, type);
    return progress!;
  }

  // ── Quiz result persistence ────────────────────────────────────────────────

  static Future<void> saveQuizResult(QuizResult result) async {
    final db = await database;

    final resultId = await db.insert(_tQuizResults, {
      'entry_id': result.entryId,
      'entry_type': _typeStr(result.entryType),
      'completed_at': result.completedAt.toIso8601String(),
      'factual_score': result.factualScore,
      'passed': result.passed ? 1 : 0,
    });

    // Save individual answers
    final batch = db.batch();
    result.selectedOptions.forEach((qNum, optId) {
      batch.insert(_tQuizAnswers, {
        'quiz_result_id': resultId,
        'question_number': qNum,
        'question_type': 'factual',
        'selected_option_id': optId,
      });
    });
    result.sliderValues.forEach((qNum, val) {
      batch.insert(_tQuizAnswers, {
        'quiz_result_id': resultId,
        'question_number': qNum,
        'question_type': 'reflective',
        'slider_value': val,
      });
    });
    await batch.commit(noResult: true);

    if (result.passed) {
      await markQuizPassed(result.entryId, result.entryType);
    }
  }

  // ── Unlock gate: is the next sequential entry unlocked? ───────────────────
  //
  // Rules:
  //   • Entry 1 is always available (no prerequisite).
  //   • Entry N (N > 1) is available only if entry N-1 is completed.

  static Future<bool> isEntryUnlocked(
      String entryId, EntryType type, int sequenceNumber) async {
    if (sequenceNumber == 1) return true;

    // We need the id of the previous entry — caller must pass the ordered list
    // and handle this via the provider. This method checks if the entry's own
    // progress record exists and entry_completed = 1 for the predecessor.
    // The provider resolves predecessor id; this helper stays generic.
    // (See DiscoverNotifier.isEntryUnlocked for the full logic.)
    return false; // Overridden by provider
  }

  // ── Stats (for Growth Map) ─────────────────────────────────────────────────

  static Future<Map<String, int>> getCompletionStats() async {
    final db = await database;
    final result = <String, int>{};

    for (final type in [
      _typeStr(EntryType.prophet),
      _typeStr(EntryType.sahabi),
      _typeStr(EntryType.divineName),
    ]) {
      final rows = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM $_tProgress
        WHERE entry_type = ? AND entry_completed = 1
      ''', [type]);
      result[type] = rows.first['cnt'] as int;
    }
    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _typeStr(EntryType t) {
    switch (t) {
      case EntryType.prophet:
        return 'prophet';
      case EntryType.sahabi:
        return 'sahabi';
      case EntryType.divineName:
        return 'divine_name';
    }
  }

  static DiscoverProgress _progressFromRow(Map<String, dynamic> row) {
    final typeStr = row['entry_type'] as String;
    final type = typeStr == 'prophet'
        ? EntryType.prophet
        : typeStr == 'sahabi'
            ? EntryType.sahabi
            : EntryType.divineName;

    return DiscoverProgress(
      entryId: row['entry_id'] as String,
      entryType: type,
      layersUnlocked: row['layers_unlocked'] as int,
      lastLayerUnlockedAt: row['last_layer_unlocked_at'] != null
          ? DateTime.parse(row['last_layer_unlocked_at'] as String)
          : null,
      quizPassed: (row['quiz_passed'] as int) == 1,
      quizPassedAt: row['quiz_passed_at'] != null
          ? DateTime.parse(row['quiz_passed_at'] as String)
          : null,
      entryCompleted: (row['entry_completed'] as int) == 1,
    );
  }

  /// Call on app teardown or tests
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
