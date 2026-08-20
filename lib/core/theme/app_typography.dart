/// Taddabur Typography System
///
/// Three typefaces, used with strict purpose:
///   Amiri  → ALL Arabic text, no exceptions
///   Lora   → English display/headings (manuscript warmth)
///   Inter  → UI chrome only (buttons, labels, metadata)
///
/// Why strict rules: mixing fonts randomly makes apps look amateur.
/// Consistent typography is the single biggest signal of design quality.
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
    Color color = AppColors.white,
    double size = 32,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color,
        height: 1.9,
        fontWeight: FontWeight.w400,
      );

  static TextStyle arabicDisplay({
    Color color = AppColors.ink,
    double size = 26,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color,
        height: 1.9,
      );

  static TextStyle arabicBody({
    Color color = AppColors.ink,
    double size = 20,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color,
        height: 1.85,
      );

  static TextStyle arabicSmall({
    Color color = AppColors.ink,
    double size = 16,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color,
        height: 1.8,
      );

  // ── Display — Lora ────────────────────────────────────────────
  // Used for: screen titles, card headlines, sahabi names
  // Never used for: body copy, labels, metadata

  static TextStyle displayLarge({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 1.3,
      );

  static TextStyle displayMedium({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.35,
      );

  static TextStyle displaySmall({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      );

  // Italic Lora for translations and quotes
  static TextStyle quoteItalic({Color color = AppColors.body}) =>
      GoogleFonts.lora(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: color,
        height: 1.7,
      );

  // ── UI — Inter ────────────────────────────────────────────────
  // Used for: everything else — buttons, labels, body, captions
  // Inter is invisible when done right — it gets out of the way

  static TextStyle labelLarge({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle labelMedium({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle labelSmall({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.8,
        // Small caps feel — uppercase with tracking
      );

  static TextStyle bodyLarge({Color color = AppColors.body}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.75,
      );

  static TextStyle bodyMedium({Color color = AppColors.body}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.7,
      );

  static TextStyle bodySmall({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 12,
        color: color,
        height: 1.55,
      );

  static TextStyle caption({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle buttonPrimary() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      );

  static TextStyle buttonSecondary({Color color = AppColors.jade}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      );
}
