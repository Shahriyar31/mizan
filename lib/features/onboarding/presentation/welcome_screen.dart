/// Welcome — the first thing a new user sees.
///
/// Built from the `Mizan Light.pdf` welcome mockup: a full-bleed painted valley,
/// the mark under a mihrab arch, the wordmark and tagline, an athar of Umar ibn
/// al-Khattab, and one primary action.
///
/// ── Notes on fidelity to the mockup ───────────────────────────────────
/// • The scenery is **painted**, not the mockup bitmap — see [WelcomeLandscape]
///   for why (rule #2, and so the dark theme gets a night valley for free).
/// • The mockup has a small grey-violet rounded square with an arrow floating
///   over the right edge, roughly two-thirds down. It is not on the token
///   palette, it overlaps the text block, and it duplicates the CTA below it, so
///   it is read as leftover chrome from the design tool and is not built.
/// • The mockup renders inside a phone frame with a notch. Real insets come from
///   [SafeArea], so the spacing below is measured from the safe area, not from
///   the mockup's pixel top.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/mizan_brand.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../../shared/widgets/mizan/mizan_logo.dart';
import '../domain/onboarding_flags.dart';
import 'widgets/welcome_landscape.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    return Scaffold(
      backgroundColor: p.page,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WelcomeLandscape(),

          // Legibility, not decoration. The text block and the CTA sit over the
          // near banks, which are near-solid ink; without this the quote would
          // be navy on navy. Fading to the page colour is also what the mockup
          // does — its bottom edge is clean cream.
          const _BottomScrim(),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The lockup sits high and the text block low, with the valley
                // visible between them. Flex rather than fixed gaps, so a short
                // screen compresses the empty middle instead of clipping the
                // quote.
                return Column(
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.045),
                    const _Lockup(),
                    const Spacer(),
                    const _Quote(),
                    SizedBox(height: constraints.maxHeight * 0.035),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MizanGeometry.gutter + 8,
                      ),
                      child: MizanButton(
                        label: 'Begin Your Journey',
                        trailingIcon: Icons.arrow_forward_rounded,
                        expand: true,
                        onPressed: () async {
                          await OnboardingFlags.markWelcomeSeen();
                          if (!context.mounted) return;
                          // `go`, not `push` — the welcome screen must not stay
                          // on the stack for the back button to return to.
                          context.go('/home');
                        },
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.035),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  LOCKUP
// ══════════════════════════════════════════════════════════════════════

class _Lockup extends StatelessWidget {
  const _Lockup();

  /// Width of the glyph. The mockup's mark is ~35% of the screen width; this is
  /// a fixed value instead so the lockup does not balloon on a tablet.
  static const double _glyphWidth = 152;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final ink = MizanGlyphInk.forPalette(p);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _glyphWidth * 1.62,
          height: _glyphWidth * 1.30,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // The cream-ink master already has the mihrab arch drawn into it;
              // adding a second one would double the lines in the dark theme.
              if (!ink.hasArch)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(top: _glyphWidth * 0.02),
                    child: MizanArch(
                      rings: 2,
                      opacity: 0.42,
                      color: p.accent,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(bottom: _glyphWidth * 0.03),
                child: const MizanGlyph(width: _glyphWidth),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const MizanWordmark(fontSize: 36),
        const SizedBox(height: 14),
        const MizanTagline(withRules: true, ruleWidth: 26),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  QUOTE
// ══════════════════════════════════════════════════════════════════════

class _Quote extends StatelessWidget {
  const _Quote();

  // TODO(citation): this athar needs a verified reference before release.
  // The wording is transcribed from the design mockup. It is widely attributed
  // to Umar ibn al-Khattab (رضي الله عنه) alongside "take account of yourselves
  // before you are taken to account", but a specific collection, volume and
  // page — plus a grading — has NOT been verified, so none is claimed here.
  // Do not invent one. Until it is sourced, this is the only unsourced text in
  // the app and it is on the very first screen, which is the worst place for it.
  static const _text = 'Weigh your deeds\nbefore they are weighed for you.';
  static const _attribution = '— Umar ibn al-Khattab';
  static const _honorific = 'رضي الله عنه';

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MizanGeometry.gutter + 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A drawn quote mark, not a typed one: two filled commas at a size and
          // colour we control. A `"` glyph would inherit the text colour and its
          // shape would change with the font.
          _QuoteGlyph(color: p.accent, size: 26),
          const SizedBox(height: 12),
          Text(
            _text,
            textAlign: TextAlign.center,
            // The translation role — Playfair italic. This is a transmitted
            // saying, not the app's own voice, and italic serif is exactly what
            // the type scale reserves for that.
            style: MizanType.translation(color: p.ink).copyWith(
              fontSize: 21,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          // Latin name and Arabic honorific on one line, so the honorific never
          // wraps onto a line of its own.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$_attribution ',
                  style: MizanType.body(color: p.muted).copyWith(fontSize: 14),
                ),
                TextSpan(
                  text: _honorific,
                  style: MizanType.arabic(color: p.muted, fontSize: 15)
                      // The Arabic role's 1.9 line-height exists for body
                      // Arabic; inside a mixed line it would push the Latin
                      // baseline down and open a gap above.
                      .copyWith(height: 1.0),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}

/// The opening quote mark: two teardrops. Drawn rather than typed — see the
/// note at the call site.
class _QuoteGlyph extends StatelessWidget {
  const _QuoteGlyph({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: CustomPaint(painter: _QuoteGlyphPainter(color)),
    );
  }
}

class _QuoteGlyphPainter extends CustomPainter {
  const _QuoteGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.height * 0.42;
    final gap = size.width * 0.20;

    for (final cx in [r, r * 2 + gap]) {
      // A comma: a disc with a tail pulled down and to the left.
      canvas.drawPath(
        Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, r), radius: r))
          ..moveTo(cx - r * 0.15, r * 1.2)
          ..quadraticBezierTo(
            cx + r * 0.35, r * 1.5,
            cx - r * 0.30, size.height,
          )
          ..quadraticBezierTo(
            cx - r * 0.60, r * 1.6,
            cx - r * 0.15, r * 1.2,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_QuoteGlyphPainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════════════════
//  SCRIM
// ══════════════════════════════════════════════════════════════════════

/// Lifts the lower half of the scene toward the page colour so the quote and
/// the CTA sit on something they can be read against.
///
/// ── On strength ───────────────────────────────────────────────────────
/// The first attempt ramped to 0.97 and erased the bottom 40% of the painting —
/// river, foliage and all — leaving a blank slab with text on it. The scrim is
/// now deliberately weak, and the *painting* does most of the work instead: the
/// near banks are held well below opaque, and the river widens to almost a
/// third of the screen exactly where the quote sits, so the text mostly falls on
/// lit water. The scrim only has to take the edge off the banks either side.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              p.page.withValues(alpha: 0.0),
              p.page.withValues(alpha: 0.16),
              p.page.withValues(alpha: 0.44),
              p.page.withValues(alpha: 0.62),
            ],
            stops: const [0.56, 0.72, 0.88, 1.0],
          ),
        ),
      ),
    );
  }
}
