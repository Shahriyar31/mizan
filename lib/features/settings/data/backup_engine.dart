/// The backup rules, with no database and no Flutter attached.
///
/// ── Why this is a separate file ─────────────────────────────────────────
/// [BackupService] used to hold both the rules and the plumbing. That made the
/// rules unprovable: every one of them ran only behind `sqflite`, which needs a
/// real device or an FFI backend, so the merge policy — the part where somebody's
/// writing gets silently lost if a comparison is backwards — could only be
/// checked by installing the app and trying it.
///
/// The rules are the risky part, so they live here, where they can be executed
/// against an in-memory store by `tools/verify_backup.dart` and by
/// `test/unit/features/settings/backup_engine_test.dart`. Nothing in this file
/// imports Flutter, `sqflite`, or `shared_preferences`. Storage arrives as
/// [BackupTables] and [BackupPrefs], and the only difference between a test and a
/// phone is which implementation is passed in — so what the tests prove is the
/// code that actually runs, not a copy of it.
///
/// [BackupService] is now the adapter: it builds the sqflite and
/// SharedPreferences implementations and hands them to [BackupEngine]. The
/// reasoning for *what* is backed up and *why* each rule is what it is stays in
/// that file's header, which is the one a reader will open first.
library;

import 'dart:convert';

// ══════════════════════════════════════════════════════════════════════
//  WHAT A BACKUP CONTAINS
// ══════════════════════════════════════════════════════════════════════

/// One backed-up table: which columns travel, and what identifies a row.
///
/// The column list is a whitelist, not documentation. The backup arrives as text
/// the reader has pasted, so it is untrusted input — it may have been truncated
/// by a notes app, hand-edited, or produced by a future version of the app. Any
/// key outside this list is dropped before it reaches the store, so a malformed
/// backup fails as "skipped rows" rather than as an exception mid-transaction.
class TableSpec {
  const TableSpec({
    required this.name,
    required this.keys,
    required this.columns,
  });

  final String name;

  /// The natural key — what makes two rows the same reflection, the same night,
  /// the same saved word. Never the autoincrement `id`, which is local to one
  /// installation and meaningless in another.
  final List<String> keys;

  /// Every column carried, including the keys.
  final List<String> columns;
}

const reflectionsSpec = TableSpec(
  name: 'reflections',
  keys: ['surah_number', 'ayah_number'],
  columns: ['surah_number', 'ayah_number', 'reflection', 'saved_at'],
);

/// Keyed on `entry_date`, which is the whole point of the fix in #100: keying a
/// night on anything shared between nights made every muhasabah overwrite the
/// last one. `tools/verify_backup.dart` asserts two different nights survive a
/// round trip, because that is the regression that cost real entries.
const muhasabahSpec = TableSpec(
  name: 'muhasabah_entries',
  keys: ['entry_date'],
  columns: ['entry_date', 'for_allah', 'nafs_pull', 'tomorrow', 'saved_at'],
);

const hadithReflectionsSpec = TableSpec(
  name: 'hadith_reflections',
  keys: ['collection', 'number'],
  columns: ['collection', 'number', 'reflection', 'saved_at'],
);

const vocabSpec = TableSpec(
  name: 'vocab_words',
  keys: ['arabic', 'surah_number', 'ayah_number'],
  columns: [
    'arabic',
    'transliteration',
    'meaning',
    'root',
    'insight',
    'surah_number',
    'ayah_number',
    'surah_name',
    'saved_at',
    'review_count',
    'next_review_at',
  ],
);

const layerUnlocksSpec = TableSpec(
  name: 'layer_unlocks',
  keys: ['surah_number', 'ayah_number', 'layer_index'],
  columns: ['surah_number', 'ayah_number', 'layer_index', 'unlocked_at'],
);

const discoverProgressSpec = TableSpec(
  name: 'discover_progress',
  keys: ['entry_id', 'entry_type'],
  columns: [
    'entry_id',
    'entry_type',
    'layers_unlocked',
    'last_layer_unlocked_at',
    'quiz_passed',
    'quiz_passed_at',
    'entry_completed',
  ],
);

