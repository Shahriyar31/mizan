/// Welcome — the first thing a new user sees.
///
/// Built from the `Mizan Light.pdf` welcome mockup: a full-bleed painted valley,
/// the mark under a mihrab arch, the wordmark, the Arabic name, one line of
/// tagline, and one entry action.
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
///
/// ── Why there is no longer a quotation here ───────────────────────────
/// This screen used to carry an athar attributed to Umar ibn al-Khattab, lifted
/// from the mockup, with a standing TODO saying no collection, volume, page or
/// grading had been verified. An unsourced transmitted saying is not something
/// this app may ship, least of all on the very first screen a user ever sees.
/// The brand lockup — mark, wordmark, Arabic name, tagline — is what the screen
/// says instead, and every word of it is the app's own voice.
///
/// ── Why there is exactly one action ───────────────────────────────────
/// Signing in is optional and lives behind Settings › account; there is no
/// router guard and every tab works signed out. Putting a "Sign in" control
/// here would give that action a second entry point and would imply an account
/// is required, which is the opposite of true. So the only control is *Begin*,
/// and a single muted line says plainly that no account is needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                    SizedBox(height: constraints.maxHeight * 0.05),
                    const _Lockup(),
                    const Spacer(),
                    const _Entry(),
                    SizedBox(height: constraints.maxHeight * 0.055),
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

  /// Width of the mark. The mockup's mark is ~35% of the screen width; this is
  /// a fixed value instead so the lockup does not balloon on a tablet.
  static const double _markWidth = 132;

  /// `mīzān` — the scale, the balance. The app's own name, so it is the app's
  /// own voice and needs no attribution.
  static const String _arabicName = 'ميزان';

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The mark, and nothing behind it. This used to be a cut-out glyph inside
        // a drawn [MizanArch]; the new artwork is a tile with the arch already in
        // it, so the drawn one would be a second arch around the first. Narrower
        // than the old 152 because the tile occupies its full box, where the
        // cut-out left air around the edges.
        const MizanMark(width: _markWidth),
        const SizedBox(height: 14),
        const MizanWordmark(fontSize: 36),
        const SizedBox(height: 2),
        // The Arabic name, on the Arabic role — never a Latin style, even for
        // one word. Gold-family *as text* is illegal on cream, so this is
        // `accentText` (bronze on light, gold on dark) rather than `accent`.
        //
        // The role's 1.9 line-height is tuned for running Arabic; on a single
        // display word it opens a gap the size of another line above and below
        // the glyphs. 1.7 is still comfortably clear of Amiri's own
        // ascent-plus-descent, so nothing is at risk of being clipped.
        Text(
          _arabicName,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: MizanType.arabic(color: p.accentText, fontSize: 26)
              .copyWith(height: 1.7),
        ),
        const SizedBox(height: 8),
        const MizanTagline(withRules: true, ruleWidth: 26),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ENTRY
// ══════════════════════════════════════════════════════════════════════

/// One button, and one line telling the truth about accounts.
///
/// The screen used to end with an athar attributed to Umar ibn al-Khattab,
/// transcribed from the design mockup and carrying a standing TODO because no
/// collection, volume, page or grading had ever been verified for it. Citation
/// Lock does not bend for decoration: an unsourced transmitted saying cannot
/// ship, least of all as the first sentence a user ever reads. It is gone, and
/// nothing has been invented to replace it.
class _Entry extends ConsumerWidget {
  const _Entry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MizanGeometry.gutter + 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MizanButton(
            label: 'Begin',
            onPressed: () async {
              // Persist first, then navigate. If the write failed and we had
              // already left, the next launch would land here again with no way
              // to tell the user why.
              await OnboardingFlags.markWelcomeSeen();
              if (context.mounted) context.go('/home');
            },
          ),
          const SizedBox(height: 14),
          // Said plainly, because the opposite is what people expect. There is
          // no router guard: every tab works signed out, and `/auth` is reached
          // only from Settings. A "Sign in" button here would both imply an
          // account is required and give that action a second front door.
          Text(
            'No account needed. Everything works offline.',
            textAlign: TextAlign.center,
            style: MizanType.body(color: p.muted).copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
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
