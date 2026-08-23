/// App Icon — pick which of the two Mizan marks the app wears.
///
/// Three states, not two. "Match my theme" is the default and a real choice, not
/// an absence of one: it keeps the mark contrasting with the page, so it flips
/// with the theme. Picking a variant explicitly stops it following.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final chosen = ref.watch(logoVariantProvider);
    final controller = ref.read(logoVariantProvider.notifier);
    final effective = chosen ?? MizanLogoVariant.forPalette(p);

    return SettingsSubScaffold(
      title: 'App Icon',
      children: [
        const _Label('The mark'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MizanGeometry.gutter,
          ),
          child: Row(
            children: [
              for (final variant in MizanLogoVariant.values) ...[
                if (variant != MizanLogoVariant.values.first)
                  const SizedBox(width: MizanGeometry.gap),
                Expanded(
                  child: _VariantCard(
                    variant: variant,
                    // Only an explicit pick reads as chosen. When following the
                    // theme, neither card is checked — the effective one is
                    // marked "in use" instead, so the two ideas stay distinct.
                    chosen: chosen == variant,
                    inUse: chosen == null && effective == variant,
                    onTap: () => controller.set(variant),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: MizanGeometry.gap),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MizanGeometry.gutter,
          ),
          // MizanRow draws its own fill, border and press feedback — wrapping it
          // in a MizanSurface would double the hairline and nest two InkWells.
          child: MizanRow(
            title: 'Match my theme',
            subtitle: 'Navy in the light theme, cream in the dark',
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
                      : Icons.schedule_rounded,
                  size: 20,
                  color: p.muted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    launcherSwapSupported
                        ? 'Your choice also changes the icon on your home '
                            'screen.'
                        : 'This changes the mark inside the app. Changing the '
                            'icon on your home screen needs platform-specific '
                            'setup that is not finished yet, so it stays as it '
                            'is for now.',
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

/// One icon option: the mark at a size where the artwork is actually readable,
/// its name, and its state.
class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.chosen,
    required this.inUse,
    required this.onTap,
  });

  final MizanLogoVariant variant;
  final bool chosen;
  final bool inUse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          // The variant is passed explicitly, so each card shows its own mark
          // rather than both showing whatever is currently selected.
          MizanMark(size: 76, variant: variant),
          const SizedBox(height: 16),
          Text(variant.label, style: MizanType.bodyStrong(color: p.ink)),
          const SizedBox(height: 4),
          Text(
            variant.description,
            textAlign: TextAlign.center,
            style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (chosen)
            _Check(on: true)
          else if (inUse)
            Text(
              'IN USE',
              style: MizanType.sectionLabel(color: p.muted),
            )
          else
            // Holds the row's height steady, so selecting does not make the
            // cards jump.
            const SizedBox(height: 20),
        ],
      ),
    );
  }
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
