/// Storage doubles and a seeded device, shared by both backup harnesses.
///
/// ── Why this is shared rather than copied ──────────────────────────────
/// The backup rules are checked twice: by `tools/verify_backup.dart`, which runs
/// under plain `dart run` on any machine with the Dart SDK, and by
/// `test/unit/features/settings/backup_engine_test.dart`, which runs under
/// `flutter test`. Two harnesses exist because `flutter test` needs a working
/// Flutter toolchain and the script does not, so the script is what can be run in
/// a sandbox, over SSH, or by somebody who has only cloned the repo.
///
/// Both need a fake store and a device with a history on it. Keeping two copies
/// of those would mean two things that can be wrong, and — worse — two that can
/// quietly stop agreeing, so a rule could pass in one harness and fail in the
/// other for reasons that have nothing to do with the rule. The fixtures live
/// here once; the two files differ only in how they assert, which is the part
/// worth reading twice.
///
/// Nothing here imports Flutter, so the script can use it too.
library;

import 'package:mizan/features/settings/data/backup_engine.dart';

// ══════════════════════════════════════════════════════════════════════
//  STORAGE, IN MEMORY
// ══════════════════════════════════════════════════════════════════════

/// [BackupTables] over plain maps.
///
/// Deliberately faithful to sqflite in the two ways that could otherwise hide a
/// bug: [readAll] returns only the requested columns, and every row handed out is
/// a copy. A merge rule that mutated what it was given would be caught here,
/// rather than passing because it happened to edit the store in place.
class MemoryTables implements BackupTables {
  MemoryTables([Map<String, List<Map<String, Object?>>>? seed])
      : rows = {
          for (final e in (seed ?? const {}).entries)
            e.key: [for (final r in e.value) {...r}],
        };

  final Map<String, List<Map<String, Object?>>> rows;

  /// Tables whose reads should throw, standing in for a table missing from an
  /// older schema or a database file that will not open.
  final Set<String> unreadable = {};

  /// Makes [runInTransaction] throw, standing in for a database that cannot be
  /// written to at all.
  bool transactionsFail = false;

  @override
  Future<List<Map<String, Object?>>> readAll(
    String table,
    List<String> columns,
  ) async {
    _guard(table);
    return [
      for (final row in rows[table] ?? const <Map<String, Object?>>[])
        <String, Object?>{
          for (final c in columns)
            if (row.containsKey(c)) c: row[c],
        },
    ];
  }

  @override
  Future<Map<String, Object?>?> findByKey(
    String table,
    Map<String, Object?> key,
  ) async {
    _guard(table);
    final row = find(table, key);
    return row == null ? null : {...row};
  }

  @override
  Future<void> insertRow(String table, Map<String, Object?> row) async {
    (rows[table] ??= []).add({...row});
  }

  @override
  Future<void> updateRow(
    String table,
    Map<String, Object?> key,
    Map<String, Object?> values,
  ) async {
    find(table, key)?.addAll(values);
  }

  @override
  Future<void> runInTransaction(Future<void> Function() body) async {
    if (transactionsFail) throw StateError('database is locked');
    await body();
  }

  void _guard(String table) {
    if (unreadable.contains(table)) throw StateError('no such table: $table');
  }

  int count(String table) => rows[table]?.length ?? 0;

  /// The live row, for assertions. Returns the store's own map, so a test reads
  /// what a later merge would read.
  Map<String, Object?>? find(String table, Map<String, Object?> key) {
    for (final row in rows[table] ?? const <Map<String, Object?>>[]) {
      if (key.entries.every((e) => row[e.key] == e.value)) return row;
    }
    return null;
  }
}

class MemoryPrefs implements BackupPrefs {
  MemoryPrefs([Map<String, Object>? seed]) : values = {...?seed};

  final Map<String, Object> values;

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object value) async => values[key] = value;
}

// ══════════════════════════════════════════════════════════════════════
//  A DEVICE WITH A HISTORY ON IT
// ══════════════════════════════════════════════════════════════════════

/// Fixed so an assertion can name the exact `created_at` in the backup rather
/// than whatever the clock said mid-run.
final DateTime fixedNow = DateTime.parse('2026-08-25T09:00:00.000');

/// Builds the engine over the three given stores, with the clock pinned.
BackupEngine engineFor(
  MemoryTables main,
  MemoryTables discover,
  MemoryPrefs prefs, {
  List<String>? log,
}) =>
    BackupEngine(
      main: main,
      discover: discover,
      prefs: prefs,
      log: (message, error) => log?.add('$message: $error'),
      clock: () => fixedNow,
    );

