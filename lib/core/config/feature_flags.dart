/// FeatureFlags — read-once config from .env, with safe defaults.
///
/// Your README makes the point well: ship code that's turned off, then flip a
/// flag when it's ready — no big-bang releases. This centralises that so no
/// widget reads dotenv directly. `1`/`true`/`on` (any case) means enabled.
///
/// [seedSocialDemo] controls whether Halaqa/Minbar pre-populate sample data on
/// first run — handy for demos, and trivial to turn off for production.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class FeatureFlags {
  FeatureFlags._();

  static bool _on(String key, {bool fallback = false}) {
    final raw = dotenv.maybeGet(key)?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return fallback;
    return raw == '1' || raw == 'true' || raw == 'on' || raw == 'yes';
  }

  static bool get halaqa => _on('FEATURE_HALAQA', fallback: true);
  static bool get minbar => _on('FEATURE_MINBAR', fallback: true);
  static bool get scholarAi => _on('FEATURE_SCHOLAR_AI', fallback: true);

  /// Seed a sample circle + Minbar feed on first launch (demo experience).
  static bool get seedSocialDemo =>
      _on('FEATURE_SEED_SOCIAL', fallback: true);
}
