/// Mizan components — the small vocabulary every screen is built from.
///
/// Nothing here invents a colour, a size, or a text style; everything reads
/// from [MizanPalette], [MizanGeometry] and [MizanType]. If a screen needs a
/// shape that is not in this file, add it here rather than inlining a
/// `Container` — that is how a design system erodes.
///
/// Contents:
///   [MizanSurface]      flat card with a hairline — for anything holding text
///   [MizanButton]       Primary / Secondary / Quiet / Chip
///   [MizanIconTile]     the round or squared icon touchable
///   [MizanRow]          tappable list row with leading tile and chevron
///   [MizanSectionLabel] DM Sans 700 · 11 · 0.16em uppercase
///   [MizanRule]         a 1px hairline
///   [MizanDiamond]      the gold diamond glyph, filled or outline
///   [MizanArch]         the mihrab arch outline used as page decoration
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/branding/mizan_icons.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import 'mizan_pressable.dart';

// ══════════════════════════════════════════════════════════════════════
//  SURFACE
// ══════════════════════════════════════════════════════════════════════

/// A card that holds text: flat, hairline border, **no shadow**.
///
/// "Stays flat: Ayah cards, the Thread hero, feed posts, section wells —
/// anything that only holds text. Hairline border, no shadow."
///
/// Set [tone] to change which surface colour it sits on. Set [onTap] only if
/// the whole card is genuinely tappable, in which case it becomes a
/// [MizanPressable] and *does* get the raise — a tappable card is a touchable.
class MizanSurface extends StatelessWidget {
  const MizanSurface({
    super.key,
    required this.child,
    this.tone = MizanTone.card,
    this.padding = const EdgeInsets.all(MizanGeometry.cardPadding),
    this.radius,
    this.showBorder = true,
    this.onTap,
  });

  final Widget child;
  final MizanTone tone;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;
  final bool showBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final r = radius ?? MizanGeometry.cardBorderRadius;
    final fill = tone.resolve(p);
    final side = showBorder
        ? BorderSide(color: tone.hairlineOn(p), width: MizanGeometry.hairlineWidth)
        : BorderSide.none;

