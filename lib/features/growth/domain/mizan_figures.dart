/// Al-Mizan's figures — every number on the Home hero card and the Al-Mizan
/// screen, derived from one birth date and the user's real app history.
///
/// ── The rules this file exists to enforce ─────────────────────────────
/// **Nothing here estimates, and nothing here counts down.** There is no life
/// expectancy in this file, no remaining-days figure, no percentage and no
/// progress fraction, and there must never be one: no one is told the number of
/// their days. The lived portion is measurable and is measured; the remainder is
/// not ours to model. If a figure cannot be derived from the birth date or from
/// something the app actually recorded, the caller shows a prompt instead of a
/// number — which is why every accessor here is on a class that is only
/// constructed once a birth date exists.
///
/// ── Why the arithmetic is here and not in the screens ─────────────────
/// It was in three places: private helpers in `al_meezan_screen.dart`, a verbatim
/// copy in `meezan_summary.dart` (whose own comment admitted the duplication and
/// asked for this file), and the date line on Home. Three copies of a calendar
/// calculation is how one screen ends up a day out from another. The functions
/// below are pure, take an explicit `now`, and touch neither Flutter nor storage,
/// so they can be exercised directly — see `tools/verify_mizan_figures.dart`.
///
/// ── On the Hijri calendar ─────────────────────────────────────────────
/// `HijriDate` is the tabular (arithmetic) calendar, which is what the
/// `hijri_calendar` package implements too. It is *not* a 354-day approximation
/// of the year — it runs the real 30-year cycle of 10,631 days — but it is also
/// not moon sighting, so it can land a day either side of a locality's observed
/// date. That is why nothing computed here is used to say when to fast or when
/// Eid falls. Counting whole Ramadans elapsed is exactly the kind of question it
/// is good for.
library;

import '../../home/domain/streak_math.dart';
import '../../../core/util/hijri_date.dart';

/// Every figure Al-Mizan shows, computed together so no two can disagree.
class MizanFigures {
  const MizanFigures({
    required this.birthDate,
    required this.dayNumber,
    required this.jumuahs,
    required this.ramadansWitnessed,
    required this.prayerTimesPassed,
    required this.daysToRamadan,
    required this.hijriToday,
  });

  /// The one input the user supplies. Device-only.
  final DateTime birthDate;

  /// **Today is day N.** Whole days since birth, plus one — the day you are
  /// living is a day you have been given, so it counts.
  ///
  /// This is deliberately not a "days lived" total, and the distinction is the
  /// whole point of the Home card: a total is the same number every morning until
  /// you stop reading it, whereas "today is day 9,702" is a different sentence
  /// each day and visibly moves. Do not turn this back into a total.
  final int dayNumber;

  /// Fridays that have fallen since birth, inclusive of today if today is Friday.
  final int jumuahs;

  /// Ramadans that have **fully passed**. One in progress is not counted — see
  /// [ramadansWitnessed] for why that needs its own calculation.
  final int ramadansWitnessed;

  /// Prayer times that have come and gone since the user turned fifteen Hijri
  /// years old, five to a day.
  ///
  /// **This counts prayer times, not prayers performed.** The app has no idea
  /// what was prayed and will never claim to; the copy that renders this must say
  /// "prayer times passed" and must never say "prayers". Zero until the fifteenth
  /// Hijri birthday, because before that there is nothing to count.
  final int prayerTimesPassed;

  /// Days until the next 1 Ramadan. Zero while Ramadan is in progress, which the
  /// copy handles as "Ramadan is here" rather than as a countdown of nothing.
  ///
  /// The only forward-looking figure in Al-Mizan, and the only one a person can
  /// act on — which is why it is the only one drawn in gold.
  final int daysToRamadan;

  /// Today's Hijri date, for the date line next to the card's eyebrow.
  final HijriDate hijriToday;

  bool get isRamadanNow => hijriToday.month == 9;

  /// The Home card's second line. Both figures are measures of time given, never
  /// of anything done with it.
  String get livedLine => '${groupThousands(ramadansWitnessed)} Ramadans'
      ' · ${groupThousands(jumuahs)} Jumu’ahs';

  /// The Home card's last line, and the one people act on.
  String get ramadanLine => isRamadanNow
      ? 'Ramadan is here'
      : 'Ramadan returns in ${groupThousands(daysToRamadan)} days';

