/// The Mizan record over time — what Growth's seven-day strip and its
/// "since you began" strip are drawn from.
///
/// ── Why this file had to exist ────────────────────────────────────────
/// `todays_mizan.dart` stores exactly one day: a single pref holding
/// `yyyy-mm-dd|l,r,a`, which reads as three empty facets the moment the date
/// stamp goes stale. That is the right design for a card about *today* and it
/// needs no cleanup pass, but it means the app has never known whether Tuesday
/// was recorded. A seven-day strip cannot be drawn from it, and neither can
/// "days with Mizan · of them recorded · longest run".
///
/// ── Rule 2 is the reason for the shape of this, not just its copy ─────
/// *"Nothing here is scored, graded, ranked or totalled into a verdict."* So this
/// file stores days, never deeds. It cannot tell you *what* was done on a past
/// day — only that the day was not empty — because a history of which facets were
/// lit is the raw material for exactly the ranking rule 2 forbids, and the safest
/// place for data you must not use is nowhere.
///
/// The one figure here that could turn into a score is `longestRun`, and Growth
/// renders it under a line that disarms it: *"Gaps are not failures. The record
/// simply shows where you were."* Without that line this becomes a streak app.
///
/// ── Why counters and a short window, not a list of every day ─────────
/// An unbounded date list in `SharedPreferences` is rewritten in full on every
/// write and grows for the life of the install. So the totals are kept as
/// counters bumped once per day — O(1) forever — and only a **14-day** window of
/// dates is retained, which is the seven the strip draws plus a week of slack.
/// The consequence is deliberate: the strip is exact, and history older than a
/// fortnight is a count rather than a calendar. Nothing in the spec asks to
/// re-draw a month, and if something ever does, that is a real store, not a
/// longer pref.
///
/// ── Longest run reuses the streak; it does not shadow it ─────────────
/// `StreakStore` already counts consecutive days on which the Mizan record was
/// non-empty — `TodaysMizanController.mark` is its only caller, by design. That
/// *is* the current run, so a second counter here would be a parallel feature
/// that can disagree with the first. This file keeps only the high-water mark,
/// and takes the live run from `streakProvider`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/domain/streak_math.dart';
import '../../home/domain/streak_provider.dart';

/// How many days of dates are kept. The strip needs 7; the rest is slack so a
/// user who reopens the app after a week still sees a correct strip.
const int _kWindow = 14;

/// How many days the strip draws, today last.
const int kMizanStripDays = 7;

/// The record over time. Every field is a day count or a date — never a deed.
class MizanRecord {
  const MizanRecord({
    required this.firstDay,
    required this.daysRecorded,
    required this.longestRun,
    required this.currentRun,
    required this.recentDays,
    required this.today,
  });

  /// The first day anything was recorded, or null if nothing ever has been.
  ///
  /// Null is not zero. A user who has recorded nothing has not "begun", and the
  /// strip that reads this shows nothing rather than a row of empty marks and
  /// three noughts, which would read as a report card on a day one user.
  final DateTime? firstDay;

  /// Days on which at least one facet was marked. Not deeds — a day with three
  /// facets counts once, the same as a day with one.
  final int daysRecorded;

  /// The longest run of consecutive recorded days, ever.
  ///
  /// Only ever rendered beneath the line that says gaps are not failures. It is
  /// here because it is a true fact about the record, not because a longer one is
  /// better than a shorter one.
  final int longestRun;

  /// The run in progress, from `StreakStore` — the same number the Home streak
  /// pill shows, so the two can never disagree.
  final int currentRun;

  /// Dates within the retained window that were recorded, as `yyyy-mm-dd`.
  final Set<String> recentDays;

  final DateTime today;

  static MizanRecord empty(DateTime today) => MizanRecord(
        firstDay: null,
        daysRecorded: 0,
        longestRun: 0,
        currentRun: 0,
        recentDays: const <String>{},
        today: today,
      );

  bool get hasBegun => firstDay != null;

  /// Days since the first record, inclusive of both ends — the denominator in
  /// "N days with Mizan · M of them recorded".
  ///
  /// Deliberately *not* days since install. This counts from the day the user
  /// first recorded something, so the two figures describe the same span and the
  /// second can never be a small fraction of a number the user does not
  /// recognise.
  int get daysWithMizan =>
      firstDay == null ? 0 : daysBetweenDates(firstDay!, today) + 1;

  /// The strip, oldest first, today last. `true` where that day was recorded.
  List<bool> get strip => [
        for (var i = kMizanStripDays - 1; i >= 0; i--)
          recentDays.contains(_stamp(_daysAgo(today, i))),
      ];

