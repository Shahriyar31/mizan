/// Keeping Mizan readable at widths it was never drawn for.
///
/// Every screen in this app was designed against a 390pt phone (see
/// `tools/verify_mizan_layout.dart`, which measures the Al-Mizan page at exactly
/// that width). A browser does not agree to be 390pt. Opened on a laptop the
/// same layout is handed 1440pt or more, and the result is not "roomy" — it is
/// broken in three specific ways:
///
///  1. **Line length.** `MizanType.body` is 15pt. Across 1440pt that is roughly
///     190 characters per line, against the 60–75 that prose is legible at. The
///     eye loses its place returning to the left margin. For an app whose whole
///     purpose is reading translation and reflection, this is the real defect,
///     not a cosmetic one.
///  2. **The bottom tab bar** spreads four destinations across a metre of glass,
///     so the labels drift away from the icons' optical centres and the bar stops
///     reading as a group.
///  3. **Card geometry.** `MizanSurface` uses fixed 18pt padding and fixed corner
///     radii tuned for a 350pt-wide card. On a 1400pt card the padding vanishes
///     proportionally and the radius looks like a rounding error.
///
/// The fix is to stop the *content* growing and let the page background take the
/// extra room, which is what a phone-first app on a desktop browser should do.
///
/// ## Why this is not gated on web
///
/// It reacts to width, not to platform. A tablet, a foldable opened flat, and a
/// phone rotated to landscape all hand the app a width it was not drawn for, and
/// all three predate the web build. Gating on `kIsWeb` would have fixed the
/// browser and left the Android tablet broken for no reason.
///
/// On a portrait phone this widget measures the viewport, finds it at or below
/// the cap, and returns its child untouched — no extra render object, nothing to
/// pay for.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/mizan_tokens.dart';

/// Layout limits, in logical pixels.
abstract final class MizanBreakpoints {
  /// The widest the app's content is ever laid out.
  ///
  /// 520, chosen rather than picked. The floor is the 390 the design is drawn
  /// at; below that nothing improves. The ceiling is line length: at 15pt body
  /// text and DM Sans's ~0.5em average advance, 520pt of column minus 40pt of
  /// page gutter minus 36pt of card padding leaves 444pt of measure, which is
  /// about 59 characters — the top of the comfortable band. Every step past that
  /// buys width the reader pays for.
  ///
  /// It is also inside the range the layout verifier already sweeps (320, 360,
  /// 375, 390, 412, 430, **520**, 600, 834), so the Ramadan field's nine-per-row
  /// guarantee is measured here and not assumed.
  static const double contentMaxWidth = 520;

  /// Below this, treat the window as a phone held in the hand: no cap, no
  /// frame, nothing between the content and the glass.
  static bool isPhoneWidth(double width) => width <= contentMaxWidth;
}

/// Caps the app's content width and centres it on the page colour.
///
/// Install once, in `MaterialApp.builder`, so it wraps every route including the
/// shell that carries the tab bar. Wrapping individual screens would leave the
/// tab bar full-width and the content narrow, which looks like a bug.
class MizanResponsiveShell extends StatelessWidget {
  const MizanResponsiveShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;

    // The common case, and the whole reason this check is cheap: a phone.
    if (MizanBreakpoints.isPhoneWidth(width)) return child;

    final p = MizanPalette.of(context);
    const capped = MizanBreakpoints.contentMaxWidth;

    return ColoredBox(
      // Not `Container(color:)` — the surrounding field is a single flat fill
      // and ColoredBox is the render object that does exactly that.
      color: p.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: capped),
          child: DecoratedBox(
            // A hairline down each side. Without it the column reads as a
            // layout accident — content that failed to fill its window. With
            // it, it reads as a deliberate measure, which is what it is. Uses
            // the palette's own hairline so it is correct in both themes and
            // changes if the token does.
            decoration: BoxDecoration(
              color: p.page,
              border: Border.symmetric(
                vertical: BorderSide(color: p.hairline, width: 1),
              ),
            ),
            // The correctness step, and the easy one to miss.
            //
            // Constraining the box does not tell anything inside it that the
            // world got smaller. `MediaQuery.sizeOf(context)` would still report
            // the full window, so any screen sizing itself from the viewport —
            // and any `MediaQuery`-driven breakpoint further down — would lay
            // out against 1440 inside a 520 box and overflow. Overriding the
            // size here makes the constraint and the reported size agree, which
            // is the invariant the rest of the app assumes on a phone.
            //
            // Horizontal padding is zeroed with it: `padding` describes notches
            // and rounded display corners at the *window's* edges, and this
            // column no longer touches them. Keeping a phone's 44pt left inset
            // on a centred desktop column would indent the content for a notch
            // that is nowhere near it. Vertical padding is kept — a browser's
            // top inset is 0 anyway, and on a tablet the status bar really is
            // above this column.
            child: MediaQuery(
              data: media.copyWith(
                size: Size(capped, media.size.height),
                padding: media.padding.copyWith(left: 0, right: 0),
                viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
