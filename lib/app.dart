/// TadabburApp — root widget
/// Sets up: theme, router, localization, Riverpod
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/settings/domain/settings_providers.dart';
import 'l10n/app_localizations.dart';

class TadabburApp extends StatelessWidget {
  const TadabburApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _TadabburMaterialApp(),
    );
  }
}

class _TadabburMaterialApp extends ConsumerWidget {
  const _TadabburMaterialApp();

  Brightness _resolveBrightness(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = _resolveBrightness(context, themeMode);

    // AppColors is a single mutable palette, not one-per-ThemeData — so we
    // resolve brightness ourselves and build exactly one ThemeData from it.
    // (Handing MaterialApp separate `theme`/`darkTheme` objects would call
    // AppTheme.build() twice, and the second call — always `darkTheme` —
    // would silently overwrite AppColors back to dark regardless of what
    // the user picked.)
    final theme = AppTheme.build(brightness);

    return MaterialApp.router(
        title: 'Taddabur',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: AppRouter.router,
        // Remount the current screen when brightness changes so it picks up
        // the new AppColors values immediately, without waiting for its own
        // next natural rebuild.
        builder: (context, child) => KeyedSubtree(
          key: ValueKey(brightness),
          child: child ?? const SizedBox.shrink(),
        ),
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
