/// The day-journey counter shown in the Home header.
///
/// ── What a streak day is, and what it used to be ──────────────────────
/// It used to advance on **app open**. `recordOpen` ran once in `main()` before
/// the first frame and bumped the count whenever the calendar day had changed, so
/// launching Mizan and closing it a second later extended your journey. That
/// measures one thing: that the icon got tapped. Duolingo hangs its streak on a
/// finished lesson and Snapchat on a sent snap, and that is exactly why those
/// numbers mean something to the people holding them.
///
/// A Mizan streak day is now a day on which you engaged with something. The
/// signal is [TodaysMizan], because that class already answers precisely this
/// question — it records "learned / reflected / acted" per calendar day, is
/// already persisted, and is already marked from the places where engagement
/// actually happens. The *first* facet marked on a given day advances the streak;
/// the second and third do not. A streak counts days, never deeds, so Rule #4
/// holds: there is still nothing here that totals, ranks or grades.
///
/// ── Three defects this closes ─────────────────────────────────────────
///   1. **Opening no longer counts.** Only [recordActivity] moves the number.
///   2. **The value is derived, never stale.** A stored count means nothing
///      without the date it was last touched, so [evaluate] compares that date
///      with today on every read: active today or yesterday means the run is
///      alive; two days or more means it is broken and the streak reads 0.
///      Nothing has to fire at midnight for that to be true, and no cleanup pass
///      can forget to run.
///   3. **It is reactive.** [streakProvider] was a plain `Provider<int>` handing
///      back a static field resolved before `runApp`, so the pill could not
///      change while the app was open — not when you finished an ayah, and not
///      when midnight passed on a phone that was never closed. It is a
///      `StateNotifier` now, and `app.dart` re-evaluates it on resume.
///
/// ── Ownership ─────────────────────────────────────────────────────────
/// Three SharedPreferences keys, one owner, no exceptions:
///
///   • `streak_count` — days in the current run. Written only by
///     [recordActivity]. `GrowthStatsRepository` reads it and must run it through
///     [Streak] semantics rather than trusting the bare integer.
///   • `streak_last_active_date` — the day the count last moved. Without this the
///     count cannot be interpreted at all.
///   • `last_opened_at` — opens, not activity. Still written by [recordOpen],
///     because "welcome back, it has been three days" is a different question
///     from "how long is your run" and needs its own answer.
///
/// ── On counting by calendar day ───────────────────────────────────────
/// The date arithmetic lives in `streak_math.dart`, which has no Flutter and no
/// storage in it and is therefore testable on its own — see that file for why
/// `DateTime.difference(...).inDays` is the wrong tool and what DST does to it.
/// This file is the storage half: read three keys, write two, expose a notifier.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streak_math.dart';

export 'streak_math.dart' show Streak;

abstract final class StreakStore {
  static const _countKey = 'streak_count';
  static const _lastActiveKey = 'streak_last_active_date';
  static const _lastOpenedKey = 'last_opened_at';

  /// Whole days since the previous open, or `null` on a first launch. Kept
  /// because "welcome back" copy needs to know a gap happened, and this is still
  /// the only place that can tell.
  static int? daysAway;

  /// Stamp today's open and work out how long the user was away. Call once, from
  /// `main()`. Deliberately does **not** touch the streak count.
  static Future<void> recordOpen({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(now ?? DateTime.now());

    final lastRaw = prefs.getString(_lastOpenedKey);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    daysAway = last == null ? null : daysBetweenDates(last, today);

    // One-time migration. The old count meant "days opened in a row" and there
    // was no activity date at all, so on the first launch after this change
    // `evaluate` would find a count it cannot interpret and report a broken run —
    // silently wiping a streak the user believes they have. Adopting their last
    // open as their last active day is the closest true statement available from
    // what was stored, and it errs towards keeping the run.
    if (last != null &&
        prefs.getInt(_countKey) != null &&
        prefs.getString(_lastActiveKey) == null) {
      await prefs.setString(_lastActiveKey, dateOnly(last).toIso8601String());
    }

    await prefs.setString(_lastOpenedKey, today.toIso8601String());
  }

  /// Read the run. Pure with respect to storage: a read never writes, so a
  /// broken run is *reported* as broken and the count is only rewritten when real
  /// activity next arrives.
  static Future<Streak> evaluate({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    return _evaluate(prefs, dateOnly(now ?? DateTime.now()));
  }

  static Streak _evaluate(SharedPreferences prefs, DateTime today) {
    final lastRaw = prefs.getString(_lastActiveKey);
    return resolveStreak(
      count: prefs.getInt(_countKey) ?? 0,
      lastActive: lastRaw == null ? null : DateTime.tryParse(lastRaw),
      today: today,
    );
  }

  /// Count today. Idempotent within a day — the second and third things you do
  /// today are not a second and third day.
  static Future<Streak> recordActivity({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(now ?? DateTime.now());

    final current = _evaluate(prefs, today);
    if (current.activeToday) return current;

    final next = nextStreakCount(current);
    await prefs.setInt(_countKey, next);
    await prefs.setString(_lastActiveKey, today.toIso8601String());
    return Streak(days: next, activeToday: true);
  }
}

class StreakController extends StateNotifier<Streak> {
  StreakController() : super(Streak.none) {
    reevaluate();
  }

  /// Recompute from storage. Called on construction and whenever the app returns
  /// to the foreground — that second call is what makes a midnight rollover
  /// visible on a phone that was left sitting on the Home screen.
  Future<void> reevaluate() async {
    final value = await StreakStore.evaluate();
    if (mounted) state = value;
  }

  /// Called from [TodaysMizanController.mark] — the one place in the app that
  /// decides something meaningful happened today. Nothing else should call this;
  /// if a new action deserves to count, mark a facet and it will.
  Future<void> recordActivity() async {
    if (state.activeToday) return; // cheap guard; the store is idempotent anyway
    final value = await StreakStore.recordActivity();
    if (mounted) state = value;
  }
}

final streakProvider = StateNotifierProvider<StreakController, Streak>(
  (ref) => StreakController(),
);
