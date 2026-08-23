library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mizan_tokens.dart';
import '../../core/theme/mizan_typography.dart';
import '../../features/discover/models/discover_models.dart';
import 'mizan/mizan_components.dart';
import 'mizan/mizan_pressable.dart';
import 'narrative_text.dart';
import 'pill_layer_navigation.dart';

/// One scaffold for every "5 layers + quiz" Discover detail screen — Prophet,
/// Sahabi, Seerah, Divine Name. Rebuilt from `Mizan Light.pdf` / `Mizan
/// Dark.pdf` page 5 (screen 04 of 08), which is this screen, not the Discover
/// index: the mockup shows Adam, layer 1 of 5.
///
/// Four screens share this file, so the rebuild lands on all four at once.
///
/// ── What the mockup shows and what the data can support ────────────────
///
///   • **"The First Human · 5 layers · 8 min"** — the era comes from the entry,
///     the layer count is `layers.length`, and the reading estimate is counted
///     off the actual words in the story at 180 wpm. Nothing is hardcoded; if
///     the text grows, the estimate moves with it.
///
///   • **A "Reviewed" chip.** Dropped. It asserts that a scholar checked this
///     page, and nothing in the data records that. Its slot holds the thing that
///     *is* recorded — the named source, `layer.source`, which is the citation
///     the Citation Lock actually requires.
///
///   • **The sand quote card holding hadith text.** The layer model carries
///     `content` (the narrative), `source`, and optional `quranRef` /
///     `hadithRef` — references, not quoted text. So a reference becomes a
///     citation chip, and the narrative is set as narrative. Rendering
///     `hadithRef` inside quotation marks would be publishing a hadith text this
///     app never stored.
///
///   • **The bookmark icon** in the hero. There is no saved-stories store for
///     Discover entries — [SavedAyatStore] covers ayat only. Share is real and
///     stays; the bookmark is left out rather than drawn dead.
class LayerStoryScaffold extends StatefulWidget {
  const LayerStoryScaffold({
    super.key,
    required this.layers,
    required this.navLabels,
    required this.headerTitle,
    required this.headerSubtitle,
    this.headerTrailing,
    this.onBeginQuiz,
    this.onShare,
    this.initialLayer = 0,
  });

  final List<DiscoverLayer> layers;
  final List<String> navLabels;

  /// The large Arabic title in the hero (e.g. `entry.nameArabic`).
  final String headerTitle;

  /// The line beneath it (e.g. "Adam — The First Human"). Rule #6: the Arabic
  /// never stands alone, and this is what stands with it.
  final String headerSubtitle;

  /// An optional small trailing label, e.g. "#12" for a divine name.
  final String? headerTrailing;

  /// Called when "Begin Quiz" is tapped on the final layer. Null hides it.
  final VoidCallback? onBeginQuiz;

  /// Called when the hero's share button is tapped. Null hides the button. One
  /// hook here gives all four Discover screens a share action.
  final VoidCallback? onShare;

  final int initialLayer;

  @override
  State<LayerStoryScaffold> createState() => _LayerStoryScaffoldState();
}

class _LayerStoryScaffoldState extends State<LayerStoryScaffold> {
  late int _currentLayer = widget.initialLayer;
  late final Set<int> _visited = {widget.initialLayer};

