/// MizanLogo — the brand lockup.
///
/// Three pieces, each usable alone:
///
///   [MizanMark]     the rounded tile with the book-and-scales artwork
///   [MizanWordmark] `MIZAN` in Playfair Display with wide tracking
///   [MizanTagline]  `LEARN · REFLECT · GROW`, gold dots, optional flanking rules
///   [MizanLogo]     all three stacked — the welcome-screen lockup
///
/// [MizanMark] and [MizanLogo] honour the user's icon choice from
/// Settings › Personalisation › App Icon. Pass an explicit `variant` to override
/// (the Settings chooser does this, to show both options at once).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/mizan_brand.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';

// ══════════════════════════════════════════════════════════════════════
//  MARK
// ══════════════════════════════════════════════════════════════════════

/// The app mark. Square, rounded, drawn from a bundled PNG at 1x/2x/3x.
class MizanMark extends ConsumerWidget {
  const MizanMark({super.key, this.size = 72, this.variant, this.shadow = false});

  final double size;

  /// Null → the user's choice, falling back to the theme-appropriate variant.
  final MizanLogoVariant? variant;

  /// Raise the tile off the page with the palette's rest shadow. Off by default:
  /// depth belongs to things you tap, and a logo is not a button.
  final bool shadow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final chosen = variant ??
        ref.watch(logoVariantProvider) ??
        MizanLogoVariant.forPalette(p);

    // The asset is a plain square; the rounding happens here so it stays crisp
    // at any size. See [mizanMarkRadiusRatio] for why the number is what it is.
    final radius = BorderRadius.circular(size * mizanMarkRadiusRatio);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ? p.restShadow : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          chosen.asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Mizan',
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  GLYPH
// ══════════════════════════════════════════════════════════════════════

/// The artwork with **no tile behind it**, sitting straight on the page.
///
/// Sized by [width], never by height, and the height is left to fall out of the
/// aspect ratio. The two masters are 0.914 and 0.933 of their width across the
/// book — a 2% difference, invisible — but their *heights* differ by 5%, because
/// only the cream-ink master carries the mihrab arch. Constraining the width
/// therefore keeps the book optically the same size in both themes; constraining
/// the height would visibly shrink the mark in the dark theme to make room for
/// the arch.
///
/// The ink follows the page, not the user's App Icon choice — see [MizanGlyphInk].
class MizanGlyph extends StatelessWidget {
  const MizanGlyph({super.key, this.width = 150});

  final double width;

  @override
  Widget build(BuildContext context) {
    final ink = MizanGlyphInk.forPalette(MizanPalette.of(context));
    return Image.asset(
      ink.asset,
      width: width,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Mizan',
    );
  }
}

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
        MizanMark(size: markSize, variant: variant),
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
        MizanMark(size: markSize, variant: variant),
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
