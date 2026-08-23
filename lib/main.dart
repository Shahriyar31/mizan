/// Taddabur — Entry Point
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/branding/mizan_brand.dart';
import 'features/home/domain/streak_provider.dart';
import 'features/onboarding/domain/onboarding_flags.dart';
import 'services/database/database_service.dart';
import 'services/seed/social_seeder.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Read the chosen app-icon variant before the first frame, so the mark on the
  // welcome screen is right immediately instead of flashing the theme default.
  await LogoVariantController.restore();

  // Whether to open on the welcome screen. Must be read before `runApp`, since
  // AppRouter's initialLocation is evaluated during the first build.
  await OnboardingFlags.restore();

  // Resolve the day-streak once, here, before anything can render it. This is
  // the ONLY writer of `streak_count` and `last_opened_at` — see StreakStore's
  // header for why having two writers used to freeze the counter.
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

  runApp(const TadabburApp());
}
