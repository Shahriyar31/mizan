/// Mizan Typography
///
/// Six roles, transcribed exactly from `Mizan Tokens.pdf`:
///
///   Screen title      Playfair Display 600 · 32/37 · -0.01em
///   Card headline     Playfair Display 600 · 23/29
///   Translation       Playfair Display italic 400 · 17/26
///   Body / list title DM Sans 400 · 15/24   (titles 600)
///   Section label     DM Sans 700 · 11 · 0.16em uppercase
///   Arabic            Amiri 400 · 30 / 1.9 · RTL
///
/// There is no seventh role. If a screen wants a size that is not on this
/// list, it should use the nearest role rather than inventing one — the whole
/// point of a six-role scale is that a reader can tell the roles apart.
///
/// ── Fonts are bundled, not fetched ────────────────────────────────────
/// All three families ship as TTFs in `assets/fonts/` and are declared in
/// `pubspec.yaml`, so every style below is a plain [TextStyle] naming a family
/// the engine already has.
///
/// This file used to call `google_fonts`, which downloads a family the first
/// time it is asked for and falls back to Roboto until the bytes arrive. The
/// effect was that a first launch on a phone with no signal — a plane, a
/// basement, a fresh install before the wifi is joined — rendered the entire app
/// in a font it was never designed in: the serif/sans contrast that separates an
/// ayah's meaning from the app's own voice simply vanished, and the wide
/// letter-spacing on the wordmark and section labels was applied to the wrong
/// letterforms. Bundling costs about 1 MB in the APK and removes the failure
/// mode completely.
///
/// The weights declared in `pubspec.yaml` are the ones used here: 400/600/700
/// plus italic for Playfair, 400/500/600/700 for DM Sans. Asking for a weight
/// with no matching asset makes the engine synthesise one, which looks wrong at
/// display sizes — so add the TTF rather than the number.
library;

import 'package:flutter/material.dart';

abstract final class MizanType {
  // Family names, in one place. These must match the `family:` keys in
  // pubspec.yaml exactly — a typo does not fail the build, it silently falls
  // back to the platform default.
  static const String serifFamily = 'Playfair Display';
  static const String sansFamily = 'DM Sans';
  static const String arabicFamily = 'Amiri';

  /// Playfair Display 600 · 32/37 · -0.01em. One per screen.
  static TextStyle screenTitle({Color? color}) => TextStyle(
        fontFamily: serifFamily,
        color: color,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 37 / 32,
        letterSpacing: -0.32, // -0.01em at 32px
      );

  /// Playfair Display 600 · 23/29. Card headlines, questions, prophet names.
  static TextStyle cardHeadline({Color? color}) => TextStyle(
        fontFamily: serifFamily,
        color: color,
        fontSize: 23,
        fontWeight: FontWeight.w600,
        height: 29 / 23,
      );

  /// Playfair Display *italic* 400 · 17/26. Translation and sub-prompt.
  /// Always italic serif — this is what visually separates the meaning of an
  /// ayah from the app's own voice.
  static TextStyle translation({Color? color}) => TextStyle(
        fontFamily: serifFamily,
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 26 / 17,
      );

  /// DM Sans 400 · 15/24. Long narration, list subtitles, everything prose.
  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: sansFamily,
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 24 / 15,
      );

  /// DM Sans 600 · 15/24. List row titles and inline emphasis.
  static TextStyle bodyStrong({Color? color}) => TextStyle(
        fontFamily: sansFamily,
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 24 / 15,
      );

  /// DM Sans 700 · 11 · 0.16em, uppercase. Section labels and meta rows.
  /// Callers must uppercase the string themselves — letter-spacing this wide
  /// only reads correctly on caps.
  static TextStyle sectionLabel({Color? color}) => TextStyle(
        fontFamily: sansFamily,
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 1.76, // 0.16em at 11px
      );

  /// Amiri 400 · 30 / 1.9. Always right-aligned, always paired with
  /// transliteration or translation. Non-negotiable rule #6.
  static TextStyle arabic({Color? color, double fontSize = 30}) => TextStyle(
        fontFamily: arabicFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.9,
      );

  /// Button labels — DM Sans 600 at 15, the same weight as a list title so a
  /// button never shouts louder than the row above it.
  static TextStyle button({Color? color}) => TextStyle(
        fontFamily: sansFamily,
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  /// Tab bar labels. DM Sans 600 at 11 — small, but they sit under an icon
  /// and use the theme's single grey, so they still clear contrast.
  static TextStyle navLabel({Color? color}) => TextStyle(
        fontFamily: sansFamily,
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
      );

  /// The `MIZAN` wordmark: Playfair Display 600, very wide tracking.
  /// Size is caller-supplied because the wordmark appears at 34px on the
  /// welcome screen and ~18px in a header.
  static TextStyle wordmark({Color? color, double fontSize = 34}) => TextStyle(
        fontFamily: serifFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: fontSize * 0.22,
      );

  /// `LEARN · REFLECT · GROW`. Same construction as a section label but with
  /// even wider tracking, matching the lockup in the brand sheet.
  static TextStyle tagline({Color? color, double fontSize = 11}) => TextStyle(
        fontFamily: sansFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: fontSize * 0.28,
      );

  /// A Material TextTheme wired to the Mizan roles, so stock widgets that read
  /// `Theme.of(context).textTheme` land somewhere sane instead of defaulting
  /// to Roboto.
  static TextTheme textTheme(Color ink, Color muted) => TextTheme(
        displayLarge: screenTitle(color: ink),
        headlineMedium: screenTitle(color: ink),
        headlineSmall: cardHeadline(color: ink),
        titleLarge: cardHeadline(color: ink),
        titleMedium: bodyStrong(color: ink),
        titleSmall: bodyStrong(color: ink),
        bodyLarge: body(color: ink),
        bodyMedium: body(color: ink),
        bodySmall: body(color: muted),
        labelLarge: button(color: ink),
        labelMedium: sectionLabel(color: muted),
        labelSmall: navLabel(color: muted),
      );
}
