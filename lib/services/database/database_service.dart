/// DatabaseService — SQLite setup.
/// v2 added layer_unlocks + reflections.
/// v3 adds the social tables for Halaqa (private circles) and Al-Minbar
/// (public feed), plus the local user_profile used as the "current user".
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/utils/logger.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  static Database? _database;
  static const String _tag = 'DatabaseService';
  static const int _version = 3; // v3 adds social tables (Halaqa + Minbar)

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

    // Social tables (Halaqa + Al-Minbar + local profile)
    await _createSocialTables(db);

    AppLogger.info('Database schema created', tag: _tag);
  }

  /// Social feature tables — shared by [_onCreate] (fresh installs) and
  /// [_onUpgrade] (existing users moving to v3). Kept in one place so the two
  /// paths can never drift apart. IDs are TEXT (UUIDs) and timestamps are ISO
  /// 8601 strings, matching the rest of the local schema and mapping cleanly
  /// onto the Supabase tables in supabase/migrations/001_initial_schema.sql.
  Future<void> _createSocialTables(Database db) async {
    // The local "current user" — one row. Stands in for a future auth user.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id           TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        created_at   TEXT NOT NULL
      )
    ''');

    // A private study circle (2–8 members), joined via invite_code.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS halaqas (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        created_by  TEXT NOT NULL,
        invite_code TEXT NOT NULL UNIQUE,
        max_members INTEGER NOT NULL DEFAULT 8,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS halaqa_members (
        id             TEXT PRIMARY KEY,
        halaqa_id      TEXT NOT NULL,
        user_id        TEXT NOT NULL,
        display_name   TEXT NOT NULL,
        joined_at      TEXT NOT NULL,
        last_active_at TEXT,
        UNIQUE(halaqa_id, user_id)
      )
    ''');

    // A share = a denormalised SharedContent snapshot (content_json) plus an
    // optional ≤100-char personal note. No replies column — by design.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS halaqa_shares (
        id             TEXT PRIMARY KEY,
        halaqa_id      TEXT NOT NULL,
        shared_by      TEXT NOT NULL,
        shared_by_name TEXT NOT NULL,
        content_json   TEXT NOT NULL,
        personal_note  TEXT,
        shared_at      TEXT NOT NULL
      )
    ''');

    // Reactions are the ONLY response allowed. One row per (share, user,
    // reaction) so a member can independently toggle Du'a / Resonated / Moved.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS halaqa_reactions (
        id         TEXT PRIMARY KEY,
        share_id   TEXT NOT NULL,
        user_id    TEXT NOT NULL,
        reaction   TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(share_id, user_id, reaction)
      )
    ''');

    // Al-Minbar: the public feed. Same snapshot idea, no circle, no note.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS minbar_shares (
        id             TEXT PRIMARY KEY,
        shared_by      TEXT NOT NULL,
        shared_by_name TEXT NOT NULL,
        content_json   TEXT NOT NULL,
        shared_at      TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS minbar_reactions (
        id         TEXT PRIMARY KEY,
        share_id   TEXT NOT NULL,
        user_id    TEXT NOT NULL,
        reaction   TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(share_id, user_id, reaction)
      )
    ''');

    // Indexes for the queries the feeds actually run.
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_halaqa_members_halaqa ON halaqa_members (halaqa_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_halaqa_shares_halaqa ON halaqa_shares (halaqa_id, shared_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_halaqa_reactions_share ON halaqa_reactions (share_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_minbar_shares_time ON minbar_shares (shared_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_minbar_reactions_share ON minbar_reactions (share_id)');
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

    if (oldVersion < 3) {
      // Social tables (Halaqa + Al-Minbar + local profile) — new in v3.
      await _createSocialTables(db);
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
