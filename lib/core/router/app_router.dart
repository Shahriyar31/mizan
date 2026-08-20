/// App Router — Single source of truth for all navigation
///
/// Uses GoRouter (declarative routing) instead of Navigator.push
/// Why GoRouter:
/// - Deep link ready from day one
/// - URL-based navigation (useful for web later)
/// - Type-safe routes
/// - Works with bottom navigation without stack complexity
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Shell screens
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/quran_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/halaqa/presentation/halaqa_screen.dart';
import '../../features/growth/presentation/growth_screen.dart';
import '../../features/minbar/presentation/minbar_screen.dart';

// The main shell widget that holds the bottom navigation
import '../../shared/widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      // ShellRoute wraps all tab screens with the bottom navigation bar
      // This means the bottom nav persists across tab switches
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/quran',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: QuranScreen(),
            ),
          ),
          GoRoute(
            path: '/discover',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiscoverScreen(),
            ),
          ),
          GoRoute(
            path: '/halaqa',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HalaqaScreen(),
            ),
          ),
          GoRoute(
            path: '/growth',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GrowthScreen(),
            ),
          ),
          GoRoute(
            path: '/minbar',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MinbarScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
