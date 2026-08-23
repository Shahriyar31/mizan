// ─────────────────────────────────────────────────────────────────────────────
// discover_database.dart
// SQLite tables for Discover progress, quiz results, unlock state.
// Uses the sqflite package, same pattern as the app's existing Vocab Bank DB.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/discover_models.dart';

class DiscoverDatabase {
  static const _dbName = 'mizan_discover_v2.db';
  static const _legacyDbName = 'taddabur_discover_v2.db';
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
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);
    await _migrateLegacyFile(dir);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Carries Discover progress across the Taddabur → Mizan rename. Same
  /// reasoning as [DatabaseService]: the file name is part of the product name,
  /// so renaming the product would otherwise reset every entry the user has
  /// already read. Only moves into an absent target, so it can never overwrite
  /// live progress with a stale file.
  static Future<void> _migrateLegacyFile(String dir) async {
    final target = join(dir, _dbName);
    final legacy = join(dir, _legacyDbName);
    try {
      if (await databaseExists(target)) return;
      if (!await databaseExists(legacy)) return;
      await File(legacy).rename(target);
    } catch (_) {
      // Non-fatal: a fresh Discover database is better than a failed launch.
    }
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

  /// Creates the progress row if it does not exist, with the first layer open
  /// and nothing else. Called the moment a story is opened.
  ///
  /// It used to seed `layers_unlocked: 5` under a "Dev mode" comment, which would
  /// have opened every layer of every story on first tap. It also used to be
  /// unreachable — its only caller was [openLayersUpTo]'s ancestor, which nothing
  /// called — so in practice no row was ever written and three separate features
  /// silently did nothing: the layer rail on Home, "Continue reading" on the
  /// Discover index, and the Reading/Complete filter chips.
  ///
  /// `last_layer_unlocked_at` is stamped here too. Opening the first layer *is*
  /// that layer becoming open, and "Continue reading" orders by this column — so
  /// without the stamp a story you started but did not finish would never appear
  /// there.
  static Future<DiscoverProgress> ensureProgress(
      String entryId, EntryType type) async {
    final existing = await getProgress(entryId, type);
    if (existing != null) return existing;

    final db = await database;
    final now = DateTime.now();
    await db.insert(_tProgress, {
      'entry_id': entryId,
      'entry_type': _typeStr(type),
      'layers_unlocked': 1,
      'last_layer_unlocked_at': now.toIso8601String(),
      'quiz_passed': 0,
      'entry_completed': 0,
    });

    return DiscoverProgress(
      entryId: entryId,
      entryType: type,
      layersUnlocked: 1, // must mirror the inserted value above
      lastLayerUnlockedAt: now,
      quizPassed: false,
      entryCompleted: false,
    );
  }

  /// Open the story up to and including layer [count], and return the row.
  ///
  /// Monotonic on purpose: it takes the larger of the stored count and [count],
  /// so re-reading layer 1 of a story you have finished cannot close layers 2–5
  /// behind you. That also makes it safe to call on every advance without the
  /// caller tracking what is already open.
  ///
  /// Replaces `unlockNextLayer`, which incremented blindly and threw a
  /// [StateError] when it thought the day's allowance was used up. Throwing from
  /// a "the reader tapped Continue" path is the wrong shape for this: the worst
  /// case here is that a layer is already open, which is not an error.
  static Future<DiscoverProgress> openLayersUpTo(
    String entryId,
    EntryType type,
    int count,
  ) async {
    final progress = await ensureProgress(entryId, type);
    if (count <= progress.layersUnlocked) return progress;

    final db = await database;
    final now = DateTime.now();

    await db.update(
      _tProgress,
      {
        'layers_unlocked': count,
        'last_layer_unlocked_at': now.toIso8601String(),
      },
      where: 'entry_id = ? AND entry_type = ?',
      whereArgs: [entryId, _typeStr(type)],
    );

    return progress.copyWith(
      layersUnlocked: count,
      lastLayerUnlockedAt: now,
    );
  }

  /// Call when quiz is passed — marks entry complete.
  static Future<DiscoverProgress> markQuizPassed(
      String entryId, EntryType type) async {
    // Guarantees the row exists before the update below. Without this the update
    // matched nothing and the `getProgress` that followed returned null, so
    // passing a quiz threw a null-check error on the way to the results screen.
    await ensureProgress(entryId, type);

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
      _typeStr(EntryType.seerah),
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
      case EntryType.seerah:
        return 'seerah';
    }
  }

  static EntryType _typeFromStr(String s) {
    switch (s) {
      case 'prophet':
        return EntryType.prophet;
      case 'sahabi':
        return EntryType.sahabi;
      case 'seerah':
        return EntryType.seerah;
      case 'divine_name':
      default:
        return EntryType.divineName;
    }
  }

  static DiscoverProgress _progressFromRow(Map<String, dynamic> row) {
    final type = _typeFromStr(row['entry_type'] as String);

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