    if (onTap != null) {
      return MizanPressable(
        onTap: onTap,
        borderRadius: r,
        fill: fill,
        border: side,
        padding: padding,
        child: child,
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedRectangleBorder(borderRadius: r, side: side),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Which surface colour a component sits on.
enum MizanTone {
  /// App background.
  page,

  /// Raised surface / list row.
  card,

  /// Inset well — search fields and quote panels on light, chips and nested
  /// cards on dark.
  sunk,

  /// A navy panel in *both* themes. The Today's Thread hero and the Halaqa
  /// quote card use this: on light it is the one dark surface on the screen, on
  /// dark it is the normal card.
  inverse;

  Color resolve(MizanPalette p) => switch (this) {
        MizanTone.page => p.page,
        MizanTone.card => p.card,
        MizanTone.sunk => p.sunk,
        MizanTone.inverse => p.isLight ? p.ink : p.card,
      };

  /// The text colour that reads on this tone.
  Color onColor(MizanPalette p) => switch (this) {
        MizanTone.inverse => p.isLight ? p.onFilled : p.ink,
        _ => p.ink,
      };

  /// The secondary text colour that reads on this tone. Still one grey per
  /// theme — on the inverse panel in light mode the single grey is too dark, so
  /// the cream ink is dimmed instead of introducing a second grey token.
  Color mutedOn(MizanPalette p) => switch (this) {
        MizanTone.inverse =>
          p.isLight ? p.onFilled.withValues(alpha: 0.66) : p.muted,
        _ => p.muted,
      };

  /// The rule colour that reads on this tone. The light hairline (`#E3D6BE`) is
  /// warm cream — on a navy panel it would glare, so the inverse tone uses gold
  /// at the same 18% the dark theme uses everywhere.
  Color hairlineOn(MizanPalette p) => switch (this) {
        MizanTone.inverse when p.isLight => p.accent.withValues(alpha: 0.28),
        _ => p.hairline,
      };

  /// The accent colour that is legal *as text* on this tone. Gold is illegal as
  /// text on cream, but perfectly legal on the navy inverse panel.
  Color accentTextOn(MizanPalette p) => switch (this) {
        MizanTone.inverse => p.accent,
        _ => p.accentText,
      };
}

// ══════════════════════════════════════════════════════════════════════
//  BUTTONS
// ══════════════════════════════════════════════════════════════════════

enum MizanButtonKind {
  /// Light: navy fill, cream label. Dark: gold fill, navy label.
  primary,

  /// Outlined. Light: navy hairline + navy label. Dark: gold hairline + gold
  /// label.
  secondary,

  /// Light: sunk cream fill. Dark: raised navy fill. A real button that does
  /// not want to compete.
  quiet,

  /// Full-radius outline, smaller type. Filters and layer tabs.
  chip,
}

class MizanButton extends StatelessWidget {
  const MizanButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = MizanButtonKind.primary,
    this.icon,
    this.trailingIcon,
    this.selected = false,
    this.expand = false,
    this.onInverse = false,
  });

  const MizanButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.selected = false,
    this.expand = false,
    this.onInverse = false,
  }) : kind = MizanButtonKind.secondary;

  const MizanButton.quiet({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.selected = false,
    this.expand = false,
    this.onInverse = false,
  }) : kind = MizanButtonKind.quiet;

  const MizanButton.chip({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.selected = false,
    this.expand = false,
    this.onInverse = false,
  }) : kind = MizanButtonKind.chip;

  final String label;
  final VoidCallback? onPressed;
  final MizanButtonKind kind;
  final IconData? icon;
  final IconData? trailingIcon;

  /// For [MizanButtonKind.chip] — a selected chip fills instead of outlining.
  final bool selected;

  final bool expand;

  /// True when the button sits on a [MizanTone.inverse] panel (the Thread hero,
  /// the navy account card). On light that panel is navy, so a navy-fill
  /// primary would vanish — gold trim takes over instead.
  final bool onInverse;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    late Color fill;
    late Color labelColor;
    late BorderSide side;

    switch (kind) {
      case MizanButtonKind.primary:
        if (onInverse) {
          // On navy, the primary is a gold-outlined pill with a gold label —
          // exactly the "Continue →" control on Today's Thread.
          fill = Colors.transparent;
          labelColor = p.accent;
          side = BorderSide(color: p.accent, width: MizanGeometry.hairlineWidth);
        } else {
          fill = p.isLight ? p.ink : p.accent;
          labelColor = p.onFilled;
          side = BorderSide.none;
        }
      case MizanButtonKind.secondary:
        fill = onInverse ? Colors.transparent : p.card;
        labelColor = onInverse ? p.accent : (p.isLight ? p.ink : p.accentText);
        side = BorderSide(
          color: onInverse ? p.accent : (p.isLight ? p.ink : p.accent),
          width: MizanGeometry.hairlineWidth,
        );
      case MizanButtonKind.quiet:
        fill = p.sunk;
        labelColor = p.ink;
        side = BorderSide.none;
      case MizanButtonKind.chip:
        if (selected) {
          fill = p.isLight ? p.ink : p.accent;
          labelColor = p.onFilled;
          side = BorderSide.none;
        } else {
          fill = onInverse ? p.sunk : p.card;
          labelColor = p.ink;
          side = BorderSide(
            color: p.hairline,
            width: MizanGeometry.hairlineWidth,
          );
        }
    }

    final isChip = kind == MizanButtonKind.chip;
    final textStyle = isChip
        ? MizanType.button(color: labelColor).copyWith(fontSize: 13)
        : MizanType.button(color: labelColor);
    final iconSize = isChip ? 15.0 : 18.0;

    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: labelColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: iconSize, color: labelColor),
        ],
      ],
    );

    final button = MizanPressable(
      onTap: onPressed,
      borderRadius: const BorderRadius.all(
        Radius.circular(MizanGeometry.pillRadius),
      ),
      fill: fill,
      border: side,
      padding: EdgeInsets.symmetric(
        horizontal: isChip ? 16 : 24,
        vertical: isChip ? 9 : 13,
      ),
      // A transparent-fill control has nothing to raise, and stacking a warm
      // shade under a see-through pill just looks dirty.
      shadowsEnabled: fill != Colors.transparent,
      semanticLabel: label,
      child: row,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ICON TILE
// ══════════════════════════════════════════════════════════════════════

/// The circular or squared icon touchable: the profile and bell buttons on
/// Home, the four action icons on an ayah card, the Settings gear, the audio
/// controls. Always at least 44×44.
///
/// Takes *either* a Material [icon] or a piece of [artwork] from the brand set.
/// Artwork exists for ten things — the five tabs plus hadith, prophet, sahaba,
/// names99 and settings — and where one of those ten is the subject, the artwork
/// is what must appear; see `assets/README.md`. It is two-colour raster art, so
/// [iconColor], [filled] and anything else that would recolour it does not apply
/// to it: pass artwork only on a `card` or `sunk` tone, which is the cream (or
/// navy, in the dark set) ground it was drawn against.
class MizanIconTile extends StatelessWidget {
  const MizanIconTile({
    super.key,
    this.icon,
    this.artwork,
    this.onTap,
    this.size = MizanGeometry.tapTarget,
    this.iconSize = 20,
    this.circle = true,
    this.tone = MizanTone.card,
    this.iconColor,
    this.filled = false,
    this.semanticLabel,
    this.badge = false,
  })  : assert(icon != null || artwork != null,
            'MizanIconTile needs an icon or artwork'),
        assert(artwork == null || !filled,
            'Artwork cannot sit on a filled tile — it would be two-colour art '
            'on navy or gold, which is not a ground it was drawn for');

  /// The Material glyph. Null when [artwork] carries the tile instead.
  final IconData? icon;

  /// Brand artwork, for the ten things that have it. Never tinted.
  final MizanIcons? artwork;

  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  /// Circle for controls, squared (radius 14) for the leading tile of a list
  /// row.
  final bool circle;

  final MizanTone tone;
  final Color? iconColor;

  /// Fill with the accent instead of the tone — the "current" icon tile, like
  /// Al-Meezan's navy square on Growth.
  final bool filled;

  final String? semanticLabel;

  /// A small gold dot at the top-right, for the bell with unread notifications.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final fill = filled ? (p.isLight ? p.ink : p.accent) : tone.resolve(p);
    final fg = iconColor ?? (filled ? p.onFilled : tone.accentTextOn(p));

    Widget tile = MizanPressable(
      onTap: onTap,
      borderRadius: circle
          ? const BorderRadius.all(Radius.circular(MizanGeometry.pillRadius))
          : MizanGeometry.rowBorderRadius,
      fill: fill,
      border: filled
          ? BorderSide.none
          : BorderSide(
              color: tone.hairlineOn(p),
              width: MizanGeometry.hairlineWidth,
            ),
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: artwork != null
              // No colour passed: the art carries its own two.
              ? MizanIcon(artwork!, size: iconSize, semanticLabel: semanticLabel)
              : Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );

    if (badge) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    return tile;
  }
}

