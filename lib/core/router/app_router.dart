/// App Router — Single source of truth for all navigation
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/quran_screen.dart';
import '../../features/quran/presentation/ayah_detail_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/halaqa/presentation/halaqa_screen.dart';
import '../../features/growth/presentation/growth_screen.dart';
import '../../features/minbar/presentation/minbar_screen.dart';
import '../../shared/widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      // ShellRoute — bottom nav persists across tabs
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),

          // Quran tab — with nested surah detail route
          GoRoute(
            path: '/quran',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: QuranScreen(),
            ),
            // Surah detail is a sub-route of /quran
            // This is the correct GoRouter pattern for nested navigation
            routes: [
              GoRoute(
                path: ':surahNumber',
                // Full path becomes /quran/1, /quran/2 etc
                builder: (context, state) {
                  final surahNumber = int.tryParse(
                        state.pathParameters['surahNumber'] ?? '1',
                      ) ??
                      1;
                  return AyahDetailScreen(surahNumber: surahNumber);
                },
              ),
            ],
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
