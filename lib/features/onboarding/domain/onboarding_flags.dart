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

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    welcomeSeen = prefs.getBool(_welcomeKey) ?? false;
    layersIntroSeen = prefs.getBool(_layersIntroKey) ?? false;
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
}
