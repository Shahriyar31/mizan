/// Gregorian → Hijri, using the tabular (arithmetic) Islamic calendar.
///
/// ── Why this is a shared file ─────────────────────────────────────────
/// This conversion already existed as a private `_toHijri` inside
/// `al_meezan_screen.dart`, where it powers the "Ramadans witnessed" count.
/// Home's Today's Mizan card needs the same conversion for its date line, and
/// two copies of a calendar algorithm is how a project ends up showing two
/// different dates on two screens of the same app. So it lives here once, and
/// Al-Meezan delegates to it.
///
/// ── On accuracy, which matters here ───────────────────────────────────
/// This is the tabular civil calendar (the "Kuwaiti algorithm") — pure
/// arithmetic, no astronomy and no moon sighting. It is the standard offline
/// conversion and it is what almost every offline app uses, but it can land one
/// day either side of the date a given locality actually observes, because that
/// date depends on local sighting.
///
/// That is a real limitation, not a rounding error, and it is why nothing in
/// this file is used to make a religious claim. It is fine for "today is roughly
/// the 17th of Ramadan" on a header, and it is fine for counting whole Hijri
/// years elapsed. It must NOT be used to tell someone when to fast, when Eid is,
/// or when a sacred day falls — those need a sighting-based or authority-issued
/// calendar, which would have to come from a verified source.
library;

class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;

  /// 1–12.
  final int month;

  /// 1–30.
  final int day;

  /// Transliterated month names, in order.
  static const monthNames = <String>[
    'Muharram',
    'Safar',
    "Rabi' al-Awwal",
    "Rabi' al-Thani",
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  String get monthName => monthNames[(month - 1).clamp(0, 11)];

  /// `17 Ramadan` — the form the Home date line uses.
  String get dayAndMonth => '$day $monthName';

  /// `17 Ramadan 1447 AH`.
  String get full => '$day $monthName $year AH';

  /// Convert a Gregorian date via its Julian Day Number.
  factory HijriDate.fromGregorian(DateTime d) {
    final jdn = _gregorianToJdn(d.year, d.month, d.day);
    var l = jdn - 1948440 + 10632;
    final nCycles = (l - 1) ~/ 10631;
    l = l - 10631 * nCycles + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * nCycles + j - 30;
    return HijriDate(year, month, day);
  }

  static HijriDate today({DateTime? now}) =>
      HijriDate.fromGregorian(now ?? DateTime.now());

  /// Full Hijri years elapsed between two Gregorian dates — i.e. how many
  /// Ramadans a person has lived through.
  static int yearsBetween(DateTime from, DateTime to) {
    final b = HijriDate.fromGregorian(from);
    final n = HijriDate.fromGregorian(to);
    var years = n.year - b.year;
    // Subtract one if this Hijri year's anniversary hasn't arrived yet.
    if (n.month < b.month || (n.month == b.month && n.day < b.day)) years -= 1;
    return years < 0 ? 0 : years;
  }

  static int _gregorianToJdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        ((153 * mm + 2) ~/ 5) +
        365 * yy +
        (yy ~/ 4) -
        (yy ~/ 100) +
        (yy ~/ 400) -
        32045;
  }
}

/// `Mon`, `Tue`, … for the Gregorian weekday, which the Home date line pairs
/// with the Hijri day. Deliberately not `intl` — one three-letter list does not
/// justify a localisation dependency here, and the rest of the app's dates are
/// already formatted by hand.
const List<String> kWeekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String weekdayShort(DateTime d) => kWeekdayShort[(d.weekday - 1).clamp(0, 6)];