  /// The dates the strip covers, matching [strip] index for index — for
  /// semantics labels, so the row is not an unreadable run of shapes to a screen
  /// reader.
  List<DateTime> get stripDays => [
        for (var i = kMizanStripDays - 1; i >= 0; i--) _daysAgo(today, i),
      ];
}

/// Reads and writes the record. Static, like [StreakStore], because there is one
/// record per device and no instance state worth holding.
abstract final class MizanRecordStore {
  static const _firstDayKey = 'mizan_first_day';
  static const _daysRecordedKey = 'mizan_days_recorded';
  static const _longestRunKey = 'mizan_longest_run';
  static const _recentDaysKey = 'mizan_recent_days';

  /// Note that today has a record. Idempotent per day: the second and third
  /// facet of a day change nothing, because this counts days.
  ///
  /// Called from `TodaysMizanController` only — the same single entry point that
  /// owns the streak — so a day cannot be counted here without also being
  /// counted there.
  ///
  /// [currentRun] is the streak *after* it has been advanced for today, so the
  /// high-water mark is compared against a run that already includes today.
  static Future<void> noteRecorded({
    required int currentRun,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(now ?? DateTime.now());
    final stamp = _stamp(today);

    final recent = prefs.getStringList(_recentDaysKey) ?? const <String>[];
    final isNewDay = !recent.contains(stamp);

    if (isNewDay) {
      // Keep only the window, and only dates at or behind today. A device whose
      // clock was set forward and back would otherwise leave a future date in
      // the list, which would draw as a recorded day the user never had.
      final kept = <String>[
        for (final s in recent)
          if (_within(s, today)) s,
        stamp,
      ]..sort();
      await prefs.setStringList(
        _recentDaysKey,
        kept.length <= _kWindow ? kept : kept.sublist(kept.length - _kWindow),
      );

      await prefs.setInt(
        _daysRecordedKey,
        (prefs.getInt(_daysRecordedKey) ?? 0) + 1,
      );

      // First day is written once and then left alone. Guarded rather than
      // overwritten, so a user whose clock slips backwards does not lose the
      // real start of their record.
      if (prefs.getString(_firstDayKey) == null) {
        await prefs.setString(_firstDayKey, stamp);
      }
    }

    // Updated on every call, not just new days: the run can be advanced by the
    // self-heal path in `_restore` on a day that is already counted.
    final storedLongest = prefs.getInt(_longestRunKey) ?? 0;
    if (currentRun > storedLongest) {
      await prefs.setInt(_longestRunKey, currentRun);
    }
  }

  static Future<MizanRecord> load({int currentRun = 0, DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(now ?? DateTime.now());

    final firstRaw = prefs.getString(_firstDayKey);
    final first = _parse(firstRaw);
    if (first == null) return MizanRecord.empty(today);

    final recent = prefs.getStringList(_recentDaysKey) ?? const <String>[];
    final stored = prefs.getInt(_longestRunKey) ?? 0;

    return MizanRecord(
      firstDay: first,
      daysRecorded: prefs.getInt(_daysRecordedKey) ?? 0,
      // Maxed at read time as well as write time. A run in progress that has
      // already passed the stored mark is the true longest run right now, and
      // waiting for the next `mark` to say so would show a user a number they
      // can see is wrong.
      longestRun: currentRun > stored ? currentRun : stored,
      currentRun: currentRun,
      recentDays: recent.toSet(),
      today: today,
    );
  }

  /// Test and repair hook. Not called from `lib`.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstDayKey);
    await prefs.remove(_daysRecordedKey);
    await prefs.remove(_longestRunKey);
    await prefs.remove(_recentDaysKey);
  }

  static bool _within(String stamp, DateTime today) {
    final d = _parse(stamp);
    if (d == null) return false;
    final age = daysBetweenDates(d, today);
    return age >= 0 && age < _kWindow;
  }
}

/// The record, with the live run folded in from [streakProvider].
///
/// Watches the streak rather than reading it once, so marking a facet refreshes
/// both the strip and the run without Growth needing to know that it should.
final mizanRecordProvider = FutureProvider<MizanRecord>((ref) async {
  final streak = ref.watch(streakProvider);
  return MizanRecordStore.load(currentRun: streak.days);
});

// ── date helpers, shared with the record's own encoding ────────────────

/// `DateTime(y, m, d - n)` rather than subtracting a `Duration`: Dart normalises
/// the underflow and stays on local midnight, where 24-hour durations land on
/// 23:00 the previous day across a DST spring-forward and silently shift a day.
DateTime _daysAgo(DateTime from, int n) =>
    DateTime(from.year, from.month, from.day - n);

String _stamp(DateTime d) => '${d.year}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _parse(String? stamp) {
  if (stamp == null) return null;
  final p = stamp.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}
