/// Today's Mizan — the three things the Home strip records.
///
/// ── Rule #4, which governs this whole file ────────────────────────────
/// *"No scoring of deeds. The Mizan strip records what you engaged with today;
/// it never totals, ranks, or grades. No '+1', no percentage, no verdict."*
///
/// So this is deliberately three booleans and nothing else. There is no count,
/// no sum, no `score` getter, and no ordering between the facets — adding any of
/// those would break the rule, and the card's own footer says so out loud: *"A
/// record, not a score."* If a future change wants a number here, that is a
/// product decision to take to the user, not an implementation detail.
///
/// The three are also **not** a checklist to complete. Nothing in the UI may
/// nudge, congratulate, or shame based on how many are lit.
///
/// ── Persistence ───────────────────────────────────────────────────────
/// One key holding a `yyyy-mm-dd|l,r,a` string. Stamping the date into the value
/// means a stale record from yesterday reads as three empty facets today without
/// needing a midnight timer or a cleanup pass.
///
/// `reflected` unions in the pre-existing `last_muhasabah_date` pref, so a user
/// who has been writing muhasabah since before this file existed does not see
/// that facet reset to empty.
///
/// ── Why the streak listens here ───────────────────────────────────────
/// [mark] is the only place in the app that asserts "something happened today",
/// so it is the only honest input to a day-streak. The first facet marked on a
/// day advances [streakProvider]; the second and third do not, because a streak
/// counts *days*, not deeds. That distinction is what keeps Rule #4 intact — the
/// streak is not a score derived from this record, it is a count of the days the
/// record was non-empty.
///
/// The consequence worth knowing: **if an action does not mark a facet, it does
/// not count towards the streak.** That is the intended design. When a new
/// meaningful action ships, mark the facet it belongs to and the streak follows
/// for free; never reach for `StreakStore` directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../growth/domain/mizan_record.dart';
import 'streak_provider.dart';

/// The three facets. Named for what the user *did*, never for a value earned.
enum MizanFacet {
  /// Took in knowledge: read an ayah, finished a Discover layer, reviewed a word.
  learned,

  /// Turned inward: wrote a reflection or sat with the muhasabah questions.
  reflected,

  /// Turned outward: shared with a circle, posted to Minbar, made a du'a for someone.
  acted,
}

class TodaysMizan {
  const TodaysMizan({
    this.learned = false,
    this.reflected = false,
    this.acted = false,
  });

  final bool learned;
  final bool reflected;
  final bool acted;

  static const empty = TodaysMizan();

  /// Nothing engaged today. A getter rather than `this == empty` on purpose:
  /// this class has no `==`, so identity comparison would call a freshly decoded
  /// all-false record "not empty" and quietly count a streak day for a user who
  /// has done nothing. Asking the three fields cannot get that wrong.
  bool get isEmpty => !learned && !reflected && !acted;

  bool has(MizanFacet f) => switch (f) {
        MizanFacet.learned => learned,
        MizanFacet.reflected => reflected,
        MizanFacet.acted => acted,
      };

  TodaysMizan with_(MizanFacet f) => switch (f) {
        MizanFacet.learned => _copy(learned: true),
        MizanFacet.reflected => _copy(reflected: true),
        MizanFacet.acted => _copy(acted: true),
      };

  TodaysMizan _copy({bool? learned, bool? reflected, bool? acted}) =>
      TodaysMizan(
        learned: learned ?? this.learned,
        reflected: reflected ?? this.reflected,
        acted: acted ?? this.acted,
      );

  String encode(DateTime day) =>
      '${_stamp(day)}|${learned ? 1 : 0},${reflected ? 1 : 0},${acted ? 1 : 0}';

  /// Returns [empty] for anything unparseable or not stamped with [day] — a
  /// corrupt value and a stale value should both simply mean "nothing yet".
  static TodaysMizan decode(String? raw, DateTime day) {
    if (raw == null) return empty;
    final parts = raw.split('|');
    if (parts.length != 2 || parts.first != _stamp(day)) return empty;
    final f = parts[1].split(',');
    if (f.length != 3) return empty;
    return TodaysMizan(
      learned: f[0] == '1',
      reflected: f[1] == '1',
      acted: f[2] == '1',
    );
  }

  static String _stamp(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class TodaysMizanController extends StateNotifier<TodaysMizan> {
  TodaysMizanController(this._ref) : super(TodaysMizan.empty) {
    _restore();
  }

  final Ref _ref;

  static const _key = 'todays_mizan';

  /// Written by the muhasabah screen since long before this file. Read, never
  /// written, here.
  static const _muhasabahKey = 'last_muhasabah_date';

  /// Re-read from storage. Called on construction, and again from `app.dart`
  /// whenever the app resumes — a record stamped `yyyy-mm-dd` is only true for
  /// the day it names, and the app may have been in the background across
  /// midnight.
  Future<void> refresh() => _restore();

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    var value = TodaysMizan.decode(prefs.getString(_key), today);

    // Honour muhasabah written before this store existed, or written by the
    // muhasabah screen without going through `mark`.
    if (prefs.getString(_muhasabahKey) == TodaysMizan._stamp(today)) {
      value = value.with_(MizanFacet.reflected);
    }
    if (mounted) state = value;

    // Self-heal. Two cases land here: a facet stamped today by a build that
    // predates the streak change, and the muhasabah union just above — neither
    // of which ever called `recordActivity`. Recording it now is safe because
    // that call is idempotent per day, and the alternative is a user who
    // demonstrably used the app today seeing their run marked at risk.
    if (!value.isEmpty) {
      await _ref.read(streakProvider.notifier).recordActivity();
      await _noteDay();
    }
  }

  /// Tell [MizanRecordStore] that today is a recorded day, so Growth's week strip
  /// and its "since you began" figures have something true to draw.
  ///
  /// Called *after* the streak, never before: the store keeps the high-water mark
  /// of the run, and comparing against a run that has not yet counted today would
  /// leave the longest run permanently one short.
  Future<void> _noteDay() => MizanRecordStore.noteRecorded(
        currentRun: _ref.read(streakProvider).days,
      );

  /// Record that a facet was engaged today. Idempotent — marking twice is not
  /// different from marking once, because there is nothing to increment.
  Future<void> mark(MizanFacet facet) async {
    if (state.has(facet)) return;
    final next = state.with_(facet);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.encode(DateTime.now()));

    // Today now holds something. Deliberately after the write: the streak is a
    // claim about a day that is already on disk.
    await _ref.read(streakProvider.notifier).recordActivity();
    await _noteDay();
  }
}

final todaysMizanProvider =
    StateNotifierProvider<TodaysMizanController, TodaysMizan>(
  (ref) => TodaysMizanController(ref),
);
