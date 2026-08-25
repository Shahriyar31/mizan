/// Proof that a backup survives a round trip, run from the command line.
///
///     dart run tools/verify_backup.dart
///
/// Exits 0 when every rule holds, or 1 with a list of what broke — so it can be
/// put in front of a commit.
///
/// ── Why this exists as a script ────────────────────────────────────────
/// Backup and restore is the one feature whose failure is silent and permanent.
/// A backwards comparison in the merge policy does not crash and shows no error;
/// it quietly keeps the shorter streak, or overwrites tonight's muhasabah with
/// last week's, and the reader finds out much later that something they wrote is
/// gone. "It looked fine on the phone" is not evidence about any of that.
///
/// It is a script rather than only a `flutter test` because it has to be runnable
/// where Flutter is not. `sqflite` has no desktop implementation and
/// `shared_preferences` needs platform channels, so code that touched either
/// directly could only be checked on a device. [BackupEngine] therefore takes its
/// storage as [BackupTables] and [BackupPrefs]; this file supplies the in-memory
/// versions from `test/support/backup_fixtures.dart` and runs the real export and
/// the real restore against them. What is verified below is the production code
/// path with the storage swapped — not a re-implementation, which would agree
/// with itself while both were wrong.
///
/// `test/unit/features/settings/backup_engine_test.dart` covers the same rules
/// with `expect()` and shares these fixtures, so the two cannot drift.
///
/// ── What it does not cover, stated plainly ─────────────────────────────
/// That sqflite reads and writes the rows correctly, and that the two schemas
/// really have the columns the specs name. Those need a device. Everything
/// between reading a row and writing it back is checked here.
library;

// A command-line report is the whole output of this file, so print is correct.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:mizan/features/settings/data/backup_engine.dart';

// Reaching into test/ is deliberate: the fake store and the seeded device are
// fixtures, and a second copy of a fixture is a second thing that can be wrong.
import '../test/support/backup_fixtures.dart';

Future<void> main() async {
  await roundTrip();
  await restoringTwice();
  await mergeNeverLoses();
  await malformedInput();
  await failureIsContained();

  print('');
  if (_failures.isEmpty) {
    print('\x1B[32m✓ $_passed checks passed.\x1B[0m');
    exit(0);
  }
  print('\x1B[31m✗ ${_failures.length} of ${_failures.length + _passed} '
      'checks failed:\x1B[0m');
  for (final f in _failures) {
    print('  • $f');
  }
  exit(1);
}

// ══════════════════════════════════════════════════════════════════════
//  SEED → EXPORT → WIPE → RESTORE
// ══════════════════════════════════════════════════════════════════════

