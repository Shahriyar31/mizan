/// App Router — Single source of truth for all navigation
library;
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/quran_screen.dart';
import '../../features/quran/presentation/ayah_detail_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/discover/screens/prophet_detail_screen.dart';
import '../../features/discover/screens/sahabi_detail_screen.dart';
import '../../features/discover/screens/seerah_detail_screen.dart';
import '../../features/discover/screens/divine_name_detail_screen.dart';
import '../../features/halaqa/presentation/halaqa_screen.dart';
import '../../features/halaqa/presentation/halaqa_circle_screen.dart';
import '../../features/growth/presentation/growth_screen.dart';
import '../../features/growth/presentation/vocab_bank_screen.dart';
import '../../features/growth/presentation/muhasabah_screen.dart';
import '../../features/minbar/presentation/minbar_screen.dart';
import '../../shared/widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
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
            routes: [
              GoRoute(
                path: ':surahNumber',
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
            routes: [
              GoRoute(
                path: 'prophet/:prophetId',
                builder: (context, state) {
                  final prophetId = state.pathParameters['prophetId']!;
                  return ProphetDetailScreen(prophetId: prophetId);
                },
              ),
              GoRoute(
                path: 'sahabi/:sahabiId',
                builder: (context, state) {
                  final sahabiId = state.pathParameters['sahabiId']!;
                  return SahabiDetailScreen(sahabiId: sahabiId);
                },
              ),
              GoRoute(
                path: 'seerah/:seerahId',
                builder: (context, state) {
                  final seerahId = state.pathParameters['seerahId']!;
                  return SeerahDetailScreen(seerahId: seerahId);
                },
              ),
              GoRoute(
                path: 'name/:nameId',
                builder: (context, state) {
                  final nameId = state.pathParameters['nameId']!;
                  return DivineNameDetailScreen(nameId: nameId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/halaqa',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HalaqaScreen(),
            ),
            routes: [
              GoRoute(
                path: 'circle/:halaqaId',
                builder: (context, state) {
                  final halaqaId = state.pathParameters['halaqaId']!;
                  return HalaqaCircleScreen(halaqaId: halaqaId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/growth',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GrowthScreen(),
            ),
            routes: [
              GoRoute(
                path: 'vocab',
                builder: (context, state) => const VocabBankScreen(),
              ),
              GoRoute(
                path: 'muhasabah',
                builder: (context, state) => const MuhasabahScreen(),
              ),
            ],
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
