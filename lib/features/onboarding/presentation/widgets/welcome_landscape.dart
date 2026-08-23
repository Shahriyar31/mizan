/// The painted landscape behind the welcome lockup.
///
/// ── Why this is painted and not a bitmap ──────────────────────────────
/// Non-negotiable rule #2 allows **one image per screen**, and on the welcome
/// screen that one image is the Mizan glyph. The scenery is therefore drawn.
/// Three things fall out of that, all of them wanted:
///
///   1. It themes. The mockup's scene is cream-and-blue; a bundled PNG would
///      stay cream-and-blue on the navy page and look pasted on. Every colour
///      here resolves from [MizanPalette], so the dark theme gets the same
///      composition at night rather than a second asset to keep in sync.
///   2. It costs nothing. A full-bleed illustration at 3x is ~1–2 MB; this is
///      a few hundred bytes of path data that scales to any screen.
///   3. It is resolution-independent — no soft edges on a tablet.
///
/// ── Composition, and why it is built from *masses* ─────────────────────
/// The single most important property of the mockup, measured off it band by
/// band, is that the dark part of the scene is a narrow horizontal **belt**
/// between 0.55 and 0.78 of the height. Above it the page is almost pure cream
/// (mean luminance 212–249 out of 255); below it the page is cream again
/// (215–238) so the quote has clean paper to sit on.
///
/// An earlier version drew the foreground as ridge silhouettes — a curve closed
/// down to the bottom of the canvas. That is wrong by construction: a ridge
/// darkens everything below it, so the bottom third went muddy, the river
/// drowned, the foliage vanished into the bank it was drawn on, and a heavy
/// scrim had to be stacked on top to win the text back, which flattened the
/// whole lower half into a slab.
///
/// So the foreground here is **two bounded masses** — a left valley side and a
/// right one — each closed along a top *and* a bottom edge. The gap between
/// them is the lit corridor the river runs down, and the page below them is
/// untouched. Nothing needs to be covered up afterwards.
///
/// Back to front: sky wash, sun bloom on the horizon, three very pale far
/// ridges, a valley floor that resets the lower half to page brightness,
/// horizon mist, birds, the mosque on the right slope, the two valley masses,
/// the river, and a foliage spray at each outer edge of the belt.
///
/// Everything is expressed as a **fraction** of the canvas, so the scene
/// recomposes on any aspect ratio instead of cropping.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/mizan_tokens.dart';

