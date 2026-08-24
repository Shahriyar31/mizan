/// Mizan brand — the logo variants and the user's choice between them.
///
/// Five tiles ship, all the same artwork — the mihrab arch, `ميزان` in
/// calligraphy, an open book beneath it — over five different fields:
///
///   • **Classic**  navy calligraphy on warm cream. The launcher icon.
///   • **Midnight** gold calligraphy on deep navy.
///   • **Light**    the same as Classic on plain white.
///   • **Emerald**  cream calligraphy on deep green.
///   • **Plum**     cream calligraphy on deep aubergine.
///
/// The user picks one in Settings › Personalisation › App Icon. That choice
/// drives every in-app appearance of the mark (welcome screen, headers, the
/// about card) immediately.
///
/// ── Each variant is two files, and the difference matters ─────────────
/// [MizanLogoVariant.asset] is the rounded tile: 900×1046 with the corners
/// already cut to transparency at the iOS squircle ratio. That is the in-app
/// one — the transparent corners are the point, and re-clipping it would put a
/// second, differently-shaped corner over the first.
///
/// [MizanLogoVariant.squareAsset] is the opaque square, padded out to 1046×1046.
/// That is the *launcher* one: both platforms want a full-bleed square and apply
/// their own mask, so handing them pre-rounded art wastes the corners twice.
/// Nothing in Dart reads it — the Android mipmaps and the iOS appiconset are
/// baked from it by `tools/make_launcher_icons.py` — but it is named here so the
/// pairing is written down somewhere.
///
/// ── The tiles are not square ──────────────────────────────────────────
/// 900×1046, a 0.861 aspect. From the asset README, as a rule: *"Use
/// `BoxFit.contain` or set one dimension only. A square box squashes the book at
/// the bottom of the mark."* [MizanMark] therefore sizes by width and lets the
/// height fall out, and takes no `height`.
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
/// The native wiring is **not** in place, so [launcherSwapSupported] is false
/// and the Settings screen says so plainly rather than offering a control that
/// quietly does nothing. Only Classic is baked into the launcher slots; the
/// alternate-icon resources that used to sit beside it were removed when the new
/// artwork landed, because five unreachable copies of an unwired feature is
/// worse than none.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/mizan_tokens.dart';

/// Whether changing the *home-screen* icon is wired up. See the library note.
const bool launcherSwapSupported = false;

/// Corner radius of the mark, as a fraction of its width — the iOS squircle
/// ratio, and the one the artwork's own corners are cut at.
///
/// Nothing clips with this any more; the rounded PNGs arrive with their corners
/// already transparent. It survives because [MizanMark]'s optional drop shadow
/// still needs a silhouette to trace, and a shadow on the wrong radius is a
/// visible grey seam outside the artwork's edge.
const double mizanMarkRadiusRatio = 0.2237;

enum MizanLogoVariant {
  classic(
    id: 'classic',
    label: 'Classic',
    description: 'Navy calligraphy on warm cream',
    asset: 'assets/logo/mizan_classic.png',
    squareAsset: 'assets/logo/square/mizan_classic.png',
    isPaleField: true,
  ),

  midnight(
    id: 'midnight',
    label: 'Midnight',
    description: 'Gold calligraphy on deep navy',
    asset: 'assets/logo/mizan_midnight.png',
    squareAsset: 'assets/logo/square/mizan_midnight.png',
    isPaleField: false,
  ),

  light(
    id: 'light',
    label: 'Light',
    description: 'Navy calligraphy on white',
    asset: 'assets/logo/mizan_light.png',
    squareAsset: 'assets/logo/square/mizan_light.png',
    isPaleField: true,
  ),

  emerald(
    id: 'emerald',
    label: 'Emerald',
    description: 'Cream calligraphy on deep green',
    asset: 'assets/logo/mizan_emerald.png',
    squareAsset: 'assets/logo/square/mizan_emerald.png',
    isPaleField: false,
  ),

  plum(
    id: 'plum',
    label: 'Plum',
    description: 'Cream calligraphy on deep aubergine',
    asset: 'assets/logo/mizan_plum.png',
    squareAsset: 'assets/logo/square/mizan_plum.png',
    isPaleField: false,
  );

  const MizanLogoVariant({
    required this.id,
    required this.label,
    required this.description,
    required this.asset,
    required this.squareAsset,
    required this.isPaleField,
  });

  /// Stable storage key — never rename these, or a saved choice is lost.
  final String id;

  final String label;
  final String description;

  /// The rounded, transparent-cornered tile. This is the in-app one.
  final String asset;

  /// The opaque square, for launcher generation. See the library note.
  final String squareAsset;

  /// Whether the tile's field is near-white. Cream and white fields vanish on a
  /// cream page and need contrast against it; the three dark fields do not.
  final bool isPaleField;

  /// The variant that reads best on a given palette when the user has expressed
  /// no preference: the tile brings its own field colour, so it should contrast
  /// with the page it sits on. Midnight on cream, Classic on navy.
  static MizanLogoVariant forPalette(MizanPalette p) =>
      p.isLight ? MizanLogoVariant.midnight : MizanLogoVariant.classic;

  static MizanLogoVariant? decode(String? raw) {
    for (final v in MizanLogoVariant.values) {
      if (v.id == raw) return v;
    }
    // The two ids the previous, two-variant artwork saved. A user who picked one
    // of those keeps the closest field colour instead of being silently reset to
    // "match my theme", which would look like the app forgetting.
    return switch (raw) {
      'navy' => MizanLogoVariant.midnight,
      'cream' => MizanLogoVariant.classic,
      _ => null,
    };
  }
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
