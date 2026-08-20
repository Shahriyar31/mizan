/// Taddabur — Entry Point
library;

import 'package:flutter/material.dart';
import 'services/database/database_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database before app starts
  // This creates the database file and tables on first run
  await DatabaseService.instance.database;

  runApp(const TadabburApp());
}