/// Tables in the main database, in the order they are written back.
const mainTableSpecs = <TableSpec>[
  reflectionsSpec,
  muhasabahSpec,
  hadithReflectionsSpec,
  vocabSpec,
  layerUnlocksSpec,
];

/// The label each table is counted under, on screen and in the backup's own
/// header. Kept beside the specs so a new table cannot be added to the backup
/// and then be invisible in the summary the reader is asked to trust.
const Map<String, String> tableLabels = {
  'reflections': 'Ayah reflections',
  'muhasabah_entries': 'Muhasabah nights',
  'hadith_reflections': 'Hadith reflections',
  'vocab_words': 'Saved words',
  'layer_unlocks': 'Layers opened',
  'discover_progress': 'Discover progress',
};

/// The label preferences are counted under.
const String prefsLabel = 'Settings & records';

// ══════════════════════════════════════════════════════════════════════
//  HOW EACH PREFERENCE MERGES
// ══════════════════════════════════════════════════════════════════════

/// What to do when the backup and the device both have a value for a key.
enum Merge {
  /// Keep the larger. For counts and for high-water marks — a streak of 40 and a
  /// streak of 12 resolve to 40, because the shorter one is not evidence the
  /// longer never happened.
  max,

  /// Keep the smaller. Only for `mizan_first_day`: the record began the first
  /// time it began, and a later date would shorten a span the reader has lived.
  min,

  /// Every entry from both sides, deduplicated. For sets of days and sets of
  /// saved ayat, where each element is independently true.
  union,

  /// True if either side is true. For flags that record something having
  /// happened, which cannot un-happen.
  orFlag,

  /// Write only if the device has nothing. The device's own value wins because
  /// it is the more recent statement of the same fact — where you are reading
  /// now, and the birth date you may have just typed in.
  fillOnly,
}

/// The preferences that travel, and how each one resolves. A key absent from
/// this map is neither exported nor restored, which is what keeps device
/// settings and day-stamped state out of the backup by construction.
const Map<String, Merge> prefPolicy = {
  // Al-Mizan record
  'mizan_first_day': Merge.min,
  'mizan_days_recorded': Merge.max,
  'mizan_longest_run': Merge.max,
  'mizan_recent_days': Merge.union,
  'meezan_birth_date': Merge.fillOnly,

  // Streak. `streak_last_active_date` and `last_opened_at` sort correctly as
  // strings — one is `yyyy-MM-dd`, the other ISO 8601 — so "the later day" is
  // the larger string, and `max` is literally right rather than approximately.
  'streak_count': Merge.max,
  'streak_last_active_date': Merge.max,
  'last_opened_at': Merge.max,

  // Muhasabah's "have I sat with it today" flag, same `yyyy-MM-dd` ordering.
  'last_muhasabah_date': Merge.max,

  // Saved ayat are a set, so both sides' saves survive.
  'saved_ayat': Merge.union,

  // Where the reader had reached. Restored only onto a device that has no
  // reading position of its own.
  'last_ayah': Merge.fillOnly,
  'last_ayah_arabic': Merge.fillOnly,
  'last_ayah_translation': Merge.fillOnly,
  'last_surah': Merge.fillOnly,
  'last_surah_name': Merge.fillOnly,

  // Whether they have already been shown the six-layer explainer.
  'reader_layers_intro_seen': Merge.orFlag,
};

// ══════════════════════════════════════════════════════════════════════
//  STORAGE, NAMED BUT NOT CHOSEN
// ══════════════════════════════════════════════════════════════════════

/// The four things the engine does to rows. Deliberately not sqflite's
/// `DatabaseExecutor`: that type drags in the plugin, and with it the need for a
/// device to run any of this.
///
/// Implementations may throw. The engine catches per table on the way out and
/// per row on the way in, so one unreadable table or one bad row costs that one
/// thing rather than the whole backup — see [BackupEngine.readTable] and
/// [BackupEngine.mergeTable].
abstract class BackupTables {
  /// Every row of [table], restricted to [columns].
  Future<List<Map<String, Object?>>> readAll(String table, List<String> columns);