// ══════════════════════════════════════════════════════════════════════
//  LIST ROW
// ══════════════════════════════════════════════════════════════════════

/// A tappable list row: leading icon tile, title, subtitle, trailing chevron.
/// Radius 14, raised at rest, inset on press. Used on Quran, Halaqa, Growth
/// and Settings.
class MizanRow extends StatelessWidget {
  const MizanRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.tone = MizanTone.card,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final MizanTone tone;

  /// An optional second line below a hairline — "Next session today, 8:30 PM"
  /// on a Halaqa circle, or the Al-Meezan stat line on Growth.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MizanType.bodyStrong(color: tone.onColor(p))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: MizanType.body(color: tone.mutedOn(p))),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            if (trailing == null && showChevron && onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 22, color: tone.mutedOn(p)),
            ],
          ],
        ),
        if (footer != null) ...[
          const SizedBox(height: 14),
          MizanRule(color: tone.hairlineOn(p)),
          const SizedBox(height: 12),
          footer!,
        ],
      ],
    );

    return MizanPressable(
      onTap: onTap,
      borderRadius: footer != null
          ? MizanGeometry.cardBorderRadius
          : MizanGeometry.rowBorderRadius,
      fill: tone.resolve(p),
      border: BorderSide(
        color: tone.hairlineOn(p),
        width: MizanGeometry.hairlineWidth,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MizanGeometry.cardPaddingTight,
        vertical: 14,
      ),
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      child: body,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SMALL PARTS
// ══════════════════════════════════════════════════════════════════════

/// DM Sans 700 · 11 · 0.16em, uppercased for you. Section labels use the
/// theme's link colour; on a navy panel they use gold.
class MizanSectionLabel extends StatelessWidget {
  const MizanSectionLabel(this.text, {super.key, this.color, this.onInverse = false});

  final String text;
  final Color? color;
  final bool onInverse;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: MizanType.sectionLabel(
        color: color ?? (onInverse ? p.accent : p.link),
      ),
    );
  }
}

