/// Page chrome for every knowledge screen — theme, scholar, place, journey,
/// hadith, and the two indexes.
///
/// The four Discover detail screens open with a navy band: back arrow, big gold
/// Arabic, a meta line under it. This is that band, and it exists as its own
/// widget because five new screens needed it and the version inside
/// [LayerStoryScaffold] is private to that file's five-layer reader. Same tone,
/// same arch, same gutter, same type — a theme page has to look like it belongs
/// to the same app as a prophet page, because the reader walks between them in
/// one tap.
///
/// The band is deliberately *not* refactored out of the layer reader. Four
/// shipped screens depend on that one pixel-for-pixel, and there is nothing to
/// gain from touching them.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/mizan_tokens.dart';
import '../../../../core/theme/mizan_typography.dart';
import '../../../../shared/widgets/mizan/mizan_components.dart';
import '../../../../shared/widgets/mizan/mizan_pressable.dart';

/// The navy band at the top of a knowledge page.
class KnowledgeHero extends StatelessWidget {
  const KnowledgeHero({
    super.key,
    required this.title,
    this.titleArabic,
    this.meta,
    this.eyebrow,
    this.trailing,
    this.footer,
  });

  /// English or transliterated. Always present — rule #6: the Arabic never
  /// stands alone.
  final String title;

  final String? titleArabic;

  /// The line under the title: "Theme · 14 entries", "701–774 AH · Shafi'i".
  final String? meta;

  /// A small uppercase label above the title — the type, usually.
  final String? eyebrow;

  /// An action at the top right, e.g. share.
  final Widget? trailing;

  /// Anything that belongs inside the band under the meta line.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;

    return DecoratedBox(
      decoration: BoxDecoration(color: tone.resolve(p)),
      child: SafeArea(
        bottom: false,
        // ClipRect keeps the arch inside the band; no fixed height, so a long
        // title or a large text scale grows the band instead of overflowing it.
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: -46,
                right: -96,
                child: SizedBox(
                  width: 260,
                  height: 300,
                  child: MizanArch(color: p.accent, rings: 1, opacity: 0.30),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MizanGeometry.gutter,
                  6,
                  MizanGeometry.gutter,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KnowledgeHeroIcon(
                          icon: Icons.arrow_back_ios_new_rounded,
                          semanticLabel: 'Back',
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (eyebrow != null) ...[
                      MizanSectionLabel(eyebrow!, onInverse: true),
                      const SizedBox(height: 10),
                    ],
                    if (titleArabic != null) ...[
                      // Gold as text is legal here and nowhere else on cream.
                      Text(
                        titleArabic!,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MizanType.arabic(
                          color: tone.accentTextOn(p),
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      style: MizanType.screenTitle(color: tone.onColor(p)),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        meta!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MizanType.body(color: tone.mutedOn(p))
                            .copyWith(fontSize: 14.5),
                      ),
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A flat icon touchable for use *on* the navy band. Flat because the band is
/// already the raised surface here; a neumorphic tile on top of it would read as
/// a second card.
class KnowledgeHeroIcon extends StatelessWidget {
  const KnowledgeHeroIcon({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return MizanPressable(
      onTap: onTap,
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.all(10),
      semanticLabel: semanticLabel,
      child: Icon(icon, size: 20, color: p.accent),
    );
  }
}

/// Hero band plus a scrolling body on the page colour. Every knowledge screen is
/// this, so they all scroll the same way and end with the same bottom padding
/// clear of the tab bar.
class KnowledgeScaffold extends StatelessWidget {
  const KnowledgeScaffold({
    super.key,
    required this.hero,
    required this.children,
    this.bottom,
  });

  final KnowledgeHero hero;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          hero,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                MizanGeometry.gutter,
                22,
                MizanGeometry.gutter,
                MizanGeometry.scrollBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// The label above a block on a knowledge page, with the hairline running out to
/// the right margin — the same header the layer reader uses for "LAYER 1 OF 5".
class KnowledgeSectionHeader extends StatelessWidget {
  const KnowledgeSectionHeader(this.label, {super.key, this.trailingText});

  final String label;

  /// A count, usually. "14 entries" sits at the right of the rule.
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Row(
      children: [
        MizanSectionLabel(label),
        const SizedBox(width: 12),
        Expanded(child: MizanRule(color: p.hairline)),
        if (trailingText != null) ...[
          const SizedBox(width: 12),
          Text(trailingText!, style: MizanType.sectionLabel(color: p.muted)),
        ],
      ],
    );
  }
}

/// What a knowledge page shows while the graph is still being built, and what it
/// shows if a ref turns out not to exist. Both are quiet on purpose: the graph is
/// an addition to a working app, so nothing here is allowed to look like a fault.
class KnowledgePlaceholder extends StatelessWidget {
  const KnowledgePlaceholder({
    super.key,
    required this.title,
    this.message,
    this.loading = false,
  });

  final String title;
  final String? message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, MizanGeometry.gutter, 6),
              child: Row(
                children: [
                  MizanIconTile(
                    icon: Icons.arrow_back_ios_new_rounded,
                    semanticLabel: 'Back',
                    iconSize: 17,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: MizanType.cardHeadline(color: p.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accentText,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MizanGeometry.gutter,
                        ),
                        child: Text(
                          message ?? 'Nothing here yet.',
                          textAlign: TextAlign.center,
                          style: MizanType.body(color: p.muted),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