  void _goTo(int index) {
    if (index == _currentLayer) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentLayer = index;
      _visited.add(index);
    });
  }

  /// Whole minutes at 180 words per minute, over the entire story rather than
  /// the current layer, because it answers "how long is this?" before you start.
  /// Null when the text is too short for the number to mean anything.
  int? get _readingMinutes {
    final words = widget.layers.fold<int>(
      0,
      (sum, l) => sum + l.content.trim().split(RegExp(r'\s+')).length,
    );
    final minutes = (words / 180).ceil();
    return minutes < 1 ? null : minutes;
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final layer = _currentLayer < widget.layers.length
        ? widget.layers[_currentLayer]
        : null;
    final isLastLayer = _currentLayer == widget.layers.length - 1;

    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          _Hero(
            title: widget.headerTitle,
            subtitle: widget.headerSubtitle,
            trailing: widget.headerTrailing,
            layerCount: widget.layers.length,
            readingMinutes: _readingMinutes,
            onShare: widget.onShare,
            current: _currentLayer,
            visited: _visited,
          ),
          Expanded(
            child: layer == null
                ? const SizedBox.shrink()
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(_currentLayer),
                      padding: const EdgeInsets.fromLTRB(
                        MizanGeometry.gutter,
                        22,
                        MizanGeometry.gutter,
                        28,
                      ),
                      child: _LayerBody(
                        layer: layer,
                        layerIndex: _currentLayer,
                        layerCount: widget.layers.length,
                        layerLabel: widget.navLabels.length > _currentLayer
                            ? widget.navLabels[_currentLayer]
                            : layer.title,
                        isLastLayer: isLastLayer,
                        onBeginQuiz: widget.onBeginQuiz,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: PillLayerNavigation(
        labels: widget.navLabels,
        selectedIndex: _currentLayer,
        // Bronze on cream, gold on navy — the chips sit on the page, so this is
        // the text-legal member of the gold family.
        accent: p.accentText,
        onSelected: _goTo,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HERO — the one navy band on the screen
// ══════════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.layerCount,
    required this.readingMinutes,
    required this.onShare,
    required this.current,
    required this.visited,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final int layerCount;
  final int? readingMinutes;
  final VoidCallback? onShare;
  final int current;
  final Set<int> visited;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;

    final meta = [
      subtitle,
      '$layerCount layers',
      if (readingMinutes != null) '$readingMinutes min',
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(color: tone.resolve(p)),
      // The band runs to the top of the display; only its content is inset.
      child: SafeArea(
        bottom: false,
        // No fixed height. The old `SizedBox(height: 208)` was tuned to a
        // one-line subtitle; a two-line one — a long kunya like "Abu Bakr
        // as-Siddiq — First Caliph — Al-Siddiq · 5 layers · 5 min", or any
        // larger text scale — overflowed it, which is the striped bar that
        // showed up across the band. The Stack now takes its height from the
        // Column, so the band grows with its content instead of clipping it.
        child: ClipRect(
          child: Stack(
            children: [
              // Rule #2: the arch outline is how a surface gets texture without
              // spending the screen's one image. Stack clips it to the band.
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
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HeroIcon(
                          icon: Icons.arrow_back_ios_new_rounded,
                          semanticLabel: 'Back',
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                        if (trailing != null) ...[
                          Text(
                            trailing!,
                            style: MizanType.sectionLabel(
                              color: tone.mutedOn(p),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (onShare != null)
                          _HeroIcon(
                            icon: Icons.ios_share_rounded,
                            semanticLabel: 'Share this story',
                            onTap: onShare!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Gold as text is legal here: this is the navy panel.
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MizanType.arabic(
                        color: tone.accentTextOn(p),
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MizanType.body(color: tone.mutedOn(p))
                          .copyWith(fontSize: 14.5),
                    ),
                    const SizedBox(height: 16),
                    _ProgressDots(
                      count: layerCount,
                      current: current,
                      visited: visited,
                      color: p.accent,
                      onToneMuted: tone.mutedOn(p),
                    ),
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

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
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
      // Flat on the band: the navy panel is already the raised thing here, and a
      // neumorphic tile on top of it would read as a second surface.
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.all(10),
      semanticLabel: semanticLabel,
      child: Icon(icon, size: 20, color: p.accent),
    );
  }
}

/// Where you are in the story. Visited layers stay lit, which is a record of
/// where you have been rather than a score — Rule #4.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.current,
    required this.visited,
    required this.color,
    required this.onToneMuted,
  });

  final int count;
  final int current;
  final Set<int> visited;
  final Color color;
  final Color onToneMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isCurrent = i == current;
        final isVisited = visited.contains(i);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 6),
          width: isCurrent ? 22 : 7,
          height: 4,
          decoration: BoxDecoration(
            color: isCurrent
                ? color
                : isVisited
                    ? color.withValues(alpha: 0.55)
                    : onToneMuted.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ONE LAYER
// ══════════════════════════════════════════════════════════════════════

class _LayerBody extends StatelessWidget {
  const _LayerBody({
    required this.layer,
    required this.layerIndex,
    required this.layerCount,
    required this.layerLabel,
    required this.isLastLayer,
    required this.onBeginQuiz,
  });

  final DiscoverLayer layer;
  final int layerIndex;
  final int layerCount;
  final String layerLabel;
  final bool isLastLayer;
  final VoidCallback? onBeginQuiz;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "LAYER 1 OF 5" in an outlined pill, with the hairline running out to
        // the right margin — the mockup's one horizontal line on this screen.
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
                border: Border.all(
                  color: p.accentText.withValues(alpha: 0.45),
                  width: MizanGeometry.hairlineWidth,
                ),
              ),
              child: Text(
                'LAYER ${layerIndex + 1} OF $layerCount',
                style: MizanType.sectionLabel(color: p.accentText),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: MizanRule(color: p.hairline)),
          ],
        ),
        const SizedBox(height: 22),

        Text(layer.title, style: MizanType.screenTitle(color: p.ink)),
        const SizedBox(height: 10),
        // The teaser is the one italic line on the page.
        Text(layer.subtitle, style: MizanType.translation(color: p.muted)),
        const SizedBox(height: 18),

        _CitationChips(layer: layer),
        const SizedBox(height: 22),

        // Kept as-is: this widget already handles paragraph rhythm and the
        // moment label, and it now paints Mizan colours through the shared
        // token bridge.
        NarrativeText(
          content: layer.content,
          accent: p.accentText,
          momentLabel: layerLabel,
        ),
        const SizedBox(height: 22),
        ReflectionCard(subtitle: layer.subtitle, accent: p.accentText),

        if (isLastLayer && onBeginQuiz != null) ...[
          const SizedBox(height: 30),
          MizanButton(
            label: 'Begin the questions',
            icon: Icons.quiz_outlined,
            kind: MizanButtonKind.primary,
            expand: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onBeginQuiz!();
            },
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

/// The references for this layer, plus the named source. Each chip is a claim
/// about where the words came from, which is the whole point of them.
///
/// Stacked full width rather than wrapped side by side, and this is deliberate:
/// a citation is somebody else's sentence, so its length is not ours to predict.
/// "Quran 9:40 — 'the second of the two, when they were in the cave'" is a
/// perfectly ordinary reference that ran 156px past the screen edge as a pill.
/// A full-width row cannot overflow horizontally — the text simply wraps — so
/// no citation has to be shortened, guessed at, or clipped to fit the layout.
class _CitationChips extends StatelessWidget {
  const _CitationChips({required this.layer});

  final DiscoverLayer layer;

  @override
  Widget build(BuildContext context) {
    final source = layer.source.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (layer.quranRef != null)
          _Chip(
            icon: Icons.menu_book_outlined,
            text: layer.quranRef!,
            // The Quran reference is the primary one, so it takes the filled
            // navy pill and the others stay outlined.
            filled: true,
          ),
        if (layer.hadithRef != null) ...[
          const SizedBox(height: 10),
          _Chip(icon: Icons.format_quote_rounded, text: layer.hadithRef!),
        ],
        if (source.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Chip(
            icon: Icons.verified_outlined,
            text: source,
            // Sage, the palette's one "sourced" colour — this chip is not an
            // accent, it is a provenance mark.
            useSage: true,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    this.filled = false,
    this.useSage = false,
  });

  final IconData icon;
  final String text;
  final bool filled;
  final bool useSage;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    if (filled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: p.isLight ? p.ink : p.card,
          borderRadius: MizanGeometry.rowBorderRadius,
          border: Border.all(
            color: p.accent.withValues(alpha: 0.36),
            width: MizanGeometry.hairlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gold glyph on a navy fill — exactly where gold is free to go.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 17, color: p.accent),
              ),
              const SizedBox(width: 9),
              // Expanded, not Flexible: the row owns the full width, so the
              // citation wraps instead of running off the screen.
              Expanded(
                child: Text(
                  text,
                  style: MizanType.bodyStrong(
                    color: MizanTone.inverse.onColor(p),
                  ).copyWith(fontSize: 14.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final color = useSage ? p.sage : p.muted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: MizanGeometry.rowBorderRadius,
        border: Border.all(color: p.hairline, width: MizanGeometry.hairlineWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: MizanType.body(color: p.ink)
                    .copyWith(fontSize: 14.5, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
