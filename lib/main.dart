/// Mizan — Entry Point
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/branding/mizan_brand.dart';
import 'core/config/build_config.dart';
import 'core/config/supabase_config.dart';
import 'core/utils/logger.dart';
import 'features/home/domain/streak_provider.dart';
import 'features/onboarding/domain/onboarding_flags.dart';
import 'features/onboarding/domain/session_gate.dart';
import 'services/database/database_service.dart';
import 'services/audio/audio_session_setup.dart';
import 'services/audio/playback_arbiter.dart';
import 'services/seed/social_seeder.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration is compiled in, not loaded. `.env` used to be a declared
  // asset, which meant a plaintext copy of every key sat inside the APK for
  // anybody to unzip; it now reaches the app as `--dart-define` constants and
  // there is no file in the build to read. See core/config/build_config.dart —
  // including what that does and does not protect.
  //
  // Nothing is awaited here as a result, and nothing can fail: a build made
  // without its variables has them absent rather than wrong, and SupabaseConfig
  // turns that into a sentence on the sign-in screen instead of a black screen.
  // Logged once, by name and length only, so a debug console says which
  // variables a build actually received.
  AppLogger.info('build config: ${BuildConfig.describe()}', tag: 'main');

  // Tell the OS this app plays recitation, before any player exists. Without
  // this iOS routes it to the ambient stream (thin, silenced by the ringer
  // switch, stopped by screen lock) and Android never requests audio focus, so
  // recitation and whatever else is playing are mixed into one output. See
  // AudioSessionSetup.
  await AudioSessionSetup.configure();

  // A phone call or unplugged headphones pause recitation — never discard it.
  // Routed through the arbiter, so neither player has to know these events
  // exist. This is the app's only interruption handler; both players are built
  // with `handleInterruptions: false` so just_audio does not install a second,
  // conflicting one.
  await AudioSessionSetup.attachInterruptionHandling(
    onPause: PlaybackArbiter.instance.pauseAll,
    isPlaying: () => PlaybackArbiter.instance.anyPlaying,
  );

  // Read the chosen app-icon variant before the first frame, so the mark on the
  // welcome screen is right immediately instead of flashing the theme default.
  await LogoVariantController.restore();

  // Whether to open on the welcome screen. Must be read before `runApp`, since
  // AppRouter's initialLocation is evaluated during the first build.
  await OnboardingFlags.restore();

  // Stamp the open and work out how long the user was away. This is the ONLY
  // writer of `last_opened_at` — see StreakStore's header for why having two
  // writers used to freeze the counter.
  //
  // It no longer touches the streak. Opening the app is not an act of learning,
  // so the count now moves only when a Today's Mizan facet is marked; the number
  // itself is derived on read and needs nothing done to it here.
  await StreakStore.recordOpen();

  // Initialize SQLite (personal local data)
  await DatabaseService.instance.database;

  // Initialize Supabase (social data + layer cache).
  //
  // The URL and key are validated first, and when they are unusable this points
  // at a deliberately unresolvable host rather than at localhost — see
  // SupabaseConfig for why the old localhost fallback silently broke stored
  // sessions. Initializing either way is intentional: `Supabase.instance.client`
  // is read from a dozen files that would otherwise throw an AssertionError, and
  // an honest sentence on the sign-in screen is better than a crash.
  final supabase = SupabaseConfig.current;
  await Supabase.initialize(
    url: supabase.url,
    // `anonKey` is deprecated in favour of `publishableKey`; internally it is
    // `publishableKey ?? anonKey!`, so this is a pure rename and a legacy
    // `eyJ…` anon key is still accepted here.
    publishableKey: supabase.key,
  );

  // Wait for a stored session to come back, when there is one to come back.
  //
  // `Supabase.initialize` does not do this itself — it wraps `recoverSession` in
  // a CancelableOperation and returns immediately — so without this line
  // AppRouter's initialLocation reads `currentSession` while it is still null
  // and sends a signed-in person to the sign-in screen. Returns instantly when
  // no session is stored, so a first-time user pays nothing for it. See
  // SessionGate.
  await SessionGate.settle();

  // Seed demo Halaqa + Al-Minbar data on first run (guarded by a feature flag
  // and an "empty tables" check). Never throws — safe to await here.
  await SocialSeeder.run();

  runApp(const MizanApp());
}
