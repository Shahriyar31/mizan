/// The welcome flow: six screens, one page view, dark regardless of the system.
///
/// Replaces the old single welcome screen at `/welcome`. That route sits outside
/// the app's `ShellRoute` on purpose — the flow is full-bleed and must not have
/// the bottom nav floating over its arches.
///
/// ── Forcing dark ──────────────────────────────────────────────────────
/// The brief is explicit: this flow is dark only, and theme resolution begins on
/// the first app screen after it. That takes three things, not one, because the
/// theme leaks out of the widget tree in two directions:
///
///  1. `Theme(data: MizanTheme.dark, …)` for anything below that reads
///     `MizanPalette.of(context)` — the shared components, and the Material time
///     picker on Screen 4.
///  2. An [AnnotatedRegion] for the status-bar icons. `systemOverlayStyle` is set
///     inside `MizanTheme._build` on the *appBarTheme*, and this flow has no app
///     bar, so wrapping in a dark theme alone leaves the icons wherever the last
///     screen put them — dark glyphs on a navy background if the person's phone
///     is in light mode.
///  3. The legacy mutable-static `AppColors`, which `app.dart` primes from the
///     resolved brightness. Nothing in these six screens reads it — they are
///     built entirely on [OnbTok] — so it is left alone rather than mutated and
///     restored, which would be a global side effect for a local problem.
///
/// ── Skip goes to sign-in, not to Home ─────────────────────────────────
/// Skip means "I do not want to answer these questions", not "let me in without
/// an account". So it jumps to Screen 6, which is the one screen in the flow
/// that is not skippable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_theme.dart';
import '../domain/onboarding_flags.dart';
import 'pages/onb_intent_page.dart';
import 'pages/onb_layers_page.dart';
import 'pages/onb_rhythm_page.dart';
import 'pages/onb_rooms_page.dart';
import 'pages/onb_sign_in_page.dart';
import 'pages/onb_welcome_page.dart';
import 'widgets/onboarding_kit.dart';

class WelcomeFlow extends ConsumerStatefulWidget {
  const WelcomeFlow({super.key});

  @override
  ConsumerState<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends ConsumerState<WelcomeFlow> {
  final _pages = PageController();

  /// Index of the sign-in screen, which is where Skip lands.
  static const _signInIndex = 5;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _to(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _to((_pages.page?.round() ?? 0) + 1);

  void _skip() => _to(_signInIndex);

  /// Leaves the flow for the real auth screen.
  ///
  /// The welcome flag is marked seen *here*, at the point the person reaches
  /// sign-in — not on the first tap of "Begin your journey". Marking it early
  /// would mean somebody who backs out on Screen 3 never sees the flow again and
  /// lands on a Home screen that has explained nothing to them.
  Future<void> _leaveFor(String route) async {
    await OnboardingFlags.markWelcomeSeen();
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light glyphs, because the flow is navy whatever the phone is set to.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: OnbTok.ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: MizanTheme.dark,
        child: PopScope(
          // Back on the first screen would otherwise close the app. Inside the
          // flow it steps back a page, which is what the gesture means here.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final page = _pages.page?.round() ?? 0;
            if (page > 0) _to(page - 1);
          },
          child: Scaffold(
            backgroundColor: OnbTok.ink,
            body: PageView(
              controller: _pages,
              // No swiping between screens. Each one has an explicit control at
              // the bottom, and a flow that also swipes gives two ways to do the
              // same thing with different failure modes — a half-swipe on Screen
              // 4 would leave the permission prompt unasked and the person
              // unsure whether they agreed to anything.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                OnbWelcomePage(
                  onBegin: _next,
                  onSignIn: () => _leaveFor('/auth?login=1&from=welcome'),
                ),
                OnbLayersPage(onContinue: _next, onSkip: _skip),
                OnbRoomsPage(onContinue: _next, onSkip: _skip),
                OnbRhythmPage(onDone: _next, onSkip: _skip),
                OnbIntentPage(onContinue: _next, onSkip: _skip),
                OnbSignInPage(
                  onCreateAccount: () => _leaveFor('/auth?from=welcome'),
                  onSignIn: () => _leaveFor('/auth?login=1&from=welcome'),
                  onTerms: () => context.push('/settings/more/terms'),
                  onPrivacy: () => context.push('/settings/more/privacy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
