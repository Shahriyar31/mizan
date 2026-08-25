/// FeatureFlags — read-once config from the build environment, with safe
/// defaults.
///
/// Your README makes the point well: ship code that's turned off, then flip a
/// flag when it's ready — no big-bang releases. This centralises that so no
/// widget reads the environment directly. `1`/`true`/`on`/`yes` (any case) means
/// enabled, and an undefined flag falls back to on.
///
/// The values live in `.env` and reach the app as `--dart-define` constants; see
/// `build_config.dart`. Unlike the keys, flags **are** passed by the release build
/// script — they decide what the app does, they say nothing secret, and a release
/// with the flags dropped would silently ship with three finished features in
/// their fallback state.
///
/// [seedSocialDemo] controls whether Halaqa/Minbar pre-populate sample data on
/// first run — handy for demos, and trivial to turn off for production.
library;

import 'build_config.dart';

class FeatureFlags {
  FeatureFlags._();

  static bool get halaqa => BuildConfig.featureHalaqa;
  static bool get minbar => BuildConfig.featureMinbar;
  static bool get scholarAi => BuildConfig.featureScholarAi;

  /// Seed a sample circle + Minbar feed on first launch (demo experience).
  static bool get seedSocialDemo => BuildConfig.featureSeedSocial;
}
