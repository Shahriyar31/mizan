/// GoRouter configuration
/// All app routes defined here — single source of truth for navigation
library;

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// TODO: Import screen files as they are created
// import '../../features/home/presentation/home_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Routes will be added here as screens are built
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text(
              'Taddabur — Setup Complete\nStart building screens',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}
