/// Taddabur — Entry Point
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database/database_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Initialize SQLite (personal local data)
  await DatabaseService.instance.database;

  // Initialize Supabase (social data + layer cache)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const TadabburApp());
}
