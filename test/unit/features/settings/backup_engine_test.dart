/// The backup merge policy, rule by rule.
///
/// ── Why these tests are worth having ──────────────────────────────────
/// Everything else in the app fails loudly. A wrong rule here fails silently and
/// permanently: it keeps the shorter streak, or overwrites tonight's muhasabah
/// with last week's, and the reader discovers weeks later that something they
/// wrote is gone. There is no server copy to fall back on, so a regression in
/// this file's subject matter is unrecoverable for whoever hits it.
///
/// These run against [BackupEngine], which takes its storage as [BackupTables]
/// and [BackupPrefs] rather than touching sqflite or SharedPreferences. So the
/// code under test is the code that ships — only the storage is swapped. The
/// fakes and the seeded device come from `test/support/backup_fixtures.dart`,
/// shared with `tools/verify_backup.dart`, which checks the same rules from the
/// command line for machines with no Flutter toolchain.
///
/// What is *not* covered here, deliberately: that sqflite reads and writes the
/// rows correctly, and that the two schemas have the columns the specs name.
/// Those need a device. Everything between reading a row and writing it back is
/// covered.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/settings/data/backup_engine.dart';

import '../../../support/backup_fixtures.dart';

void main() {
  group('a backup survives a wiped phone', () {
    test('the export counts what the device actually holds', () async {
      final summary = await seededEngine().export();

      expect(summary.counts, {
        'Ayah reflections': 2,
        'Muhasabah nights': 3,
        'Hadith reflections': 1,
        'Saved words': 2,
        'Layers opened': 3,
        'Discover progress': 2,
        prefsLabel: prefPolicy.length,
      });
      expect(summary.totalRecords, seededRowCount() + prefPolicy.length);
      expect(summary.createdAt, fixedNow);
    });

    test('a fresh export reads back through inspect()', () async {
      final summary = await seededEngine().export();
      final preview = BackupEngine.inspect(summary.json);

      expect(preview.ok, isTrue, reason: preview.error);
      // The header the reader is asked to trust has to agree with the payload,
      // or they confirm one thing and get another.
      expect(preview.records, summary.totalRecords);
      expect(preview.createdAt, fixedNow);
    });

    test('every row comes back onto an empty device', () async {
      final json = await seededBackupJson();
      final main = MemoryTables();
      final discover = MemoryTables();
      final report =
          await engineFor(main, discover, MemoryPrefs()).restore(json);

      expect(report.failed, isFalse, reason: report.error);
      expect(report.added, seededRowCount());
      expect(report.updated, 0);
      expect(report.skipped, 0);
      expect(report.changedAnything, isTrue);

      for (final spec in mainTableSpecs) {
        final before = seedMain()[spec.name]!;
        expect(main.count(spec.name), before.length,
            reason: '${spec.name} lost rows');
        for (final row in before) {
          final got =
              main.find(spec.name, {for (final k in spec.keys) k: row[k]});
          expect(got, isNotNull, reason: '${spec.name} row missing');
          for (final c in spec.columns) {
            expect(got![c], row[c], reason: '${spec.name}.$c differs');
          }
        }
      }
      expect(discover.count('discover_progress'), 2);
    });

    // The regression in #100: nights were keyed on something shared between
    // nights, so each entry replaced the one before it. A fixture with one night
    // passes that bug happily, which is why there are three here.
    test('three different nights of muhasabah all survive', () async {
      final json = await seededBackupJson();
      final main = MemoryTables();
      await engineFor(main, MemoryTables(), MemoryPrefs()).restore(json);

      expect(main.count('muhasabah_entries'), 3);
      for (final night in seedMain()['muhasabah_entries']!) {
        final got =
            main.find('muhasabah_entries', {'entry_date': night['entry_date']});
        expect(got, isNotNull, reason: '${night['entry_date']} is missing');
        expect(got!['for_allah'], night['for_allah'],
            reason: '${night['entry_date']} has another night\'s words');
      }
    });

    test('preferences keep their types, not just their values', () async {
      final json = await seededBackupJson();
      final prefs = MemoryPrefs();
      final report =
          await engineFor(MemoryTables(), MemoryTables(), prefs).restore(json);

      expect(report.prefsWritten, prefPolicy.length);
      // A String written to a key the app reads with getInt throws at the point
      // of use, a long way from here — so the type is the assertion.
      expect(prefs.read('streak_count'), isA<int>());
      expect(prefs.read('streak_count'), 12);
      expect(prefs.read('reader_layers_intro_seen'), isA<bool>());
      expect(prefs.read('mizan_recent_days'), isA<List<String>>());
      expect(prefs.read('mizan_recent_days'), hasLength(3));
      expect(prefs.read('last_ayah_arabic'),
          'رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً');
    });
  });

  group('restoring the same backup twice', () {
    test('changes nothing and says so', () async {
      final main = MemoryTables(seedMain());
      final discover = MemoryTables(seedDiscover());
      final prefs = MemoryPrefs(seedPrefs());
      final json = (await engineFor(main, discover, prefs).export()).json;

      final report = await engineFor(main, discover, prefs).restore(json);

      expect(report.added, 0);
      expect(report.updated, 0);
      expect(report.skipped, 0);
      expect(report.unchanged, seededRowCount());
      expect(report.prefsWritten, 0);
      // This is what stops the reader pressing restore again and again.
      expect(report.changedAnything, isFalse);
      expect(main.count('muhasabah_entries'), 3, reason: 'nights duplicated');
      expect(main.count('vocab_words'), 2, reason: 'words duplicated');
    });
  });

  group('merging an old backup into a phone still in use', () {
    /// The device disagrees with the backup in every way a real phone might.
    Future<(MemoryTables, MemoryTables, MemoryPrefs, RestoreReport)> merge()
        async {
      final json = await seededBackupJson();

      final main = MemoryTables({
        'reflections': [
          {
            'surah_number': 2,
            'ayah_number': 255,
            'reflection': 'Rewritten on the 26th, and better.',
            'saved_at': '2026-08-26T20:00:00.000',
          },
        ],
        'muhasabah_entries': [
          {
            'entry_date': '2026-08-26',
            'for_allah': 'Sat with it properly.',
            'nafs_pull': 'Nothing I want to write down.',
            'tomorrow': 'Again.',
            'saved_at': '2026-08-26T23:00:00.000',
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
            'review_count': 5,
            'next_review_at': '2026-09-20T22:05:00.000',
          },
        ],
        'layer_unlocks': [
          {
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
      expect(report.failed, isFalse, reason: report.error);
      return (main, discover, prefs, report);
    }

    test('written prose: the later draft wins, whichever side holds it',
        () async {
      final (main, _, _, _) = await merge();

      expect(
        main.find('reflections', {'surah_number': 2, 'ayah_number': 255})?[
            'reflection'],
        'Rewritten on the 26th, and better.',
        reason: 'an older backup overwrote a newer reflection',
      );
      expect(
        main.find('reflections', {'surah_number': 18, 'ayah_number': 10})?[
            'reflection'],
        'They asked for mercy first, then guidance.',
        reason: "the backup's own reflection was not added",
      );
    });

    test('nothing on the device is deleted', () async {
      final (main, _, _, _) = await merge();

      expect(main.count('muhasabah_entries'), 4);
      expect(main.find('muhasabah_entries', {'entry_date': '2026-08-26'}),
          isNotNull,
          reason: "the device's own night was lost");
      expect(main.find('muhasabah_entries', {'entry_date': '2026-08-22'}),
          isNotNull,
          reason: "the backup's night was not restored");
    });

    test('saved-word review progress is never rewound', () async {
      final (main, _, _, _) = await merge();

      // The device's copy carries live spaced-repetition state the backup
      // predates, so the backup adds words and never touches the ones here.
      expect(
        main.find('vocab_words',
            {'arabic': 'رَحْمَة', 'surah_number': 18, 'ayah_number': 10})?[
            'review_count'],
        5,
      );
      expect(main.count('vocab_words'), 2);
    });

    test('a layer opened when it first opened', () async {
      final (main, _, _, _) = await merge();

      expect(
        main.find('layer_unlocks',
            {'surah_number': 2, 'ayah_number': 255, 'layer_index': 0})?[
            'unlocked_at'],
        '2026-08-20T21:00:00.000',
        reason: 'a reinstall date overwrote the real unlock date',
      );
    });

    test('Discover progress moves forward on each field independently',
        () async {
      final (_, discover, _, _) = await merge();
      final yusuf = discover.find(
          'discover_progress', {'entry_id': 'yusuf', 'entry_type': 'prophet'});

      expect(yusuf?['layers_unlocked'], 3, reason: 'layers went backwards');
      expect(yusuf?['quiz_passed'], 1, reason: 'a passed quiz was un-passed');
      // The two timestamps are not symmetric, and the names say why:
      // last_layer_unlocked_at is the most recent unlock, quiz_passed_at is the
      // first pass.
      expect(yusuf?['last_layer_unlocked_at'], '2026-08-26T18:00:00.000');
      expect(yusuf?['quiz_passed_at'], '2026-08-26T18:10:00.000');
      expect(
          discover.find('discover_progress',
              {'entry_id': 'abu-bakr', 'entry_type': 'sahabi'}),
          isNotNull);
    });

    test('each preference resolves by its own policy', () async {
      final (_, _, prefs, _) = await merge();

      expect(prefs.read('streak_count'), 40, reason: 'max kept the smaller');
      expect(prefs.read('mizan_first_day'), '2026-07-01',
          reason: 'min kept the later date');
      expect(prefs.read('mizan_days_recorded'), 30);
      expect(prefs.read('mizan_recent_days'), hasLength(4),
          reason: 'union dropped one side');
      expect(prefs.read('saved_ayat'), hasLength(3));
      expect(prefs.read('last_ayah'), 200,
          reason: 'fillOnly overwrote the reading position');
      expect(prefs.read('meezan_birth_date'), '1999-12-31');
      expect(prefs.read('reader_layers_intro_seen'), true,
          reason: 'orFlag un-happened a flag');
      expect(prefs.read('streak_last_active_date'), '2026-08-26');
    });
  });

  group('text that is not a backup', () {
    // The backup arrives from the clipboard, so it can be anything at all. Each
    // message has to name something the reader can act on.
    const cases = <String, (String, String)>{
      'an empty clipboard': ('   ', 'clipboard is empty'),
      'truncated text': ('{"mizan.backup":1,"tables":{"refl', 'incomplete'),
      'a JSON array': ('[1,2,3]', "doesn't look like"),
      'JSON that is not a backup': (
        '{"note":"shopping list"}',
        "doesn't look like"
      ),
      'an unversioned object': ('{"mizan.backup":"one"}', "doesn't look like"),
      'a backup from a newer app': (
        '{"mizan.backup":99,"tables":{}}',
        'newer version'
      ),
    };

    cases.forEach((name, expectation) {
      final (raw, wanted) = expectation;

      test('$name is refused, with a reason', () {
        final preview = BackupEngine.inspect(raw);
        expect(preview.ok, isFalse);
        expect(preview.error, contains(wanted));
        expect(preview.counts, isEmpty);
      });

      test('$name writes nothing and leaves the device alone', () async {
        final main = MemoryTables(seedMain());
        final prefs = MemoryPrefs(seedPrefs());
        final report =
            await engineFor(main, MemoryTables(), prefs).restore(raw);

        expect(report.failed, isTrue);
        expect(report.total, 0);
        expect(report.prefsWritten, 0);
        expect(main.count('muhasabah_entries'), 3);
      });
    });
  });

  group('a backup that is damaged rather than fake', () {
    // A valid envelope with individually broken rows. Each bad row must cost
    // itself and nothing else — the difference between "skipped 2" and losing
    // the whole restore to one exception.
    String damaged() => jsonEncode({
          'mizan.backup': 1,
          'created_at': fixedNow.toIso8601String(),
          'counts': {'Muhasabah nights': 4},
          'prefs': {
            'streak_count': {'t': 'i', 'v': 9},
            'mizan_recent_days': {'t': 's', 'v': 'not-a-list'},
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
              {
                'for_allah': 'Orphan row.',
                'saved_at': '2026-09-02T22:00:00.000',
              },
              'a string where a row should be',
              {
                'entry_date': '2026-09-03',
                'for_allah': 'Also good.',
                'nafs_pull': '-',
                'tomorrow': '-',
                'saved_at': '2026-09-03T22:00:00.000',
                'mood_rating': 7,
              },
            ],
            'future_table': [
              {'whatever': 1}
            ],
          },
        });

    test('good rows land and bad rows are counted, not fatal', () async {
      final main = MemoryTables();
      final report =
          await engineFor(main, MemoryTables(), MemoryPrefs()).restore(damaged());

      expect(report.failed, isFalse, reason: report.error);
      expect(report.added, 2);
      expect(report.skipped, 2, reason: 'a missing key and a non-object row');
      expect(main.count('muhasabah_entries'), 2);
    });

    test('unknown tables and columns are dropped before the store', () async {
      final main = MemoryTables();
      await engineFor(main, MemoryTables(), MemoryPrefs()).restore(damaged());

      // An unknown column reaching sqflite would abort the transaction for every
      // row after it, so the whitelist runs first.
      expect(
          main
              .find('muhasabah_entries', {'entry_date': '2026-09-03'})!
              .containsKey('mood_rating'),
          isFalse);
      expect(main.count('future_table'), 0);
    });

    test('one unmergeable preference does not stop the others', () async {
      final prefs = MemoryPrefs();
      await engineFor(MemoryTables(), MemoryTables(), prefs).restore(damaged());

      expect(prefs.read('streak_count'), 9);
      expect(prefs.read('mizan_recent_days'), isNull,
          reason: 'a string was written to a list key');
      expect(prefs.read('theme_mode'), isNull,
          reason: 'a key outside prefPolicy was restored');
    });
  });

  group('when part of the device will not answer', () {
    test('an unreadable table exports as empty, and is reported', () async {
      final log = <String>[];
      final brokenDiscover = MemoryTables(seedDiscover())
        ..unreadable.add('discover_progress');

      final summary = await engineFor(
              MemoryTables(seedMain()), brokenDiscover, MemoryPrefs(seedPrefs()),
              log: log)
          .export();

      expect(summary.counts['Discover progress'], 0);
      // Everything else still travels: a second database that will not open must
      // not cost the reader their written record.
      expect(summary.counts['Muhasabah nights'], 3);
      expect(summary.counts['Ayah reflections'], 2);
      expect(log.join(' '), contains('discover_progress'),
          reason: 'the failure was swallowed silently');
    });

    test('a table missing from an older schema costs only itself', () async {
      final oldSchema = MemoryTables(seedMain())
        ..unreadable.add('hadith_reflections');

      final summary =
          await engineFor(oldSchema, MemoryTables(seedDiscover()), MemoryPrefs())
              .export();

      expect(summary.counts['Hadith reflections'], 0);
      expect(summary.counts['Ayah reflections'], 2);
      expect(summary.counts['Saved words'], 2);
    });

    test('a main store that cannot be written still lets the rest through',
        () async {
      final json = await seededBackupJson();
      final lockedMain = MemoryTables()..transactionsFail = true;
      final discover = MemoryTables();
      final prefs = MemoryPrefs();

      final report = await engineFor(lockedMain, discover, prefs).restore(json);

      expect(report.failed, isTrue);
      // The reader has to be told the one thing they would otherwise fear.
      expect(report.error, contains('Nothing was deleted'));
      expect(lockedMain.count('muhasabah_entries'), 0);
      // Separate stores, so recovering them is strictly better than recovering
      // nothing.
      expect(discover.count('discover_progress'), 2);
      expect(report.prefsWritten, prefPolicy.length);
    });
  });
}
