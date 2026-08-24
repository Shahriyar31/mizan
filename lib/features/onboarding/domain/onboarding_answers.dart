/// What the person told us during onboarding, and where it is kept.
///
/// Two answers are collected in the welcome flow and both of them change the
/// app, which is the only reason they are asked:
///
///  * [MizanIntent] — why they are here. Decides where they land the first time
///    the app opens, and stays readable afterwards so Settings can show it and
///    change it.
///  * [DailyMinutes] — how much time they have. Sets the size of a day's
///    reading.
///
/// ── Why this is its own store ──────────────────────────────────────────
/// It would be tempting to hang these off [OnboardingFlags], which is already a
/// plain static read before the first frame. But those two flags are read by
/// `AppRouter`'s `initialLocation`, which is evaluated exactly once and can
/// therefore be a static; these two are read by screens that have to *rebuild*
/// when the person changes their mind in Settings. That needs a provider.
///
/// ── Why the reminder time is not here ─────────────────────────────────
/// Because it already exists. `NotificationPreferences` holds the daily
/// reminder hour and minute and is wired to real scheduled notifications, so
/// onboarding writes into that rather than keeping a second copy that would
/// immediately disagree with it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why somebody opened Mizan. Asked last in the flow, on purpose: it is the
/// only question whose answer changes the app, and asking it after they have
/// seen what the app *is* gets a truthful answer rather than a guess.
enum MizanIntent {
  /// Roots, grammar, why this word.
  words(
    id: 'words',
    icon: Icons.translate,
    title: 'Understand the words',
    subtitle: 'Roots, grammar, why this word',
    landing: '/quran',
  ),

  /// Prophets, companions, places.
  stories(
    id: 'stories',
    icon: Icons.groups_2,
    title: 'Follow the stories',
    subtitle: 'Prophets, companions, places',
    landing: '/discover',
  ),

  /// Small, every day, without guilt.
  habit(
    id: 'habit',
    icon: Icons.calendar_month,
    title: 'Build a daily habit',
    subtitle: 'Small, every day, without guilt',
    landing: '/growth',
  ),

  /// Tafsir, isnad, scholarly difference.
  depth(
    id: 'depth',
    icon: Icons.account_balance,
    title: 'Study with depth',
    subtitle: 'Tafsir, isnad, scholarly difference',
    landing: '/knowledge/scholars',
  );

  const MizanIntent({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.landing,
  });

  /// Stable storage value. Never renamed: the enum's `name` would do the same
  /// job until somebody reorders or renames a case, at which point everybody's
  /// stored answer silently becomes something else.
  final String id;

  final IconData icon;
  final String title;
  final String subtitle;

  /// Where the app opens the first time, immediately after sign-in.
  ///
  /// This is the whole point of asking. An answer collected and ignored is
  /// worse than not asking, because it teaches the person that the questions
  /// are decoration.
  ///
  /// Every one of these is a route that exists in `AppRouter` — checked, because
  /// a landing route that does not resolve turns the reward for answering into
  /// GoRouter's error screen. Two are the nearest real thing rather than the
  /// literal promise: "understand the words" opens the reader's surah index
  /// rather than a reader with the Words layer already open, since there is no
  /// ayah to open it on yet; "study with depth" opens Scholars, which is where
  /// tafsir and isnad are reached from.
  final String landing;

