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
  // The sky between Isha and Fajr — the most honest Islamic hour
  static const Color night = Color(0xFF0B1120);
  static const Color slate = Color(0xFF1A2535);
  static const Color jade = Color(0xFF2B7A6F); // verified/trusted
  static const Color jadeLight = Color(0xFF3A9E90);
  static const Color gold = Color(0xFFC8973A); // primary accent
  static const Color goldSoft = Color(0xFFE8C97A); // gold on dark bg
  static const Color goldPale = Color(0xFFFDF6E3); // gold tint

  // ── Surface Palette ───────────────────────────────────────────
  // Parchment feels like manuscript — warm, not clinical white
  static const Color parchment = Color(0xFFF4EFE6);
  static const Color parchment2 = Color(0xFFEAE2D6);
  static const Color parchment3 = Color(0xFFDDD5C8);
  static const Color white = Color(0xFFFFFFFF);

  // ── Text Palette ──────────────────────────────────────────────
  static const Color ink = Color(0xFF0B1120); // primary text
  static const Color body = Color(0xFF374151); // body text
  static const Color muted = Color(0xFF6B7280); // secondary text
  static const Color border = Color(0xFFDDD5C8);

  // ── Semantic Palette ──────────────────────────────────────────
  // These communicate meaning — do not use for decoration
  static const Color success = Color(0xFF166534); // Sahih grade
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color error = Color(0xFFBE123C); // missing, offline
  static const Color errorBg = Color(0xFFFFF1F2);
  static const Color amber = Color(0xFF92400E); // warning
  static const Color amberBg = Color(0xFFFFFBEB);
  static const Color violet = Color(0xFF5B21B6); // hadith accent
  static const Color violetBg = Color(0xFFF5F3FF);

  // ── Minbar Card Materials ─────────────────────────────────────
  // Each content type has its own visual material — like physical objects
  static const Color cardQuranBg = Color(0xFFF4EFE6); // parchment
  static const Color cardSahabiBg = Color(0xFF1C1108); // candlelight
  static const Color cardHadithBg = Color(0xFF1E2D3D); // scholarly navy
  static const Color cardNameBg = Color(0xFF0B1120); // carved night
  static const Color cardProphetBg = Color(0xFF0D2218); // emerald depth

  // ── Navigation ────────────────────────────────────────────────
  static const Color navActive = gold;
  static const Color navInactive = Color(0xFFB0A898);
  static const Color navBg = white;
}
