/// Taddabur — Entry Point
/// Kept minimal intentionally — all setup delegated to app.dart
///
/// Why so short: main() should only do three things:
/// 1. Ensure Flutter is initialized
/// 2. Set up any async dependencies
/// 3. Run the app
/// Business logic, routing, theming — all in app.dart
library;

import 'package:flutter/material.dart';
import 'app.dart';

Future<void> main() async {
  // Must be called before any Flutter framework code
  // that requires the binding to be initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const TadabburApp());
}