/// The headline claim of the feature: a phone can be replaced.
Future<void> roundTrip() async {
  section('A backup survives a wiped phone');

  final summary = await seededEngine().export();

  equals(
      'export counts 2 ayah reflections', summary.counts['Ayah reflections'], 2);
  equals(
      'export counts 3 muhasabah nights', summary.counts['Muhasabah nights'], 3);
  equals('export counts 1 hadith reflection',
      summary.counts['Hadith reflections'], 1);
  equals('export counts 2 saved words', summary.counts['Saved words'], 2);
  equals('export counts 3 layers opened', summary.counts['Layers opened'], 3);
  equals('export counts 2 Discover entries',
      summary.counts['Discover progress'], 2);
  equals('every policy preference was exported', summary.counts[prefsLabel],
      prefPolicy.length);
  equals('totalRecords adds up', summary.totalRecords,
      seededRowCount() + prefPolicy.length);
  check('the text is not empty', summary.bytes > 500, '${summary.bytes} bytes');

  // Read back the way the reader does — through the header, not the internals.
  final preview = BackupEngine.inspect(summary.json);
  check('a fresh export inspects as valid', preview.ok, preview.error);
  equals('the preview agrees with the export', preview.records,
      summary.totalRecords);
  equals('the preview carries the date', preview.createdAt, fixedNow);

  // The phone is gone. Everything below is a new, empty device.
  final main = MemoryTables();
  final discover = MemoryTables();
  final prefs = MemoryPrefs();
  final report = await engineFor(main, discover, prefs).restore(summary.json);

  check('the restore did not fail', !report.failed, report.error);
  equals('every row was added', report.added, seededRowCount());
  equals('nothing was updated', report.updated, 0);
  equals('nothing was skipped', report.skipped, 0);
  equals(
      'every preference was written', report.prefsWritten, prefPolicy.length);
  check('the screen would say something changed', report.changedAnything);

  // ── The regression that cost real entries ─────────────────────────
  equals('all three muhasabah nights came back',
      main.count('muhasabah_entries'), 3);
  for (final night in ['2026-08-22', '2026-08-23', '2026-08-24']) {
    final row = main.find('muhasabah_entries', {'entry_date': night});
    final original = seedMain()['muhasabah_entries']!
        .firstWhere((r) => r['entry_date'] == night);
    check(
        '$night is present with its own words',
        row != null && row['for_allah'] == original['for_allah'],
        row == null ? 'missing' : 'got "${row['for_allah']}"');
  }

  // ── Everything else, column by column ─────────────────────────────
  for (final spec in mainTableSpecs) {
    final before = seedMain()[spec.name]!;
    equals('${spec.name}: all ${before.length} rows back',
        main.count(spec.name), before.length);
    for (final row in before) {
      final key = {for (final k in spec.keys) k: row[k]};
      final got = main.find(spec.name, key);
      check(
          '${spec.name}: $key restored intact',
          got != null && spec.columns.every((c) => got[c] == row[c]),
          got == null ? 'row missing' : 'a column differs');
    }
  }

  final yusuf = discover
      .find('discover_progress', {'entry_id': 'yusuf', 'entry_type': 'prophet'});
  equals("Yusuf's three layers came back", yusuf?['layers_unlocked'], 3);
  check('an unattempted quiz stayed unattempted',
      yusuf?['quiz_passed_at'] == null);

  // Types matter as much as values: a String written to a key the app reads with
  // getInt throws at the point of use, a long way from here.
  equals('streak_count came back as 12', prefs.read('streak_count'), 12);
  check('streak_count is typed as int', prefs.read('streak_count') is int);
  check('reader_layers_intro_seen is typed as bool',
      prefs.read('reader_layers_intro_seen') is bool);
  check('mizan_recent_days is a list of strings',
      prefs.read('mizan_recent_days') is List<String>);
  equals('mizan_recent_days has all three days',
      (prefs.read('mizan_recent_days') as List).length, 3);
  equals('the Arabic of the last ayah is unmangled',
      prefs.read('last_ayah_arabic'), 'رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً');
}

/// The report promises a second restore is safe. This is that promise.
Future<void> restoringTwice() async {
  section('Restoring the same backup twice changes nothing');

  final main = MemoryTables(seedMain());
  final discover = MemoryTables(seedDiscover());
  final prefs = MemoryPrefs(seedPrefs());
  final json = (await engineFor(main, discover, prefs).export()).json;

  // Back into the very device it came from.
  final report = await engineFor(main, discover, prefs).restore(json);

  equals('nothing added', report.added, 0);
  equals('nothing updated', report.updated, 0);
  equals('nothing skipped', report.skipped, 0);
  equals(
      'every row reported as already here', report.unchanged, seededRowCount());
  equals('no preference rewritten', report.prefsWritten, 0);
  check('the screen would say nothing changed', !report.changedAnything);
  equals('still three muhasabah nights, not six',
      main.count('muhasabah_entries'), 3);
  equals('still two saved words', main.count('vocab_words'), 2);
}

// ══════════════════════════════════════════════════════════════════════
//  THE MERGE
// ══════════════════════════════════════════════════════════════════════

