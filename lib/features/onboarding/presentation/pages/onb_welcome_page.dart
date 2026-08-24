/// Screen 1 of 6 — Welcome.
///
/// The mark, the name, the verse. No step dots and no Skip: there is nothing
/// yet to skip, and a progress indicator on a title page tells somebody they
/// are in a process before they have agreed to be in one.
///
/// ── The one animation in the whole flow ───────────────────────────────
/// The horizon glow breathes, over seven seconds, and nothing else in these six
/// screens moves. That is deliberate on both counts. One slow thing on an
/// otherwise still page reads as depth; a page where the pattern drifts and the
/// text staggers in and the arches parallax reads as a screensaver, and the
/// verse stops being the thing you look at. Seven seconds is slow enough that
/// you notice it only if you stop and watch.
library;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/mizan/mizan_logo.dart';
import '../widgets/onboarding_kit.dart';

class OnbWelcomePage extends StatefulWidget {
  const OnbWelcomePage({
    super.key,
    required this.onBegin,
    required this.onSignIn,
  });

  final VoidCallback onBegin;

  /// Straight to the sign-in screen. Somebody reinstalling the app on a new
  /// phone should not have to walk five explanatory screens to reach their own
  /// account.
  final VoidCallback onSignIn;

  @override
  State<OnbWelcomePage> createState() => _OnbWelcomePageState();
}

class _OnbWelcomePageState extends State<OnbWelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  late final Animation<double> _glowOpacity = Tween<double>(
    begin: 0.42,
    end: 0.9,
  ).animate(CurvedAnimation(parent: _glow, curve: Curves.easeInOut));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion removes the animation and pins the glow at .7 — the middle
    // of its range, so the composition still has its light source. Merely
    // shortening the duration would keep the pulsing, which is the thing the
    // setting is asking us not to do.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      if (_started) {
        _glow.stop();
        _started = false;
      }
      return;
    }
    if (!_started) {
      _started = true;
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return OnbScaffold(
      khatam: true,
      contentPadding: const EdgeInsets.only(left: 32, right: 32, top: 64),
      background: _WelcomeBackdrop(
        glow: reduceMotion
            ? const AlwaysStoppedAnimation<double>(0.7)
            : _glowOpacity,
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnbPrimaryButton(
            label: 'Begin your journey',
            onTap: widget.onBegin,
          ),
          const SizedBox(height: 18),
          OnbQuietButton(
            label: 'Already have an account? ',
            emphasis: 'Sign in',
            onTap: widget.onSignIn,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The real app mark, at the brief's 76.
          //
          // The brief reconstructs the mark as five inline SVG paths, and also
          // exempts the app mark from its own no-images rule. Both readings
          // point the same way here: Mizan has exactly one mark, it is an
          // asset, and the person chose which colour of it sits on their home
          // screen. Drawing a second one from paths would put a mark on the
          // welcome screen that exists nowhere else in the app — and the icon
          // set was consolidated to one on purpose.
          const MizanMark(width: 76),

          const SizedBox(height: 24),
          const _Wordmark(),

          const SizedBox(height: 12),
          Text('LEARN · REFLECT · GROW', style: OnbType.tagline()),

          const SizedBox(height: 40),
          Container(width: 52, height: 1, color: OnbTok.gold50),

          const SizedBox(height: 34),
          Text(
            'وَزِنُوا أَعْمَالَكُمْ قَبْلَ أَنْ تُوزَنَ عَلَيْكُم',
            style: OnbType.arabic(fontSize: 23, height: 1.95),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),

          const SizedBox(height: 20),
          // 272 is the brief's measure. It exists to force the break after
          // "before they are" so the line lands on "weighed for you" — the half
          // of the sentence that carries the weight.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 272),
            child: Text(
              'Weigh your deeds before they are weighed for you.',
              style: OnbType.quoteLarge(),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Umar ibn al-Khattab رضي الله عنه',
            style: OnbType.sans(fontSize: 12.5, color: OnbTok.mist),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// MIZAN, tracked out to .2em.
///
/// Letter-spacing is applied *after* every glyph including the last, so a
/// centred tracked word sits half a letter-space left of true centre — 4.2pt
/// here, which is visible against a centred column. CSS fixes this with
/// `text-indent: .2em`; the same correction in Flutter is a left pad of one
/// full letter-space, which pushes the optical centre back where it belongs.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    const track = 42 * 0.2;
    return Padding(
      padding: const EdgeInsets.only(left: track),
      child: Text(
        'MIZAN',
        style: OnbType.wordmark(),
        semanticsLabel: 'Mizan',
      ),
    );
  }
}

/// Two nested mihrab arches and the horizon glow beneath them.
///
/// Both arches are open at the bottom — the brief's `border-bottom: none` — so
/// they read as an architectural opening rather than as two stacked lozenges.
/// The radius is always exactly half the width, which is what makes the top a
/// true semicircle and not a rounded rectangle.
///
/// ── Why a painter and not a Container ─────────────────────────────────
/// `BoxDecoration` asserts that a border with different sides cannot also have
/// a border radius, so a three-sided rounded arch is not expressible as a
/// decoration at all. One short painter is the honest answer.
class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop({required this.glow});

  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;

            // The brief pins these against its 390×844 frame. Held as fractions
            // of that frame so the composition keeps its proportions on a 640pt
            // phone instead of sliding the glow up into the verse.
            final outerTop = h * (210 / 844);
            final innerTop = h * (262 / 844);
            final glowBottom = h * (150 / 844);

            return Stack(
              children: [
                Positioned(
                  top: outerTop,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: _Arch(
                      width: 296,
                      height: 520,
                      color: OnbTok.gold30,
                    ),
                  ),
                ),
                Positioned(
                  top: innerTop,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: _Arch(
                      width: 212,
                      height: 468,
                      color: OnbTok.gold15,
                    ),
                  ),
                ),
                Positioned(
                  bottom: glowBottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FadeTransition(
                      opacity: glow,
                      child: const _HorizonGlow(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Arch extends StatelessWidget {
  const _Arch({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _ArchPainter(color)),
      );
}

class _ArchPainter extends CustomPainter {
  const _ArchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so a 1px line lands wholly inside the box rather
    // than straddling its edge and rendering as a soft 2px smear.
    const half = 0.5;
    final r = size.width / 2 - half;
    const left = half;
    final right = size.width - half;
    final bottom = size.height;

    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, r + half)
      ..arcToPoint(
        Offset(right, r + half),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(right, bottom);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.color != color;
}

/// `radial-gradient(ellipse at bottom, rgba(216,180,90,.16), transparent 70%)`
/// in a 420×340 box.
///
/// Flutter's [RadialGradient] is circular, so the ellipse is produced by
/// painting a circle and scaling it — 340 wide by 170 tall becomes 420 by 340,
/// anchored at the bottom edge where the light is supposed to come from.
class _HorizonGlow extends StatelessWidget {
  const _HorizonGlow();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 420,
        height: 340,
        child: Transform.scale(
          scaleX: 420 / 340,
          scaleY: 340 / 170,
          alignment: Alignment.bottomCenter,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomCenter,
                radius: 0.5, // 0.5 × 340 (the shorter side) = 170
                colors: [OnbTok.gold16, Color(0x000A2233)],
                stops: [0.0, 0.7],
              ),
            ),
          ),
        ),
      );
}
