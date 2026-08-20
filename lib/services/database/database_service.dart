/// DatabaseService — SQLite setup, now with layer_unlocks table
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/utils/logger.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  static Database? _database;
  static const String _tag = 'DatabaseService';
  static const int _version = 2; // bumped from 1 → 2 for new table

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'taddabur.db');
    AppLogger.info('Opening database at $path', tag: _tag);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Creating database schema v$version', tag: _tag);

    // Vocabulary Bank table
    await db.execute('''
      CREATE TABLE vocab_words (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        arabic          TEXT NOT NULL,
        transliteration TEXT NOT NULL,
        meaning         TEXT NOT NULL,
        root            TEXT NOT NULL DEFAULT '',
        insight         TEXT NOT NULL DEFAULT '',
        surah_number    INTEGER NOT NULL,
        ayah_number     INTEGER NOT NULL,
        surah_name      TEXT NOT NULL,
        saved_at        TEXT NOT NULL,
        review_count    INTEGER NOT NULL DEFAULT 0,
        next_review_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_vocab_next_review ON vocab_words (next_review_at)
    ''');
    await db.execute('''
      CREATE INDEX idx_vocab_arabic ON vocab_words (arabic)
    ''');

    // Layer unlock tracking table
    await db.execute('''
      CREATE TABLE layer_unlocks (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number  INTEGER NOT NULL,
        ayah_number   INTEGER NOT NULL,
        layer_index   INTEGER NOT NULL,
        unlocked_at   TEXT NOT NULL,
        UNIQUE(surah_number, ayah_number, layer_index)
      )
    ''');

    // Reflection storage table (for Layer 5 — personal reflection)
    await db.execute('''
      CREATE TABLE reflections (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number  INTEGER NOT NULL,
        ayah_number   INTEGER NOT NULL,
        reflection    TEXT NOT NULL,
        saved_at      TEXT NOT NULL,
        UNIQUE(surah_number, ayah_number)
      )
    ''');

    AppLogger.info('Database schema created', tag: _tag);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'Upgrading database v$oldVersion → v$newVersion',
      tag: _tag,
    );

    if (oldVersion < 2) {
      // Add layer_unlocks table (new in v2)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS layer_unlocks (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          surah_number  INTEGER NOT NULL,
          ayah_number   INTEGER NOT NULL,
          layer_index   INTEGER NOT NULL,
          unlocked_at   TEXT NOT NULL,
          UNIQUE(surah_number, ayah_number, layer_index)
        )
      ''');

      // Add reflections table (new in v2)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reflections (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          surah_number  INTEGER NOT NULL,
          ayah_number   INTEGER NOT NULL,
          reflection    TEXT NOT NULL,
          saved_at      TEXT NOT NULL,
          UNIQUE(surah_number, ayah_number)
        )
      ''');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