/// An old backup pasted into a phone that has been in use since. Every rule here
/// exists so that nothing on either side is lost.
Future<void> mergeNeverLoses() async {
  section('Merging an old backup into a phone still in use');

  final json = await seededBackupJson();

  // The device has kept going, and disagrees in every way that matters.
  final main = MemoryTables({
    'reflections': [
      {
        // Rewritten since the backup, so the device holds the later draft.
        'surah_number': 2,
        'ayah_number': 255,
        'reflection': 'Rewritten on the 26th, and better.',
        'saved_at': '2026-08-26T20:00:00.000',
      },
    ],
    'muhasabah_entries': [
      {
        // A night the backup has never heard of. It must still be here after.
        'entry_date': '2026-08-26',
        'for_allah': 'Sat with it properly.',
        'nafs_pull': 'Nothing I want to write down.',
        'tomorrow': 'Again.',
        'saved_at': '2026-08-26T23:00:00.000',
      },
    ],
    'vocab_words': [
      {
        // Reviewed four more times since the backup was taken.
        'arabic': 'رَحْمَة',
        'transliteration': 'rahmah',
        'meaning': 'mercy',
        'root': 'ر ح م',
        'insight': 'The womb shares the root.',
        'surah_number': 18,
        'ayah_number': 10,
        'surah_name': 'Al-Kahf',
        'saved_at': '2026-08-21T22:05:00.000',
        'review_count': 5,
        'next_review_at': '2026-09-20T22:05:00.000',
      },
    ],
    'layer_unlocks': [
      {
        // Re-unlocked after a reinstall, so the device's date is later and is
        // not when the layer actually opened.
        'surah_number': 2,
        'ayah_number': 255,
        'layer_index': 0,
        'unlocked_at': '2026-08-26T10:00:00.000',
      },
    ],
  });

  final discover = MemoryTables({
    'discover_progress': [
      {
        // Behind on layers, ahead on the quiz. Each field moves on its own.
        'entry_id': 'yusuf',
        'entry_type': 'prophet',
        'layers_unlocked': 1,
        'last_layer_unlocked_at': '2026-08-26T18:00:00.000',
        'quiz_passed': 1,
        'quiz_passed_at': '2026-08-26T18:10:00.000',
        'entry_completed': 0,
      },
    ],
  });

  final prefs = MemoryPrefs({
    'streak_count': 40,
    'mizan_first_day': '2026-08-01',
    'mizan_days_recorded': 12,
    'mizan_recent_days': <String>['2026-08-26'],
    'saved_ayat': <String>['36:1'],
    'last_ayah': 200,
    'last_surah': 36,
    'meezan_birth_date': '1999-12-31',
    'reader_layers_intro_seen': false,
    'streak_last_active_date': '2026-08-26',
  });

  final report = await engineFor(main, discover, prefs).restore(json);
  check('the restore did not fail', !report.failed, report.error);

  // Written prose: the later draft wins, whichever side it is on.
  equals(
      "the device's newer reflection was kept",
      main.find(
          'reflections', {'surah_number': 2, 'ayah_number': 255})?['reflection'],
      'Rewritten on the 26th, and better.');
  equals(
      "the backup's reflection for 18:10 was added",
      main.find(
          'reflections', {'surah_number': 18, 'ayah_number': 10})?['reflection'],
      'They asked for mercy first, then guidance.');

  // Nothing is deleted, ever.
  equals("four muhasabah nights — three restored plus the device's own",
      main.count('muhasabah_entries'), 4);
  check("the device's own night is untouched",
      main.find('muhasabah_entries', {'entry_date': '2026-08-26'}) != null);
  check("the backup's 22nd came back",
      main.find('muhasabah_entries', {'entry_date': '2026-08-22'}) != null);

  // Review progress is live data that the backup predates.
  equals(
      'four extra reviews were not rewound',
      main.find('vocab_words', {
        'arabic': 'رَحْمَة',
        'surah_number': 18,
        'ayah_number': 10
      })?['review_count'],
      5);
  equals(
      'the second word was added from the backup', main.count('vocab_words'), 2);

  // A layer opened when it first opened.
  equals(
      'the earlier unlock date won',
      main.find('layer_unlocks', {
        'surah_number': 2,
        'ayah_number': 255,
        'layer_index': 0
      })?['unlocked_at'],
      '2026-08-20T21:00:00.000');

  // Discover moves forward on each field independently.
  final yusuf = discover
      .find('discover_progress', {'entry_id': 'yusuf', 'entry_type': 'prophet'});
  equals('layers advanced 1 → 3', yusuf?['layers_unlocked'], 3);
  equals('the quiz stayed passed', yusuf?['quiz_passed'], 1);
  equals('the most recent unlock is the later of the two',
      yusuf?['last_layer_unlocked_at'], '2026-08-26T18:00:00.000');
  equals('the pass date is the first one', yusuf?['quiz_passed_at'],
      '2026-08-26T18:10:00.000');
  check(
      'the entry the device had never opened was added',
      discover.find('discover_progress',
              {'entry_id': 'abu-bakr', 'entry_type': 'sahabi'}) !=
          null);

  // Preferences, one rule each.
  equals('the longer streak was kept (max)', prefs.read('streak_count'), 40);
  equals('the earlier first day won (min)', prefs.read('mizan_first_day'),
      '2026-07-01');
  equals("the backup's higher day count won (max)",
      prefs.read('mizan_days_recorded'), 30);
  equals('recorded days are the union of both',
      (prefs.read('mizan_recent_days') as List).length, 4);
  equals('saved ayat are the union of both',
      (prefs.read('saved_ayat') as List).length, 3);
  equals('the reading position was left alone (fillOnly)',
      prefs.read('last_ayah'), 200);
  equals('the birth date already on the phone was kept (fillOnly)',
      prefs.read('meezan_birth_date'), '1999-12-31');
  equals('a flag that happened cannot un-happen (orFlag)',
      prefs.read('reader_layers_intro_seen'), true);
  equals('the later active date was kept (max)',
      prefs.read('streak_last_active_date'), '2026-08-26');
}

