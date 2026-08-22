/// Taddabur Typography System
///
/// Three typefaces, used with strict purpose:
///   Amiri  → ALL Arabic text, no exceptions
///   Lora   → English display/headings (manuscript warmth)
///   Inter  → UI chrome only (buttons, labels, metadata)
///
/// Why strict rules: mixing fonts randomly makes apps look amateur.
/// Consistent typography is the single biggest signal of design quality.
///
/// Every default color below is theme-aware (resolves against whichever
/// brightness AppColors is currently set to). Override with the named
/// 'color' parameter only when a style needs to deviate from that default —
/// e.g. white text sitting on a solid-filled accent button/badge, which
/// stays white in both themes because the fill itself is always dark
/// enough to hold contrast.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      GoogleFonts.lora(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.3,
      );

  static TextStyle displayMedium({Color? color}) =>
      GoogleFonts.lora(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle displaySmall({Color? color}) =>
      GoogleFonts.lora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.4,
      );

  // Italic Lora for translations and quotes
  static TextStyle quoteItalic({Color? color}) =>
      GoogleFonts.lora(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: color ?? AppColors.textSecondary,
        height: 1.7,
      );

  // ── UI — Inter ────────────────────────────────────────────────
  // Used for: everything else — buttons, labels, body, captions
  // Inter is invisible when done right — it gets out of the way

  static TextStyle labelLarge({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle labelMedium({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.muted,
      );

  static TextStyle labelSmall({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.muted,
        letterSpacing: 0.8,
        // Small caps feel — uppercase with tracking
      );

  static TextStyle bodyLarge({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
        height: 1.75,
      );

  static TextStyle bodyMedium({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
        height: 1.7,
      );

  static TextStyle bodySmall({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 12,
        color: color ?? AppColors.muted,
        height: 1.55,
      );

  static TextStyle caption({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.muted,
        letterSpacing: 0.5,
      );

  static TextStyle buttonPrimary() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        // ink, not night — this sits on the jade/gold button fill, not the
        // app background, and must stay dark in both themes.
        color: AppColors.ink,
      );

  static TextStyle buttonSecondary({Color? color}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.jade,
      );
}
