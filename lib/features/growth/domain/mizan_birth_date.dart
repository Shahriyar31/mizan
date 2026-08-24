/// The birth date, and the provider every Al-Mizan surface reads.
///
/// Replaces `meezan_summary.dart`, which held a second copy of the calendar
/// arithmetic and whose own comment asked to be refactored into exactly this. The
/// arithmetic now lives once, in `mizan_figures.dart`, which stays free of Flutter
/// and Riverpod so it can be exercised by `tools/verify_mizan_figures.dart`. This
/// file is only the plumbing between that and the widgets: one pref key in, one
/// nullable value out.
///
/// ── Null is the whole point of the type ───────────────────────────────
/// [mizanFiguresProvider] resolves to `null` when no birth date has been stored,
/// and every caller must handle that by *asking* for the date. It must never
/// substitute a zero, an average, or a guess from the install date. Rule 4 of the
/// feature brief: no figure is fabricated or estimated to fill a slot — if the
/// birth date is missing, the screen asks for it. `MizanFigures` has no
/// constructor that does not take a real birth date, so the rule is enforced by
/// the type rather than by remembering it at four call sites.
///
/// ── Why the date rolls over on resume ─────────────────────────────────
/// The day number is the one figure on Home that changes without the user doing
/// anything. A phone left on the Home screen overnight would keep yesterday's
/// number until the process was killed, which is precisely the case where a
/// person notices. [MizanFiguresController.refresh] is called from the single
/// `WidgetsBindingObserver` in `app.dart`, alongside the streak's own
/// re-evaluation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mizan_figures.dart';

/// Where the date has lived since the first version of this screen. Unchanged on
/// purpose — a new key would silently lose the date for every existing user.
const String kMizanBirthDateKey = 'meezan_birth_date';

/// Reads and writes the birth date. Device-only; nothing about it is ever sent
/// anywhere, which is why it is a pref and not part of the account.
abstract final class MizanBirthDate {
  static Future<DateTime?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kMizanBirthDateKey);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    // A stored date in the future is not a birth date. Treated as absent so the
    // screen asks again, rather than rendering a negative day number.
    return parsed.isAfter(DateTime.now()) ? null : parsed;
  }

  static Future<void> write(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kMizanBirthDateKey, date.toIso8601String());
  }
}

/// Every Al-Mizan figure, or null until a birth date exists.
class MizanFiguresController extends StateNotifier<AsyncValue<MizanFigures?>> {
  MizanFiguresController() : super(const AsyncValue.loading()) {
    refresh();
  }

  /// Re-read the date and recompute. Called on construction, from `app.dart` on
  /// resume, and after the user sets or changes the date.
  Future<void> refresh() async {
    final birth = await MizanBirthDate.read();
    if (!mounted) return;
    state = AsyncValue.data(
      birth == null ? null : MizanFigures.forBirthDate(birth),
    );
  }

  Future<void> set(DateTime date) async {
    await MizanBirthDate.write(date);
    await refresh();
  }
}

final mizanFiguresProvider =
    StateNotifierProvider<MizanFiguresController, AsyncValue<MizanFigures?>>(
  (ref) => MizanFiguresController(),
);