  /// The row matching [key] exactly, or null. [key] is column → value.
  Future<Map<String, Object?>?> findByKey(String table, Map<String, Object?> key);

  Future<void> insertRow(String table, Map<String, Object?> row);

  Future<void> updateRow(
    String table,
    Map<String, Object?> key,
    Map<String, Object?> values,
  );

  /// Runs [body] atomically where the store can. A store with no transactions
  /// may simply call it — the engine never depends on rollback, because no rule
  /// in it deletes anything, so a half-applied restore is a smaller restore
  /// rather than a damaged device.
  Future<void> runInTransaction(Future<void> Function() body);
}

/// The preference store, as much of it as a backup needs.
abstract class BackupPrefs {
  /// The stored value, or null. Types are whatever the app wrote: bool, int,
  /// double, String, or List&lt;String&gt;.
  Object? read(String key);

  /// Writes [value], which is one of those same five types. The implementation
  /// dispatches on the runtime type; the engine has already decided that this
  /// write should happen and that the type is right.
  Future<void> write(String key, Object value);
}

// ══════════════════════════════════════════════════════════════════════
//  REPORTS
// ══════════════════════════════════════════════════════════════════════

/// What an export contains, so the screen can say so before the reader trusts it.
class BackupSummary {
  const BackupSummary({
    required this.json,
    required this.counts,
    required this.createdAt,
  });

  /// The text to put on the clipboard.
  final String json;

  /// Rows per label, in the order they should be listed.
  final Map<String, int> counts;

  final DateTime createdAt;

  int get bytes => utf8.encode(json).length;

  /// Total records, so the screen can lead with one number.
  int get totalRecords => counts.values.fold(0, (a, b) => a + b);
}

/// What a pasted backup claims to be, read without writing anything.
///
/// The reader is shown this and asked to confirm before a restore touches the
/// database. A merge cannot be undone from inside the app, so "restore" must not
/// be a single tap on text nobody has looked at — especially when the text came
/// from the clipboard and could be anything.
class BackupPreview {
  const BackupPreview({this.createdAt, this.counts = const {}, this.error});

  const BackupPreview.invalid(String this.error)
      : createdAt = null,
        counts = const {};

  final DateTime? createdAt;
  final Map<String, int> counts;

  /// Set when the text is not a backup this version can read. [counts] is then
  /// empty and nothing should be offered but the message.
  final String? error;

  bool get ok => error == null;

  int get records => counts.values.fold(0, (a, b) => a + b);
}

/// The outcome of a restore, always reported — a merge that silently did
/// nothing and a merge that recovered 300 records look identical otherwise.
class RestoreReport {
  RestoreReport();

  /// Rows that did not exist here and were written.
  int added = 0;

  /// Rows that existed and were advanced by the backup's copy.
  int updated = 0;

  /// Rows the device already had in an equal-or-better state. Not a failure —
  /// this is the number that is large when you restore a backup you already
  /// restored, and saying so is what stops the reader pressing it again.
  int unchanged = 0;

  /// Rows dropped because they were malformed: wrong shape, missing a key, or
  /// naming a table this version does not know.
  int skipped = 0;

  /// Preference values written or advanced.
  int prefsWritten = 0;

  /// Set when the backup could not be read at all. Everything else is zero.
  String? error;

  bool get failed => error != null;

  bool get changedAnything => added > 0 || updated > 0 || prefsWritten > 0;

  int get total => added + updated + unchanged + skipped;
}

/// Somewhere for the engine to report a swallowed failure, without knowing what
/// logging looks like. [BackupService] passes the app logger; a test can collect
/// the messages and assert that a failure really was contained rather than
/// silently absent.
typedef BackupLog = void Function(String message, Object? error);