  factory MizanFigures.forBirthDate(DateTime birthDate, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final birth = dateOnly(birthDate);
    return MizanFigures(
      birthDate: birth,
      dayNumber: daysBetweenDates(birth, today) + 1,
      jumuahs: fridaysBetween(birth, today),
      ramadansWitnessed: ramadansWitnessedBetween(birth, today),
      prayerTimesPassed: prayerTimesPassedSince(birth, today),
      daysToRamadan: daysToNextRamadan(today),
      hijriToday: HijriDate.fromGregorian(today),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  The pure calculations
//
//  Two of these carry a `Between` / `Since` suffix only because a field on
//  [MizanFigures] already holds the plain name, and a field shadows a top-level
//  function inside the class body.
// ══════════════════════════════════════════════════════════════════════

/// Fridays between two dates, inclusive of both ends.
///
/// Moved here from `al_meezan_screen.dart` and `meezan_summary.dart`, which held
/// identical copies.
int fridaysBetween(DateTime from, DateTime to) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  final totalDays = daysBetweenDates(start, end);
  if (totalDays < 0) return 0;
  // Days from `start` until the first Friday it reaches (DateTime.friday == 5).
  final offset = (DateTime.friday - start.weekday + 7) % 7;
  if (offset > totalDays) return 0;
  return ((totalDays - offset) ~/ 7) + 1;
}

/// Ramadans that have fully passed since birth.
///
/// This is **not** `HijriDate.yearsBetween`, which is what the app used before
/// and which is a different question. That counts Hijri *birthday* anniversaries,
/// so it is a year behind for anyone born in Muharram through Sha'ban whose
/// birthday has not yet come round again — someone born in Rabi' al-Thani has
/// lived through the Ramadan that followed, but their anniversary test says
/// otherwise. Counting Ramadans has to be anchored to Ramadan.
///
/// A Ramadan counts when the whole month sits between the birth date and today:
/// its first day is on or after the birth date, and its last day is behind us. So
/// the run of qualifying Hijri years is contiguous and only its two ends need
/// finding, which avoids needing a Hijri → Gregorian conversion at all.
int ramadansWitnessedBetween(DateTime birth, DateTime now) {
  final b = HijriDate.fromGregorian(dateOnly(birth));
  final n = HijriDate.fromGregorian(dateOnly(now));

  // Born before Ramadan (or on its very first day) and that year's Ramadan is
  // still ahead of them; born during or after it and it is not theirs to count.
  final first = (b.month < 9 || (b.month == 9 && b.day == 1)) ? b.year : b.year + 1;

  // Month 9 means Ramadan is happening now, which is not yet witnessed.
  final last = n.month > 9 ? n.year : n.year - 1;

  return last < first ? 0 : last - first + 1;
}

/// Days until the next 1 Ramadan, or 0 if Ramadan is in progress.
///
/// Walks forward a day at a time rather than inverting the calendar. A Hijri year
/// is at most 355 days, so this is bounded at a few hundred cheap integer
/// conversions once per screen build, and in exchange it cannot disagree with
/// [HijriDate.fromGregorian] — an independent inverse algorithm is exactly the
/// kind of thing that is subtly one day out and never noticed.
int daysToNextRamadan(DateTime now) {
  final today = dateOnly(now);
  if (HijriDate.fromGregorian(today).month == 9) return 0;
  for (var i = 1; i <= 400; i++) {
    // Day-component arithmetic, not `add(Duration(days:))`: Dart normalises the
    // overflow and stays on local midnight, where adding 24-hour durations
    // lands on 23:00 the previous day across a DST spring-forward.
    final d = DateTime(today.year, today.month, today.day + i);
    final h = HijriDate.fromGregorian(d);
    if (h.month == 9 && h.day == 1) return i;
  }
  return 0; // unreachable for any real calendar; never guess a number here
}

/// Prayer times that have passed since the fifteenth Hijri birthday, five a day.
int prayerTimesPassedSince(DateTime birth, DateTime now) {
  final from = hijriBirthday(birth, 15);
  if (from == null) return 0;
  final days = daysBetweenDates(from, dateOnly(now));
  return days <= 0 ? 0 : days * 5;
}

/// The Gregorian date on which someone born on [birth] completes [age] Hijri
/// years, or null if that date has not arrived yet.
///
/// Found by scanning, for the same reason as [daysToNextRamadan]: it is defined
/// in terms of the forward conversion, so it cannot drift from it.
/// [HijriDate.yearsBetween] is monotonic in its second argument, which makes the
/// first date that satisfies the test the only one that matters. The window is
/// anchored on the tabular year length — a 30-year cycle is 10,631 days, so a
/// Hijri year averages 354.37 — and then padded generously either side.
DateTime? hijriBirthday(DateTime birth, int age, {DateTime? notAfter}) {
  final start = dateOnly(birth);
  final estimate = (age * 354.367).floor() - 20;
  final limit = dateOnly(notAfter ?? DateTime.now());
  for (var i = estimate < 0 ? 0 : estimate; i <= estimate + 60; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    if (HijriDate.yearsBetween(start, d) >= age) {
      return d.isAfter(limit) ? null : d;
    }
  }
  return null;
}

/// 12345 → "12,345".
String groupThousands(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
