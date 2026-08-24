/// MizanLogo — the brand lockup.
///
/// Three pieces, each usable alone:
///
///   [MizanMark]     the rounded tile with the arch, calligraphy and open book
///   [MizanWordmark] `MIZAN` in Playfair Display with wide tracking
///   [MizanTagline]  `LEARN · REFLECT · GROW`, gold dots, optional flanking rules
///   [MizanLogo]     all three stacked — the welcome-screen lockup
///
/// [MizanMark] and [MizanLogo] honour the user's icon choice from
/// Settings › Personalisation › App Icon. Pass an explicit `variant` to override
/// (the Settings chooser does this, to show all five options at once).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/mizan_brand.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';

// ══════════════════════════════════════════════════════════════════════
//  MARK
// ══════════════════════════════════════════════════════════════════════

/// The app mark: the mihrab arch, `ميزان`, and the open book, on a coloured tile.
///
/// ── Sized by width, and only by width ─────────────────────────────────
/// The tiles are 900×1046, not square. Forcing them into a square box squashes
/// the book at the bottom of the mark, which is why this takes [width] and lets
/// the height fall out of [_aspect]. That is the asset README's third rule, and
/// it is also why the parameter is no longer called `size` — the old name
/// invited exactly the square box the artwork cannot survive.
///
/// ── And not clipped ───────────────────────────────────────────────────
/// The corners arrive already cut to transparency at the iOS squircle ratio. A
/// `ClipRRect` over that lays a second corner of a slightly different shape over
/// the first, and the two edges read as a visible double-rounded seam. The only
/// thing still using the ratio is the optional drop shadow, which needs a
/// silhouette to trace.
class MizanMark extends ConsumerWidget {
  const MizanMark({
    super.key,
    this.width = 72,
    this.variant,
    this.shadow = false,
  });

  /// The mark's width. Its height is `width / 0.8604`.
  final double width;

  /// Null → the user's choice, falling back to the theme-appropriate variant.
  final MizanLogoVariant? variant;

  /// Raise the tile off the page with the palette's rest shadow. Off by default:
  /// depth belongs to things you tap, and a logo is not a button.
  final bool shadow;

  /// 900 / 1046, the tiles' own aspect ratio.
  static const double _aspect = 0.8604;

  /// The height this mark will occupy at a given width — so callers laying out
  /// a fixed-height row do not have to re-derive the ratio.
  static double heightFor(double width) => width / _aspect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final chosen = variant ??
        ref.watch(logoVariantProvider) ??
        MizanLogoVariant.forPalette(p);

    final height = heightFor(width);

    // The masters are ~900px and the mark is drawn between 30 and 152. Decoded
    // at full size that is 3.8MB of RGBA per variant, and the Settings chooser
    // shows five at once. Decoding to the size actually needed keeps the cache in
    // the low hundreds of KB and gives a properly filtered downsample rather than
    // a 30:1 point-sample.
    final ratio = MediaQuery.devicePixelRatioOf(context);

    final image = Image.asset(
      chosen.asset,
      width: width,
      height: height,
      // contain, not cover: cover on an off-square box is the crop this widget
      // exists to prevent.
      fit: BoxFit.contain,
      cacheWidth: (width * ratio).round(),
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Mizan',
    );

    if (!shadow) return image;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * mizanMarkRadiusRatio),
        boxShadow: p.restShadow,
      ),
      child: image,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  GLYPH — withdrawn
// ══════════════════════════════════════════════════════════════════════
//
// There used to be a `MizanGlyph`: the artwork cut out on transparency, with no
// tile behind it, for placing straight on a page. The welcome screen used it.
//
// The new brand set has no such file. All five variants are *tiles* — the arch
// and calligraphy sit on a field colour, and the only transparency is the four
// rounded corners. Nothing here fakes the old cut-out, because the two ways to
// fake it both fail:
//
//   • Tinting or masking a tile cannot separate ink from field; the field is
//     opaque behind every stroke.
//   • Drawing the tile and calling it a glyph is not the same picture. It is a
//     tile, and pretending otherwise is how a widget name starts lying.
//
// So the welcome screen now shows [MizanMark] — the tile, honestly — and the
// decorative [MizanArch] it used to draw behind the cut-out is gone, because
// every one of the five tiles already has the arch in the artwork and two arches
// is one too many. If a true cut-out glyph is wanted later it needs new art, not
// new code.

// ══════════════════════════════════════════════════════════════════════
//  WORDMARK
// ══════════════════════════════════════════════════════════════════════

