/// First-run flags.
///
/// Deliberately **not** a Riverpod provider. `AppRouter.router` is a static
/// final, so its `initialLocation` is evaluated the first time anything touches
/// it — which happens inside `MaterialApp.router`, i.e. during the first build,
/// long after `main()` could have awaited a provider. A plain static that
/// `main()` fills in before `runApp` is read synchronously at exactly the right
/// moment.
///
/// The alternative — a GoRouter `redirect` that sends first-run users to
/// `/welcome` — was considered and rejected: `redirect` runs on *every*
/// navigation, so a flag that has not been persisted yet (or a write that
/// fails) turns into a redirect loop that traps the user on the welcome screen.
/// Choosing the start location once cannot loop.
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract final class OnboardingFlags {
  /// Stable storage key — renaming it re-shows the welcome screen to every
  /// existing user.
  static const _welcomeKey = 'onboarding_welcome_seen';

  /// Whether the welcome screen has been dismissed. Populated by [restore]
  /// before the first frame; `false` until then, which is the safe default —
  /// worst case a returning user sees the welcome screen once more, rather than
  /// a new user never seeing it.
  static bool welcomeSeen = false;

  /// Stable storage key — renaming it re-shows the six-layers card to every
  /// existing reader.
  static const _layersIntroKey = 'reader_layers_intro_seen';

  /// Whether the "Every ayah has six layers" card has been answered — by
  /// starting with Words *or* by declining. Either counts: a card that must be
  /// refused on every ayah is an advert, not an introduction.
  ///
  /// Restored with [welcomeSeen] before the first frame, so the reader either
  /// draws the card immediately or never — it can never appear a beat after the
  /// ayah has been read.
  static bool layersIntroSeen = false;

  /// Stable storage key — renaming it re-shows the Halaqa explainer to everybody.
  static const _halaqaHowItWorksKey = 'halaqa_how_it_works_seen';

  /// Whether the "How a halaqa works" panel has done its job.
  ///
  /// Set two ways, because this card asks a question the user can also answer
  /// without reading it: explicitly, when they dismiss it, and implicitly, the
  /// first time they are in a circle at all — somebody who has created or joined
  /// one has demonstrably worked out what a circle is, and an explainer that
  /// keeps reappearing above their own circles is an advert. Writing the flag in
  /// the implicit case rather than merely hiding the card is the point of it:
  /// leaving every circle later must not bring the explanation back to someone
  /// who has already run one.
  ///
  /// Restored with the others before the first frame, so the Halaqa tab either
  /// draws the panel or does not, and it can never drop in a beat late.
  static bool halaqaHowItWorksSeen = false;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    welcomeSeen = prefs.getBool(_welcomeKey) ?? false;
    layersIntroSeen = prefs.getBool(_layersIntroKey) ?? false;
    halaqaHowItWorksSeen = prefs.getBool(_halaqaHowItWorksKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    welcomeSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }

  static Future<void> markLayersIntroSeen() async {
    layersIntroSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_layersIntroKey, true);
  }

  /// Idempotent, and called from a `build` in one of its two cases — see
  /// [halaqaHowItWorksSeen]. The static is set first so a caller that checks the
  /// flag on the very next line is not told to write it twice while the
  /// [SharedPreferences] future is still in flight.
  static Future<void> markHalaqaHowItWorksSeen() async {
    halaqaHowItWorksSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_halaqaHowItWorksKey, true);
  }
}