/// The five written-record tables, as one reader's phone might hold them.
///
/// Three muhasabah nights, on purpose. One night proves nothing: the defect this
/// guards against (#100) keyed a night on something shared between nights, so
/// every entry replaced the one before it and a single-row fixture passed
/// happily while real entries were being lost.
///
/// Returned fresh from a function rather than held in a `const`, so one harness
/// mutating a restored row cannot change what the next one starts from.
Map<String, List<Map<String, Object?>>> seedMain() => {
      'reflections': [
        {
          'surah_number': 2,
          'ayah_number': 255,
          'reflection': 'His knowledge has no edge.',
          'saved_at': '2026-08-20T21:14:00.000',
        },
        {
          'surah_number': 18,
          'ayah_number': 10,
          'reflection': 'They asked for mercy first, then guidance.',
          'saved_at': '2026-08-21T22:02:00.000',
        },
      ],
      'muhasabah_entries': [
        {
          'entry_date': '2026-08-22',
          'for_allah': 'Prayed Fajr on time.',
          'nafs_pull': 'Wanted the last word in an argument.',
          'tomorrow': 'Let it go sooner.',
          'saved_at': '2026-08-22T23:10:00.000',
        },
        {
          'entry_date': '2026-08-23',
          'for_allah': 'Read with my mother.',
          'nafs_pull': 'Scrolled instead of sleeping.',
          'tomorrow': 'Phone out of the room.',
          'saved_at': '2026-08-23T23:40:00.000',
        },
        {
          'entry_date': '2026-08-24',
          'for_allah': 'Gave without being asked.',
          'nafs_pull': 'Wanted it noticed.',
          'tomorrow': 'Quietly.',
          'saved_at': '2026-08-24T22:55:00.000',
        },
      ],
      'hadith_reflections': [
        {
          'collection': 'bukhari',
          'number': 1,
          'reflection': 'Intention is the whole of it.',
          'saved_at': '2026-08-19T09:00:00.000',
        },
      ],
      'vocab_words': [
        {
          'arabic': 'رَحْمَة',
          'transliteration': 'rahmah',
          'meaning': 'mercy',
          'root': 'ر ح م',
          'insight': 'The womb shares the root.',
          'surah_number': 18,
          'ayah_number': 10,
          'surah_name': 'Al-Kahf',
          'saved_at': '2026-08-21T22:05:00.000',
          'review_count': 1,
          'next_review_at': '2026-08-26T22:05:00.000',
        },
        {
          'arabic': 'صَبْر',
          'transliteration': 'sabr',
          'meaning': 'patience',
          'root': 'ص ب ر',
          'insight': 'Holding, not enduring.',
          'surah_number': 2,
          'ayah_number': 153,
          'surah_name': 'Al-Baqarah',
          'saved_at': '2026-08-18T07:30:00.000',
          'review_count': 4,
          'next_review_at': '2026-09-02T07:30:00.000',
        },
      ],
      'layer_unlocks': [
        {
          'surah_number': 2,
          'ayah_number': 255,
          'layer_index': 0,
          'unlocked_at': '2026-08-20T21:00:00.000',
        },
        {
          'surah_number': 2,
          'ayah_number': 255,
          'layer_index': 1,
          'unlocked_at': '2026-08-20T21:06:00.000',
        },
        {
          'surah_number': 18,
          'ayah_number': 10,
          'layer_index': 0,
          'unlocked_at': '2026-08-21T21:55:00.000',
        },
      ],
    };

/// The second database. Two entries: one part-read with the quiz unattempted,
/// one finished — so the merge has both a row that can advance and a row that
/// cannot.
Map<String, List<Map<String, Object?>>> seedDiscover() => {
      'discover_progress': [
        {
          'entry_id': 'yusuf',
          'entry_type': 'prophet',
          'layers_unlocked': 3,
          'last_layer_unlocked_at': '2026-08-23T20:00:00.000',
          'quiz_passed': 0,
          'quiz_passed_at': null,
          'entry_completed': 0,
        },
        {
          'entry_id': 'abu-bakr',
          'entry_type': 'sahabi',
          'layers_unlocked': 5,
          'last_layer_unlocked_at': '2026-08-24T19:30:00.000',
          'quiz_passed': 1,
          'quiz_passed_at': '2026-08-24T19:45:00.000',
          'entry_completed': 1,
        },
      ],
    };

/// Every key in [prefPolicy], with a plausible value and the right type — so a
/// key added to the policy without being exportable shows up as a count that
/// does not match.
Map<String, Object> seedPrefs() => {
      'mizan_first_day': '2026-07-01',
      'mizan_days_recorded': 30,
      'mizan_longest_run': 12,
      'mizan_recent_days': <String>['2026-08-22', '2026-08-23', '2026-08-24'],
      'meezan_birth_date': '2001-03-14',
      'streak_count': 12,
      'streak_last_active_date': '2026-08-24',
      'last_opened_at': '2026-08-24T22:50:00.000',
      'last_muhasabah_date': '2026-08-24',
      'saved_ayat': <String>['2:255', '18:10'],
      'last_ayah': 10,
      'last_ayah_arabic': 'رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً',
      'last_ayah_translation': 'Our Lord, grant us mercy from Yourself',
      'last_surah': 18,
      'last_surah_name': 'Al-Kahf',
      'reader_layers_intro_seen': true,
    };

/// Rows across both seeded databases. Derived rather than written down, so
/// adding a fixture row cannot leave a stale total in either harness.
int seededRowCount() =>
    seedMain().values.fold<int>(0, (a, b) => a + b.length) +
    seedDiscover().values.fold<int>(0, (a, b) => a + b.length);

/// An engine over a freshly seeded device.
BackupEngine seededEngine({List<String>? log}) => engineFor(
      MemoryTables(seedMain()),
      MemoryTables(seedDiscover()),
      MemoryPrefs(seedPrefs()),
      log: log,
    );

/// The backup text a seeded device produces. The starting point for every
/// restore scenario.
Future<String> seededBackupJson() async => (await seededEngine().export()).json;