/// `MIZAN`. Playfair Display 600 with 0.22em tracking.
///
/// The trailing letter-space is trimmed — CSS `letter-spacing` and Flutter's
/// both add space *after* the final glyph, which visibly pushes a centred
/// wordmark left of true centre.
class MizanWordmark extends StatelessWidget {
  const MizanWordmark({super.key, this.fontSize = 34, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final style = MizanType.wordmark(
      color: color ?? p.ink,
      fontSize: fontSize,
    );
    return Padding(
      padding: EdgeInsets.only(left: style.letterSpacing ?? 0),
      child: Text('MIZAN', style: style, textAlign: TextAlign.center),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TAGLINE
// ══════════════════════════════════════════════════════════════════════

/// `LEARN · REFLECT · GROW` — three words, gold dot separators.
///
/// The dots are drawn, not typed. A `·` character inherits the text colour and
/// its size depends on the font; a small circle is gold at exactly the size the
/// brand sheet shows, in both themes.
class MizanTagline extends StatelessWidget {
  const MizanTagline({
    super.key,
    this.fontSize = 11,
    this.color,
    this.dotColor,
    this.withRules = false,
    this.ruleWidth = 28,
  });

  final double fontSize;
  final Color? color;
  final Color? dotColor;

  /// Flanking 1px gold rules, as on the welcome screen.
  final bool withRules;
  final double ruleWidth;

  static const _words = ['LEARN', 'REFLECT', 'GROW'];

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final textColor = color ?? p.muted;
    final dot = dotColor ?? p.accent;
    final style = MizanType.tagline(color: textColor, fontSize: fontSize);

    // Letter-spacing is added *after* every glyph, including the last one of
    // each word. That trailing space is invisible but real, so a naive layout
    // puts the dots off-centre and pushes the whole lockup left of true centre.
    // Every gap below subtracts it.
    final tracking = style.letterSpacing ?? 0;
    final gap = fontSize * 0.7;
    final dotSize = fontSize * 0.32;

    Widget rule() => Container(
          width: ruleWidth,
          height: MizanGeometry.hairlineWidth,
          color: dot.withValues(alpha: 0.55),
        );

    // Gap flanking the rules, wide enough that subtracting the tracking still
    // leaves a positive value.
    final ruleGap = fontSize * 1.1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (withRules) ...[rule(), SizedBox(width: ruleGap)],
        for (var i = 0; i < _words.length; i++) ...[
          if (i > 0) ...[
            SizedBox(width: gap),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            // Less on this side by exactly the previous word's trailing space.
            SizedBox(width: (gap - tracking).clamp(0.0, gap)),
          ],
          Text(_words[i], style: style),
        ],
        if (withRules) ...[
          SizedBox(width: (ruleGap - tracking).clamp(0.0, ruleGap)),
          rule(),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  FULL LOCKUP
// ══════════════════════════════════════════════════════════════════════

/// Mark over wordmark over tagline — the welcome screen lockup, and the header
/// of the About screen.
class MizanLogo extends StatelessWidget {
  const MizanLogo({
    super.key,
    this.markSize = 88,
    this.wordmarkSize = 34,
    this.variant,
    this.showTagline = true,
    this.taglineRules = false,
    this.color,
    this.taglineColor,
  });

  final double markSize;
  final double wordmarkSize;
  final MizanLogoVariant? variant;
  final bool showTagline;
  final bool taglineRules;

  /// Overrides the wordmark colour — needed when the lockup sits on a navy
  /// panel in the light theme, where [MizanPalette.ink] would be invisible.
  final Color? color;
  final Color? taglineColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MizanMark(width: markSize, variant: variant),
        SizedBox(height: markSize * 0.29),
        MizanWordmark(fontSize: wordmarkSize, color: color),
        if (showTagline) ...[
          SizedBox(height: wordmarkSize * 0.44),
          MizanTagline(color: taglineColor, withRules: taglineRules),
        ],
      ],
    );
  }
}

/// The lockup laid out horizontally: mark on the left, wordmark and tagline
/// stacked to its right. For app bars and the Settings account card.
class MizanLogoRow extends StatelessWidget {
  const MizanLogoRow({
    super.key,
    this.markSize = 44,
    this.wordmarkSize = 20,
    this.variant,
    this.showTagline = true,
    this.color,
    this.taglineColor,
  });

  final double markSize;
  final double wordmarkSize;
  final MizanLogoVariant? variant;
  final bool showTagline;
  final Color? color;
  final Color? taglineColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MizanMark(width: markSize, variant: variant),
        SizedBox(width: markSize * 0.32),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MizanWordmark(fontSize: wordmarkSize, color: color),
            if (showTagline) ...[
              SizedBox(height: wordmarkSize * 0.3),
              MizanTagline(fontSize: 9, color: taglineColor),
            ],
          ],
        ),
      ],
    );
  }
}
