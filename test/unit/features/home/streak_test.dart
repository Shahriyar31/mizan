/// Streak semantics — the calendar arithmetic and the storage round-trip.
///
/// Run with `flutter test test/unit/features/home/streak_test.dart`.
///
/// Everything here passes an explicit `today`/`now`, so the suite behaves the
/// same at 09:00 and at 23:59:59. Tests that read the real clock to check
/// date logic pass all day and fail at midnight, which is the one time you are
/// not watching.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/home/domain/streak_math.dart';
import 'package:mizan/features/home/domain/streak_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('daysBetweenDates', () {
    // The defect the old streak had: it subtracted two *instants* and floored
    // the result, so whether a day had passed depended on the time of day.
    test('counts calendar days, not elapsed hours', () {
      expect(
        daysBetweenDates(DateTime(2026, 8, 17, 23, 0), DateTime(2026, 8, 18, 8)),
        1,
        reason: '23:00 to 08:00 next morning is one calendar day',
      );
      expect(
        daysBetweenDates(DateTime(2026, 8, 17, 8), DateTime(2026, 8, 18, 23, 0)),
        1,
        reason: 'same two days from the other end must give the same answer',
      );
      expect(
        daysBetweenDates(
            DateTime(2026, 8, 17, 0, 1), DateTime(2026, 8, 17, 23, 59)),
        0,
      );
    });

    test('crosses month, year and leap boundaries', () {
      expect(daysBetweenDates(DateTime(2026, 8, 31), DateTime(2026, 9)), 1);
      expect(daysBetweenDates(DateTime(2026, 12, 31), DateTime(2027)), 1);
      expect(daysBetweenDates(DateTime(2028, 2, 28), DateTime(2028, 2, 29)), 1);
    });

    // A 23-hour and a 25-hour day must both still be one day. Only meaningful
    // when the suite runs in a DST-observing zone (these are Europe/Berlin's
    // 2026 transitions); harmless elsewhere.
    test('survives daylight saving transitions', () {
      expect(daysBetweenDates(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
      expect(
          daysBetweenDates(DateTime(2026, 10, 25), DateTime(2026, 10, 26)), 1);
      expect(daysBetweenDates(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    });

    test('is negative when the clock moved backwards', () {
      expect(daysBetweenDates(DateTime(2026, 8, 18), DateTime(2026, 8, 17)), -1);
    });
  });

  group('resolveStreak', () {
    final today = DateTime(2026, 8, 18, 9, 30);

    test('no run on a fresh install', () {
      expect(resolveStreak(count: 0, lastActive: null, today: today),
          Streak.none);
    });

    test('a count without a date is not a run', () {
      // This is why `streak_last_active_date` exists: the integer alone cannot
      // be interpreted, and guessing would invent a streak.
      expect(resolveStreak(count: 7, lastActive: null, today: today),
          Streak.none);
    });

    test('a zero or negative count is not a run', () {
      expect(
        resolveStreak(count: 0, lastActive: DateTime(2026, 8, 18), today: today),
        Streak.none,
      );
      expect(
        resolveStreak(
            count: -3, lastActive: DateTime(2026, 8, 18), today: today),
        Streak.none,
      );
    });

    test('active today reads as counted', () {
      final s = resolveStreak(
          count: 5, lastActive: DateTime(2026, 8, 18, 1), today: today);
      expect(s, const Streak(days: 5, activeToday: true));
      expect(s.atRisk, isFalse);
    });

    test('active yesterday is alive but at risk', () {
      final s = resolveStreak(
          count: 5, lastActive: DateTime(2026, 8, 17, 23, 50), today: today);
      expect(s, const Streak(days: 5, activeToday: false));
      expect(s.atRisk, isTrue,
          reason: 'today can still be saved, so the number is real');
    });

    test('one missed day breaks the run', () {
      expect(
        resolveStreak(
            count: 5, lastActive: DateTime(2026, 8, 16, 23, 50), today: today),
        Streak.none,
      );
      expect(
        resolveStreak(count: 99, lastActive: DateTime(2026, 7), today: today),
        Streak.none,
      );
    });

    test('a backwards clock does not break the run', () {
      // Timezone change, NTP correction, or the user setting the date. Losing a
      // 200-day streak to that would be indefensible.
      expect(
        resolveStreak(count: 5, lastActive: DateTime(2026, 8, 20), today: today),
        const Streak(days: 5, activeToday: false),
      );
    });
  });

  group('nextStreakCount', () {
    test('starts at one, extends by one, never twice in a day', () {
      expect(nextStreakCount(Streak.none), 1);
      expect(nextStreakCount(const Streak(days: 5, activeToday: false)), 6);
      expect(nextStreakCount(const Streak(days: 5, activeToday: true)), 5);
    });
  });

  group('a month of use, simulated', () {
    test('runs build, survive an idle evening, and break on a missed day', () {
      // Marked on these days of September 2026; idle on the rest.
      const marked = {1, 2, 3, 4, 5, 7, 8, 12, 13, 14, 15, 16, 17, 18};
      var count = 0;
      DateTime? last;
      final shown = <int, int>{};

      for (var d = 1; d <= 20; d++) {
        final day = DateTime(2026, 9, d, 20);
        var s = resolveStreak(count: count, lastActive: last, today: day);
        if (marked.contains(d) && !s.activeToday) {
          count = nextStreakCount(s);
          last = dateOnly(day);
          s = resolveStreak(count: count, lastActive: last, today: day);
        }
        shown[d] = s.days;
      }

      expect(shown[5], 5, reason: 'five days in a row');
      expect(shown[6], 5,
          reason: 'idle day 6 still SHOWS 5 — it can still be saved tonight');
      expect(shown[7], 1, reason: 'day 6 was missed, so day 7 is a new day one');
      expect(shown[8], 2);
      expect(shown[9], 2, reason: 'idle, yesterday counted');
      expect(shown[10], 0, reason: 'day 9 was missed');
      expect(shown[12], 1);
      expect(shown[18], 7, reason: 'days 12 to 18');
      expect(shown[20], 0, reason: 'day 19 was missed');
    });
  });

  group('StreakStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('twenty actions in one day count as one day', () async {
      final day = DateTime(2026, 9, 1, 12);
      for (var i = 0; i < 20; i++) {
        await StreakStore.recordActivity(now: day);
      }
      expect(await StreakStore.evaluate(now: day),
          const Streak(days: 1, activeToday: true));
    });

    test('consecutive days accumulate', () async {
      for (var d = 1; d <= 4; d++) {
        await StreakStore.recordActivity(now: DateTime(2026, 9, d, 20));
      }
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 4, 21)),
          const Streak(days: 4, activeToday: true));
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 5, 9)),
          const Streak(days: 4, activeToday: false));
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 6, 9)),
          Streak.none);
    });

    test('reading never writes', () async {
      await StreakStore.recordActivity(now: DateTime(2026, 9, 1, 20));
      // Evaluate long after the run broke, then come back to the day after it
      // was last alive. A read that "cleaned up" would have destroyed the count
      // and this would report 1 instead of 2.
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 30)),
          Streak.none);
      await StreakStore.recordActivity(now: DateTime(2026, 9, 2, 20));
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 2, 21)),
          const Streak(days: 2, activeToday: true));
    });

    test('opening the app does not advance the streak', () async {
      await StreakStore.recordActivity(now: DateTime(2026, 9, 1, 20));
      await StreakStore.recordOpen(now: DateTime(2026, 9, 2, 8));
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 2, 8, 30)),
          const Streak(days: 1, activeToday: false),
          reason: 'the old code would have made this 2 for merely launching');
    });

    test('an existing streak survives the upgrade', () async {
      // What a device that installed the previous build looks like: a count and
      // a last-opened date, but no last-active date, because that key did not
      // exist yet. Reporting 0 here would wipe a run the user believes they have.
      SharedPreferences.setMockInitialValues({
        'streak_count': 12,
        'last_opened_at': DateTime(2026, 9, 3).toIso8601String(),
      });
      await StreakStore.recordOpen(now: DateTime(2026, 9, 4, 8));
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 4, 8, 30)),
          const Streak(days: 12, activeToday: false));
      await StreakStore.recordActivity(now: DateTime(2026, 9, 4, 9));
      expect(await StreakStore.evaluate(now: DateTime(2026, 9, 4, 9, 30)),
          const Streak(days: 13, activeToday: true));
    });

    test('recordOpen still reports how long the user was away', () async {
      await StreakStore.recordOpen(now: DateTime(2026, 9, 1, 8));
      expect(StreakStore.daysAway, isNull, reason: 'first ever launch');
      await StreakStore.recordOpen(now: DateTime(2026, 9, 6, 8));
      expect(StreakStore.daysAway, 5);
    });
  });
}
