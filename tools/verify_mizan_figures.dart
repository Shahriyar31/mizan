/// Checks Al-Mizan's calendar arithmetic. Run with:
///
///   flutter/bin/cache/dart-sdk/bin/dart tools/verify_mizan_figures.dart
///
/// Nothing here imports Flutter, which is the reason `mizan_figures.dart` keeps
/// its calculations pure and takes an explicit `now`. Calendar code that is one
/// day out is not a class of bug that gets noticed by looking at a screen — a
/// wrong Ramadan count looks exactly as plausible as a right one — so the
/// properties below are asserted rather than eyeballed.
library;

// A command-line report is the whole output of this file, so print is correct.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:mizan/core/util/hijri_date.dart';
import 'package:mizan/features/growth/domain/mizan_figures.dart';

int _failures = 0;

void check(String what, Object? got, Object? want) {
  final ok = got == want;
  if (!ok) _failures++;
  print('${ok ? '  ok  ' : ' FAIL '} $what → $got${ok ? '' : '  (want $want)'}');
}

void expect(String what, bool ok, [String note = '']) {
  if (!ok) _failures++;
  print('${ok ? '  ok  ' : ' FAIL '} $what $note');
}

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  print('── day number is inclusive of today ──');
  // Born today: you are living day 1, not day 0.
  check('born today', MizanFigures.forBirthDate(d(2026, 8, 24),
      now: d(2026, 8, 24)).dayNumber, 1);
  check('born yesterday', MizanFigures.forBirthDate(d(2026, 8, 23),
      now: d(2026, 8, 24)).dayNumber, 2);
  // Across a spring-forward DST boundary in Europe/Berlin (29 Mar 2026), which is
  // where `Duration(days: 1)` arithmetic loses an hour and then a whole day.
  check('spans DST spring-forward', MizanFigures.forBirthDate(d(2026, 3, 28),
      now: d(2026, 3, 30)).dayNumber, 3);

  print('\n── Jumu\'ahs ──');
  // 2026-08-21 is a Friday; 2026-08-28 is the next.
  check('one Friday, inclusive', fridaysBetween(d(2026, 8, 21), d(2026, 8, 24)), 1);
  check('two Fridays', fridaysBetween(d(2026, 8, 21), d(2026, 8, 28)), 2);
  check('none yet', fridaysBetween(d(2026, 8, 22), d(2026, 8, 24)), 0);
  check('today is Friday counts', fridaysBetween(d(2026, 8, 24), d(2026, 8, 28)), 1);

  print('\n── Ramadans witnessed: the case yearsBetween got wrong ──');
  // The defect this replaced. Someone born in Rabi' al-Thani (month 4) has lived
  // through every Ramadan since, but a birthday-anniversary count is one short
  // whenever today's Hijri month is earlier than their birth month.
  final born = _gregorianForHijri(1421, 4, 10);
  final today = _gregorianForHijri(1447, 3, 10);
  final anniversaryAnswer = HijriDate.yearsBetween(born, today);
  final ramadanAnswer = ramadansWitnessedBetween(born, today);
  print('       born ${HijriDate.fromGregorian(born).full}');
  print('       today ${HijriDate.fromGregorian(today).full}');
  expect('Ramadan count exceeds the anniversary count',
      ramadanAnswer == anniversaryAnswer + 1,
      '(ramadans=$ramadanAnswer anniversaries=$anniversaryAnswer)');
  check('Ramadans 1421..1446', ramadanAnswer, 26);

  print('\n── Ramadans witnessed: boundaries ──');
  // In Ramadan right now: this one is in progress, so it is not witnessed.
  final inRamadan = _gregorianForHijri(1447, 9, 15);
  check('mid-Ramadan does not count it',
      ramadansWitnessedBetween(_gregorianForHijri(1420, 1, 1), inRamadan),
      1446 - 1420 + 1);
  // 1 Shawwal: it has just completed, so it does.
  final eid = _gregorianForHijri(1447, 10, 1);
  check('1 Shawwal counts it',
      ramadansWitnessedBetween(_gregorianForHijri(1420, 1, 1), eid),
      1447 - 1420 + 1);
  // Born on 1 Ramadan witnesses that whole month; born on the 2nd does not.
  check('born 1 Ramadan 1440, today Shawwal 1440',
      ramadansWitnessedBetween(_gregorianForHijri(1440, 9, 1),
          _gregorianForHijri(1440, 10, 5)), 1);
  check('born 2 Ramadan 1440, today Shawwal 1440',
      ramadansWitnessedBetween(_gregorianForHijri(1440, 9, 2),
          _gregorianForHijri(1440, 10, 5)), 0);
  check('newborn has witnessed none',
      ramadansWitnessedBetween(d(2026, 8, 24), d(2026, 8, 24)), 0);

  print('\n── days to Ramadan ──');
  final dtr = daysToNextRamadan(d(2026, 8, 24));
  final landing = DateTime(2026, 8, 24 + dtr);
  final landingH = HijriDate.fromGregorian(landing);
  expect('lands on 1 Ramadan', landingH.month == 9 && landingH.day == 1,
      '($dtr days → ${landingH.full})');
  expect('inside one Hijri year', dtr > 0 && dtr <= 355, '($dtr)');
  expect('zero during Ramadan', daysToNextRamadan(inRamadan) == 0);
  // No day before the answer may also be 1 Ramadan — i.e. it is the *next* one.
  var earlier = 0;
  for (var i = 1; i < dtr; i++) {
    final h = HijriDate.fromGregorian(DateTime(2026, 8, 24 + i));
    if (h.month == 9 && h.day == 1) earlier++;
  }
  check('no earlier 1 Ramadan skipped', earlier, 0);

  print('\n── prayer times: never before fifteen ──');
  check('a child has none',
      prayerTimesPassedSince(d(2020, 1, 1), d(2026, 8, 24)), 0);
  final fifteen = hijriBirthday(d(2000, 1, 31), 15, notAfter: d(2026, 8, 24));
  expect('fifteenth Hijri birthday found', fifteen != null);
  if (fifteen != null) {
    check('exactly 15 Hijri years on that day',
        HijriDate.yearsBetween(d(2000, 1, 31), fifteen), 15);
    // And not a day early.
    final dayBefore = DateTime(fifteen.year, fifteen.month, fifteen.day - 1);
    check('14 the day before',
        HijriDate.yearsBetween(d(2000, 1, 31), dayBefore), 14);
    final pt = prayerTimesPassedSince(d(2000, 1, 31), d(2026, 8, 24));
    expect('divisible by five', pt % 5 == 0, '($pt)');
    print('       fifteenth Hijri birthday: '
        '${fifteen.toIso8601String().substring(0, 10)}  → $pt prayer times');
  }
  expect('not yet fifteen returns null',
      hijriBirthday(d(2020, 1, 1), 15, notAfter: d(2026, 8, 24)) == null);

  print('\n── nothing counts down against a life ──');
  final src = _read('lib/features/growth/domain/mizan_figures.dart');
  // Guarded, because an empty read would make every check below pass silently.
  expect('source was read', src.length > 1000, '(${src.length} chars)');
  for (final banned in ['lifeExpectancy', 'remainingDays', 'percentOfLife',
    'daysLeft', 'yearsLeft']) {
    expect('no $banned', !src.contains(banned));
  }

  print('\n── the figures a real user would see today ──');
  final f = MizanFigures.forBirthDate(d(2000, 1, 31), now: d(2026, 8, 24));
  print('       day ${groupThousands(f.dayNumber)}'
      '  ·  ${f.livedLine}  ·  ${f.ramadanLine}');
  print('       ${groupThousands(f.prayerTimesPassed)} prayer times'
      '  ·  today is ${f.hijriToday.full}');
  expect('day number is plausible for a 26-year-old',
      f.dayNumber > 9600 && f.dayNumber < 9800, '(${f.dayNumber})');
  expect('Jumu\'ahs is roughly days/7',
      (f.jumuahs - f.dayNumber / 7).abs() < 3, '(${f.jumuahs})');
  expect('Ramadans is roughly years lived',
      f.ramadansWitnessed >= 26 && f.ramadansWitnessed <= 28,
      '(${f.ramadansWitnessed})');

  print('\n${_failures == 0 ? 'ALL CHECKS PASSED' : '$_failures CHECK(S) FAILED'}');
}

/// A Gregorian date whose Hijri value is the one asked for, found by scanning —
/// test scaffolding only, so the tests can be written in the calendar they are
/// about instead of in hand-converted Gregorian dates.
DateTime _gregorianForHijri(int y, int m, int day) {
  // 1 Muharram 1 AH is JDN 1948440; work back to a Gregorian year and scan.
  final approx = ((y - 1) * 354.367).floor();
  var probe = DateTime(622, 7, 19 + approx);
  for (var i = -400; i <= 400; i++) {
    final c = DateTime(probe.year, probe.month, probe.day + i);
    final h = HijriDate.fromGregorian(c);
    if (h.year == y && h.month == m && h.day == day) return c;
  }
  throw StateError('no Gregorian date for $y-$m-$day AH');
}

String _read(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : '';
}
