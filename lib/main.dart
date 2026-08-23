/// Mizan — Entry Point
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/branding/mizan_brand.dart';
import 'features/home/domain/streak_provider.dart';
import 'features/onboarding/domain/onboarding_flags.dart';
import 'services/database/database_service.dart';
import 'services/audio/audio_session_setup.dart';
import 'services/audio/playback_arbiter.dart';
import 'services/seed/social_seeder.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

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

  // Initialize Supabase (social data + layer cache)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Seed demo Halaqa + Al-Minbar data on first run (guarded by a feature flag
  // and an "empty tables" check). Never throws — safe to await here.
  await SocialSeeder.run();

  runApp(const MizanApp());
}
