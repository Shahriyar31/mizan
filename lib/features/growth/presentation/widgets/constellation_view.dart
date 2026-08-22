/// ConstellationView — the night sky at the heart of the Growth Map.
///
/// Draws the four areas of practice as four small constellations laid out in a
/// 2×2 sky. Each constellation's stars light up as the user's real numbers
/// cross the milestone thresholds defined in [GrowthConstellation]. Lit stars
/// glow and twinkle gently; unlit ones are faint rings — a picture of what is
/// still to come. A field of tiny background stars gives the sky depth even
/// before anything is earned.
///
/// The twinkle is deliberately slow and low-amplitude: this screen is meant to
/// feel calm, not busy.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/growth_map_models.dart';

class ConstellationView extends StatefulWidget {
  const ConstellationView({
    super.key,
    required this.constellations,
    this.height = 300,
  });

  /// Expected in display order: quran, vocabulary, reflection, discover
  /// (i.e. the order [buildGrowthMap] returns). Each maps to one sky quadrant.
  final List<GrowthConstellation> constellations;
  final double height;

  @override
  State<ConstellationView> createState() => _ConstellationViewState();
}

class _ConstellationViewState extends State<ConstellationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // A fixed field of faint background stars. Generated once with a constant
  // seed so the sky is stable across rebuilds (it must not reshuffle when the
  // widget repaints).
  late final List<_BgStar> _bgStars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    final rng = math.Random(7);
    _bgStars = List.generate(54, (_) {
      return _BgStar(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: 0.4 + rng.nextDouble() * 1.1,
        phase: rng.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _SkyPainter(
                constellations: widget.constellations,
                bgStars: _bgStars,
                t: _controller.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _BgStar {
  const _BgStar({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phase,
  });
  final double dx;
  final double dy;
  final double radius;
  final double phase;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.constellations,
    required this.bgStars,
    required this.t,
  });

  final List<GrowthConstellation> constellations;
  final List<_BgStar> bgStars;
  final double t; // 0..1 animation phase

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintBackgroundStars(canvas, size);

    // 2×2 grid of constellation boxes.
    const pad = 14.0;
    const gap = 10.0;
    final cellW = (size.width - pad * 2 - gap) / 2;
    final cellH = (size.height - pad * 2 - gap) / 2;

    for (var i = 0; i < constellations.length && i < 4; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final origin = Offset(
        pad + col * (cellW + gap),
        pad + row * (cellH + gap),
      );
      _paintConstellation(
        canvas,
        constellations[i],
        origin,
        Size(cellW, cellH),
      );
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    // A soft radial lift from the centre — keeps the sky from feeling flat
    // without competing with the app's night background.
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          AppColors.slate.withValues(alpha: 0.55),
          AppColors.night.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintBackgroundStars(Canvas canvas, Size size) {
    for (final s in bgStars) {
      final tw = _twinkle(s.phase);
      final paint = Paint()
        ..color = AppColors.textSecondary
            .withValues(alpha: 0.10 + 0.18 * tw);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.radius * (0.85 + 0.3 * tw),
        paint,
      );
    }
  }

  void _paintConstellation(
    Canvas canvas,
    GrowthConstellation c,
    Offset origin,
    Size box,
  ) {
    Offset posOf(int i) {
      final star = c.stars[i];
      return origin + Offset(star.dx * box.width, star.dy * box.height);
    }

    // ── Connecting lines (drawn first, under the stars) ──
    for (final link in c.links) {
      final a = link[0];
      final b = link[1];
      final bothLit = c.isLit(a) && c.isLit(b);
      final linePaint = Paint()
        ..strokeWidth = bothLit ? 1.3 : 1.0
        ..color = bothLit
            ? c.color.withValues(alpha: 0.38)
            : AppColors.border.withValues(alpha: 0.28);
      canvas.drawLine(posOf(a), posOf(b), linePaint);
    }

    // ── Stars ──
    for (var i = 0; i < c.stars.length; i++) {
      final center = posOf(i);
      if (c.isLit(i)) {
        final tw = _twinkle(i * 0.17);
        // Colored glow halo.
        final glow = Paint()
          ..color = c.color.withValues(alpha: 0.22 + 0.16 * tw)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(center, 6.5 + 1.5 * tw, glow);
        // Colored mid.
        canvas.drawCircle(
          center,
          3.6,
          Paint()..color = c.color.withValues(alpha: 0.9),
        );
        // Bright core.
        canvas.drawCircle(
          center,
          1.8 + 0.4 * tw,
          Paint()..color = AppColors.goldPale,
        );
      } else {
        // A faint ring — a star waiting to be earned.
        canvas.drawCircle(
          center,
          2.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = AppColors.muted.withValues(alpha: 0.35),
        );
      }
    }

    // ── Area label along the bottom of the box ──
    final tp = TextPainter(
      text: TextSpan(
        text: c.name.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: c.color.withValues(alpha: c.litCount > 0 ? 0.75 : 0.4),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: box.width);
    tp.paint(
      canvas,
      Offset(
        origin.dx + (box.width - tp.width) / 2,
        origin.dy + box.height - tp.height - 2,
      ),
    );
  }

  /// A slow sinusoidal twinkle in [0,1], offset by [phase] (0..1).
  double _twinkle(double phase) {
    return 0.5 + 0.5 * math.sin(2 * math.pi * (t + phase));
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => true;
}
