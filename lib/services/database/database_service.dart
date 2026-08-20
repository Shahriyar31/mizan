/// DatabaseService — SQLite setup and table management
///
/// Why a single DatabaseService for the whole app:
/// SQLite has one database file per app. Opening it multiple times
/// wastes resources. We open it once here and share it everywhere.
///
/// This service only handles:
/// - Opening the database
/// - Creating tables
/// - Migrations (future schema changes)
///
/// It does NOT handle queries — those go in repositories.
/// One responsibility per class.
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/utils/logger.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static Database? _database;
  static const String _tag = 'DatabaseService';

  // Current schema version
  // Increment this when you change table structure
  static const int _version = 1;

  /// Returns the open database, opening it if needed
  Future<Database> get database async {
    // Return existing connection if open
    if (_database != null) return _database!;

    // Open for the first time
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    // Get the device's default database directory
    // On Android: /data/data/com.example.ummahapp/databases/
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

  /// Called when database is created for the first time
  /// Defines all table schemas
  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Creating database schema v$version', tag: _tag);

    // ── Vocabulary Bank table ─────────────────────────────────
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

    // Index for fast lookup of words due for review
    // Used every morning when building the Wird
    await db.execute('''
      CREATE INDEX idx_vocab_next_review
      ON vocab_words (next_review_at)
    ''');

    // Index for looking up if a word is already saved
    // Used to show correct state on Save button
    await db.execute('''
      CREATE INDEX idx_vocab_arabic
      ON vocab_words (arabic)
    ''');

    AppLogger.info('Database schema created', tag: _tag);
  }

  /// Called when version number increases
  /// Handles schema migrations without losing user data
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'Upgrading database from v$oldVersion to v$newVersion',
      tag: _tag,
    );
    // Future migrations go here
    // Example: ALTER TABLE vocab_words ADD COLUMN notes TEXT
  }

  /// Closes the database — call when app is terminating
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
