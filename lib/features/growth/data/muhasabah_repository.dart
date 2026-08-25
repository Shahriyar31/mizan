/// Muhasabah — the nightly self-accounting, one entry per night.
///
/// Private forever. This never leaves the device: there is no Supabase table for
/// it, no sync, and nothing in the app counts it, scores it or shows it to
/// anybody else. The only way a copy exists elsewhere is if the reader exports
/// one themselves from Settings → Your data.
///
/// ── Why this file exists ───────────────────────────────────────────────
/// Muhasabah used to be written straight from the screen into the `reflections`
/// table at (surah_number 0, ayah_number 0). That table declares
/// `UNIQUE(surah_number, ayah_number)` and the insert used
/// `ConflictAlgorithm.replace`, so every night overwrote the previous night and
/// the table never held more than one entry. Nothing displayed the history, so
/// nothing revealed the loss.
///
/// Routing every read and write through one repository over a date-keyed table
/// is what stops that class of bug returning: there is one place that decides
/// what a muhasabah key is, and it is the night, not a sentinel.
library;

import 'package:sqflite/sqflite.dart';

import '../../../services/database/database_service.dart';

/// One night's sitting with the three questions.
class MuhasabahEntry {
  const MuhasabahEntry({
    required this.date,
    required this.forAllah,
    required this.nafsPull,
    required this.tomorrow,
    required this.savedAt,
  });

  /// The night this belongs to, as `yyyy-MM-dd` in local time.
  final String date;

  /// "What did I do today for the sake of Allah?"
  final String forAllah;

  /// "What did my nafs pull me toward that I should not have followed?"
  final String nafsPull;

  /// "What is my intention for tomorrow?"
  final String tomorrow;

  /// When the entry was last written, ISO 8601 local.
  final String savedAt;

  bool get isEmpty =>
      forAllah.isEmpty && nafsPull.isEmpty && tomorrow.isEmpty;

  Map<String, Object?> toRow() => {
        'entry_date': date,
        'for_allah': forAllah,
        'nafs_pull': nafsPull,
        'tomorrow': tomorrow,
        'saved_at': savedAt,
      };

  static MuhasabahEntry fromRow(Map<String, Object?> row) => MuhasabahEntry(
        date: (row['entry_date'] as String?) ?? '',
        forAllah: (row['for_allah'] as String?) ?? '',
        nafsPull: (row['nafs_pull'] as String?) ?? '',
        tomorrow: (row['tomorrow'] as String?) ?? '',
        savedAt: (row['saved_at'] as String?) ?? '',
      );
}

class MuhasabahRepository {
  MuhasabahRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  static const String table = 'muhasabah_entries';

  /// The one implementation of the app's date key.
  ///
  /// `yyyy-MM-dd` in **local** time, zero-padded. Padding is not cosmetic: the
  /// key is compared as a string and sorted as a string, so `2026-8-9` would
  /// both mismatch the same night written elsewhere and sort after
  /// `2026-12-01`. The `last_muhasabah_date` preference that Home and Growth
  /// read uses this same function, so the table and the flag can never disagree
  /// about which night it is.
  static String dateKey(DateTime when) {
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    return '${when.year}-$m-$d';
  }

  /// Saves tonight's entry, replacing an earlier save **of the same night**.
  ///
  /// Replace is correct here and was catastrophic before: the key is the date,
  /// so it means "I thought of something else to add tonight", never "discard
  /// every night I have written".
  Future<void> save({
    required String forAllah,
    required String nafsPull,
    required String tomorrow,
    DateTime? when,
  }) async {
    final now = when ?? DateTime.now();
    final db = await _db.database;
    await db.insert(
      table,
      MuhasabahEntry(
        date: dateKey(now),
        forAllah: forAllah.trim(),
        nafsPull: nafsPull.trim(),
        tomorrow: tomorrow.trim(),
        savedAt: now.toIso8601String(),
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tonight's entry if the reader has already written one, else null — so the
  /// screen can show them their own words instead of an empty form that is
  /// about to replace them.
  Future<MuhasabahEntry?> entryFor(DateTime when) async {
    final db = await _db.database;
    final rows = await db.query(
      table,
      where: 'entry_date = ?',
      whereArgs: [dateKey(when)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MuhasabahEntry.fromRow(rows.first);
  }

  /// Every night on record, newest first.
  Future<List<MuhasabahEntry>> all() async {
    final db = await _db.database;
    final rows = await db.query(table, orderBy: 'entry_date DESC');
    return rows.map(MuhasabahEntry.fromRow).toList();
  }

  /// How many nights are on record — the figure that was always 1 before.
  Future<int> count() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }
}
