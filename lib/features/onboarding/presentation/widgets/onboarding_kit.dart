/// The onboarding flow's own small design kit.
///
/// ── Why this is not `MizanPalette` ────────────────────────────────────
/// The welcome flow is dark only. It ignores the system colour scheme and the
/// theme setting, because it runs before the person has one — theme resolution
/// begins on the first app screen after it. Reading colours through
/// `MizanPalette.of(context)` would work (the flow wraps itself in
/// `MizanTheme.dark`), but the flow's spec pins exact values for a dozen fills
/// and hairlines that have no name in the app palette — `rgba(216,180,90,.26)`,
/// `rgba(78,140,166,.10)`, and so on. Naming them here, once, with the spec's
/// own rgba() written beside each, makes the flow auditable against the brief
/// line by line. That is worth one small local token set.
///
/// The token table below is the entire palette. Nothing in this flow may
/// introduce a colour that is not on it.
///
/// ── Why the type is built here ────────────────────────────────────────
/// [MizanType] is a deliberate six-role scale, and its own doc comment says a
/// screen wanting an off-scale size should use the nearest role rather than
/// invent one. The welcome flow is the one place that legitimately breaks that
/// rule: it is a poster, not a screen, and its brief specifies fourteen exact
/// sizes from 9.5 to 42. Building them here keeps them out of the app scale
/// where they would licence drift on every other screen.
///
/// ── Fonts ─────────────────────────────────────────────────────────────
/// All three families are bundled TTFs declared in `pubspec.yaml`, so this flow
/// renders identically with the network disconnected — which the brief requires
/// and which matters more here than anywhere else in the app, because this flow
/// *is* first launch. It previously called `google_fonts`, which fetches on
/// first use: the very first person to open Mizan on a phone with no signal saw
/// the whole poster in the platform sans.
///
/// The family strings are taken from [MizanType] rather than written out again,
/// so a rename in `pubspec.yaml` has one place to follow.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/mizan_typography.dart';

import '../../../../shared/widgets/mizan/mizan_pressable.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Tokens
// ═══════════════════════════════════════════════════════════════════════════

abstract final class OnbTok {
  /// Background, and the label on the gold button.
  static const ink = Color(0xFF0A2233);

  /// Edge hairline.
  static const inkLine = Color(0xFF1A3A4A);

  /// Panel fill — rgba(243,237,224,.05)
  static const card = Color(0x0DF3EDE0);

  /// Panel border — rgba(216,180,90,.26)
  static const cardLine = Color(0x42D8B45A);

  /// The mark, the pattern, the arches, the eyebrows, the primary button.
  static const gold = Color(0xFFD8B45A);

  /// Headlines and body.
  static const paper = Color(0xFFF3EDE0);

  /// Secondary text on panels.
  static const mist = Color(0xFFC6D4DB);

  /// Helper text, Skip, inactive.
  static const mistDim = Color(0xFFA9BFC9);

  /// The blue used only by the notification note. Not a new colour: it is the
  /// same `#4E8CA6` the app palette already calls `link`.
  static const blue = Color(0xFF4E8CA6);

  // ── Gold at the alphas the brief names ────────────────────────────────
  static const gold03 = Color(0x08D8B45A); // rgba(216,180,90,.03)
  static const gold08 = Color(0x14D8B45A); // rgba(216,180,90,.08)
  static const gold13 = Color(0x21D8B45A); // rgba(216,180,90,.13)
  static const gold15 = Color(0x26D8B45A); // rgba(216,180,90,.15)
  static const gold16 = Color(0x29D8B45A); // rgba(216,180,90,.16)
  static const gold22 = Color(0x38D8B45A); // rgba(216,180,90,.22)
  static const gold24 = Color(0x3DD8B45A); // rgba(216,180,90,.24)
  static const gold28 = Color(0x47D8B45A); // rgba(216,180,90,.28)
  static const gold30 = Color(0x4DD8B45A); // rgba(216,180,90,.30)
  static const gold32 = Color(0x52D8B45A); // rgba(216,180,90,.32)
  static const gold45 = Color(0x73D8B45A); // rgba(216,180,90,.45)
  static const gold50 = Color(0x80D8B45A); // rgba(216,180,90,.5)

  // ── Paper at the alphas the brief names ───────────────────────────────
  static const paper025 = Color(0x06F3EDE0); // rgba(243,237,224,.025)
  static const paper045 = Color(0x0BF3EDE0); // rgba(243,237,224,.045)

  // ── The notification note ─────────────────────────────────────────────
  static const blue10 = Color(0x1A4E8CA6); // rgba(78,140,166,.10)
  static const blue30 = Color(0x4D4E8CA6); // rgba(78,140,166,.3)