// ══════════════════════════════════════════════════════════════════════
//  UNTRUSTED TEXT
// ══════════════════════════════════════════════════════════════════════

/// The backup arrives as text the reader pasted, so it can be anything at all.
Future<void> malformedInput() async {
  section('Text that is not a backup');

  for (final (name, raw, wanted) in <(String, String, String)>[
    ('an empty clipboard', '   ', 'clipboard is empty'),
    ('truncated text', '{"mizan.backup":1,"tables":{"refl', 'incomplete'),
    ('a JSON array', '[1,2,3]', "doesn't look like"),
    (
      'JSON that is not a backup',
      '{"note":"shopping list"}',
      "doesn't look like"
    ),
    ('an unversioned object', '{"mizan.backup":"one"}', "doesn't look like"),
    (
      'a backup from a newer app',
      '{"mizan.backup":99,"tables":{}}',
      'newer version'
    ),
  ]) {
    final preview = BackupEngine.inspect(raw);
    check('$name is refused on inspection', !preview.ok);
    check('$name says why in words a reader can act on',
        preview.error?.contains(wanted) ?? false, preview.error);

    final main = MemoryTables(seedMain());
    final report =
        await engineFor(main, MemoryTables(), MemoryPrefs()).restore(raw);
    check('$name writes nothing', report.failed && report.total == 0);
    equals('$name leaves the device alone', main.count('muhasabah_entries'), 3);
  }

  section('A backup that is damaged rather than fake');

  // A valid envelope with individually broken rows. Each bad row costs itself
  // and nothing else — that is the difference between "skipped 2" and losing the
  // whole restore to one exception.
  final damaged = jsonEncode({
    'mizan.backup': 1,
    'created_at': fixedNow.toIso8601String(),
    'counts': {'Muhasabah nights': 4},
    'prefs': {
      'streak_count': {'t': 'i', 'v': 9},
      // A type that disagrees with what the app writes for this key.
      'mizan_recent_days': {'t': 's', 'v': 'not-a-list'},
      // A key no policy mentions: must not be written just because it is there.
      'theme_mode': {'t': 's', 'v': 'dark'},
    },
    'tables': {
      'muhasabah_entries': [
        {
          'entry_date': '2026-09-01',
          'for_allah': 'Good row.',
          'nafs_pull': '-',
          'tomorrow': '-',
          'saved_at': '2026-09-01T22:00:00.000',
        },
        // No entry_date, so nothing identifies which night this is.
        {'for_allah': 'Orphan row.', 'saved_at': '2026-09-02T22:00:00.000'},
        // Not an object at all.
        'a string where a row should be',
        // An unknown column, from a hand-edited or newer backup.
        {
          'entry_date': '2026-09-03',
          'for_allah': 'Also good.',
          'nafs_pull': '-',
          'tomorrow': '-',
          'saved_at': '2026-09-03T22:00:00.000',
          'mood_rating': 7,
        },
      ],
      // A table this version does not know about.
      'future_table': [
        {'whatever': 1}
      ],
    },
  });

  final main = MemoryTables();
  final prefs = MemoryPrefs();
  final report = await engineFor(main, MemoryTables(), prefs).restore(damaged);

  check('a damaged backup still restores what it can', !report.failed,
      report.error);
  equals('the two good rows landed', report.added, 2);
  equals('the two bad rows were skipped', report.skipped, 2);
  equals('the unknown table was ignored', main.count('future_table'), 0);
  check(
      'the unknown column was dropped before the store',
      main
              .find('muhasabah_entries', {'entry_date': '2026-09-03'})
              ?.containsKey('mood_rating') ==
          false);
  equals('the good preference was written', prefs.read('streak_count'), 9);
  check('the wrongly-typed preference was left alone',
      prefs.read('mizan_recent_days') == null);
  check('a preference outside the policy was not written',
      prefs.read('theme_mode') == null);
}

