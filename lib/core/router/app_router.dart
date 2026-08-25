/// App Router — Single source of truth for all navigation
library;
import 'package:go_router/go_router.dart';
import '../config/supabase_config.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/quran_screen.dart';
import '../../features/quran/presentation/ayah_detail_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/discover/screens/prophet_detail_screen.dart';
import '../../features/discover/screens/sahabi_detail_screen.dart';
import '../../features/discover/screens/seerah_detail_screen.dart';
import '../../features/discover/screens/divine_name_detail_screen.dart';
import '../../features/knowledge/presentation/hadith_detail_screen.dart';
import '../../features/knowledge/presentation/hadith_topics_screen.dart';
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
import '../../features/onboarding/domain/session_gate.dart';
import '../../features/onboarding/presentation/welcome_flow.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/auth_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/settings/presentation/personalisation_screen.dart';
import '../../features/settings/presentation/app_icon_screen.dart';
import '../../features/settings/presentation/audio_screen.dart';
import '../../features/settings/presentation/translation_screen.dart';
import '../../features/settings/presentation/system_screen.dart';
import '../../features/settings/presentation/data_screen.dart';
import '../../features/settings/presentation/language_screen.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../../features/settings/presentation/more_content_screens.dart';
import '../../shared/widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  /// Routes that are reachable without an account. Everything else needs one.
  ///
  /// This set is what makes the guard below safe. [OnboardingFlags] argues
  /// against a `redirect` on the grounds that a redirect runs on every
  /// navigation and a flag that has not been persisted yet turns into a loop —
  /// and that is true of a *flag-based* redirect. This one cannot loop, because
  /// both its targets are themselves in the open set, so the second pass always
  /// returns null. No disk read, no async, no state.
  ///
  /// The two legal screens are in here for a reason that is not negotiable: the
  /// sign-in screen asks the person to agree to them, and a link to terms you
  /// cannot open until after you have accepted them is not a link. They are
  /// shell children, so they keep the bottom bar while signed out — the same
  /// chrome they have when reached from Settings, and the price of not
  /// registering a second route to the same screen.
  static const _openRoutes = <String>{
    '/welcome',
    '/auth',
    '/settings/more/terms',
    '/settings/more/privacy',
  };

  static bool _isOpen(String location) {
    for (final route in _openRoutes) {
      if (location == route || location.startsWith('$route/')) return true;
    }
    return false;
  }

  /// True when there is no account system to gate against.
  ///
  /// ── Why the gate has an off switch ─────────────────────────────────────
  /// Sign-in is required, and that is right when there is a server to sign in
  /// to. When [SupabaseConfig] cannot find a usable URL and key, there is not:
  /// [SessionGate.signedIn] is false permanently, every sign-in attempt is
  /// refused by `AuthRepository._configProblem` before it leaves the phone, and
  /// a guard that admits nobody turns the whole app into a screen the person
  /// cannot leave — Qur'an, layers, audio, their own local record, all of it
  /// behind a door with no key. The person holding the phone did not cause that
  /// and cannot fix it.
  ///
  /// So a misconfigured build opens, with the reason in words on the sign-in
  /// screen when they go looking for it. This is the same judgement
  /// `SupabaseConfig` already makes about not refusing to start.
  static bool get _gateOff => !SupabaseConfig.current.isUsable;

  /// Where a cold start lands.
  ///
  /// Read synchronously during the first build, which is why `main()` awaits
  /// both [OnboardingFlags.restore] and [SessionGate.settle] first.
  ///
  ///  * Never seen the flow → the flow.
  ///  * Seen it, signed in → Home.
  ///  * Seen it, signed out → straight to sign-in. Walking somebody who has
  ///    already read all five explanatory screens back through them to reach
  ///    their own account would be a punishment for signing out.
  ///
  /// Which *form* that last case opens on is [SessionGate.everSignedIn], not a
  /// constant. Two different people arrive here: one who has an account and
  /// signed out, and one who finished the flow, reached Screen 6, and quit before
  /// creating anything. Sending the second to a screen headed "Welcome back"
  /// which then rejects their email as unregistered is a bad first minute for the
  /// person most likely to give up.
  static String get _initialLocation {
    if (!OnboardingFlags.welcomeSeen) return '/welcome';
    if (SessionGate.signedIn || _gateOff) return '/home';
    return _signInRoute;
  }

  /// Sign-in, opened on the form that fits what this device has done before.
  static String get _signInRoute =>
      SessionGate.everSignedIn ? '/auth?login=1' : '/auth';

  static final AuthRefreshNotifier _authRefresh = AuthRefreshNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: _initialLocation,
    // Re-runs the guard the instant somebody signs in or out, so signing out
    // from Settings leaves the app rather than leaving them on a stale Home.
    refreshListenable: _authRefresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (_isOpen(location)) return null;
      if (SessionGate.signedIn || _gateOff) return null;
      // No account, and they are pointed at the app. Send them to the flow if
      // they have never seen it, or to sign-in if they have.
      return OnboardingFlags.welcomeSeen ? _signInRoute : '/welcome';
    },
    routes: [
      // Outside the ShellRoute on purpose: the welcome flow is full-bleed and
      // must not have the bottom nav over its arches.
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeFlow(),
      ),
      // Also outside the shell. `/auth` is reachable while signed out, and the
      // shell's bottom nav is five tabs into an app that will not open without
      // an account — every one of them would bounce straight back here. The
      // screen returns with `context.go('/settings')`, so nothing depends on it
      // being a shell child.
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AuthScreen(
            startOnLogin: state.uri.queryParameters['login'] == '1',
            fromWelcome: state.uri.queryParameters['from'] == 'welcome',
          ),
        ),
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
                path: 'data',
                builder: (context, state) => const DataScreen(),
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
                    builder: (context, state) => const AboutMizanScreen(),
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
          // The learning section: ten topics in, citations out. Not an index of
          // collections — a reader arrives with a question, not a book number.
          GoRoute(
            path: '/knowledge/hadith-topics',
            builder: (context, state) => const HadithTopicsScreen(),
          ),
          GoRoute(
            path: '/knowledge/hadith-topic/:id',
            builder: (context, state) =>
                HadithTopicScreen(topicId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
