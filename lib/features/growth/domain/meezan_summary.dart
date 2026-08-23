/// Al-Meezan summary — the one line of it that appears on Growth.
///
/// Al-Meezan is derived entirely from a single birth date the user sets, stored
/// on device only (`meezan_birth_date`). Nothing here is a deed count and nothing
/// is scored: days lived, Fridays lived through and Ramadans witnessed are
/// measures of *time given*, which is the point of the screen. Rule #4 forbids
/// grading what someone did with that time, and this file does not.
///
/// ── Why the arithmetic is duplicated, and what to do about it ──────────
/// `al_meezan_screen.dart` computes the same three numbers with private
/// top-level helpers. They are reproduced here **verbatim** so the Growth row and
/// the Al-Meezan screen can never disagree by a day. That is a temporary state:
/// the screen should be refactored to read this provider, at which point its
/// copies of `_fridaysBetween` / `_hijriYearsBetween` should be deleted. Until
/// then, any change to the maths must be made in both places.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/util/hijri_date.dart';

/// The three measures, already formatted for display.
class MeezanSummary {
  const MeezanSummary({
    required this.daysLived,
    required this.jumuahs,
    required this.ramadans,
  });

  final int daysLived;
  final int jumuahs;
  final int ramadans;

  /// "8,412 days · 1,201 Fridays · 23 Ramadans witnessed"
  String get line => '${groupThousands(daysLived)} days'
      ' · ${groupThousands(jumuahs)} Fridays'
      ' · $ramadans Ramadans witnessed';
}

/// Null when no birth date has been set — the caller must show a prompt rather
/// than zeros, because "0 days" is a false statement about a living person.
final meezanSummaryProvider = FutureProvider<MeezanSummary?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('meezan_birth_date');
  if (stored == null) return null;
  final birthDate = DateTime.tryParse(stored);
  if (birthDate == null) return null;

  final now = DateTime.now();
  if (birthDate.isAfter(now)) return null;

  return MeezanSummary(
    daysLived: now.difference(birthDate).inDays,
    jumuahs: fridaysBetween(birthDate, now),
    ramadans: HijriDate.yearsBetween(birthDate, now),
  );
});

/// Whole Fridays that have fallen between two dates, inclusive of both ends.
/// Copied verbatim from `al_meezan_screen.dart` — see the library comment.
int fridaysBetween(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final totalDays = end.difference(start).inDays;
  if (totalDays < 0) return 0;
  // Days from start until the first Friday (DateTime.friday == 5).
  final offset = (DateTime.friday - start.weekday + 7) % 7;
  if (offset > totalDays) return 0;
  return ((totalDays - offset) ~/ 7) + 1;
}

/// 12345 → "12,345".
String groupThousands(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
