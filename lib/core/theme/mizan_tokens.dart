/// Mizan Design Tokens
///
/// Every value in this file is transcribed from `Mizan Tokens.pdf`, which
/// states: "Every value below is authoritative — the eight-screen light and
/// dark sets use only these tokens." Treat this file as the single source of
/// truth. If a screen needs a colour that is not here, the screen is wrong,
/// not the token set.
///
/// Structure:
///   • [MizanPalette]  — a ThemeExtension holding every role colour and the
///                       neumorphic shadow sets for one brightness. Both
///                       palettes exist simultaneously, so `MaterialApp`'s
///                       `theme`/`darkTheme` pair works normally.
///   • [MizanGeometry] — spacing, radii, tap targets. Brightness-independent.
///   • [MizanMotion]   — durations and curves.
///
/// Read a palette with `MizanPalette.of(context)`.
///
/// ── Why a ThemeExtension and not another static class ──────────────────
/// The legacy `AppColors` is a single mutable static palette flipped by
/// `applyBrightness()`. That makes it impossible for two ThemeData objects to
/// coexist, which is why `app.dart` resolves brightness by hand and remounts
/// the tree with a KeyedSubtree. A ThemeExtension is per-ThemeData, so light
/// and dark can both be live and Flutter handles the switch itself.
library;

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
//  RAW HEXES — the only place these literals may appear
// ══════════════════════════════════════════════════════════════════════

/// Light theme — cream & navy.
abstract final class _Light {
  static const page = Color(0xFFFAF6EE);
  static const card = Color(0xFFFFFDF7);
  static const sunk = Color(0xFFEADCC8);
  static const hairline = Color(0xFFE3D6BE);
  static const ink = Color(0xFF0F3B4C);
  static const muted = Color(0xFF5A7684);
  static const bronze = Color(0xFF9A7B2F);
  static const gold = Color(0xFFD4AF37);
  static const deepBlue = Color(0xFF1E5C72);
  static const sage = Color(0xFF7F9D8C);
}

/// Dark theme — navy & gold.
abstract final class _Dark {
  static const page = Color(0xFF0A2233);
  static const card = Color(0xFF0F3B4C);
  static const raised = Color(0xFF14495C);
  static const text = Color(0xFFF3EDE0);
  static const muted = Color(0xFFA9BFC9);
  static const gold = Color(0xFFD8B45A);
  static const blueAccent = Color(0xFF7FB0C6);
  static const sage = Color(0xFF8FB3A1);
}

// ══════════════════════════════════════════════════════════════════════
//  PALETTE
// ══════════════════════════════════════════════════════════════════════

/// One brightness worth of Mizan colour, carried on ThemeData.
///
/// Role names, not colour names. `onFilled` rather than "cream", `accentText`
/// rather than "gold" — because the point of the token set is that the same
/// role resolves to a *different* hue per theme, and the "gold is trim, not
/// ink" rule means gold-as-fill and gold-as-text are genuinely two roles.
@immutable
class MizanPalette extends ThemeExtension<MizanPalette> {
  const MizanPalette({
    required this.brightness,
    required this.page,
    required this.card,
    required this.sunk,
    required this.hairline,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentText,
    required this.link,
    required this.sage,
    required this.onFilled,
    required this.restShadow,
    required this.pressShadow,
  });

  final Brightness brightness;

  /// App background and the tab bar.
  final Color page;

  /// Raised surfaces and list rows.
  final Color card;

  /// Search fields and inset wells (light), chips and nested cards (dark).
  final Color sunk;

  /// Every 1px border and rule. On dark this is gold at 18% — never a solid
  /// grey.
  final Color hairline;

  /// Primary text, and the fill of a primary CTA on light.
  final Color ink;

  /// The *only* grey in this theme. Secondary text, transliteration, inactive
  /// nav labels, chevrons. There is deliberately no second tier — a lighter
  /// one always fails contrast at 10–13px.
  final Color muted;

  /// Gold as a **fill, a 1px rule, or the diamond glyph**. Never as text on
  /// light — use [accentText] for that. See the "Gold is trim, not ink" rule.
  final Color accent;

  /// Gold-family colour that is legal *as text* on this theme's surfaces.
  /// Light → bronze `#9A7B2F`. Dark → gold `#D8B45A`, which is free to be text
  /// on navy.
  final Color accentText;

  /// Links, selected states, section labels.
  final Color link;

  /// Growth and success only. Nothing else.
  final Color sage;

  /// Text/icons drawn on top of a solid [ink]/[accent] fill.
  final Color onFilled;

  /// The two-shadow "raised" set for touchables at rest.
  final List<BoxShadow> restShadow;

  /// The two-shadow inset set for touchables being pressed. Uses
  /// [BlurStyle.inner], so it must be painted as a *foreground* decoration —
  /// a normal `boxShadow` would be hidden behind the box's own fill.
  final List<BoxShadow> pressShadow;

  bool get isLight => brightness == Brightness.light;

  /// The palette for the current theme. Falls back to [light] rather than
  /// throwing, so a widget rendered outside a Mizan theme still draws.
  static MizanPalette of(BuildContext context) =>
      Theme.of(context).extension<MizanPalette>() ?? light;