  // ── Geometry ──────────────────────────────────────────────────────────

  /// Horizontal gutter for the step-dot row, content and footer.
  ///
  /// The brief pins 24 for the dot row and 32 for the welcome screen's centred
  /// column, and leaves the middle screens unstated. 24 is used throughout so
  /// the dots, the panels and the button share one left edge — on a 390pt frame
  /// a panel inset further than its own progress indicator reads as a mistake.
  static const double gutter = 24;

  /// Clearance below the primary button. This is exactly the iOS home-indicator
  /// inset, which is why the reference frame uses it: on a device that actually
  /// has an indicator the safe area supplies the same 34 and no more is needed.
  static const double bottomClearance = 34;

  static const double buttonHeight = 52;

  /// Radius on every pill: button, step dot, live chip.
  static const double pill = 999;
}

// ═══════════════════════════════════════════════════════════════════════════
// Type
// ═══════════════════════════════════════════════════════════════════════════

abstract final class OnbType {
  /// MIZAN — Playfair 600 · 42 · .2em
  static TextStyle wordmark() => const TextStyle(
        fontFamily: MizanType.serifFamily,
        color: OnbTok.paper,
        fontSize: 42,
        fontWeight: FontWeight.w600,
        letterSpacing: 42 * 0.2,
        height: 1.1,
      );

  /// LEARN · REFLECT · GROW — DM Sans · 9.5 · .32em uppercase gold
  static TextStyle tagline() => const TextStyle(
        fontFamily: MizanType.sansFamily,
        color: OnbTok.gold,
        fontSize: 9.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 9.5 * 0.32,
        height: 1.2,
      );

  /// Screen heading — Playfair 600 · 31/1.15
  static TextStyle heading() => const TextStyle(
        fontFamily: MizanType.serifFamily,
        color: OnbTok.paper,
        fontSize: 31,
        fontWeight: FontWeight.w600,
        height: 1.15,
      );

  /// Eyebrow — DM Sans 700 · 10 · .16em uppercase gold
  static TextStyle eyebrow() => const TextStyle(
        fontFamily: MizanType.sansFamily,
        color: OnbTok.gold,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 10 * 0.16,
        height: 1.3,
      );

  /// The welcome screen's English quote — Playfair italic · 21/1.45
  static TextStyle quoteLarge() => const TextStyle(
        fontFamily: MizanType.serifFamily,
        color: OnbTok.paper,
        fontSize: 21,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.45,
      );

  /// A translation or a focused room's description — Playfair italic.
  static TextStyle quote({double fontSize = 15.5, Color? color}) =>
      TextStyle(
        fontFamily: MizanType.serifFamily,
        color: color ?? OnbTok.mist,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.4,
      );

  /// Arabic — Amiri. Bundled, so it never waits on the network.
  static TextStyle arabic({double fontSize = 22, double height = 2.0}) =>
      TextStyle(
        fontFamily: MizanType.arabicFamily,
        color: OnbTok.paper,
        fontSize: fontSize,
        height: height,
      );

  /// Body and helper prose — DM Sans.
  static TextStyle sans({
    double fontSize = 13.5,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.55,
  }) =>
      TextStyle(
        fontFamily: MizanType.sansFamily,
        color: color ?? OnbTok.mist,
        fontSize: fontSize,
        fontWeight: weight,
        height: height,
      );

