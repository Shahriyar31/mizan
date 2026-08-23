/// MizanApp — root widget
/// Sets up: theme, router, localization, Riverpod
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/mizan_theme.dart';
import 'features/settings/domain/settings_providers.dart';
import 'l10n/app_localizations.dart';

class MizanApp extends StatelessWidget {
  const MizanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _MizanMaterialApp(),
    );
  }
}

class _MizanMaterialApp extends ConsumerWidget {
  const _MizanMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return KeyedSubtree(
          key: ValueKey(brightness),
          child: child ?? const SizedBox.shrink(),
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
