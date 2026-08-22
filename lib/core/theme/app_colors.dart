/// Taddabur Color System
///
/// Rules:
/// 1. Every color used in the app must be defined here
/// 2. Never use raw hex values in widget files — always reference AppColors
/// 3. Colors are grouped by purpose, not by screen
///
/// Brightness-aware: every token is a getter that resolves against the
/// currently applied brightness. `AppColors.applyBrightness()` is called once
/// per build of the root widget (see app.dart) before any widget reads a token.
/// Because these are getters and not consts, no token may be used inside a
/// `const` expression.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.dark;

  static bool get isLight => _brightness == Brightness.light;

  static void applyBrightness(Brightness value) => _brightness = value;

  static Color _pick(Color dark, Color light) => isLight ? light : dark;

  // ── Primary Palette ───────────────────────────────────────────
  // Dark: a Nordic winter sky. Light: matte cream parchment, not cold
  // white-blue — an illuminated-manuscript page, not a hospital wall.
  static Color get night => _pick(const Color(0xFF101720), const Color(0xFFFBF6EC));
  static Color get slate => _pick(const Color(0xFF1B2733), const Color(0xFFF3EAD8));
  static Color get jade => _pick(const Color(0xFF5E9FB6), const Color(0xFF2C7691));
  static Color get jadeLight => _pick(const Color(0xFF9ACDDE), const Color(0xFF4E9CB4));
  // gold: the signature accent blue — unchanged in both themes by request.
  static Color get gold => _pick(const Color(0xFF7FB7D0), const Color(0xFF1F6E8C));
  static Color get goldSoft => _pick(const Color(0xFFB7D9E6), const Color(0xFF3D8CA8));
  static Color get goldPale => _pick(const Color(0xFFE8F3F7), const Color(0xFF2A6E86));
  // clay: the third identity hue — warm copper/terracotta, an illuminated
  // manuscript's rubrication ink. Used for "in progress" states and
  // secondary highlights that shouldn't compete with the blue accent.
  static Color get clay => _pick(const Color(0xFFE0916A), const Color(0xFFAD5A2B));
  static Color get clayBg => _pick(const Color(0xFF2A1D14), const Color(0xFFF3E3D2));

  // ── Surfaces ───────────────────────────────────────────────────
  static Color get surface => _pick(const Color(0xFF17212B), const Color(0xFFFFFCF5));
  static Color get surfaceElevated => _pick(const Color(0xFF22313D), const Color(0xFFF5EEDD));
  static Color get surfaceDim => _pick(const Color(0xFF0D141B), const Color(0xFFEFE3C9));

  // ── Headline neutrals ────────────────────────────────────────────
  // A parallel scale to textPrimary/Secondary/muted, kept as separate
  // tokens because a handful of screens want a slightly different weight
  // for hero headlines specifically. Theme-aware like everything else —
  // these used to be frozen to the dark-mode value, which is why light
  // mode text used to vanish.
  static Color get parchment =>
      _pick(const Color(0xFFEAF1F4), const Color(0xFF16283A));
  static Color get parchment2 =>
      _pick(const Color(0xFFD9E4E9), const Color(0xFF3E5468));
  static Color get parchment3 =>
      _pick(const Color(0xFFC7D4DA), const Color(0xFF6C7F8C));
  // white: literal white — only correct for text/icons sitting on a
  // solid-filled accent surface (a button, a filled badge), never for text
  // on the app background. Use textPrimary for that instead.
  static Color get white => const Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────
  // ink: literal near-black — the counterpart to `white` above, for text
  // that sits on a solid accent fill and must stay dark in both themes
  // (button labels, filled-badge numbers). Never use for text on the app
  // background — use textPrimary for that.
  static Color get ink => const Color(0xFF111412);
  static Color get textPrimary =>
      _pick(const Color(0xFFEEF4F6), const Color(0xFF16283A));
  static Color get textSecondary =>
      _pick(const Color(0xFFC0CCD1), const Color(0xFF3E5468));
  static Color get body => _pick(const Color(0xFFD5DEE3), const Color(0xFF33495C));
  static Color get muted => _pick(const Color(0xFF91A0A8), const Color(0xFF6C7F8C));
  static Color get border => _pick(const Color(0xFF31424D), const Color(0xFFE3D5B8));
  static Color get borderLight =>
      _pick(const Color(0xFFC7D4DA), const Color(0xFFEDE1C8));

  // ── Semantic ──────────────────────────────────────────────────
  static Color get success => _pick(const Color(0xFF34D399), const Color(0xFF15803D));
  static Color get successDim => _pick(const Color(0xFF166534), const Color(0xFF166534));
  static Color get successBg => _pick(const Color(0xFF0D2A24), const Color(0xFFE2F5EA));
  static Color get error => _pick(const Color(0xFFF87171), const Color(0xFFB91C1C));
  static Color get errorDim => const Color(0xFFBE123C);
  static Color get errorBg => _pick(const Color(0xFF2A0F1A), const Color(0xFFFCE8E8));
  static Color get amber => _pick(const Color(0xFFFBBF24), const Color(0xFFB45309));
  static Color get amberDim => const Color(0xFF92400E);
  static Color get amberBg => _pick(const Color(0xFF2A1F0A), const Color(0xFFFDF3E0));
  static Color get violet => _pick(const Color(0xFF8B5CF6), const Color(0xFF6D28D9));
  static Color get violetDim => const Color(0xFF5B21B6);
  static Color get violetBg => _pick(const Color(0xFF1A1328), const Color(0xFFF1EAFE));

  // ── Minbar / Discover card materials ──────────────────────────
  static Color get cardQuranBg =>
      _pick(const Color(0xFF0F1A28), const Color(0xFFE9F1F8));
  // Was a muddy reddish-brown (0xFF1C1108) — a warm, refined charcoal now,
  // in the same family as the rest of the dark palette instead of clashing
  // with it.
  static Color get cardSahabiBg =>
      _pick(const Color(0xFF241C14), const Color(0xFFF8F0E4));
  static Color get cardHadithBg =>
      _pick(const Color(0xFF1E2D3D), const Color(0xFFEAF0F6));
  static Color get cardNameBg =>
      _pick(const Color(0xFF0B1120), const Color(0xFFEDEFF7));
  static Color get cardProphetBg =>
      _pick(const Color(0xFF0D2218), const Color(0xFFE6F3EC));
  static Color get cardSeerahBg =>
      _pick(const Color(0xFF171426), const Color(0xFFEFEDF8));

  // ── Quran reading surfaces ─────────────────────────────────────
  static Color get quranSurface =>
      _pick(const Color(0xFF1A2535), const Color(0xFFFFFDF7));
  static Color get quranSurfaceDim =>
      _pick(const Color(0xFF0D1626), const Color(0xFFF6EEDC));
  static Color get quranBorder =>
      _pick(const Color(0xFF2A3545), const Color(0xFFE3D5B8));
  static Color get quranMuted =>
      _pick(const Color(0xFF9CADB8), const Color(0xFF5D6E78));

  // ── Navigation ────────────────────────────────────────────────
  static Color get navActive => gold;
  static Color get navInactive =>
      _pick(const Color(0xFF82929B), const Color(0xFF77878F));
  static Color get navBg => _pick(const Color(0xFF121C25), const Color(0xFFFFFCF5));
}
