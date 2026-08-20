/// Taddabur typography system
/// Three typefaces, used deliberately:
///   Amiri     → All Arabic text
///   Lora      → English display/headings (warm, manuscript feel)
///   Inter     → UI chrome only (buttons, labels, metadata)
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // ── Arabic (Amiri) ────────────────────────────────────────────
  static TextStyle arabicDisplay({
    double size = 28,
    Color color = AppColors.ink,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color,
        height: 1.9,
      );

  static TextStyle arabicHero({Color color = AppColors.white}) =>
      arabicDisplay(size: 32, color: color);

  static TextStyle arabicBody({Color color = AppColors.ink}) =>
      arabicDisplay(size: 20, color: color);

  static TextStyle arabicSmall({Color color = AppColors.ink}) =>
      arabicDisplay(size: 16, color: color);

  // ── Display (Lora) ────────────────────────────────────────────
  static TextStyle displayLarge({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      );

  static TextStyle displayMedium({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle displaySmall({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyItalic({Color color = AppColors.body}) =>
      GoogleFonts.lora(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: color,
        height: 1.7,
      );

  // ── UI (Inter) ────────────────────────────────────────────────
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
      );

  static TextStyle bodyLarge({Color color = AppColors.body}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.75,
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

  static TextStyle buttonPrimary() =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      );
}