// ══════════════════════════════════════════════════════════════════════
//  THE ENGINE
// ══════════════════════════════════════════════════════════════════════

class BackupEngine {
  BackupEngine({
    required this.main,
    required this.discover,
    required this.prefs,
    BackupLog? log,
    DateTime Function()? clock,
  })  : _log = log ?? _ignore,
        _now = clock ?? DateTime.now;

  /// Where the five written-record tables live.
  final BackupTables main;

  /// Where `discover_progress` lives — a second database file on a device, and
  /// passed separately so that its failure cannot take the rest of the backup
  /// with it.
  final BackupTables discover;

  final BackupPrefs prefs;

  final BackupLog _log;

  /// Injectable so a test can assert on an exact `created_at` rather than on
  /// whatever the clock said mid-run.
  final DateTime Function() _now;

  static void _ignore(String _, Object? __) {}

  /// Bumped only when the *shape* changes in a way an older app cannot read.
  /// Adding a table or a column does not bump it: unknown names are dropped on
  /// restore, so an older build reads a newer backup partially rather than
  /// refusing it, and partial recovery beats none.
  static const int formatVersion = 1;

  static const String magic = 'mizan.backup';

  // ── EXPORT ──────────────────────────────────────────────────────────

  Future<BackupSummary> export() async {
    final now = _now();
    final tables = <String, List<Map<String, Object?>>>{};

    for (final spec in mainTableSpecs) {
      tables[spec.name] = await readTable(main, spec);
    }
    tables[discoverProgressSpec.name] =
        await readTable(discover, discoverProgressSpec);

    final encodedPrefs = <String, Object?>{};
    for (final key in prefPolicy.keys) {
      final value = prefs.read(key);
      if (value == null) continue;
      final encoded = encodePref(value);
      if (encoded != null) encodedPrefs[key] = encoded;
    }

    // Built from `tableLabels` rather than written out by hand, so a table added
    // to the backup cannot be missing from the summary the reader is shown.
    final counts = <String, int>{
      for (final entry in tableLabels.entries)
        entry.value: tables[entry.key]?.length ?? 0,
      prefsLabel: encodedPrefs.length,
    };

    final payload = <String, Object?>{
      magic: formatVersion,
      'created_at': now.toIso8601String(),
      'counts': counts,
      'prefs': encodedPrefs,
      'tables': tables,
    };

    return BackupSummary(
      json: jsonEncode(payload),
      counts: counts,
      createdAt: now,
    );
  }

  /// Reads one table, keeping only the whitelisted columns.
  ///
  /// Dropping `id` is not tidiness. It is an autoincrement local to this
  /// installation; carrying it across would either collide with a different row
  /// on the target device or force the merge to trust a number that means
  /// nothing there. Identity comes from [TableSpec.keys] instead.
  Future<List<Map<String, Object?>>> readTable(
    BackupTables store,
    TableSpec spec,
  ) async {
    try {
      final rows = await store.readAll(spec.name, spec.columns);
      return [
        for (final row in rows)
          <String, Object?>{
            for (final c in spec.columns)
              if (row.containsKey(c)) c: row[c],
          },
      ];
    } catch (e) {
      // A table missing on an older schema, or a database that will not open, is
      // not a reason to fail the whole export. The reader gets everything else.
      _log('Skipped ${spec.name}', e);
      return const [];
    }
  }

  /// Preferences are untyped on the way out, so the type travels with the value.
  /// Without it, a restore cannot tell `"12"` the string from `12` the int, and
  /// writing a string to a key the app reads with `getInt` throws at the point of
  /// use rather than here.
  Map<String, Object?>? encodePref(Object value) {
    if (value is bool) return {'t': 'b', 'v': value};
    if (value is int) return {'t': 'i', 'v': value};
    if (value is double) return {'t': 'd', 'v': value};
    if (value is String) return {'t': 's', 'v': value};
    if (value is List) return {'t': 'l', 'v': value.map((e) => '$e').toList()};
    return null;
  }