  // ── Light ───────────────────────────────────────────────────────────
  static const MizanPalette light = MizanPalette(
    brightness: Brightness.light,
    page: _Light.page,
    card: _Light.card,
    sunk: _Light.sunk,
    hairline: _Light.hairline,
    ink: _Light.ink,
    muted: _Light.muted,
    accent: _Light.gold,
    accentText: _Light.bronze,
    link: _Light.deepBlue,
    sage: _Light.sage,
    onFilled: _Light.card,
    restShadow: [
      // 4px 4px 10px rgba(122,104,72,.16) — warm shade, light-source side
      BoxShadow(
        color: Color(0x297A6848),
        offset: Offset(4, 4),
        blurRadius: 10,
      ),
      // -4px -4px 10px rgba(255,255,255,.92) — near-white highlight opposite
      BoxShadow(
        color: Color(0xEBFFFFFF),
        offset: Offset(-4, -4),
        blurRadius: 10,
      ),
    ],
    pressShadow: [
      // inset 3px 3px 7px rgba(122,104,72,.24)
      BoxShadow(
        color: Color(0x3D7A6848),
        offset: Offset(3, 3),
        blurRadius: 7,
        blurStyle: BlurStyle.inner,
      ),
      // inset -3px -3px 7px rgba(255,255,255,.9)
      BoxShadow(
        color: Color(0xE6FFFFFF),
        offset: Offset(-3, -3),
        blurRadius: 7,
        blurStyle: BlurStyle.inner,
      ),
    ],
  );

  // ── Dark ────────────────────────────────────────────────────────────
  static const MizanPalette dark = MizanPalette(
    brightness: Brightness.dark,
    page: _Dark.page,
    card: _Dark.card,
    sunk: _Dark.raised,
    // gold @ 18% — the spec is explicit that dark borders are never grey.
    hairline: Color(0x2ED8B45A),
    ink: _Dark.text,
    muted: _Dark.muted,
    accent: _Dark.gold,
    accentText: _Dark.gold,
    link: _Dark.blueAccent,
    sage: _Dark.sage,
    onFilled: _Dark.page,
    restShadow: [
      // 5px 5px 12px rgba(0,0,0,.45)
      BoxShadow(
        color: Color(0x73000000),
        offset: Offset(5, 5),
        blurRadius: 12,
      ),
      // -4px -4px 10px rgba(78,140,166,.13)
      BoxShadow(
        color: Color(0x214E8CA6),
        offset: Offset(-4, -4),
        blurRadius: 10,
      ),
    ],
    pressShadow: [
      // inset 3px 3px 8px rgba(0,0,0,.5)
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(3, 3),
        blurRadius: 8,
        blurStyle: BlurStyle.inner,
      ),
      // inset -3px -3px 8px rgba(78,140,166,.11)
      BoxShadow(
        color: Color(0x1C4E8CA6),
        offset: Offset(-3, -3),
        blurRadius: 8,
        blurStyle: BlurStyle.inner,
      ),
    ],
  );

  @override
  MizanPalette copyWith({
    Brightness? brightness,
    Color? page,
    Color? card,
    Color? sunk,
    Color? hairline,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? accentText,
    Color? link,
    Color? sage,
    Color? onFilled,
    List<BoxShadow>? restShadow,
    List<BoxShadow>? pressShadow,
  }) {
    return MizanPalette(
      brightness: brightness ?? this.brightness,
      page: page ?? this.page,
      card: card ?? this.card,
      sunk: sunk ?? this.sunk,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      link: link ?? this.link,
      sage: sage ?? this.sage,
      onFilled: onFilled ?? this.onFilled,
      restShadow: restShadow ?? this.restShadow,
      pressShadow: pressShadow ?? this.pressShadow,
    );
  }

  @override
  MizanPalette lerp(ThemeExtension<MizanPalette>? other, double t) {
    if (other is! MizanPalette) return this;
    return MizanPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      sunk: Color.lerp(sunk, other.sunk, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      link: Color.lerp(link, other.link, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      onFilled: Color.lerp(onFilled, other.onFilled, t)!,
      restShadow: BoxShadow.lerpList(restShadow, other.restShadow, t)!,
      pressShadow: BoxShadow.lerpList(pressShadow, other.pressShadow, t)!,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  GEOMETRY
// ══════════════════════════════════════════════════════════════════════

/// Spacing, radii and sizes. Identical in both themes.
abstract final class MizanGeometry {
  /// Horizontal screen padding.
  static const double gutter = 20;

  /// Inside a card. The spec gives a range; use [cardPaddingTight] for dense
  /// cards and [cardPadding] otherwise.
  static const double cardPadding = 20;
  static const double cardPaddingTight = 18;

  /// Vertical gap between sibling cards.
  static const double gap = 14;

  static const double cardRadius = 18;
  static const double rowRadius = 14;

  /// Chips and pills are fully rounded — use [StadiumBorder] or this value.
  static const double pillRadius = 999;

  /// Nothing tappable may be smaller than this in either dimension.
  static const double tapTarget = 44;

  /// Tab bar height, *before* the bottom safe area is added.
  static const double tabBarHeight = 64;

  /// Every scroll view ends with this much bottom padding so content clears
  /// the tab bar. Non-negotiable rule #5.
  static const double scrollBottomPadding = 96;

  /// 1px hairline. Kept as a named constant so it never drifts to 1.5 or 2.
  static const double hairlineWidth = 1;

  static const BorderRadius cardBorderRadius =
      BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius rowBorderRadius =
      BorderRadius.all(Radius.circular(rowRadius));

  /// Standard page padding: gutter on the sides, tab-bar clearance below.
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    gutter,
    0,
    gutter,
    scrollBottomPadding,
  );
}

// ══════════════════════════════════════════════════════════════════════
//  MOTION
// ══════════════════════════════════════════════════════════════════════

abstract final class MizanMotion {
  /// The tactile press. The spec fixes this at 130ms.
  static const Duration press = Duration(milliseconds: 130);
  static const Curve pressCurve = Curves.easeOut;

  /// Theme crossfade and other page-level transitions.
  static const Duration theme = Duration(milliseconds: 220);
}
