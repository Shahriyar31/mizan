/// MizanApp — root widget
/// Sets up: theme, router, localization, Riverpod
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/mizan_theme.dart';
import 'features/growth/domain/mizan_birth_date.dart';
import 'features/home/domain/streak_provider.dart';
import 'features/home/domain/todays_mizan.dart';
import 'features/settings/domain/settings_providers.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/mizan/mizan_responsive.dart';

class MizanApp extends StatelessWidget {
  const MizanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _MizanMaterialApp(),
    );
  }
}

/// Stateful for one reason: the app needs to know when it comes back to the
/// foreground.
///
/// Anything derived from "today" is wrong the moment the day changes underneath
/// it. A phone left on the Home screen overnight keeps this process alive, so the
/// streak resolved at launch and Today's Mizan restored at launch both describe
/// yesterday until something recomputes them. Nothing did. Now `resumed`
/// re-derives both from storage, which is cheap (two SharedPreferences reads) and
/// correct regardless of how long the app sat in the background.
///
/// This is the only [WidgetsBindingObserver] in the app; add day-sensitive state
/// here rather than growing a second one.
class _MizanMaterialApp extends ConsumerStatefulWidget {
  const _MizanMaterialApp();

  @override
  ConsumerState<_MizanMaterialApp> createState() => _MizanMaterialAppState();
}

class _MizanMaterialAppState extends ConsumerState<_MizanMaterialApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Re-read, do not recompute in memory: the answer lives on disk and both
    // calls are date comparisons against it.
    //
    // `refresh()` rather than `ref.invalidate` for Today's Mizan — invalidating
    // would tear the notifier down, snap the strip back to three empty facets,
    // and refill it a frame later once SharedPreferences answered. Re-reading in
    // place shows no flicker and, on the overwhelmingly common resume where the
    // day has not changed, no visible change at all.
    ref.read(streakProvider.notifier).reevaluate();
    ref.read(todaysMizanProvider.notifier).refresh();

    // The Al-Mizan day number is the one figure on Home that changes with no
    // input from the user, so it is the one a phone left on the Home screen
    // overnight would show wrong. Same reasoning as above: refresh in place.
    ref.read(mizanFiguresProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Mizan',
      debugShowCheckedModeBanner: false,

      // Mizan carries its palette in a `ThemeExtension`, so the light and dark
      // ThemeData objects are independent const values and `themeMode` — system
      // included — is handled by MaterialApp natively.
      theme: MizanTheme.light,
      darkTheme: MizanTheme.dark,
      themeMode: themeMode,

      routerConfig: AppRouter.router,
      builder: (context, child) {
        // ── Transitional bridge, delete with the last AppColors reference ──
        // Screens not yet migrated to Mizan read the legacy `AppColors`, which
        // is one *mutable static* palette rather than a per-ThemeData value.
        // Priming it here — rather than resolving brightness ourselves — means
        // it always agrees with the theme MaterialApp actually resolved, so
        // ThemeMode.system and a mid-session OS theme change both stay correct.
        final brightness = Theme.of(context).brightness;
        AppColors.applyBrightness(brightness);

        // And because that palette is global rather than inherited, a legacy
        // screen has no way to know it changed. Remounting on brightness forces
        // one. Goes away with AppColors; Mizan screens need neither.
        //
        // Wrapped in the responsive shell here, at the outermost point, for two
        // reasons. It has to be outside the Router so it also caps the tab bar
        // and every modal sheet — a full-width bar under a 520pt column would
        // look like a bug — and it has to be inside MaterialApp so there is a
        // MediaQuery and a resolved Theme to read. Below 520pt wide, which is
        // every phone in portrait, it returns this child untouched.
        return MizanResponsiveShell(
          child: KeyedSubtree(
            key: ValueKey(brightness),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Only English is actually translated (lib/l10n/app_en.arb).
      // Real foundation for more languages, not a promise of them yet.
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
