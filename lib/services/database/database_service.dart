/// DatabaseService — SQLite setup.
/// v2 added layer_unlocks + reflections.
/// v3 adds the social tables for Halaqa (private circles) and Al-Minbar
/// (public feed), plus the local user_profile used as the "current user".
/// v4 adds hadith_cache, so a hadith fetched once stays readable offline.
/// v5 adds api_cache — one generic store for every UmmahAPI payload (tafsir,
/// word-by-word, mutashabihat, reciters, Quran text), which is what turns
/// offline reading from a claim into a property of the app.
/// v6 adds hadith_reflections, the fifth layer of the hadith page. Keyed by
/// (collection, number) like the citations themselves, rather than forced into
/// the ayah `reflections` table's two integer columns.
library;

import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/utils/logger.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  static Database? _database;
  static const String _tag = 'DatabaseService';
  static const int _version = 6; // v6 adds hadith_reflections
  static const String _dbName = 'mizan.db';
  static const String _legacyDbName = 'taddabur.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);
    await _migrateLegacyFile(databasesPath);
    AppLogger.info('Opening database at $path', tag: _tag);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// The app was called Taddabur, so the file was `taddabur.db`. Renaming the
  /// product renamed the file, and simply pointing at a new name would have
  /// left every existing install staring at an empty app — saved words,
  /// reflections, unlocked layers, Halaqa rows, all still on disk but
  /// unreachable. So on first open under the new name, the old file is moved
  /// across. `openDatabase` then runs `onUpgrade` against it exactly as it
  /// would have before; nothing about the schema changes here.
  ///
  /// Only ever moves *into* an absent target. If `mizan.db` already exists the
  /// migration has happened (or the user is genuinely new) and the legacy file,
  /// if any, is stale — overwriting live data with it would be the one
  /// unrecoverable mistake available in this function.
  Future<void> _migrateLegacyFile(String databasesPath) async {
    final target = join(databasesPath, _dbName);
    final legacy = join(databasesPath, _legacyDbName);
    try {
      if (await databaseExists(target)) return;
      if (!await databaseExists(legacy)) return;
      await File(legacy).rename(target);
      AppLogger.info('Migrated $_legacyDbName → $_dbName', tag: _tag);
    } catch (e) {
      // A failed rename must not stop the app booting: falling through leaves
      // the old file untouched and opens a fresh database, which is degraded
      // but usable. Losing the launch entirely would be worse.
      AppLogger.error('Legacy database rename failed',
          error: e, tag: _tag);
    }
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

    // Knowledge platform tables (hadith cache)
    await _createKnowledgeTables(db);

    // Generic UmmahAPI response cache
    await _createApiCacheTable(db);

    AppLogger.info('Database schema created', tag: _tag);
  }

  /// Knowledge-platform tables — shared by [_onCreate] and [_onUpgrade], same
  /// reason as [_createSocialTables]: the two paths must not drift.
  ///
  /// `hadith_cache` holds the text of hadiths already fetched, keyed by
  /// (collection, number) exactly as the citations are. It is a cache, not a
  /// source of truth: deleting it costs nothing but a refetch, and `grade` is
  /// stored only when the source stated one.
  Future<void> _createKnowledgeTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hadith_cache (
        collection TEXT NOT NULL,
        number     TEXT NOT NULL,
        arabic     TEXT,
        english    TEXT,
        narrator   TEXT,
        grade      TEXT,
        book_name  TEXT,
        chapter    TEXT,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (collection, number)
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hadith_cache_fetched ON hadith_cache (fetched_at)');

    await _createHadithReflectionTable(db);
  }

  /// The reader's own words on a hadith — the fifth layer of the hadith page.
  ///
  /// Its own helper, and its own `oldVersion < 6` step, because it arrived after
  /// `hadith_cache`: a device already on v4 or v5 has the cache table and needs
  /// only this one. `IF NOT EXISTS` makes the double call from the two paths a
  /// no-op rather than a migration hazard.
  ///
  /// Unlike `hadith_cache`, this is *not* a cache. Clearing saved hadith texts
  /// must never touch it, which is why it is a separate table with a separate
  /// name rather than four more nullable columns on the cache row.
  Future<void> _createHadithReflectionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hadith_reflections (
        collection TEXT NOT NULL,
        number     TEXT NOT NULL,
        reflection TEXT NOT NULL,
        saved_at   TEXT NOT NULL,
        PRIMARY KEY (collection, number)
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hadith_reflections_saved ON hadith_reflections (saved_at)');
  }

  /// The generic response cache — shared by [_onCreate] and [_onUpgrade].
  ///
  /// `cache_key` is a request path with its query string, so it is stable across
  /// app versions and readable in a debugger. It never contains the API key: the
  /// key travels as a header precisely so it cannot end up in a cache key.
  ///
  /// `payload` is the unwrapped `data` from the response, re-encoded. Nothing
  /// queries inside it — entries are read whole — which is why one table serves
  /// tafsir, word-by-word, mutashabihat, catalogues and Quran text alike.
  Future<void> _createApiCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_cache (
        cache_key  TEXT PRIMARY KEY,
        payload    TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_api_cache_fetched ON api_cache (fetched_at)');
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

    if (oldVersion < 4) {
      // Hadith cache — new in v4.
      await _createKnowledgeTables(db);
    }

    if (oldVersion < 5) {
      // Generic UmmahAPI response cache — new in v5.
      await _createApiCacheTable(db);
    }

    if (oldVersion < 6) {
      // Hadith reflections — new in v6. Devices upgrading from v4 or v5 already
      // have hadith_cache and need only this table.
      await _createHadithReflectionTable(db);
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