  // ── READING THE ENVELOPE ────────────────────────────────────────────

  /// Validates the text and reads its header, without writing anything.
  ///
  /// Returns the payload, or a message written for the reader rather than for a
  /// log. Shared by [inspect] and [restore] so the confirmation the reader agreed
  /// to and the merge that follows can never disagree about what the text is.
  ///
  /// Static because it reads text and touches no storage — which is what lets
  /// [Your data] describe a pasted backup before anything has been opened.
  static (Map<String, Object?>?, String?) envelope(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (null, 'Your clipboard is empty. Copy a backup first.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      // Named as truncation because that is overwhelmingly the cause: notes apps
      // and chat clients cut long text, and a half-copied backup is invalid JSON
      // in exactly this way. Saying "invalid JSON" would send the reader looking
      // for a problem in the app.
      return (
        null,
        "That text is incomplete, or it isn't a Mizan backup. Copy the whole "
            'thing — from the first { to the last }.',
      );
    }

    if (decoded is! Map<String, Object?>) {
      return (null, "That doesn't look like a Mizan backup.");
    }

    final version = decoded[magic];
    if (version is! int) {
      return (null, "That doesn't look like a Mizan backup.");
    }
    if (version > formatVersion) {
      // Refused outright rather than importing the half this build understands:
      // a partial restore from a newer app would look like it worked.
      return (
        null,
        'This backup was made by a newer version of Mizan. Update the app, then '
            'restore.',
      );
    }

    return (decoded, null);
  }

  /// Reads a pasted backup's header so it can be described before it is applied.
  static BackupPreview inspect(String raw) {
    final (payload, error) = envelope(raw);
    if (payload == null) return BackupPreview.invalid(error!);

    final counts = <String, int>{};
    final declared = payload['counts'];
    if (declared is Map) {
      for (final e in declared.entries) {
        final v = e.value;
        if (v is int) counts['${e.key}'] = v;
      }
    }

    return BackupPreview(
      createdAt: DateTime.tryParse('${payload['created_at']}'),
      counts: counts,
    );
  }

  // ── RESTORE ─────────────────────────────────────────────────────────

  /// Merges a pasted backup into this device. Never deletes anything.
  Future<RestoreReport> restore(String raw) async {
    final report = RestoreReport();

    final (payload, error) = envelope(raw);
    if (payload == null) {
      report.error = error;
      return report;
    }

    final tables = payload['tables'];
    final tableMap = tables is Map ? tables : const {};

    try {
      await main.runInTransaction(() async {
        for (final spec in mainTableSpecs) {
          await mergeTable(main, spec, tableMap[spec.name], report);
        }
      });
    } catch (e) {
      _log('Restore into the main store failed', e);
      report.error = 'Some of your data could not be written. '
          'Nothing was deleted — try again.';
      // Deliberately falls through: prefs and Discover are separate stores and
      // recovering them is strictly better than recovering nothing.
    }

    try {
      await discover.runInTransaction(() async {
        await mergeTable(discover, discoverProgressSpec,
            tableMap[discoverProgressSpec.name], report);
      });
    } catch (e) {
      _log('Restore into Discover failed', e);
    }

    try {
      await mergePrefs(payload['prefs'], report);
    } catch (e) {
      _log('Restore of preferences failed', e);
    }

    return report;
  }

  Future<void> mergeTable(
    BackupTables store,
    TableSpec spec,
    Object? incoming,
    RestoreReport report,
  ) async {
    if (incoming is! List) return;

    for (final entry in incoming) {
      if (entry is! Map) {
        report.skipped++;
        continue;
      }

      // Whitelist first, so an unknown column from a hand-edited backup cannot
      // reach the store and abort the transaction for every row after it.
      final row = <String, Object?>{
        for (final c in spec.columns)
          if (entry.containsKey(c)) c: entry[c],
      };

      final missingKey = spec.keys.any((k) => row[k] == null);
      if (missingKey) {
        report.skipped++;
        continue;
      }

      final key = <String, Object?>{for (final k in spec.keys) k: row[k]};

      Map<String, Object?>? found;
      try {
        found = await store.findByKey(spec.name, key);
      } catch (e) {
        report.skipped++;
        continue;
      }

      if (found == null) {
        try {
          await store.insertRow(spec.name, row);
          report.added++;
        } catch (e) {
          report.skipped++;
        }
        continue;
      }

      final merged = resolve(spec, row, found);
      if (merged == null) {
        report.unchanged++;
        continue;
      }
      try {
        await store.updateRow(spec.name, key, merged);
        report.updated++;
      } catch (e) {
        report.skipped++;
      }
    }
  }

