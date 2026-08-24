/// The ten Mizan icons — the artwork, and the one rule that governs it.
///
/// ── Why this is not `IconData` ────────────────────────────────────────
/// These are not font glyphs. Each one is two-colour raster artwork: teal ink
/// with gold accents for the cream theme, gold ink with cream accents for the
/// navy theme. A font icon is one colour by definition, so the whole set could
/// not be expressed as `IconData` without throwing away half of every icon.
///
/// That is also why [MizanIcon] takes no `color`. From the asset README, and it
/// is a rule rather than a preference:
///
///   > **Never tint them.** No `color:`, no `ColorFiltered`, no `Icon()`
///   > substitution. Each icon is two-colour artwork; tinting collapses it to
///   > one flat shape.
///
/// A tint could not do the job even if it were allowed: the dark theme sends
/// teal to gold *and* gold to cream, and no single colour filter performs two
/// different mappings in one pass. So there are two files, and the theme picks
/// between them — see [MizanIcons.assetFor].
///
/// ── Why an enum and not a string ──────────────────────────────────────
/// The README's second rule is "never substitute a Material icon because a name
/// looks missing — all ten exist." A string path makes that mistake silent: a
/// typo becomes a runtime asset error, and the tempting fix is `Icons.something`
/// instead. An enum makes the same mistake a compile error, and makes the full
/// set discoverable, so there is nothing to guess at.
///
/// If an eleventh icon is ever needed, this enum will not have it. That is the
/// intended outcome: ask for the artwork rather than reaching for Material.
library;

import 'package:flutter/widgets.dart';

import '../theme/mizan_tokens.dart';

/// The ten icons that ship, by name. Identical filenames in both themes.
enum MizanIcons {
  // ── The five tabs ───────────────────────────────────────────────────
  home,
  quran,
  discover,
  halaqa,
  minbar,

  // ── Sections reached from inside a tab ──────────────────────────────
  hadith,
  prophet,
  sahaba,
  names99,
  settings;

  /// The bundled path for this icon on a given [brightness].
  ///
  /// Only one path segment differs between the sets, exactly as the asset README
  /// lays out. The `2.0x` and `3.0x` folders are a Flutter convention and are
  /// resolved by the framework from the device pixel ratio — nothing here has to
  /// know the density.
  ///
  /// The dark set is not a nicety. On navy, the light set's teal ink drops to
  /// roughly 1.3:1 against the page and the icon reads as an empty gold outline,
  /// so the switch is load-bearing rather than a refinement.
  String assetFor(Brightness brightness) => brightness == Brightness.dark
      ? 'assets/icons/dark/$name.png'
      : 'assets/icons/$name.png';
}

/// One of the ten icons, at the size you ask for, in the theme's set.
///
/// Deliberately has no `color` parameter. See the library note.
class MizanIcon extends StatelessWidget {
  const MizanIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.opacity = 1.0,
    this.semanticLabel,
  });

  final MizanIcons icon;

  /// Width and height in logical pixels. The artwork is square.
  final double size;

  /// Applied to the **image only**, never to a surrounding column.
  ///
  /// The tab bar fades the inactive icon to 0.52 and this is where that fade
  /// belongs. Fading a whole tab drags its label down with it, and a 10px label
  /// at 52% lands near 2:1 contrast — legible in a mockup, not on a phone in
  /// daylight, and a WCAG failure either way. Keeping the parameter here, on the
  /// image, makes the correct thing the easy thing.
  final double opacity;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The palette rather than `Theme.brightnessOf`, because the palette is what
    // every other Mizan widget reads and it is the thing that actually crossfades
    // on a theme change.
    final image = Image.asset(
      icon.assetFor(MizanPalette.of(context).brightness),
      width: size,
      height: size,
      // The 1x, 2x and 3x cuts cover every common device ratio, so this only
      // matters on the odd 3.5x panel, where medium resampling keeps the gold
      // hairlines from crawling.
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
    );

    if (opacity >= 1.0) return image;
    return Opacity(opacity: opacity, child: image);
  }
}
