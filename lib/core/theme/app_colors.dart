/// Legacy colour tokens, now aliased onto the MIZAN palette.
///
/// ── What this file is for ─────────────────────────────────────────────
/// The app has ~780 call sites across 49 files that read `AppColors.something`.
/// The screens rebuilt onto the design system read [MizanPalette] from the
/// widget tree instead and never come here. Everything not yet rebuilt — the
/// quiz, the settings sub-screens, the older reader chrome — still reads these
/// tokens, and until this file changed they painted the *old* palette: a blue
/// accent, colder creams, six differently-tinted card materials, amber and
/// violet accents. Correct in both themes, but a different app to look at.
///
/// So every token below is now a view onto [MizanPalette.light] /
/// [MizanPalette.dark]. Nothing is invented here: each getter returns a colour
/// that exists in the Mizan spec. The whole app is one palette from this commit
/// on, and a screen's *layout* can then be rebuilt on its own schedule without
/// the colour being wrong in the meantime.
///
/// ── Consequences worth knowing ────────────────────────────────────────
///   • Several legacy tokens now resolve to the same colour — `jade` and
///     `jadeLight`, `parchment2` and `parchment3`, all six `card*Bg` materials.
///     That is deliberate: the Mizan palette has four hues and one grey per
///     theme, so a scale of near-identical greys has nowhere to land. Screens
///     that relied on those materials to tell content types apart should use an
///     icon or a label instead, which the rebuilt screens do.
///   • `gold` resolves to **bronze** in light mode. Rule #1 of the spec: the
///     gold family may not be text on cream, so the legal light-mode value of
///     "the gold token" is `accentText`. Dark mode keeps true gold.
///   • `error`, `errorDim` and `errorBg` are the one place a colour outside the
///     palette survives. The spec has no red, and an error signal has to be red;
///     inventing a "Mizan red" is a design decision to take deliberately, not a
///     side effect of this migration.
///
/// Tokens remain getters, never consts, so no token may be used inside a
/// `const` expression. [applyBrightness] is called once per root build from
/// `app.dart` and `app_theme.dart` before any widget reads a token.
library;

import 'package:flutter/material.dart';

import 'mizan_tokens.dart';

class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.dark;

  static bool get isLight => _brightness == Brightness.light;

  static void applyBrightness(Brightness value) => _brightness = value;

  /// The single source of truth. Both palettes are const, so this is a lookup,
  /// not an allocation.
  static MizanPalette get _p => isLight ? MizanPalette.light : MizanPalette.dark;

  /// Kept for the handful of tokens with no Mizan equivalent (the error reds).
  static Color _pick(Color dark, Color light) => isLight ? light : dark;

  // ── Primary palette ───────────────────────────────────────────
  /// The app background: deep navy on dark, cream parchment on light.
  static Color get night => _p.page;

  /// The secondary surface — a raised panel on dark, an inset well on light.
  static Color get slate => _p.sunk;

  /// The calm blue. In Mizan this is the link/secondary-accent hue.
  static Color get jade => _p.link;
  static Color get jadeLight => _p.link;

  /// The signature accent. Bronze on light so it stays legal as text (Rule #1),
  /// true gold on dark.
  static Color get gold => _p.accentText;

  /// A lower-emphasis accent. The palette has one gold per theme, so these
  /// resolve to it and rely on opacity at the call site for emphasis.
  static Color get goldSoft => _p.accentText;
  static Color get goldPale => _p.accentText;

  /// Was a warm terracotta third hue, used for "in progress". Mizan has no
  /// third hue, so in-progress states take the calm blue.
  static Color get clay => _p.link;
  static Color get clayBg => _p.sunk;

  // ── Surfaces ───────────────────────────────────────────────────
  static Color get surface => _p.card;
  static Color get surfaceElevated => _p.sunk;
  static Color get surfaceDim => _p.page;

  // ── Headline neutrals ────────────────────────────────────────────
  /// One ink per theme — cream text on navy, deep navy text on cream.
  static Color get parchment => _p.ink;
  static Color get parchment2 => _p.muted;
  static Color get parchment3 => _p.muted;

  /// Literal white. Only correct on a solid accent fill, never on the page.
  static Color get white => const Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────
  /// Text that must stay dark on a solid accent fill, in both themes. This is
  /// exactly what [MizanPalette.onFilled] means on dark.
  static Color get ink => MizanPalette.dark.onFilled;

  static Color get textPrimary => _p.ink;
  static Color get textSecondary => _p.muted;
  static Color get body => _p.ink;
  static Color get muted => _p.muted;

  /// One hairline per theme: warm cream on light, gold at 18% on dark — the spec
  /// is explicit that dark borders are never grey.
  static Color get border => _p.hairline;
  static Color get borderLight => _p.hairline;

  // ── Semantic ──────────────────────────────────────────────────
  /// Sage is the palette's one success colour.
  static Color get success => _p.sage;
  static Color get successDim => _p.sage;
  static Color get successBg => _p.sunk;

  /// The one survival from the old palette — see the library comment.
  static Color get error =>
      _pick(const Color(0xFFF87171), const Color(0xFFB91C1C));
  static Color get errorDim => const Color(0xFFBE123C);
  static Color get errorBg =>
      _pick(const Color(0xFF2A0F1A), const Color(0xFFFCE8E8));

  /// Amber was a second warm accent; the gold family already is that.
  static Color get amber => _p.accentText;
  static Color get amberDim => _p.accentText;
  static Color get amberBg => _p.sunk;

  /// Violet had no place in a four-hue palette; it becomes the calm blue.
  static Color get violet => _p.link;
  static Color get violetDim => _p.link;
  static Color get violetBg => _p.sunk;

  // ── Minbar / Discover card materials ──────────────────────────
  /// Six tinted materials collapse to one inset surface. Content type is now
  /// carried by an icon and a label, not by a background tint.
  static Color get cardQuranBg => _p.sunk;
  static Color get cardSahabiBg => _p.sunk;
  static Color get cardHadithBg => _p.sunk;
  static Color get cardNameBg => _p.sunk;
  static Color get cardProphetBg => _p.sunk;
  static Color get cardSeerahBg => _p.sunk;

  // ── Quran reading surfaces ─────────────────────────────────────
  static Color get quranSurface => _p.card;
  static Color get quranSurfaceDim => _p.sunk;
  static Color get quranBorder => _p.hairline;
  static Color get quranMuted => _p.muted;

  // ── Navigation ────────────────────────────────────────────────
  /// The tab bar's active colour is the ink, not the accent: in Mizan the active
  /// tab is marked by a gold diamond beneath the label, and the label itself
  /// stays ink so it never becomes gold text on cream.
  static Color get navActive => _p.ink;
  static Color get navInactive => _p.muted;
  static Color get navBg => _p.card;
}
