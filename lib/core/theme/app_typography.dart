/// Mizan Typography System — the legacy scale
///
/// Three typefaces, used with strict purpose:
///   Amiri            → ALL Arabic text, no exceptions
///   Playfair Display → English display/headings (manuscript warmth)
///   DM Sans          → UI chrome only (buttons, labels, metadata)
///
/// Why strict rules: mixing fonts randomly makes apps look amateur.
/// Consistent typography is the single biggest signal of design quality.
///
/// ── Why these are Playfair and DM Sans now, not Lora and Inter ────────
/// Two reasons, and both are about the same defect. The families were fetched at
/// runtime by `google_fonts`, so any screen still on this scale rendered in the
/// platform sans on a first launch with no connection — and this scale is not
/// dead code: `notifications_screen.dart`, `system_screen.dart` and several
/// others still call it. Bundling Lora and Inter as well would have meant four
/// families in the APK to draw two typefaces.
///
/// The second reason is that Lora next to Playfair Display, and Inter next to DM
/// Sans, are the kind of near-miss that reads as sloppiness rather than as a
/// choice — two serifs and two grotesques doing the same job one screen apart.
/// [MizanType] is the real scale and these now borrow its families, so a screen
/// that has not been migrated yet at least shares the app's voice.
///
/// New code should use [MizanType]. This exists so the un-migrated screens keep
/// working, not as a second system to pick from.
///
/// Every default color below is theme-aware (resolves against whichever
/// brightness AppColors is currently set to). Override with the named
/// 'color' parameter only when a style needs to deviate from that default —
/// e.g. white text sitting on a solid-filled accent button/badge, which
/// stays white in both themes because the fill itself is always dark
/// enough to hold contrast.
library;

import 'package:flutter/material.dart';
import 'mizan_typography.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // ── Arabic (Amiri) ────────────────────────────────────────────
  // height: 1.9 is critical for Arabic — standard line height
  // cuts off diacritics (tashkeel) above and below letters

  static TextStyle arabicHero({
    Color? color,
    double size = 32,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color ?? AppColors.textPrimary,
        height: 1.9,
        fontWeight: FontWeight.w400,
      );

  static TextStyle arabicDisplay({
    Color? color,
    double size = 26,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color ?? AppColors.gold,
        height: 1.9,
      );

  static TextStyle arabicBody({
    Color? color,
    double size = 20,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color ?? AppColors.textPrimary,
        height: 1.85,
      );

  static TextStyle arabicSmall({
    Color? color,
    double size = 16,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color ?? AppColors.textSecondary,
        height: 1.8,
      );

  // ── Display — Lora ────────────────────────────────────────────
  // Used for: screen titles, card headlines, sahabi names
  // Never used for: body copy, labels, metadata

  static TextStyle displayLarge({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.serifFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.3,
      );

  static TextStyle displayMedium({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.serifFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle displaySmall({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.serifFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.4,
      );

  // Italic Lora for translations and quotes
  static TextStyle quoteItalic({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.serifFamily,
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: color ?? AppColors.textSecondary,
        height: 1.7,
      );

  // ── UI — Inter ────────────────────────────────────────────────
  // Used for: everything else — buttons, labels, body, captions
  // Inter is invisible when done right — it gets out of the way

  static TextStyle labelLarge({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle labelMedium({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.muted,
      );

  static TextStyle labelSmall({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.muted,
        letterSpacing: 0.8,
        // Small caps feel — uppercase with tracking
      );

  static TextStyle bodyLarge({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
        height: 1.75,
      );

  static TextStyle bodyMedium({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
        height: 1.7,
      );

  static TextStyle bodySmall({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 12,
        color: color ?? AppColors.muted,
        height: 1.55,
      );

  static TextStyle caption({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.muted,
        letterSpacing: 0.5,
      );

  static TextStyle buttonPrimary() => TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        // ink, not night — this sits on the jade/gold button fill, not the
        // app background, and must stay dark in both themes.
        color: AppColors.ink,
      );

  static TextStyle buttonSecondary({Color? color}) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.jade,
      );
}
