/// The streak's arithmetic, with no Flutter and no storage in it.
///
/// Split out from `streak_provider.dart` for one reason: **calendar arithmetic is
/// the part that gets this wrong**, and it is the part worth testing on its own.
/// The provider around it is plumbing — read three prefs keys, write two — and
/// plumbing does not have edge cases at midnight, across a DST boundary, or when
/// a device clock jumps backwards. This file does, so it takes no dependencies
/// and can be exercised directly.
///
/// Nothing here reads the clock either. Every function takes `today` as an
/// argument, so a test can name the day it means instead of hoping the suite does
/// not run at 23:59:59.
library;

/// The run as it stands on a given day.
class Streak {
  const Streak({required this.days, required this.activeToday});

  /// Consecutive days ending today or yesterday. **Zero means there is no live
  /// run** — either nothing has been done yet, or a whole day went by untouched.
  final int days;

  /// True once today has been counted.
  final bool activeToday;

  static const none = Streak(days: 0, activeToday: false);

  /// Alive, but today is still open. This is the state Duolingo greys the flame
  /// for, and the one worth showing differently: the number is real, and it is
  /// also the number you stand to lose tonight.
  bool get atRisk => days > 0 && !activeToday;

  @override
  bool operator ==(Object other) =>
      other is Streak && other.days == days && other.activeToday == activeToday;

  @override
  int get hashCode => Object.hash(days, activeToday);

  @override
  String toString() => 'Streak(days: $days, activeToday: $activeToday)';
}

/// Midnight on the day [d] falls on, in local time.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to] — 0 for the same day, 1 for
/// consecutive days, negative if [to] is earlier.
///
/// Why this exists instead of `to.difference(from).inDays`: that subtracts two
/// *instants* and floors the result, so 23:00 Monday → 08:00 Tuesday is `0` while
/// 08:00 Monday → 23:00 Tuesday is `1`. Same two calendar days, different
/// answers, which is exactly the bug the old streak had. Normalising both ends to
/// midnight first removes the time of day from the question entirely.
///
/// The `Duration` is still taken *after* normalising rather than by subtracting
/// day numbers, so month and year boundaries need no special handling. The `.5`
/// rounding absorbs the 23- and 25-hour days that daylight saving produces: on a
/// DST change the normalised difference is 23h or 25h, and `inDays` alone would
/// call that 0 or 1 day respectively — one of which is wrong.
int daysBetweenDates(DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  return (b.difference(a).inHours / 24).round();
}

/// Decide the run from what was stored.
///
/// * [count] — `streak_count` as persisted, meaningless on its own.
/// * [lastActive] — the day [count] last moved, or null if it never has.
/// * [today] — the day being asked about.
///
/// The rules, in the order they are applied:
///
///   1. **No last-active day, or a non-positive count → no run.** A count
///      without a date cannot be interpreted, and a zero or negative count is
///      not a run whatever the date says.
///   2. **Active today → alive, today counted.**
///   3. **Active yesterday → alive, today still open.** This is the window in
///      which the streak can be extended; it is not yet broken.
///   4. **Last active in the future → alive, today still open.** A device clock
///      that moved backwards (timezone change, NTP correction, a user setting the
///      date) is not a missed day, and breaking somebody's run over it would be
///      indefensible. The run stands and today simply is not counted yet.
///   5. **Two or more days ago → broken, no run.**
Streak resolveStreak({
  required int count,
  required DateTime? lastActive,
  required DateTime today,
}) {
  if (lastActive == null || count <= 0) return Streak.none;

  final gap = daysBetweenDates(lastActive, today);
  if (gap == 0) return Streak(days: count, activeToday: true);
  if (gap <= 1) return Streak(days: count, activeToday: false);
  return Streak.none;
}

/// The count to store when activity lands on [today], given the run [current].
///
/// Extends a live run, restarts a broken one at 1, and returns the count
/// unchanged when today is already counted — the second and third things you do
/// today are not a second and third day.
int nextStreakCount(Streak current) {
  if (current.activeToday) return current.days;
  return current.days > 0 ? current.days + 1 : 1;
}
