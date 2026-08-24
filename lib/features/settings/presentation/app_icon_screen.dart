/// App Icon — pick which of the five Mizan marks the app wears.
///
/// Six states, not five. "Match my theme" is a real choice rather than an
/// absence of one: it keeps the mark contrasting with the page, so it flips with
/// the theme. Picking a variant explicitly stops it following.
///
/// The default is **Midnight**, not "Match my theme" — Midnight is the mark
/// baked into the launcher icon, so an untouched install wears the same tile
/// inside the app as it shows on the home screen.
///
/// ── Why rows and not a grid of cards ──────────────────────────────────
/// This was two big tap-cards side by side when two variants shipped. Five do
/// not fit that shape: three across leaves a ragged second row of two, two
/// across needs a scroll to reach the fifth, and either way the artwork ends up
/// smaller than it was. So the marks are shown once at a size where the
/// calligraphy is actually readable, and the choice itself is five rows in the
/// same idiom as every other Settings list. What a chooser row has to answer is
/// "which field colour is this" — a 40px tile answers that.
///
/// The chrome is still [SettingsSubScaffold] so this reads as part of the
/// Settings section; the body is built from Mizan primitives.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/mizan_brand.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../../shared/widgets/mizan/mizan_logo.dart';
import 'widgets/settings_row.dart';

class AppIconScreen extends ConsumerWidget {
  const AppIconScreen({super.key});

  /// The preview mark's width. Sized by width only — the tiles are 900×1046 and
  /// a square box crops the book. See [MizanMark].
  static const double _previewWidth = 104;

  /// The mark beside each row.
  static const double _rowMarkWidth = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final chosen = ref.watch(logoVariantProvider);
    final controller = ref.read(logoVariantProvider.notifier);
    final effective = chosen ?? MizanLogoVariant.forPalette(p);

    return SettingsSubScaffold(
      title: 'App Icon',
      children: [
        // The mark you have, large. This is the only place on the screen where
        // the artwork is big enough to read, which is why it is here at all.
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Center(
            child: Column(
              children: [
                MizanMark(width: _previewWidth, variant: effective),
                const SizedBox(height: 12),
                Text(
                  chosen == null
                      ? '${effective.label} — matching your theme'
                      : effective.label,
                  style: MizanType.body(color: p.muted),
                ),
              ],
            ),
          ),
        ),

        const _Label('The mark'),
        for (final variant in MizanLogoVariant.values)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MizanGeometry.gutter,
              0,
              MizanGeometry.gutter,
              MizanGeometry.gap,
            ),
            // MizanRow draws its own fill, border and press feedback — wrapping it
            // in a MizanSurface would double the hairline and nest two InkWells.
            child: MizanRow(
              title: variant.label,
              subtitle: variant.description,
              // Passed explicitly, so each row shows its own mark rather than
              // five copies of whatever is currently selected.
              leading: MizanMark(width: _rowMarkWidth, variant: variant),
              showChevron: false,
              // Only an explicit pick reads as chosen. When following the theme,
              // no row is checked — the effective one is marked "in use"
              // instead, so the two ideas stay distinct.
              trailing: chosen == variant
                  ? const _Check(on: true)
                  : (chosen == null && effective == variant
                      ? Text(
                          'IN USE',
                          style: MizanType.sectionLabel(color: p.muted),
                        )
                      : const _Check(on: false)),
              onTap: () => controller.set(variant),
            ),
          ),

        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MizanGeometry.gutter,
          ),
          child: MizanRow(
            title: 'Match my theme',
            subtitle: 'Midnight in the light theme, Classic in the dark',
            leading: Icon(
              Icons.brightness_auto_rounded,
              size: 20,
              color: p.accentText,
            ),
            showChevron: false,
            trailing: _Check(on: chosen == null),
            onTap: () => controller.set(null),
          ),
        ),

        const _Label('Home screen'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MizanGeometry.gutter,
          ),
          child: MizanSurface(
            tone: MizanTone.sunk,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  launcherSwapSupported
                      ? Icons.check_circle_outline_rounded
                      : Icons.home_rounded,
                  size: 20,
                  color: p.muted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    launcherSwapSupported
                        ? 'Your choice also changes the icon on your home '
                            'screen.'
                        : 'Your home-screen icon is Midnight. This picker '
                            'changes the mark used inside the app only.',
                    style: MizanType.body(color: p.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          MizanGeometry.gutter,
          24,
          MizanGeometry.gutter,
          10,
        ),
        child: MizanSectionLabel(text),
      );
}

/// A gold diamond when on, an empty ring when off — the palette has no green,
/// and a Material check circle would import a colour that is not in the spec.
class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return SizedBox(
      height: 20,
      width: 20,
      child: Center(
        child: on
            ? const MizanDiamond(size: 11, filled: true)
            : Container(
                height: 13,
                width: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.hairline,
                    width: MizanGeometry.hairlineWidth,
                  ),
                ),
              ),
      ),
    );
  }
}