  static MizanIntent? fromId(String? id) {
    if (id == null) return null;
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// How long a day's reading should be. The middle option is the default
/// because it is the one the flow describes as an ayah with its layers — the
/// thing the app is actually for.
enum DailyMinutes {
  five(minutes: 5, label: 'one ayah'),
  ten(minutes: 10, label: 'an ayah, layered'),
  twenty(minutes: 20, label: 'a full story');

  const DailyMinutes({required this.minutes, required this.label});

  final int minutes;

  /// What that much time buys, in the app's own terms rather than in minutes.
  final String label;

  static DailyMinutes fromMinutes(int? minutes) {
    for (final value in values) {
      if (value.minutes == minutes) return value;
    }
    return DailyMinutes.ten;
  }
}

@immutable
class OnboardingAnswers {
  const OnboardingAnswers({
    this.intent,
    this.minutes = DailyMinutes.ten,
    this.landingConsumed = false,
  });

  /// Null when the person skipped the question. Skipping is allowed and means
  /// "no preference" — it must never be silently filled in with a guess.
  final MizanIntent? intent;

  final DailyMinutes minutes;

  /// Whether the intent's landing route has already been used.
  ///
  /// The intent decides where the app opens *once*. Without this flag it would
  /// decide where the app opens every time, which would make the five tabs
  /// pointless and trap somebody who answered "stories" on the Discover tab
  /// forever.
  final bool landingConsumed;

  /// The route to open on, or null when there is nothing to honour — either no
  /// answer was given or it has already been honoured once.
  String? get pendingLanding =>
      landingConsumed ? null : intent?.landing;

  OnboardingAnswers copyWith({
    MizanIntent? intent,
    DailyMinutes? minutes,
    bool? landingConsumed,
  }) =>
      OnboardingAnswers(
        intent: intent ?? this.intent,
        minutes: minutes ?? this.minutes,
        landingConsumed: landingConsumed ?? this.landingConsumed,
      );
}

class OnboardingAnswersController extends StateNotifier<OnboardingAnswers> {
  OnboardingAnswersController() : super(const OnboardingAnswers()) {
    _ready = _load();
  }

  static const _kIntent = 'onboarding_intent';
  static const _kMinutes = 'onboarding_daily_minutes';
  static const _kLandingConsumed = 'onboarding_landing_consumed';

  late final Future<void> _ready;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = OnboardingAnswers(
      intent: MizanIntent.fromId(p.getString(_kIntent)),
      minutes: DailyMinutes.fromMinutes(p.getInt(_kMinutes)),
      landingConsumed: p.getBool(_kLandingConsumed) ?? false,
    );
  }

  /// Writes the answer through immediately rather than at the end of the flow.
  ///
  /// The alternative — hold both answers in the flow's own State and write them
  /// after sign-in — is how these answers get lost. Sign-in leaves the app: an
  /// OAuth round trip can and does take the process with it, and anything held
  /// only in a State object goes with it. Persisting on tap means the answers
  /// are already on disk before the account boundary is anywhere near.
  Future<void> setIntent(MizanIntent intent) async {
    state = state.copyWith(intent: intent);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kIntent, intent.id);
  }

  Future<void> setMinutes(DailyMinutes minutes) async {
    state = state.copyWith(minutes: minutes);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMinutes, minutes.minutes);
  }

  /// Called by the flow once it has handed the person to their landing route,
  /// so the next launch opens on Home like everybody else's.
  Future<void> markLandingConsumed() async {
    if (state.landingConsumed) return;
    state = state.copyWith(landingConsumed: true);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLandingConsumed, true);
  }

  /// The route to open on after sign-in, marked consumed in the same step.
  ///
  /// One method rather than a read the caller follows with a write, because the
  /// two must not be separable: a caller that reads the route and forgets to
  /// mark it would pin the app to that one tab on every launch from then on.
  ///
  /// It awaits the load first. This is the difference between acting on the
  /// stored answer and acting on the default: the state starts at its defaults
  /// and is replaced a frame or two later, so a screen that merely *displays*
  /// the answer can read it straight away and rebuild, while the sign-in screen
  /// — which reads it exactly once and then navigates — cannot. Skipping this
  /// await is how the answer gets lost at the account boundary, and losing it
  /// there is the most common bug in this flow.
  ///
  /// Returns null when there is nothing to honour: the question was skipped, or
  /// its answer has already been used once.
  Future<String?> takeLanding() async {
    await _ready;
    final landing = state.pendingLanding;
    if (landing != null) await markLandingConsumed();
    return landing;
  }

  /// Lets somebody change their mind from Settings, which the flow promises
  /// them in writing: "You can change it any time in Settings."
  Future<void> clearIntent() async {
    state = OnboardingAnswers(
      minutes: state.minutes,
      landingConsumed: state.landingConsumed,
    );
    final p = await SharedPreferences.getInstance();
    await p.remove(_kIntent);
  }
}

final onboardingAnswersProvider =
    StateNotifierProvider<OnboardingAnswersController, OnboardingAnswers>(
  (ref) => OnboardingAnswersController(),
);