  /// The gold button's label — DM Sans 700 · 15.5, in ink.
  static TextStyle buttonLabel() => const TextStyle(
        fontFamily: MizanType.sansFamily,
        color: OnbTok.ink,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  /// A numeral on a rhythm card — Playfair 600 · 23.
  static TextStyle numeral({Color? color}) => TextStyle(
        fontFamily: MizanType.serifFamily,
        color: color ?? OnbTok.paper,
        fontSize: 23,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// The girih background
// ═══════════════════════════════════════════════════════════════════════════

/// The one pattern in the flow, tiled from a single 60×60 cell.
///
/// ── Why the fade is a mask and not an opacity ─────────────────────────
/// Dropping the whole pattern to 22% and calling it done gives a flat grey
/// wash: every line is equally faint, including the ones at the bottom of the
/// screen behind the headline and the button, where they compete with text.
/// A vertical mask instead lets the pattern be fully itself at the top edge and
/// genuinely gone by a third of the way down, so it reads as light falling on a
/// surface rather than as a texture someone turned down. Implemented as a
/// [ShaderMask] in `dstIn`, which is the exact equivalent of the brief's SVG
/// `<mask>` over a filled rect.
class GirihBackground extends StatelessWidget {
  const GirihBackground({super.key, this.khatam = false});

  /// The welcome screen's denser variant: the same three paths plus corner
  /// diagonals, and a longer, stronger fade.
  final bool khatam;

  @override
  Widget build(BuildContext context) {
    // white .34 → .12 → 0   |   white .22 → 0
    final gradient = khatam
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x57FFFFFF), // .34
              Color(0x1FFFFFFF), // .12
              Color(0x00FFFFFF),
            ],
            stops: [0.0, 0.36, 0.64],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x38FFFFFF), // .22
              Color(0x00FFFFFF),
            ],
            stops: [0.0, 0.30],
          );

    return IgnorePointer(
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => gradient.createShader(rect),
          child: CustomPaint(
            painter: _GirihPainter(khatam: khatam),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _GirihPainter extends CustomPainter {
  _GirihPainter({required this.khatam});

  final bool khatam;

  static const double _cell = 60;

  /// One cell, built once and reused for every tile. Building 200 Paths per
  /// frame would be the expensive part of this widget; translating one is not.
  static final Path _base = _buildBase(corners: false);
  static final Path _baseWithCorners = _buildBase(corners: true);

  static Path _buildBase({required bool corners}) {
    final p = Path();

    // Octagon: M17.6 0 H42.4 L60 17.6 V42.4 L42.4 60 H17.6 L0 42.4 V17.6 Z
    p.moveTo(17.6, 0);
    p.lineTo(42.4, 0);
    p.lineTo(60, 17.6);
    p.lineTo(60, 42.4);
    p.lineTo(42.4, 60);
    p.lineTo(17.6, 60);
    p.lineTo(0, 42.4);
    p.lineTo(0, 17.6);
    p.close();

    // Star: M30 9 L51 30 L30 51 L9 30 Z
    p.moveTo(30, 9);
    p.lineTo(51, 30);
    p.lineTo(30, 51);
    p.lineTo(9, 30);
    p.close();

    // Square: M15 15 H45 V45 H15 Z
    p.addRect(const Rect.fromLTWH(15, 15, 30, 30));

    if (corners) {
      // M0 0 L9 9  M60 0 L51 9  M0 60 L9 51  M60 60 L51 51
      p.moveTo(0, 0);
      p.lineTo(9, 9);
      p.moveTo(60, 0);
      p.lineTo(51, 9);
      p.moveTo(0, 60);
      p.lineTo(9, 51);
      p.moveTo(60, 60);
      p.lineTo(51, 51);
    }

    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = khatam ? _baseWithCorners : _base;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      // The khatam lattice is denser, so the brief drops it to .6 to keep the
      // total ink on the screen the same.
      ..color = khatam ? OnbTok.gold.withValues(alpha: 0.6) : OnbTok.gold;

    // Only the masked band is worth painting. The girih fade reaches zero at
    // 30% of the height and the khatam at 64%, so everything below that is
    // invisible by construction and tiling it would be pure cost.
    final visibleHeight = size.height * (khatam ? 0.66 : 0.32);
    final rows = (visibleHeight / _cell).ceil();
    final cols = (size.width / _cell).ceil();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, visibleHeight));
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.save();
        canvas.translate(col * _cell, row * _cell);
        canvas.drawPath(cell, paint);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GirihPainter old) => old.khatam != khatam;
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared chrome
// ═══════════════════════════════════════════════════════════════════════════

/// Step dots and Skip. Decorative to look at, announced properly to a screen
/// reader: four unlabelled dots tell a blind user nothing, so the row carries
/// "Step 2 of 4" and the dots themselves are excluded.
class OnbStepRow extends StatelessWidget {
  const OnbStepRow({
    super.key,
    required this.step,
    required this.total,
    required this.onSkip,
  });

  final int step;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: OnbTok.gutter,
        right: OnbTok.gutter,
        top: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: 'Step $step of $total',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 1; i <= total; i++)
                    Padding(
                      padding: EdgeInsets.only(right: i == total ? 0 : 6),
                      child: Container(
                        width: i == step ? 20 : 7,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == step ? OnbTok.gold : OnbTok.gold32,
                          borderRadius:
                              BorderRadius.circular(OnbTok.pill),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // A 13px word needs a 44px target around it, so the tap area is
          // padded rather than the label made bigger.
          MizanPressable(
            onTap: onSkip,
            fill: Colors.transparent,
            shadowsEnabled: false,
            borderRadius: BorderRadius.circular(OnbTok.pill),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            semanticLabel: 'Skip onboarding',
            child: Text(
              'Skip',
              style: OnbType.sans(fontSize: 13, color: OnbTok.mistDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small uppercase gold line above a heading.
class OnbEyebrow extends StatelessWidget {
  const OnbEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: OnbType.eyebrow());
}

/// The gold pill. One per screen, at the bottom, with the arrow.
///
/// Built on [MizanPressable] rather than reimplemented, so the press feels
/// exactly like every other button in Mizan: the inner-blur shadow trick, the
/// Android ripple substitution and the 1px nudge all come for free. The brief's
/// rest shadow is `rgba(0,0,0,.5)` and the app token is `.45`; the five points
/// are left alone, because a button in the welcome flow that feels different
/// from a button in the app is a worse outcome than a shadow alpha two
/// hundredths off a mockup.
class OnbPrimaryButton extends StatelessWidget {
  const OnbPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: OnbTok.buttonHeight,
      width: double.infinity,
      child: MizanPressable(
        onTap: onTap,
        fill: OnbTok.gold,
        borderRadius: BorderRadius.circular(OnbTok.pill),
        semanticLabel: label,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: OnbType.buttonLabel()),
              if (showArrow) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18, color: OnbTok.ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The quieter line under a primary button — "Begin without reminders",
/// "Already have an account? Sign in".
///
/// [emphasis] is the tail of the sentence that carries the action, drawn in
/// gold 600. Splitting it out rather than passing a RichText keeps the 44px
/// tap target around the *whole* line, which is what someone actually aims at.
class OnbQuietButton extends StatelessWidget {
  const OnbQuietButton({
    super.key,
    required this.label,
    this.emphasis,
    required this.onTap,
  });

  final String label;
  final String? emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = OnbType.sans(fontSize: 13, color: OnbTok.mistDim);
    return Center(
      child: MizanPressable(
        onTap: onTap,
        fill: Colors.transparent,
        shadowsEnabled: false,
        borderRadius: BorderRadius.circular(OnbTok.pill),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        semanticLabel: emphasis == null ? label : '$label $emphasis',
        child: Text.rich(
          TextSpan(
            text: label,
            style: base,
            children: [
              if (emphasis != null)
                TextSpan(
                  text: emphasis,
                  style: base.copyWith(
                    color: OnbTok.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The shell every screen after Welcome shares.
///
/// ── Why the middle region flexes ──────────────────────────────────────
/// The reference frame is 390×844 but the flow has to survive 360×640 through
/// 430×932 — a 292pt swing in height. Fixed vertical offsets would put the
/// button off the bottom of a 640pt phone and leave a hole on a 932pt one. So
/// the chrome and the footer are `flex: none` at their natural height and
/// everything between them is one [Expanded]: the content settles wherever
/// there is room, and the button keeps its 34pt clearance on every frame.
///
/// ── Why the middle region can scroll, when the brief says it must not ──
/// It cannot scroll on any frame where the content fits, which includes the
/// reference frame and everything taller. The scroll view exists for 360×640,
/// where four screens' fixed content lands within about twenty points of the
/// available height — close enough that a font falling back to the platform
/// sans, or a system text-size bump, tips it over. The choice there is between
/// a few points of scroll and a yellow-and-black overflow stripe across the
/// panel, and the brief's intent is plainly the former. A `minHeight` equal to
/// the available height keeps `MainAxisAlignment.center` meaningful, so on every
/// normal phone this behaves exactly as if it were a plain centred column.
class OnbScaffold extends StatelessWidget {
  const OnbScaffold({
    super.key,
    this.step,
    this.total = 4,
    this.onSkip,
    required this.child,
    required this.footer,
    this.khatam = false,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: OnbTok.gutter),
    this.background,
  });

  /// Null on Welcome and Sign in — the two screens that carry no progress.
  final int? step;
  final int total;
  final VoidCallback? onSkip;

  /// Should be a [Column] with `mainAxisAlignment: MainAxisAlignment.center`.
  final Widget child;

  /// The button, and anything quiet beneath it.
  final Widget footer;

  final bool khatam;
  final EdgeInsetsGeometry contentPadding;

  /// Anything that belongs behind the content but in front of the pattern —
  /// the welcome screen's arches and horizon glow.
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    // 34 on the reference frame; more only on a device whose own inset demands
    // it, never less.
    final bottom = viewPadding.bottom > OnbTok.bottomClearance
        ? viewPadding.bottom
        : OnbTok.bottomClearance;

    return ColoredBox(
      color: OnbTok.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GirihBackground(khatam: khatam),
          if (background != null) background!,
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (step != null && onSkip != null)
                  OnbStepRow(step: step!, total: total, onSkip: onSkip!),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: contentPadding,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              contentPadding.vertical,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: OnbTok.gutter,
                    right: OnbTok.gutter,
                    bottom: bottom,
                  ),
                  child: footer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
