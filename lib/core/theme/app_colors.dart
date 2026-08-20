/// Taddabur color system
/// All colors in the app come from here — never hardcode hex values elsewhere
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Prevent instantiation

  // ── Primary palette ──────────────────────────────────────────
  static const Color night      = Color(0xFF0B1120); // Deep night blue
  static const Color slate      = Color(0xFF1A2535); // Slightly lighter night
  static const Color jade       = Color(0xFF2B7A6F); // Verified/trusted
  static const Color jadeLlight = Color(0xFF3A9E90); // Jade hover state
  static const Color gold       = Color(0xFFC8973A); // Primary accent
  static const Color goldSoft   = Color(0xFFE8C97A); // Gold on dark bg
  static const Color goldPale   = Color(0xFFFDF6E3); // Gold tint on white

  // ── Surface palette ──────────────────────────────────────────
  static const Color parchment  = Color(0xFFF4EFE6); // Main background
  static const Color parchment2 = Color(0xFFEAE2D6); // Secondary surface
  static const Color parchment3 = Color(0xFFDDD5C8); // Border/divider
  static const Color white      = Color(0xFFFFFFFF);

  // ── Text palette ─────────────────────────────────────────────
  static const Color ink        = Color(0xFF0B1120); // Primary text
  static const Color body       = Color(0xFF374151); // Body text
  static const Color muted      = Color(0xFF6B7280); // Secondary text
  static const Color border     = Color(0xFFDDD5C8); // Border color

  // ── Semantic palette ─────────────────────────────────────────
  static const Color success    = Color(0xFF166534); // Sahih grade
  static const Color successBg  = Color(0xFFF0FDF4);
  static const Color error      = Color(0xFFBE123C); // Missing, offline
  static const Color errorBg    = Color(0xFFFFF1F2);
  static const Color amber      = Color(0xFF92400E); // Warning
  static const Color amberBg    = Color(0xFFFFFBEB);
  static const Color violet     = Color(0xFF5B21B6); // Hadith accent
  static const Color violetBg   = Color(0xFFF5F3FF);

  // ── Card type colors ─────────────────────────────────────────
  // Minbar card backgrounds — each content type has distinct material
  static const Color cardQuranBg    = Color(0xFFF4EFE6); // Parchment
  static const Color cardSahabiBg   = Color(0xFF1C1108); // Candlelight
  static const Color cardHadithBg   = Color(0xFF1E2D3D); // Scholarly navy
  static const Color cardNameBg     = Color(0xFF0B1120); // Carved night
  static const Color cardProphetBg  = Color(0xFF0D2218); // Emerald depth
}