  /// Decides what a row becomes when both copies exist. Returning null means
  /// "the device's copy already loses nothing" and leaves it untouched.
  Map<String, Object?>? resolve(
    TableSpec spec,
    Map<String, Object?> incoming,
    Map<String, Object?> existing,
  ) {
    switch (spec.name) {
      // Written prose: three tables, one rule. The later `saved_at` is the later
      // draft of the same thought, so it wins — but only when it really is
      // later, which is why the comparison is on the timestamp and not on which
      // side happens to be the backup.
      case 'reflections':
      case 'muhasabah_entries':
      case 'hadith_reflections':
        return _newerWins(incoming, existing, 'saved_at');

      // A saved word is a word plus where it was met. Once it is here, the
      // device's copy carries live review progress (`review_count`,
      // `next_review_at`) that the backup's copy predates, so the backup adds
      // words and never rewinds them.
      case 'vocab_words':
        return null;

      // Unlocking is monotonic — it happened or it hasn't — so the row is
      // already present and the only question is the date. The *earlier* one is
      // true: the layer opened when it first opened.
      case 'layer_unlocks':
        return _earlierWins(incoming, existing, 'unlocked_at');

      case 'discover_progress':
        return _mergeDiscover(incoming, existing);
    }
    return null;
  }

  Map<String, Object?>? _newerWins(
    Map<String, Object?> incoming,
    Map<String, Object?> existing,
    String stampColumn,
  ) {
    final a = '${incoming[stampColumn] ?? ''}';
    final b = '${existing[stampColumn] ?? ''}';
    // ISO 8601 in a fixed local format sorts lexicographically, so this is a
    // real comparison and not a heuristic.
    if (a.compareTo(b) <= 0) return null;
    return incoming;
  }

  Map<String, Object?>? _earlierWins(
    Map<String, Object?> incoming,
    Map<String, Object?> existing,
    String stampColumn,
  ) {
    final a = '${incoming[stampColumn] ?? ''}';
    final b = '${existing[stampColumn] ?? ''}';
    if (a.isEmpty || a.compareTo(b) >= 0) return null;
    return incoming;
  }

  /// Discover progress is a set of monotonic facts about one story, so each
  /// field takes the further-along value independently and the row can only ever
  /// move forward.
  ///
  /// The two timestamps are not symmetric, and the names say why.
  /// `last_layer_unlocked_at` is the *most recent* unlock, so it takes the later
  /// of the two. `quiz_passed_at` is when the quiz was first passed, so it takes
  /// the earlier.
  Map<String, Object?>? _mergeDiscover(
    Map<String, Object?> incoming,
    Map<String, Object?> existing,
  ) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

    final layers = asInt(incoming['layers_unlocked']);
    final haveLayers = asInt(existing['layers_unlocked']);
    final passed = asInt(incoming['quiz_passed']);
    final havePassed = asInt(existing['quiz_passed']);
    final done = asInt(incoming['entry_completed']);
    final haveDone = asInt(existing['entry_completed']);

    final lastUnlock = _laterOf(
        existing['last_layer_unlocked_at'], incoming['last_layer_unlocked_at']);
    final firstPass =
        _earlierOf(existing['quiz_passed_at'], incoming['quiz_passed_at']);