/// A 1px hairline rule.
class MizanRule extends StatelessWidget {
  const MizanRule({super.key, this.color, this.indent = 0});

  final Color? color;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: SizedBox(
        height: MizanGeometry.hairlineWidth,
        width: double.infinity,
        child: ColoredBox(color: color ?? p.hairline),
      ),
    );
  }
}

/// The gold diamond glyph — a square rotated 45°. Filled means "engaged",
/// outline means "not yet". It is a record, not a score: there is no count and
/// no half state.
class MizanDiamond extends StatelessWidget {
  const MizanDiamond({
    super.key,
    this.size = 7,
    this.filled = true,
    this.color,
  });

  final double size;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final c = color ?? p.accent;
    return SizedBox(
      width: size * 1.42,
      height: size * 1.42,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: filled ? c : Colors.transparent,
              border: filled ? null : Border.all(color: c, width: 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mihrab arch outline used as page decoration — behind the Home greeting,
/// on the Halaqa header, in the Discover hero, on the Settings account card.
///
/// This is *not* an image: rule #2 allows one image per screen, and the arch is
/// explicitly named as the alternative ("the arch outline, the 5%-opacity
/// pattern, or nothing"). So it is drawn.
class MizanArch extends StatelessWidget {
  const MizanArch({
    super.key,
    this.color,
    this.strokeWidth = 1,
    this.opacity = 0.5,
    this.rings = 1,
  });

  final Color? color;
  final double strokeWidth;
  final double opacity;

  /// Concentric arches, as on the welcome screen and the light cover page.
  final int rings;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return IgnorePointer(
      child: CustomPaint(
        painter: _ArchPainter(
          color: (color ?? p.accent).withValues(alpha: opacity),
          strokeWidth: strokeWidth,
          rings: rings,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ArchPainter extends CustomPainter {
  const _ArchPainter({
    required this.color,
    required this.strokeWidth,
    required this.rings,
  });

  final Color color;
  final double strokeWidth;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (var i = 0; i < rings; i++) {
      final inset = i * size.width * 0.13;
      final rect = Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset,
      );
      if (rect.width <= 0 || rect.height <= 0) break;
      canvas.drawPath(_archPath(rect), paint);
    }
  }

  /// A pointed (ogee) arch: shoulders rise straight, then two curves meet at a
  /// soft point on the centre line.
  Path _archPath(Rect r) {
    final cx = r.center.dx;
    final shoulderY = r.top + r.height * 0.46;
    return Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, shoulderY)
      ..cubicTo(
        r.left,
        r.top + r.height * 0.12,
        cx - r.width * 0.30,
        r.top,
        cx,
        r.top,
      )
      ..cubicTo(
        cx + r.width * 0.30,
        r.top,
        r.right,
        r.top + r.height * 0.12,
        r.right,
        shoulderY,
      )
      ..lineTo(r.right, r.bottom);
  }

  @override
  bool shouldRepaint(_ArchPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.rings != rings;
}