// ══════════════════════════════════════════════════════════════════════
//  CONTAINMENT
// ══════════════════════════════════════════════════════════════════════

/// One store failing must cost that store only.
Future<void> failureIsContained() async {
  section('When part of the device will not answer');

  // Export, with the Discover database refusing to open.
  final log = <String>[];
  final brokenDiscover = MemoryTables(seedDiscover())
    ..unreadable.add('discover_progress');
  final summary = await engineFor(
          MemoryTables(seedMain()), brokenDiscover, MemoryPrefs(seedPrefs()),
          log: log)
      .export();

  equals('Discover exports as empty rather than failing',
      summary.counts['Discover progress'], 0);
  equals('everything written is still there',
      summary.counts['Muhasabah nights'], 3);
  check('the failure was reported, not swallowed silently',
      log.any((l) => l.contains('discover_progress')), log.join(' | '));

  // A table missing from an older schema, mid-export.
  final oldSchema = MemoryTables(seedMain())
    ..unreadable.add('hadith_reflections');
  final partial =
      await engineFor(oldSchema, MemoryTables(seedDiscover()), MemoryPrefs())
          .export();
  equals('the missing table is empty', partial.counts['Hadith reflections'], 0);
  equals(
      'the tables around it are intact', partial.counts['Ayah reflections'], 2);

  // Restore, with the main database refusing to accept a transaction. Prefs and
  // Discover are separate stores and should still come back.
  final json = await seededBackupJson();
  final lockedMain = MemoryTables()..transactionsFail = true;
  final discover = MemoryTables();
  final prefs = MemoryPrefs();
  final report = await engineFor(lockedMain, discover, prefs).restore(json);

  check('the reader is told something went wrong', report.failed);
  check('and told that nothing was deleted',
      report.error?.contains('Nothing was deleted') ?? false, report.error);
  equals('Discover was still restored', discover.count('discover_progress'), 2);
  equals('preferences were still restored', report.prefsWritten,
      prefPolicy.length);
  equals(
      'the main store was left empty', lockedMain.count('muhasabah_entries'), 0);
}

// ══════════════════════════════════════════════════════════════════════
//  A VERY SMALL HARNESS
// ══════════════════════════════════════════════════════════════════════

int _passed = 0;
final List<String> _failures = [];
String _section = '';

void section(String name) {
  _section = name;
  print('\n\x1B[1m$name\x1B[0m');
}

void check(String what, bool ok, [String? detail]) {
  if (ok) {
    _passed++;
    print('  \x1B[32m✓\x1B[0m $what');
  } else {
    _failures.add('$_section → $what${detail == null ? '' : ' ($detail)'}');
    print('  \x1B[31m✗ $what\x1B[0m${detail == null ? '' : '  — $detail'}');
  }
}

void equals(String what, Object? actual, Object? expected) {
  check(what, actual == expected, 'expected $expected, got $actual');
}