    final changed = layers > haveLayers ||
        passed > havePassed ||
        done > haveDone ||
        lastUnlock != existing['last_layer_unlocked_at'] ||
        firstPass != existing['quiz_passed_at'];
    if (!changed) return null;

    return {
      'layers_unlocked': layers > haveLayers ? layers : haveLayers,
      'last_layer_unlocked_at': lastUnlock,
      'quiz_passed': passed > havePassed ? passed : havePassed,
      'quiz_passed_at': firstPass,
      'entry_completed': done > haveDone ? done : haveDone,
    };
  }

  Object? _laterOf(Object? a, Object? b) {
    if (a == null) return b;
    if (b == null) return a;
    return '$a'.compareTo('$b') >= 0 ? a : b;
  }

  Object? _earlierOf(Object? a, Object? b) {
    if (a == null) return b;
    if (b == null) return a;
    return '$a'.compareTo('$b') <= 0 ? a : b;
  }

  // ── PREFERENCES ─────────────────────────────────────────────────────

  Future<void> mergePrefs(Object? incoming, RestoreReport report) async {
    if (incoming is! Map) return;

    for (final policy in prefPolicy.entries) {
      final key = policy.key;
      final encoded = incoming[key];
      if (encoded is! Map) continue;

      final type = '${encoded['t']}';
      final value = encoded['v'];
      if (value == null) continue;

      final wrote = await _applyPref(key, type, value, policy.value);
      if (wrote) report.prefsWritten++;
    }
  }

  /// Returns true when something was actually written.
  Future<bool> _applyPref(
    String key,
    String type,
    Object value,
    Merge merge,
  ) async {
    try {
      final current = prefs.read(key);

      switch (merge) {
        case Merge.fillOnly:
          if (current != null) return false;
          // Awaited, not returned bare: the catch below is the whole point of
          // this try, and an unawaited future would settle outside it.
          return await _write(key, type, value);

        case Merge.orFlag:
          if (value is! bool || value == false) return false;
          if (current == true) return false;
          await prefs.write(key, true);
          return true;

        case Merge.union:
          final incoming = value is List
              ? value.map((e) => '$e').toList()
              : const <String>[];
          if (incoming.isEmpty) return false;
          final merged = <String>{
            ...?(current is List ? current.map((e) => '$e') : null),
            ...incoming,
          }.toList()
            ..sort();
          if (current is List && current.length == merged.length) return false;
          await prefs.write(key, merged);
          return true;

        case Merge.max:
        case Merge.min:
          return await _writeExtreme(key, type, value, current, merge);
      }
    } catch (e) {
      // A single key that will not merge — most plausibly because a past build
      // stored it under a different type — must not stop the other twenty.
      _log('Kept the local value for $key', e);
      return false;
    }
  }

  Future<bool> _writeExtreme(
    String key,
    String type,
    Object value,
    Object? current,
    Merge merge,
  ) async {
    if (current == null) return _write(key, type, value);

    if (value is int && current is int) {
      final keep = merge == Merge.max ? (value > current) : (value < current);
      if (!keep) return false;
      await prefs.write(key, value);
      return true;
    }

    if (value is String && current is String) {
      final cmp = value.compareTo(current);
      final keep = merge == Merge.max ? cmp > 0 : cmp < 0;
      if (!keep) return false;
      await prefs.write(key, value);
      return true;
    }

    // Types disagree between the backup and this device. The device's value is
    // the one the running code has already proved it can read.
    return false;
  }

  Future<bool> _write(String key, String type, Object value) async {
    switch (type) {
      case 'b':
        if (value is! bool) return false;
        await prefs.write(key, value);
        return true;
      case 'i':
        if (value is! int) return false;
        await prefs.write(key, value);
        return true;
      case 'd':
        if (value is! num) return false;
        await prefs.write(key, value.toDouble());
        return true;
      case 's':
        if (value is! String) return false;
        await prefs.write(key, value);
        return true;
      case 'l':
        if (value is! List) return false;
        await prefs.write(key, value.map((e) => '$e').toList());
        return true;
    }
    return false;
  }
}