class WelcomeLandscape extends StatelessWidget {
  const WelcomeLandscape({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _LandscapePainter(MizanPalette.of(context)),
        size: Size.infinite,
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter(this.p);

  final MizanPalette p;

  /// Where the ground meets the sky. Measured off the mockup: the dark belt
  /// begins at 0.55 and the sun sits just above it.
  static const double _horizon = 0.53;

  /// The sun's centre.
  static const double _sunX = 0.49;
  static const double _sunY = 0.515;

  @override
  void paint(Canvas canvas, Size size) {
    // ── The two colour families ───────────────────────────────────────
    // Distance is haze: far layers are the theme's blue at low alpha, near
    // layers are a silhouette at high alpha. One rule, both themes.
    //
    // On light, "silhouette" is the navy ink over a cream page — the classic
    // dark foreground. On dark the page is *already* the darkest thing on
    // screen, so the silhouette is the page colour itself, painted back over
    // the haze. That reads as a true cut-out in both cases without inventing a
    // shade that is not in the token set.
    final haze = p.link;
    final silhouette = p.isLight ? p.ink : p.page;

    _paintSky(canvas, size);
    _paintSunGlow(canvas, size);

    // ── Far ridges ───────────────────────────────────────────────────
    // Deliberately barely there. Sampling the mockup's mountain band gives a
    // mean of 212–228 against a 249 page — a difference of about 8%. Anything
    // stronger stops reading as distance and starts reading as terrain.
    _fill(canvas, _ridge(size, const [
      Offset(0.00, 0.330), Offset(0.13, 0.265), Offset(0.27, 0.350),
      Offset(0.41, 0.290), Offset(0.58, 0.365), Offset(0.74, 0.305),
      Offset(0.88, 0.360), Offset(1.00, 0.320),
    ]), haze.withValues(alpha: 0.09));

    _fill(canvas, _ridge(size, const [
      Offset(0.00, 0.425), Offset(0.10, 0.355), Offset(0.24, 0.440),
      Offset(0.38, 0.380), Offset(0.55, 0.450), Offset(0.71, 0.395),
      Offset(0.86, 0.455), Offset(1.00, 0.405),
    ]), haze.withValues(alpha: 0.14));

    _fill(canvas, _ridge(size, const [
      Offset(0.00, 0.495), Offset(0.16, 0.455), Offset(0.33, 0.510),
      Offset(0.50, 0.480), Offset(0.68, 0.515), Offset(0.85, 0.488),
      Offset(1.00, 0.518),
    ]), haze.withValues(alpha: 0.21));

    // ── Valley floor ─────────────────────────────────────────────────
    // The ridges above close down to the bottom of the canvas, which would
    // leave the lower half tinted with three stacked layers of haze. This
    // washes it back to page brightness, and *is* the sunlit valley floor the
    // river runs across.
    _paintValleyFloor(canvas, size);

    // A band of mist lying along the horizon, which is what makes the ridges
    // read as *behind* each other rather than merely stacked.
    _paintHorizonMist(canvas, size);

    _paintBirds(canvas, size, silhouette.withValues(alpha: 0.36));

    // ── Mosque ───────────────────────────────────────────────────────
    // On the right-hand slope, and paler than instinct suggests: the mockup's
    // mosque samples at roughly (95,127,130), which is the ink colour at about
    // half strength. It is a landmark in the haze, not a cut-out in the
    // foreground — the valley mass painted next is what it sits behind.
    _paintMosque(
      canvas,
      Rect.fromLTWH(
        size.width * 0.615,
        size.height * 0.438,
        size.width * 0.335,
        size.height * 0.150,
      ),
      silhouette.withValues(alpha: p.isLight ? 0.55 : 0.72),
    );

    // ── Valley masses ────────────────────────────────────────────────
    // The belt. Two per side: a paler outer shoulder and a darker inner one, so
    // the sides have depth without the whole thing going flat black.
    _paintMasses(canvas, size, silhouette);

    // ── River ────────────────────────────────────────────────────────
    // Painted after the masses, so its lit edge sits on top of the bank rather
    // than under it.
    _paintRiver(canvas, size);

    // ── Foliage ──────────────────────────────────────────────────────
    // Last, and the darkest thing in the scene — in the mockup the leaves
    // sample around (30,63,76), i.e. essentially solid ink. They read because
    // they overhang the *outer* edge of the belt where the page is still
    // bright, not because they are darker than the bank behind them.
    _paintFoliage(canvas, size, silhouette);
  }

  // ══════════════════════════════════════════════════════════════════
  //  LAYERS
  // ══════════════════════════════════════════════════════════════════

  /// A vertical wash: the page colour at the top, warming very slightly toward
  /// the horizon. The shift is deliberately small — this is a paper-coloured
  /// sky, not a sunset.
  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.page,
            Color.lerp(p.page, p.card, 0.55)!,
            Color.lerp(p.page, p.accent, p.isLight ? 0.09 : 0.06)!,
          ],
          stops: const [0.0, 0.30, _horizon],
        ).createShader(rect),
    );
  }

  /// The sun: a wide soft bloom with a bright core. Gold, as light — which is
  /// what gold is for in this palette. Trim, never text.
  void _paintSunGlow(Canvas canvas, Size size) {
    final centre = Offset(size.width * _sunX, size.height * _sunY);
    final bloom = size.width * 0.66;

    canvas.drawCircle(
      centre,
      bloom,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.accent.withValues(alpha: p.isLight ? 0.36 : 0.32),
            p.accent.withValues(alpha: p.isLight ? 0.13 : 0.12),
            p.accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.32, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: bloom)),
    );

    // The disc. In the mockup this is a distinct, clearly visible sun sitting on
    // the horizon, not a suggestion — so it gets a hard-ish inner core and a
    // short falloff rather than one long fade.
    //
    // Cream on light, gold on dark: on a navy page a cream disc is the
    // brightest possible thing on screen and reads as a moon; gold keeps it
    // a sun.
    final disc = size.width * 0.085;
    canvas.drawCircle(
      centre,
      disc,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (p.isLight ? p.card : p.accent).withValues(alpha: 0.97),
            (p.isLight ? p.card : p.accent).withValues(alpha: 0.85),
            (p.isLight ? p.card : p.accent).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: disc)),
    );
  }

  /// Washes the area below the horizon back to page brightness, undoing the
  /// stacked far-ridge haze and giving the river something lit to run across.
  void _paintValleyFloor(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      0,
      size.height * (_horizon - 0.02),
      size.width,
      size.height,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.page.withValues(alpha: 0.0),
            p.page.withValues(alpha: 0.72),
            p.page.withValues(alpha: 0.96),
          ],
          stops: const [0.0, 0.16, 0.46],
        ).createShader(rect),
    );
  }

  /// Horizontal haze lying on the horizon line.
  void _paintHorizonMist(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      size.height * (_horizon - 0.075),
      size.width,
      size.height * 0.16,
    );
    // On light, mist is the near-white card colour. On dark it is the theme's
    // pale blue — white haze on navy would grey the whole scene out.
    final tint = p.isLight ? p.card : p.link;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: 0.0),
            tint.withValues(alpha: p.isLight ? 0.70 : 0.20),
            tint.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(rect),
    );
  }

  /// The two valley sides that make up the dark belt.
  ///
  /// Each is a closed mass — top edge, then a bottom edge back to the outer
  /// screen edge — so the page below stays clean. Two per side: an outer
  /// shoulder at low alpha and an inner one, lower and darker, where the bank
  /// meets the water.
  void _paintMasses(Canvas canvas, Size size, Color silhouette) {
    final outer = silhouette.withValues(alpha: p.isLight ? 0.30 : 0.44);
    final inner = silhouette.withValues(alpha: p.isLight ? 0.46 : 0.58);

    // ── Left shoulder ──
    _fill(canvas, _mass(size,
      top: const [
        Offset(-0.03, 0.600), Offset(0.07, 0.568), Offset(0.16, 0.592),
        Offset(0.26, 0.638), Offset(0.35, 0.692), Offset(0.43, 0.752),
      ],
      bottom: const [
        Offset(0.42, 0.812), Offset(0.31, 0.800), Offset(0.19, 0.788),
        Offset(0.08, 0.792), Offset(-0.03, 0.806),
      ],
    ), outer);

    // ── Right shoulder ──
    _fill(canvas, _mass(size,
      top: const [
        Offset(1.03, 0.572), Offset(0.93, 0.556), Offset(0.83, 0.582),
        Offset(0.72, 0.612), Offset(0.62, 0.664), Offset(0.55, 0.726),
      ],
      bottom: const [
        Offset(0.57, 0.782), Offset(0.68, 0.806), Offset(0.80, 0.818),
        Offset(0.91, 0.812), Offset(1.03, 0.822),
      ],
    ), outer);

    // ── Left bank ──
    _fill(canvas, _mass(size,
      top: const [
        Offset(-0.03, 0.672), Offset(0.08, 0.652), Offset(0.18, 0.678),
        Offset(0.28, 0.716), Offset(0.37, 0.762), Offset(0.44, 0.806),
      ],
      bottom: const [
        Offset(0.43, 0.848), Offset(0.30, 0.836), Offset(0.17, 0.826),
        Offset(0.06, 0.830), Offset(-0.03, 0.842),
      ],
    ), inner);

    // ── Right bank ──
    _fill(canvas, _mass(size,
      top: const [
        Offset(1.03, 0.648), Offset(0.92, 0.632), Offset(0.81, 0.660),
        Offset(0.70, 0.698), Offset(0.61, 0.744), Offset(0.55, 0.790),
      ],
      bottom: const [
        Offset(0.56, 0.832), Offset(0.69, 0.848), Offset(0.81, 0.856),
        Offset(0.92, 0.850), Offset(1.03, 0.858),
      ],
    ), inner);
  }

  /// The river of light, running from under the sun down between the two banks.
  ///
  /// Built from a spine of (x, y, half-width) triples rather than two hand-drawn
  /// edges, so the taper stays symmetrical about the centreline and the bends
  /// cannot accidentally pinch shut.
  ///
  /// The centreline is traced off the mockup: it swings **left** to about 0.39
  /// around 0.625 of the height, back **right** to 0.54 by 0.68, then settles
  /// near centre. That double bend is the whole reason the water reads as
  /// distance rather than as a stripe. The half-widths stay small — the widest
  /// bright span measured is about a sixth of the screen, so half-width tops out
  /// near 0.085. It also **ends** around 0.82 rather than running off the bottom
  /// edge, because in the mockup the paper below the belt is clean.
  void _paintRiver(Canvas canvas, Size size) {
    const spine = <(double, double, double)>[
      (0.500, 0.545, 0.004),
      (0.487, 0.578, 0.010),
      (0.452, 0.606, 0.018),
      (0.402, 0.634, 0.026),
      (0.428, 0.658, 0.034),
      (0.500, 0.678, 0.042),
      (0.532, 0.702, 0.050),
      (0.516, 0.732, 0.062),
      (0.508, 0.768, 0.074),
      (0.505, 0.812, 0.085),
    ];

    final left = <Offset>[];
    final right = <Offset>[];
    for (final (x, y, half) in spine) {
      left.add(Offset((x - half) * size.width, y * size.height));
      right.add(Offset((x + half) * size.width, y * size.height));
    }

    // Down the left edge, then back up the right, and close. `extendWithPath`
    // joins the two with a line across the river's mouth at the bottom.
    final path = _smooth(left)
      ..extendWithPath(_smooth(right.reversed.toList()), Offset.zero)
      ..close();

    // The water is lit by the sun it flows from, so it is brightest at the top
    // and fades out at the bottom — fades to *nothing*, so there is no hard
    // edge where the ribbon stops.
    final rect = Rect.fromLTRB(
      0,
      size.height * 0.545,
      size.width,
      size.height * 0.82,
    );
    final lit = p.isLight ? p.card : p.accent;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(lit, p.accent, 0.50)!.withValues(alpha: 0.96),
            Color.lerp(lit, p.accent, 0.22)!
                .withValues(alpha: p.isLight ? 0.94 : 0.62),
            lit.withValues(alpha: p.isLight ? 0.70 : 0.34),
            lit.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.34, 0.74, 1.0],
        ).createShader(rect),
    );
  }

  /// Wall, raised centre block, onion dome, finial and two minarets. A pure
  /// silhouette — at this size any window or moulding turns into noise.
  ///
  /// The proportions matter more than the detail: a wide low wall, a *narrower
  /// raised block* for the dome to spring from, and a dome nearly as wide as
  /// that block. Springing the dome straight off the full-width wall is what
  /// makes a mosque silhouette read as a hat on a box.
  void _paintMosque(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    final cx = r.center.dx;

    // Low, wide base wall. Runs past the bottom of the rect so the valley mass
    // painted afterwards can bury the footing.
    path.addRect(Rect.fromLTRB(
      r.left + r.width * 0.14,
      r.top + r.height * 0.66,
      r.right - r.width * 0.14,
      r.bottom,
    ));

    // The raised centre the dome sits on.
    final blockTop = r.top + r.height * 0.46;
    path.addRect(Rect.fromLTRB(
      cx - r.width * 0.155,
      blockTop,
      cx + r.width * 0.155,
      r.bottom,
    ));

    // ── Onion dome ──
    // Springs from the centre block, wider than it at the haunch so it
    // overhangs — that overhang is the whole character of the shape.
    final domeW = r.width * 0.34;
    final domeBase = blockTop + r.height * 0.015;
    final domeTop = r.top + r.height * 0.115;
    final rise = domeBase - domeTop;
    path
      ..moveTo(cx - domeW / 2, domeBase)
      ..cubicTo(
        cx - domeW * 0.66, domeBase - rise * 0.34,
        cx - domeW * 0.42, domeTop + rise * 0.06,
        cx, domeTop,
      )
      ..cubicTo(
        cx + domeW * 0.42, domeTop + rise * 0.06,
        cx + domeW * 0.66, domeBase - rise * 0.34,
        cx + domeW / 2, domeBase,
      )
      ..close();

    // Finial: a short stem with a small ball, above the apex.
    final stem = r.height * 0.075;
    path
      ..addRect(Rect.fromLTRB(
        cx - r.width * 0.006,
        domeTop - stem,
        cx + r.width * 0.006,
        domeTop,
      ))
      ..addOval(Rect.fromCircle(
        center: Offset(cx, domeTop - stem),
        radius: r.width * 0.014,
      ));

    // ── Half-domes ──
    // A smaller dome either side of the centre block, springing off the wall.
    // The mockup shows a *cluster*, and one dome alone on a wall is the thing
    // that reads as a water tower.
    for (final side in const [-1.0, 1.0]) {
      final sx = cx + side * r.width * 0.235;
      final sw = r.width * 0.145;
      final sBase = r.top + r.height * 0.68;
      final sTop = r.top + r.height * 0.44;
      final sRise = sBase - sTop;
      path
        ..addRect(Rect.fromLTRB(sx - sw * 0.40, sBase - 2, sx + sw * 0.40, r.bottom))
        ..moveTo(sx - sw / 2, sBase)
        ..cubicTo(
          sx - sw * 0.64, sBase - sRise * 0.36,
          sx - sw * 0.40, sTop + sRise * 0.08,
          sx, sTop,
        )
        ..cubicTo(
          sx + sw * 0.40, sTop + sRise * 0.08,
          sx + sw * 0.64, sBase - sRise * 0.36,
          sx + sw / 2, sBase,
        )
        ..close();
    }

    // ── Minarets ──
    // Four, at staggered heights, all taller than the dome — that is the
    // mockup's skyline. They are the one place the silhouette is allowed to be
    // thin, because a minaret genuinely is.
    _minaret(path, r, atX: 0.045, heightFrac: 0.90, widthFrac: 0.026);
    _minaret(path, r, atX: 0.175, heightFrac: 1.06, widthFrac: 0.028);
    _minaret(path, r, atX: 0.835, heightFrac: 1.10, widthFrac: 0.029);
    _minaret(path, r, atX: 0.955, heightFrac: 0.94, widthFrac: 0.026);

    canvas.drawPath(path, paint);
  }

  /// One minaret, bottom to top: shaft, balcony, cap dome, spire.
  ///
  /// [heightFrac] is measured from the rect's bottom, so a minaret always
  /// reaches the ground no matter how tall it is — and may rise above the top of
  /// the rect, which is intended for the tall pair.
  void _minaret(
    Path path,
    Rect r, {
    required double atX,
    required double heightFrac,
    required double widthFrac,
  }) {
    final x = r.left + r.width * atX;
    final w = r.width * widthFrac;
    final top = r.bottom - r.height * heightFrac;

    // Cap dome: a squat half-oval, only slightly wider than the shaft. An oval
    // much wider than its shaft is what makes these read as lollipops.
    final capH = w * 1.30;
    path.addOval(
      Rect.fromLTRB(x - w * 0.66, top, x + w * 0.66, top + capH * 1.5),
    );

    // Balcony: a thin lip where the cap meets the shaft.
    path.addRect(Rect.fromLTRB(
      x - w * 0.86,
      top + capH,
      x + w * 0.86,
      top + capH * 1.30,
    ));

    // Shaft, from under the balcony to the ground.
    path.addRect(Rect.fromLTRB(x - w / 2, top + capH, x + w / 2, r.bottom));

    // Spire above the cap.
    path
      ..moveTo(x, top - w * 2.1)
      ..lineTo(x + w * 0.19, top + capH * 0.4)
      ..lineTo(x - w * 0.19, top + capH * 0.4)
      ..close();
  }

  /// Three birds, high on the right. Each is two short arcs — a filled shape at
  /// this size would just be a dot.
  ///
  /// Kept above 0.32 of the height and right of 0.70 of the width, which is the
  /// clear corner between the glyph and the screen edge. Lower down they would
  /// collide with the wordmark.
  void _paintBirds(Canvas canvas, Size size, Color color) {
    const birds = <(double, double, double)>[
      (0.745, 0.232, 1.00),
      (0.840, 0.268, 0.76),
      (0.786, 0.302, 0.60),
    ];
    final unit = size.width * 0.034;

    for (final (fx, fy, scale) in birds) {
      final c = Offset(fx * size.width, fy * size.height);
      final w = unit * scale;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.14).clamp(0.8, 2.0)
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - w, c.dy)
          ..quadraticBezierTo(c.dx - w * 0.45, c.dy - w * 0.60, c.dx, c.dy)
          ..quadraticBezierTo(c.dx + w * 0.45, c.dy - w * 0.60, c.dx + w, c.dy),
        paint,
      );
    }
  }

  /// A spray of leaves at each side of the belt — the mockup's framing device,
  /// and what stops the composition floating.
  ///
  /// Placement is measured, not guessed. Sampling the mockup across the belt
  /// gives its two darkest columns at x 0.00–0.18 and x 0.80–1.00, y 0.55–0.78,
  /// bottoming out around luminance 65 — near-solid ink. So each spray is
  /// rooted just **off** the screen edge inside the belt, and fans inward and
  /// upward across the belt's outer shoulder, where there is still bright page
  /// for it to be seen against.
  ///
  /// The left spray is the larger of the two, as in the mockup; the right one is
  /// smaller and higher so the pair is not a mirror.
  void _paintFoliage(Canvas canvas, Size size, Color silhouette) {
    // Solid, or as near as the theme allows. This is the darkest thing in the
    // scene and it needs to be, or it disappears into the bank.
    final paint = Paint()..color = silhouette.withValues(alpha: 0.94);

    // (root x, root y, unit length, mirrored?) per spray.
    const sprays = <(double, double, double, bool)>[
      (-0.05, 0.760, 0.30, false),
      (1.05, 0.735, 0.24, true),
    ];

    // (angle in turns clockwise from straight up, length, width) per leaf.
    // Angles fan from nearly-up to past horizontal so the spray opens like a
    // real frond cluster rather than a fan of identical blades.
    const leaves = <(double, double, double)>[
      (0.06, 1.00, 0.26),
      (0.13, 0.92, 0.25),
      (0.20, 0.80, 0.23),
      (0.27, 0.66, 0.21),
      (0.02, 0.74, 0.24),
      (0.34, 0.52, 0.19),
    ];

    for (final (rx, ry, unitFrac, mirror) in sprays) {
      final origin = Offset(rx * size.width, ry * size.height);
      final unit = size.width * unitFrac;

      for (final (turns, lengthFrac, widthFrac) in leaves) {
        final len = unit * lengthFrac;
        final wide = len * widthFrac;
        // Measured clockwise from straight up (negative y), then mirrored for
        // the right-hand spray so both fan *inward*.
        final a = turns * 2 * math.pi * (mirror ? -1 : 1);
        final dir = Offset(math.sin(a), -math.cos(a));
        final perp = Offset(-dir.dy, dir.dx);
        final tip = origin + dir * len;
        final mid = origin + dir * (len * 0.46);

        // A pointed leaf: two arcs from base to tip, bowed out either side.
        canvas.drawPath(
          Path()
            ..moveTo(origin.dx, origin.dy)
            ..quadraticBezierTo(
              mid.dx + perp.dx * wide, mid.dy + perp.dy * wide,
              tip.dx, tip.dy,
            )
            ..quadraticBezierTo(
              mid.dx - perp.dx * wide, mid.dy - perp.dy * wide,
              origin.dx, origin.dy,
            )
            ..close(),
          paint,
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  PATH HELPERS
  // ══════════════════════════════════════════════════════════════════

  void _fill(Canvas canvas, Path path, Color color) =>
      canvas.drawPath(path, Paint()..color = color);

  /// A closed mass: a smooth curve along [top], then a smooth curve along
  /// [bottom], joined and closed. Both lists are fractional.
  ///
  /// This is the shape the foreground is built from rather than [_ridge],
  /// because a mass has a bottom edge — see the note in the library doc for why
  /// that is the difference between a valley and a mud slide.
  Path _mass(Size size, {
    required List<Offset> top,
    required List<Offset> bottom,
  }) {
    Offset s(Offset o) => Offset(o.dx * size.width, o.dy * size.height);
    return _smooth([for (final o in top) s(o)])
      ..extendWithPath(_smooth([for (final o in bottom) s(o)]), Offset.zero)
      ..close();
  }

  /// A ridge silhouette: a smooth curve through [pts] (fractional), closed down
  /// to the bottom of the canvas.
  ///
  /// Only the far, very pale layers use this — see [_mass] for the foreground.
  ///
  /// The path runs a hair past both edges so that anti-aliasing on the closing
  /// verticals never leaves a pale seam at the screen edge.
  Path _ridge(Size size, List<Offset> pts) {
    final scaled = [
      for (final o in pts) Offset(o.dx * size.width, o.dy * size.height),
    ];
    final path = _smooth(scaled)
      ..lineTo(size.width + 2, scaled.last.dy)
      ..lineTo(size.width + 2, size.height + 2)
      ..lineTo(-2, size.height + 2)
      ..lineTo(-2, scaled.first.dy)
      ..close();
    return path;
  }

  /// An open path through [pts] using midpoint-quadratic smoothing: each point
  /// becomes a control point and the curve passes through the midpoints between
  /// them. Cheap, and it cannot overshoot the way a Catmull-Rom spline can —
  /// which matters here, because an overshooting ridge would poke above the one
  /// behind it.
  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length < 3) {
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// `MizanPalette.light`/`.dark` are const singletons, so this is an identity
  /// check that correctly says "no repaint" at rest. During a theme crossfade
  /// `lerp` produces a fresh instance each frame, which correctly says "yes".
  @override
  bool shouldRepaint(_LandscapePainter old) => old.p != p;
}
