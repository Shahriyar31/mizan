/// Mizan brand — the logo variants and the user's choice between them.
///
/// Five tiles ship, all the same artwork — the mihrab arch, `ميزان` in
/// calligraphy, an open book beneath it — over five different fields:
///
///   • **Classic**  navy calligraphy on warm cream.
///   • **Midnight** gold calligraphy on deep navy. The launcher icon, and the
///                  default a fresh install wears, so the mark inside the app
///                  and the one on the home screen agree.
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
/// already cut to transparency at the iOS squircle ratio. That is the in-app one.
/// The cut is not perfectly clean, though — a thin arc of the white backing the
/// mark was composited onto survives between the transparent corner and the
/// artwork's own edge, so [MizanMark] clips at [mizanMarkRadiusRatio] to drop it.
/// Clipping at that exact radius traces the silhouette the art already has, so it
/// removes the white without laying a second, differently-shaped corner over the
/// first.
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
/// and the Settings screen says the picker changes the in-app mark only, rather
/// than offering a control that quietly does nothing. Midnight is baked into the
/// launcher slots; the alternate-icon resources that used to sit beside it were
/// removed when the new artwork landed, because five unreachable copies of an
/// unwired feature is worse than none.
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

  /// The variant behind "Match my theme": the tile brings its own field colour,
  /// so it should contrast with the page it sits on. Midnight on cream, Classic
  /// on navy. This is *not* the fresh-install default — that is
  /// [LogoVariantController.defaultVariant], which is Midnight either way.
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
/// Three states share one string, and telling two of them apart is the whole
/// reason this is more than a `getString`:
///
///   key absent      a fresh install. Wears [defaultVariant] — Midnight, the
///                   mark baked into the launcher icon — so the tile inside the
///                   app and the one on the home screen agree before the user
///                   has touched anything.
///   `follow_theme`  the user asked for "Match my theme". `null` in memory, and
///                   a real, saved choice: the mark then flips with the theme,
///                   Midnight in the light one and Classic in the dark.
///   a variant id    that variant, pinned, whatever the theme does.
///
/// "Match my theme" used to be stored by *deleting* the key, which made it
/// indistinguishable from a fresh install. That was harmless while both meant
/// the same thing. It stopped being harmless the moment the default became one
/// specific variant — the choice would not have survived a restart — so it is
/// now written down explicitly.
class LogoVariantController extends StateNotifier<MizanLogoVariant?> {
  LogoVariantController() : super(_bootValue);

  static const _key = 'settings_logo_variant';

  /// Stored for "Match my theme". Deliberately not a variant id, and it must
  /// never become one, or [MizanLogoVariant.decode] would start claiming it.
  static const _followTheme = 'follow_theme';

  /// What an untouched install wears: Midnight, the mark
  /// `tools/make_launcher_icons.py` bakes into the launcher slots. Changing one
  /// without the other puts a different tile in the app than on the home screen.
  static const MizanLogoVariant defaultVariant = MizanLogoVariant.midnight;

  /// Read once during app start so the first frame already has the right mark —
  /// otherwise the welcome screen flashes the wrong tile. Seeded with the
  /// default so even a read before [restore] shows the launcher's mark.
  static MizanLogoVariant? _bootValue = defaultVariant;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _bootValue = defaultVariant;
    } else if (raw == _followTheme) {
      _bootValue = null;
    } else {
      // An id this build cannot read is a bug or a downgrade, not a wish, so it
      // falls to the default rather than to "follow the theme".
      _bootValue = MizanLogoVariant.decode(raw) ?? defaultVariant;
    }
  }

  /// Pass `null` to go back to following the theme.
  Future<void> set(MizanLogoVariant? variant) async {
    state = variant;
    _bootValue = variant;
    final prefs = await SharedPreferences.getInstance();
    // Always writes something. Removing the key would read back as a fresh
    // install, which is now Midnight rather than "follow the theme".
    await prefs.setString(_key, variant?.id ?? _followTheme);
  }
}

final logoVariantProvider =
    StateNotifierProvider<LogoVariantController, MizanLogoVariant?>(
  (ref) => LogoVariantController(),
);
