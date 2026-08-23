/// The day-journey counter shown in the Home header.
///
/// ── Why this owns two SharedPreferences keys ──────────────────────────
/// Before this file, `streak_count` was read *and written* inside a private
/// `StatefulWidget` in `home_screen.dart`, while `last_opened_at` — the value
/// the streak is computed from — was written by `homeStateProvider`. Two owners,
/// no ordering guarantee. Whichever resolved first won, and if the provider won
/// (which it usually did, being awaited during the first build) then
/// `last_opened_at` was already "now" by the time the badge looked at it, the
/// day difference came out as zero, and the streak silently froze forever.
///
/// So both keys now have exactly one owner, and it is evaluated exactly once per
/// launch — [recordOpen] is awaited in `main()` before `runApp`, the same way
/// [OnboardingFlags] is. Nothing else may write either key.
///
/// `GrowthStatsRepository` still reads `streak_count` straight out of
/// SharedPreferences, which is fine and keeps working: this class is the writer,
/// that one is a reader.
///
/// ── On counting by calendar day ───────────────────────────────────────
/// The old code compared `DateTime.now().difference(last).inDays`, which is a
/// *duration*, not a date difference. Opening the app at 23:00 and again at
/// 08:00 the next morning gives zero, so the streak did not advance even though
/// the day had changed; opening at 08:00 and again at 23:00 the next day gives
/// one, so it did. Same two calendar days, different answers, depending on the
/// hour. A streak is a count of days, so this compares dates with the time
/// stripped off.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class StreakStore {
  static const _countKey = 'streak_count';
  static const _lastOpenedKey = 'last_opened_at';

  /// Days in the current run, resolved by [recordOpen]. 1 on a first launch —
  /// today itself counts, so the counter never reads zero.
  static int days = 1;

  /// Whole days since the previous open, or `null` on a first launch. Kept
  /// because "welcome back" copy needs to know a gap happened, and this is the
  /// only place that can still tell.
  static int? daysAway;

  /// Evaluate the streak and stamp today's open. Call once, from `main()`.
  static Future<void> recordOpen({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(now ?? DateTime.now());

    var count = prefs.getInt(_countKey) ?? 1;
    final lastRaw = prefs.getString(_lastOpenedKey);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);

    if (last != null) {
      final gap = today.difference(_dateOnly(last)).inDays;
      daysAway = gap;
      if (gap == 1) {
        count += 1; // consecutive day
      } else if (gap > 1) {
        count = 1; // the run is broken; today starts a new one
      }
      // gap == 0 → same day, already counted. gap < 0 → device clock moved
      // backwards; leave the count alone rather than punishing the user for it.
    }

    days = count;
    await prefs.setInt(_countKey, count);
    await prefs.setString(_lastOpenedKey, today.toIso8601String());
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// The resolved streak, for the UI. A plain [Provider] because the value cannot
/// change while the app is open — it is decided once, before the first frame.
final streakProvider = Provider<int>((ref) => StreakStore.days);
