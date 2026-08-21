/// Taddabur Color System
///
/// Rules:
/// 1. Every color used in the app must be defined here
/// 2. Never use raw hex values in widget files — always reference AppColors
/// 3. Adding a new color? Add it here first, then use it
/// 4. Colors are grouped by purpose, not by screen
library;

import 'package:flutter/material.dart';

class AppColors {
  // Private constructor — this class should never be instantiated
  // It's a namespace for constants, not an object
  AppColors._();

  // ── Primary Palette ───────────────────────────────────────────
  // A Nordic winter sky: muted, calm and legible rather than glossy black.
  static const Color night = Color(0xFF101720);
  static const Color slate = Color(0xFF1B2733);
  static const Color jade = Color(0xFF5E9FB6); // trusted, calm teal-blue
  static const Color jadeLight = Color(0xFF9ACDDE);
  static const Color gold = Color(0xFF7FB7D0); // primary ice-blue accent
  static const Color goldSoft = Color(0xFFB7D9E6); // accent on dark bg
  static const Color goldPale = Color(0xFFE8F3F7); // accent tint

  // ── Matte Dark Surfaces ────────────────────────────────────────
  // Refined matte surfaces — never pure black, always blue-grey tinted
  static const Color surface =
      Color(0xFF17212B); // primary surface (cards, sheets)
  static const Color surfaceElevated =
      Color(0xFF22313D); // elevated cards, dialogs
  static const Color surfaceDim =
      Color(0xFF0D141B); // recessed areas, backgrounds behind cards

  // ── Surface Palette (legacy light — kept for parchment references) ───
  // Legacy names retained, now cooled to Nordic mist neutrals.
  static const Color parchment = Color(0xFFEAF1F4);
  static const Color parchment2 = Color(0xFFD9E4E9);
  static const Color parchment3 = Color(0xFFC7D4DA);
  static const Color white = Color(0xFFFFFFFF);

  // ── Text Palette — dark theme optimised ────────────────────────
  static const Color ink = Color(0xFF111412); // kept for rare light usage
  static const Color textPrimary =
      Color(0xFFEEF4F6); // ice white — primary text on dark
  static const Color textSecondary =
      Color(0xFFC0CCD1); // muted cool grey — secondary text
  static const Color body = Color(0xFF374151); // body text (light theme)
  static const Color muted = Color(0xFF91A0A8); // secondary text
  static const Color border = Color(0xFF31424D); // dark border for dark theme
  static const Color borderLight = Color(0xFFC7D4DA); // kept for light contexts

  // ── Semantic Palette ──────────────────────────────────────────
  // These communicate meaning — do not use for decoration
  static const Color success = Color(0xFF34D399); // brighter for dark bg
  static const Color successDim = Color(0xFF166534); // original for badges
  static const Color successBg = Color(0xFF0D2A24); // dark success bg
  static const Color error = Color(0xFFF87171); // brighter for dark bg
  static const Color errorDim = Color(0xFFBE123C);
  static const Color errorBg = Color(0xFF2A0F1A);
  static const Color amber = Color(0xFFFBBF24); // brighter for dark bg
  static const Color amberDim = Color(0xFF92400E);
  static const Color amberBg = Color(0xFF2A1F0A);
  static const Color violet = Color(0xFF8B5CF6); // brighter for dark bg
  static const Color violetDim = Color(0xFF5B21B6);
  static const Color violetBg = Color(0xFF1A1328);

  // ── Minbar Card Materials ─────────────────────────────────────
  // Each content type has its own visual material — like physical objects
  static const Color cardQuranBg = Color(0xFF0F1A28); // deep scholarly blue
  static const Color cardSahabiBg = Color(0xFF1C1108); // candlelight
  static const Color cardHadithBg = Color(0xFF1E2D3D); // scholarly navy
  static const Color cardNameBg = Color(0xFF0B1120); // carved night
  static const Color cardProphetBg = Color(0xFF0D2218); // emerald depth

  // ── Quran Reading Surfaces ─────────────────────────────────────
  // The deep scholarly-blue material used by the ayah reader and the
  // 5-layer tafseer screen — named here so both files reference the same
  // tokens instead of duplicating hex literals.
  static const Color quranSurface = Color(0xFF1A2535); // layer/scene cards
  static const Color quranSurfaceDim = Color(0xFF0D1626); // bottom tab bar
  static const Color quranBorder = Color(0xFF2A3545); // dividers, borders
  static const Color quranMuted = Color(0xFF9CADB8); // secondary/translation text

  // ── Navigation ────────────────────────────────────────────────
  static const Color navActive = gold;
  static const Color navInactive = Color(0xFF82929B);
  static const Color navBg = Color(0xFF121C25); // dark nav background
}
