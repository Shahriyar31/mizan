/// Export and restore everything this device holds about one reader.
///
/// ── Why this exists ────────────────────────────────────────────────────
/// Almost nothing in Mizan is on a server. Reflections, the nightly muhasabah,
/// saved words, unlocked layers, the streak, the Al-Mizan record and Discover
/// progress all live in SQLite and SharedPreferences on the phone, by design —
/// what somebody writes about the Qur'an is nobody's business but theirs. The
/// cost of that design is that a lost phone, a wiped device, or an uninstall
/// takes the lot, and there is no support ticket that can bring it back. Signing
/// in does not help: the account syncs Halaqa and Al-Minbar, not any of this.
///
/// So the reader needs a copy they own. This produces one.
///
/// ── Why the copy is JSON text and not a file ───────────────────────────
/// Handing over a *file* would need `share_plus` or `file_picker`, neither of
/// which is in `pubspec.lock`, and adding a plugin means a native build. Writing
/// to the app's own external directory is worse than useless: Android 11+ hides
/// `Android/data/` from the Files app, and the directory is deleted on uninstall
/// — precisely the event a backup exists to survive.
///
/// So the backup is a block of text, copied to the clipboard, which the reader
/// pastes wherever they actually keep things: a note, an email to themselves, a
/// message to themselves. The app already means one thing by "share a link" —
/// the Halaqa invite copies to the clipboard and says so — and this is the same
/// gesture. It works offline, with no permissions and no new dependency.
///
/// The consequence has to be stated to the reader rather than hidden: the text
/// is plain, readable JSON, so their muhasabah is legible to anyone who can read
/// wherever they paste it. That is the correct trade — a backup they cannot
/// inspect is a backup they have to take on faith — but it is theirs to make,
/// which is why [Your data] says it out loud.
///
/// ── Restore never deletes ──────────────────────────────────────────────
/// A restore is a merge, not a replacement. Someone pasting an old backup into
/// a phone they have kept using must not lose the weeks since. So every rule
/// either adds a row, advances a value, or leaves things exactly as they are;
/// nothing here issues a DELETE. The merge policy per kind of data is documented
/// beside each rule in `backup_engine.dart`, and the reasoning is always the
/// same: when two copies disagree, keep the one that loses nothing.
///
/// ── What is deliberately not in the backup ─────────────────────────────
/// * `api_cache` and `hadith_cache` — downloaded content, not a record of
///   anybody. Re-fetching costs bandwidth; carrying them would multiply the size
///   of the text by an order of magnitude for no gain.
/// * `discover_quiz_results` / `discover_quiz_answers` — per-attempt history
///   joined by an autoincrement id, so merging means remapping foreign keys, and
///   nothing in the app ever displays a past attempt. The *outcome* of every
///   quiz is in `discover_progress`, which is included.
/// * The Halaqa and Al-Minbar mirror — those rows belong to a server-side
///   account and come back when you sign in. Restoring stale copies of them onto
///   another device would show shares that no longer exist.
/// * `todays_mizan` — stamped with one calendar day and false by definition on
///   any other, so restoring it would light three facets the reader did not earn.
/// * Preferences that describe the phone rather than the person (theme, reciter,
///   translation, font sizes, reminders). Re-choosing those is friction, not
///   loss, and the same reasoning is why [AccountDataBoundary] keeps them.
///
/// ── Why this file is only the plumbing ─────────────────────────────────
/// The rules live in `backup_engine.dart`, which imports no Flutter and no
/// database. That is what makes them provable: `tools/verify_backup.dart` runs
/// the real export and the real restore against an in-memory store, so the merge
/// policy is checked by execution rather than by reading it and hoping. This file
/// supplies the two things the engine deliberately does not know — sqflite and
/// SharedPreferences — and nothing else.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/utils/logger.dart';
import '../../../services/database/database_service.dart';
import '../../discover/data/discover_database.dart';
import 'backup_engine.dart';

export 'backup_engine.dart'
    show BackupSummary, BackupPreview, RestoreReport, BackupEngine;

const String _tag = 'BackupService';

class BackupService {
  const BackupService();

  /// Kept here as well as on [BackupEngine] so nothing outside has to know the
  /// split exists.
  static const int formatVersion = BackupEngine.formatVersion;

