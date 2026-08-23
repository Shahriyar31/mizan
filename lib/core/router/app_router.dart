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
import '../../features/knowledge/presentation/hadith_detail_screen.dart';
import '../../features/knowledge/presentation/knowledge_entity_screen.dart';
import '../../features/knowledge/presentation/knowledge_index_screen.dart';
import '../knowledge/entity_ref.dart';
import '../../features/halaqa/presentation/halaqa_screen.dart';
import '../../features/halaqa/presentation/halaqa_circle_screen.dart';
import '../../features/growth/presentation/growth_screen.dart';
import '../../features/growth/presentation/growth_map_screen.dart';
import '../../features/growth/presentation/al_meezan_screen.dart';
import '../../features/growth/presentation/vocab_bank_screen.dart';
import '../../features/growth/presentation/muhasabah_screen.dart';
import '../../features/minbar/presentation/minbar_screen.dart';
import '../../features/onboarding/domain/onboarding_flags.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/auth_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/settings/presentation/personalisation_screen.dart';
import '../../features/settings/presentation/app_icon_screen.dart';
import '../../features/settings/presentation/audio_screen.dart';
import '../../features/settings/presentation/translation_screen.dart';
import '../../features/settings/presentation/system_screen.dart';
import '../../features/settings/presentation/language_screen.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../../features/settings/presentation/more_content_screens.dart';
import '../../shared/widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    // Read synchronously from a flag `main()` fills in before `runApp`. See
    // [OnboardingFlags] for why this is not a `redirect`.
    initialLocation: OnboardingFlags.welcomeSeen ? '/home' : '/welcome',
    routes: [
      // Outside the ShellRoute on purpose: the welcome screen is full-bleed and
      // must not have the bottom nav over its landscape.
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
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
                  final ayahNumber =
                      int.tryParse(state.uri.queryParameters['ayah'] ?? '');
                  return AyahDetailScreen(
                    surahNumber: surahNumber,
                    initialAyahNumber: ayahNumber,
                  );
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
                path: 'map',
                builder: (context, state) => const GrowthMapScreen(),
              ),
              GoRoute(
                path: 'meezan',
                builder: (context, state) => const AlMeezanScreen(),
              ),
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
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'personalisation',
                builder: (context, state) => const PersonalisationScreen(),
                routes: [
                  GoRoute(
                    path: 'app-icon',
                    builder: (context, state) => const AppIconScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'translation',
                builder: (context, state) => const TranslationScreen(),
              ),
              GoRoute(
                path: 'audio',
                builder: (context, state) => const AudioScreen(),
              ),
              GoRoute(
                path: 'system',
                builder: (context, state) => const SystemScreen(),
              ),
              GoRoute(
                path: 'language',
                builder: (context, state) => const LanguageScreen(),
              ),
              GoRoute(
                path: 'more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'faq',
                    builder: (context, state) => const FaqScreen(),
                  ),
                  GoRoute(
                    path: 'how-it-works',
                    builder: (context, state) => const HowItWorksScreen(),
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (context, state) => const TermsScreen(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (context, state) => const PrivacyScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutTaddaburScreen(),
                  ),
                ],
              ),
            ],
          ),
          // ── The knowledge platform ───────────────────────────────────
          //
          // Inside the shell so the bottom bar stays put: following a
          // connection is navigation within the app, not a modal detour.
          // Every one of these is pushed, never gone to, so Adam → Bukhari
          // 3326 → Creation unwinds hop by hop on back.
          //
          // The four Discover types keep their own routes above; only the
          // types the platform adds land here.
          GoRoute(
            path: '/knowledge/themes',
            builder: (context, state) =>
                const KnowledgeIndexScreen(type: EntityType.theme),
          ),
          GoRoute(
            path: '/knowledge/journeys',
            builder: (context, state) =>
                const KnowledgeIndexScreen(type: EntityType.journey),
          ),
          GoRoute(
            path: '/knowledge/scholars',
            builder: (context, state) =>
                const KnowledgeIndexScreen(type: EntityType.scholar),
          ),
          GoRoute(
            path: '/knowledge/places',
            builder: (context, state) =>
                const KnowledgeIndexScreen(type: EntityType.place),
          ),
          GoRoute(
            path: '/knowledge/theme/:id',
            builder: (context, state) => KnowledgeEntityScreen(
              entityRef:
                  EntityRef(EntityType.theme, state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/knowledge/scholar/:id',
            builder: (context, state) => KnowledgeEntityScreen(
              entityRef:
                  EntityRef(EntityType.scholar, state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/knowledge/place/:id',
            builder: (context, state) => KnowledgeEntityScreen(
              entityRef:
                  EntityRef(EntityType.place, state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/knowledge/journey/:id',
            builder: (context, state) => KnowledgeEntityScreen(
              entityRef:
                  EntityRef(EntityType.journey, state.pathParameters['id']!),
            ),
          ),
          // Collection and number as separate segments rather than one
          // `bukhari:3326` blob, so the URL survives a share and reads as a
          // citation.
          GoRoute(
            path: '/knowledge/hadith/:collection/:number',
            builder: (context, state) => HadithDetailScreen(
              collection: state.pathParameters['collection']!,
              number: state.pathParameters['number']!,
            ),
          ),
          GoRoute(
            path: '/knowledge/saved-hadith',
            builder: (context, state) => const SavedHadithScreen(),
          ),
          GoRoute(
            path: '/auth',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AuthScreen(
                startOnLogin: state.uri.queryParameters['login'] == '1',
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
