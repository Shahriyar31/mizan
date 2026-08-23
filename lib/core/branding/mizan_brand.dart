/// Mizan brand — the logo variants and the user's choice between them.
///
/// Two marks ship with the app, both the same artwork:
///
///   • **Navy** — cream book-and-scales on a deep navy tile. The default.
///   • **Cream** — navy book-and-scales on a warm cream tile.
///
/// The user picks one in Settings › Personalisation › App Icon. That choice
/// drives every in-app appearance of the mark (welcome screen, headers, the
/// about card) immediately.
///
/// ── On changing the *launcher* icon ───────────────────────────────────
/// Swapping the icon on the phone's home screen is a different problem from
/// swapping it inside the app, and it is platform-native work:
///
///   Android — declare an `<activity-alias>` per icon in AndroidManifest.xml
///             and toggle them with `PackageManager.setComponentEnabledSetting`.
///             Disabling the running component kills the app, so the swap has
///             to be sequenced carefully.
///   iOS     — `UIApplication.setAlternateIconName`, with the alternates listed
///             under `CFBundleAlternateIcons` in Info.plist. iOS shows a system
///             alert every time the icon changes; that is not suppressible.
///
/// Both launcher icon sets are already generated and on disk (see
/// `docs/APP_ICON_SWITCHING.md`), but the native wiring is **not** in place, so
/// [launcherSwapSupported] is false and the Settings screen says so plainly
/// rather than offering a control that quietly does nothing.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/mizan_tokens.dart';

/// Whether changing the *home-screen* icon is wired up. See the library note.
const bool launcherSwapSupported = false;

/// Corner radius of the mark, as a fraction of its width.
///
/// The bundled `assets/brand/*.png` are deliberately **square** — [MizanMark]
/// rounds them with a `ClipRRect`, so the corner is a vector at display size
/// rather than a bitmap corner resampled from 1024px down to 40. This ratio is
/// the one the exported launcher icons use, so the mark inside the app and the
/// icon on the home screen have the same silhouette. Change both together.
const double mizanMarkRadiusRatio = 0.2237;

enum MizanLogoVariant {
  /// Cream mark on a deep navy tile.
  navy(
    id: 'navy',
    label: 'Navy',
    description: 'Cream mark on deep navy',
    asset: 'assets/brand/mizan_icon_navy.png',
  ),

  /// Navy mark on a warm cream tile.
  cream(
    id: 'cream',
    label: 'Cream',
    description: 'Navy mark on warm cream',
    asset: 'assets/brand/mizan_icon_cream.png',
  );

  const MizanLogoVariant({
    required this.id,
    required this.label,
    required this.description,
    required this.asset,
  });

  /// Stable storage key — never rename these, or a saved choice is lost.
  final String id;

  final String label;
  final String description;
  final String asset;

  /// The variant that reads best on a given palette when the user has expressed
  /// no preference: the tile should contrast with the page it sits on, so navy
  /// on cream and cream on navy.
  static MizanLogoVariant forPalette(MizanPalette p) =>
      p.isLight ? MizanLogoVariant.navy : MizanLogoVariant.cream;

  static MizanLogoVariant? decode(String? raw) {
    for (final v in MizanLogoVariant.values) {
      if (v.id == raw) return v;
    }
    return null;
  }
}

/// The mark with **no tile** — the artwork cut out on transparency, for placing
/// directly on a page (the welcome screen does this).
///
/// ── Why this is not a [MizanLogoVariant] ──────────────────────────────
/// The tile is a *preference*: either tile reads fine on either page, because it
/// brings its own field colour. A glyph has no field, so the page dictates it —
/// navy ink on a navy page is simply invisible. So this axis is chosen from the
/// palette and is deliberately **not** user-overridable, and the App Icon
/// setting has no effect on it.
enum MizanGlyphInk {
  /// Navy-and-gold artwork, for cream pages.
  navy(
    asset: 'assets/brand/mizan_glyph_navy.png',
    hasArch: false,
  ),

  /// Cream-and-gold artwork, for navy pages.
  cream(
    asset: 'assets/brand/mizan_glyph_cream.png',
    hasArch: true,
  );

  const MizanGlyphInk({required this.asset, required this.hasArch});

  final String asset;

  /// Whether the mihrab arch is already part of the artwork.
  ///
  /// It is, on [cream] only — that master was drawn with the arch and the two
  /// are visually interlocked, so cutting it out would leave the diamond
  /// floating. Anything that draws a decorative [MizanArch] behind the glyph
  /// must check this first, or the dark theme gets two arches.
  final bool hasArch;

  /// The ink that is legible on this palette's page. See the note above on why
  /// the user's icon choice deliberately does not enter into this.
  static MizanGlyphInk forPalette(MizanPalette p) =>
      p.isLight ? MizanGlyphInk.navy : MizanGlyphInk.cream;
}

/// The user's chosen mark, or `null` for "follow the theme".
///
/// `null` is a real, meaningful state — not just "unset". A user who has never
/// touched this setting gets the mark that suits their theme, and it flips with
/// the theme. Only once they pick a specific variant does it stop following.
class LogoVariantController extends StateNotifier<MizanLogoVariant?> {
  LogoVariantController() : super(_bootValue);

  static const _key = 'settings_logo_variant';

  /// Read once during app start so the first frame already has the right mark —
  /// otherwise the welcome screen flashes the wrong tile.
  static MizanLogoVariant? _bootValue;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _bootValue = MizanLogoVariant.decode(prefs.getString(_key));
  }

  /// Pass `null` to go back to following the theme.
  Future<void> set(MizanLogoVariant? variant) async {
    state = variant;
    _bootValue = variant;
    final prefs = await SharedPreferences.getInstance();
    if (variant == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, variant.id);
    }
  }
}

final logoVariantProvider =
    StateNotifierProvider<LogoVariantController, MizanLogoVariant?>(
  (ref) => LogoVariantController(),
);