  Future<BackupSummary> export() async => (await _engine()).export();

  /// Reads a pasted backup's header without writing anything. Synchronous, and
  /// still offered here so [Your data] has one type to talk to — it needs no
  /// database and no preferences, which is why it can answer before anything is
  /// opened.
  BackupPreview inspect(String raw) => BackupEngine.inspect(raw);

  Future<RestoreReport> restore(String raw) async {
    final report = await (await _engine()).restore(raw);
    AppLogger.info(
      'Restore: +${report.added} added, ${report.updated} advanced, '
      '${report.unchanged} already here, ${report.skipped} skipped',
      tag: _tag,
    );
    return report;
  }

  /// Built per call, and cheap: the two table adapters hold nothing but a
  /// closure, and neither opens a database until an operation needs one.
  ///
  /// Preferences are the exception — the instance is loaded here, because the
  /// engine reads them synchronously. See [_PrefsStore].
  Future<BackupEngine> _engine() async => BackupEngine(
        main: _SqfliteTables(() => DatabaseService.instance.database),
        discover: _SqfliteTables(() => DiscoverDatabase.database),
        prefs: _PrefsStore(await SharedPreferences.getInstance()),
        log: (message, error) =>
            AppLogger.warning('$message: $error', tag: _tag),
      );
}

/// [BackupTables] over one sqflite database.
///
/// The database is opened lazily, through the closure, rather than passed in. A
/// Discover database that will not open therefore fails at the first read — where
/// the engine already catches it and returns an empty table — instead of at
/// construction, where it would take the whole export down with it.
class _SqfliteTables implements BackupTables {
  _SqfliteTables(this._open);

  final Future<Database> Function() _open;

  /// Set for the duration of [runInTransaction] so the reads and writes inside
  /// the body go through the transaction rather than the database. Mutable state
  /// on purpose, and safe: Dart runs this on one isolate with no yield between
  /// the assignment and the body, so no other restore can observe it half-set.
  Transaction? _txn;

  Future<DatabaseExecutor> get _executor async => _txn ?? await _open();

  @override
  Future<List<Map<String, Object?>>> readAll(
    String table,
    List<String> columns,
  ) async {
    final db = await _executor;
    return db.query(table, columns: columns);
  }

  @override
  Future<Map<String, Object?>?> findByKey(
    String table,
    Map<String, Object?> key,
  ) async {
    final db = await _executor;
    final rows = await db.query(
      table,
      where: key.keys.map((k) => '$k = ?').join(' AND '),
      whereArgs: key.values.toList(),
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> insertRow(String table, Map<String, Object?> row) async {
    final db = await _executor;
    // `ignore` rather than `replace`: a row that collides on a unique index the
    // natural key does not cover is already there in some form, and replacing it
    // would be the one delete this file promises never to do.
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> updateRow(
    String table,
    Map<String, Object?> key,
    Map<String, Object?> values,
  ) async {
    final db = await _executor;
    await db.update(
      table,
      values,
      where: key.keys.map((k) => '$k = ?').join(' AND '),
      whereArgs: key.values.toList(),
    );
  }

  @override
  Future<void> runInTransaction(Future<void> Function() body) async {
    final db = await _open();
    await db.transaction((txn) async {
      _txn = txn;
      try {
        await body();
      } finally {
        _txn = null;
      }
    });
  }
}

/// [BackupPrefs] over SharedPreferences.
///
/// The loaded instance is required rather than fetched lazily, and that is the
/// whole design of this class. [BackupPrefs.read] is synchronous — which is what
/// lets the engine's merge rules be plain comparisons instead of a chain of
/// awaits — so a store that had not loaded yet would answer `null` to every
/// question. Every preference would then look absent: the export would carry
/// none of them, and a restore would treat the device as blank and overwrite
/// values it should have kept. Taking the loaded instance in the constructor
/// makes that state unrepresentable rather than merely avoided.
class _PrefsStore implements BackupPrefs {
  const _PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Object? read(String key) => _prefs.get(key);

  @override
  Future<void> write(String key, Object value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    }
    // Any other type is unreachable: the engine only ever passes these five,
    // because they are the only five SharedPreferences can hold.
  }
}
