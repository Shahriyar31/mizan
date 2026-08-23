/// What this file used to be, and why it changed.
///
/// It was the counter-app boilerplate `flutter create` writes — it pumped
/// `MyApp()`, tapped an `Icons.add`, and asserted a "1" appeared. None of those
/// three things has ever existed in this project, and it imported
/// `package:ummahapp/main.dart` which stopped resolving the moment the Dart
/// package was renamed. So it was a test that could not compile, sitting in the
/// one place a newcomer looks first.
///
/// It is now two tests over the design system, chosen because they are the only
/// interesting thing that can be asserted without platform channels: the real
/// app root boots GoRouter, sqflite, dotenv and SharedPreferences, none of which
/// answer in a bare `flutter test`. Widening this beyond the theme layer means
/// mocking those, which is a real piece of work and not one to fake here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mizan/core/theme/mizan_theme.dart';
import 'package:mizan/core/theme/mizan_tokens.dart';
import 'package:mizan/shared/widgets/mizan/mizan_components.dart';

void main() {
  group('MizanPalette', () {
    testWidgets('resolves from the theme, per brightness', (tester) async {
      late MizanPalette lightSeen;
      late MizanPalette darkSeen;

      Widget probe(ThemeData theme, void Function(MizanPalette) capture) =>
          MaterialApp(
            theme: theme,
            home: Builder(builder: (context) {
              capture(MizanPalette.of(context));
              return const SizedBox.shrink();
            }),
          );

      await tester.pumpWidget(probe(MizanTheme.light, (p) => lightSeen = p));
      await tester.pumpWidget(probe(MizanTheme.dark, (p) => darkSeen = p));

      // The bug this guards against is real and was hit once: the legacy
      // AppColors was a single mutable static palette, so building light then
      // dark left *both* resolved to dark. If that regresses, these two are
      // equal.
      expect(lightSeen.isLight, isTrue);
      expect(darkSeen.isLight, isFalse);
      expect(lightSeen.page, isNot(darkSeen.page));
      expect(lightSeen.ink, isNot(darkSeen.ink));
    });

    testWidgets('falls back to light outside a Mizan theme', (tester) async {
      late MizanPalette seen;
      await tester.pumpWidget(MaterialApp(
        // Deliberately a stock theme with no MizanPalette extension.
        theme: ThemeData.light(),
        home: Builder(builder: (context) {
          seen = MizanPalette.of(context);
          return const SizedBox.shrink();
        }),
      ));
      expect(seen.isLight, isTrue);
    });
  });

  group('MizanButton', () {
    testWidgets('shows its label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: MizanTheme.light,
        home: Scaffold(
          body: Center(
            child: MizanButton(label: 'Begin', onPressed: () => taps++),
          ),
        ),
      ));

      expect(find.text('Begin'), findsOneWidget);
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a null onPressed does not fire', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: MizanButton(label: 'Disabled')),
        ),
      ));

      expect(find.text('Disabled'), findsOneWidget);
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();
      // Nothing to assert but the absence of a throw — a disabled Mizan button
      // must not blow up on tap, which is exactly what a bare `onTap!` would do.
    });
  });
}
