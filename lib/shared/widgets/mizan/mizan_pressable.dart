/// MizanPressable — the tactile press (soft UI)
///
/// From `Mizan Tokens.pdf`:
///
///   "Neumorphism applied only where it earns its keep. A dual shadow — warm
///    shade on the light-source side, near-white highlight opposite — makes a
///    control feel raised; the pressed state inverts both shadows inside the
///    element and nudges it 1px down. **Only things you tap get it.** Content
///    cards (ayah, thread, feed posts) stay flat with a hairline, or the screen
///    turns to mush and the hierarchy dies."
///
/// So: wrap **buttons, icon tiles, chips, tappable list rows, tab-bar items,
/// the compose button and audio controls** in this. Do *not* wrap an ayah card,
/// the Thread hero, a feed post, or a section well — those use [MizanSurface]
/// with `raised: false`.
///
/// ── How the inset shadow is drawn ─────────────────────────────────────
/// Flutter has no CSS `inset` keyword, but `BoxShadow.blurStyle` does have
/// [BlurStyle.inner]. An inner-blur shadow in a normal `decoration` would be
/// hidden behind the box's own fill, so the pressed shadows are painted as a
/// `foregroundDecoration` — on top of the fill, clipped to the same rounded
/// rect. That is the whole trick.
///
/// ── Android ───────────────────────────────────────────────────────────
/// The spec says: "on Android use elevation + ripple in place of the inset
/// shadow." Android users read a press as a ripple, and stacking an inset
/// shadow on top of one looks broken. So on Android the press keeps the rest
/// shadow (slightly tightened) and lets [InkWell] draw the ripple; every other
/// platform gets the inset treatment. Either way the 1px nudge happens, because
/// that is what makes the control feel physical.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/mizan_tokens.dart';

class MizanPressable extends StatefulWidget {
  const MizanPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.fill,
    this.border,
    this.padding,
    this.shadowsEnabled = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Defaults to the row radius (14). Use [MizanGeometry.pillRadius] for chips
  /// and buttons, or [MizanGeometry.cardRadius] for a tappable card.
  final BorderRadius? borderRadius;

  /// Defaults to the palette's `card`. Pass `Colors.transparent` for a control
  /// that should not paint its own background (an outlined button supplies its
  /// own fill through [border] + [fill]).
  final Color? fill;

  final BorderSide? border;
  final EdgeInsetsGeometry? padding;

  /// Set false for a control that must stay visually flat but still respond —
  /// a text link, say. The 1px nudge still applies.
  final bool shadowsEnabled;

  final String? semanticLabel;

  bool get _enabled => onTap != null || onLongPress != null;

  @override
  State<MizanPressable> createState() => _MizanPressableState();
}

class _MizanPressableState extends State<MizanPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  /// True where a ripple is the platform-native press signal.
  bool get _useRipple => defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final palette = MizanPalette.of(context);
    final radius = widget.borderRadius ?? MizanGeometry.rowBorderRadius;
    final fill = widget.fill ?? palette.card;
    final enabled = widget._enabled;

    final showPress = enabled && _pressed;
    final insetPress = showPress && !_useRipple;

    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: widget.border ?? BorderSide.none,
    );

    List<BoxShadow> outer() {
      if (!widget.shadowsEnabled || !enabled) return const <BoxShadow>[];
      if (insetPress) return const <BoxShadow>[];
      if (showPress) {
        // Android: keep the raise but pull it in, so the ripple reads as the
        // press and the control still looks attached to the surface.
        return palette.restShadow
            .map((s) => BoxShadow(
                  color: s.color,
                  offset: s.offset / 2,
                  blurRadius: s.blurRadius * 0.6,
                ))
            .toList(growable: false);
      }
      return palette.restShadow;
    }

    Widget content = AnimatedContainer(
      duration: MizanMotion.press,
      curve: MizanMotion.pressCurve,
      padding: widget.padding,
      decoration: ShapeDecoration(
        color: fill,
        shape: shape,
        shadows: outer(),
      ),
      foregroundDecoration: insetPress
          ? ShapeDecoration(shape: shape, shadows: palette.pressShadow)
          : null,
      child: widget.child,
    );

    if (enabled) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: radius,
          // Ripple only where it is the native idiom; elsewhere the inset
          // shadow is the feedback and a ripple would double up.
          splashColor: _useRipple ? null : Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          customBorder: shape,
          child: content,
        ),
      );
    }

    // The 1px nudge — what actually makes the control feel physical. Applied
    // outside the InkWell so a ripple travels down with it.
    content = AnimatedContainer(
      duration: MizanMotion.press,
      curve: MizanMotion.pressCurve,
      transform: Matrix4.translationValues(0, showPress ? 1 : 0, 0),
      child: content,
    );

    if (widget.semanticLabel != null) {
      content = Semantics(
        label: widget.semanticLabel,
        button: enabled,
        child: content,
      );
    }

    return ConstrainedBox(
      constraints: enabled
          ? const BoxConstraints(minHeight: MizanGeometry.tapTarget)
          : const BoxConstraints(),
      child: content,
    );
  }
}
