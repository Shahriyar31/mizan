library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/knowledge/entity_ref.dart';
import '../../core/knowledge/reference_parser.dart';
import '../../core/theme/mizan_tokens.dart';
import '../../core/theme/mizan_typography.dart';
import '../../features/discover/models/discover_models.dart';
import '../../features/discover/providers/discover_providers.dart';
import '../../features/knowledge/presentation/widgets/connected_sections.dart';
import '../../features/knowledge/presentation/widgets/evidence_view.dart';
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
///
/// ── One layer at a time ────────────────────────────────────────────────
/// The layer pills used to let you jump anywhere in the story from the moment it
/// opened, and nothing recorded that you had read anything — so a five-layer
/// story was really a five-tab article, and the progress rail on Home sat at
/// "01 / 05" forever because the table behind it was never written to.
///
/// Now, when [progress] is supplied, the story opens one layer at a time and the
/// key to the next layer is finishing the current one: read to the end, press
/// Continue, and the next pill unlocks. Layers already opened stay freely
/// reachable — going back to re-read layer 2 is not a step backwards and cannot
/// close anything behind you. Reopening the story lands on the furthest layer you
/// reached rather than starting over.
///
/// A time gate was considered for this and rejected. "Come back tomorrow for
/// layer 2" makes the app the thing that decides when you may learn, and it
/// punishes a reader who has an hour tonight and none tomorrow. Finishing is
/// something the reader does; a clock is something done to them.
///
/// This is Discover's rule alone. The Qur'an reader and the hadith sections are
/// never sequenced — any ayah and any narration is open at any time.
///
/// It is also not a score. The gate records order, not merit: nothing here
/// totals, ranks or grades, so Rule #4 holds.
class LayerStoryScaffold extends ConsumerStatefulWidget {
  const LayerStoryScaffold({
    super.key,
    required this.layers,
    required this.navLabels,
    required this.headerTitle,
    required this.headerSubtitle,
    this.headerTrailing,
    this.onBeginQuiz,
    this.onShare,
    this.entityRef,
    this.progress,
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
  ///
  /// Reaching the final layer now requires having finished the ones before it, so
  /// the quiz is gated by construction — there is no separate check for it.
  final VoidCallback? onBeginQuiz;

  /// Called when the hero's share button is tapped. Null hides the button. One
  /// hook here gives all four Discover screens a share action.
  final VoidCallback? onShare;

  /// This story's node in the knowledge graph. Supplying it appends the
  /// connected sections to the final layer — the people, verses, hadith,
  /// themes, events and places this story shares sources with.
  ///
  /// Null leaves the screen exactly as it was, so a caller that has no ref
  /// loses nothing. Deliberately on the last layer only: the block belongs at
  /// the end of the story, not five times over, and asking the graph once per
  /// screen instead of once per layer keeps the tab switches instant.
  final EntityRef? entityRef;

  /// This story's saved progress. Supplying it turns the completion gate on, and
  /// carries the entry id and section this screen writes progress back to — so
  /// the position shown and the position written can never disagree.
  ///
  /// Resolve it *before* building this widget. The row loads asynchronously and
  /// the layer to open on is fixed when the state is created, so handing it in
  /// late would land every reader on layer 1 and only then discover they were on
  /// layer 4.
  ///
  /// Null leaves every layer open, which is the right default for a caller with
  /// nothing to record against — better than a screen locked to layer 1 with no
  /// way forward.
  final DiscoverProgress? progress;

  /// Where to open when there is no [progress] to resume from.
  final int initialLayer;

  @override
  ConsumerState<LayerStoryScaffold> createState() =>
      _LayerStoryScaffoldState();
}

class _LayerStoryScaffoldState extends ConsumerState<LayerStoryScaffold> {
  late int _currentLayer = _resumeIndex();
  late final Set<int> _visited = {_currentLayer};

  /// How many layers may be opened, counting from the first. Held locally as
  /// well as persisted so pressing Continue unlocks the next pill in the same
  /// frame instead of after a round trip to sqflite.
  late int _unlocked = _initialUnlocked();

  bool get _gated => widget.progress != null;

  int _resumeIndex() {
    final total = widget.layers.length;
    if (total <= 1) return 0;
    final resume = widget.progress?.resumeIndex(total) ?? widget.initialLayer;
    return resume.clamp(0, total - 1);
  }

  int _initialUnlocked() {
    final total = widget.layers.length;
    if (total == 0) return 0;
    final stored = widget.progress?.layersUnlocked;
    // No progress row means nothing is sequenced: open the whole story.
    if (stored == null) return total;
    return stored.clamp(1, total);
  }

  void _goTo(int index) {
    if (index == _currentLayer) return;
    if (index >= _unlocked) {
      // Locked. The pill is drawn locked and refuses the tap itself, so this is
      // a backstop for any other caller rather than the path a reader hits.
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _currentLayer = index;
      _visited.add(index);
    });
  }

  /// The reader finished this layer. Opens the next one and moves to it.
  Future<void> _advance() async {
    final total = widget.layers.length;
    final next = _currentLayer + 1;
    if (next >= total) return;

    HapticFeedback.mediumImpact();
    setState(() {
      if (_unlocked < next + 1) _unlocked = next + 1;
      _currentLayer = next;
      _visited.add(next);
    });

    // Persisted after the move rather than before it. The reader has finished
    // this layer whether or not the write lands, and making them wait on a
    // database to turn a page is the worse trade; if the write fails they lose a
    // saved position, not the page they are reading.
    final progress = widget.progress;
    if (progress == null) return;
    await ref
        .read(discoverProgressProviderFor(progress.entryType).notifier)
        .recordLayerRead(
          progress.entryId,
          layerIndex: next - 1,
          layerCount: total,
        );
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
    final total = widget.layers.length;
    final layer = _currentLayer < total ? widget.layers[_currentLayer] : null;
    final isLastLayer = _currentLayer == total - 1;

    // The dots record where the reader has been. On a gated story that is the
    // persisted reach, so a story resumed at layer 4 shows 1–4 lit instead of
    // pretending this session began there.
    final reached =
        _gated ? {for (var i = 0; i < _unlocked; i++) i} : _visited;

    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          _Hero(
            title: widget.headerTitle,
            subtitle: widget.headerSubtitle,
            trailing: widget.headerTrailing,
            layerCount: total,
            readingMinutes: _readingMinutes,
            onShare: widget.onShare,
            current: _currentLayer,
            visited: reached,
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
                    // Keyed on the layer, so each layer gets a fresh scroll view
                    // and therefore starts at the top of its own text.
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
                        layerCount: total,
                        layerLabel: widget.navLabels.length > _currentLayer
                            ? widget.navLabels[_currentLayer]
                            : layer.title,
                        isLastLayer: isLastLayer,
                        onBeginQuiz: widget.onBeginQuiz,
                        onContinue: isLastLayer ? null : _advance,
                        nextLabel: widget.navLabels.length > _currentLayer + 1
                            ? widget.navLabels[_currentLayer + 1]
                            : null,
                        nextIsLocked: _currentLayer + 1 >= _unlocked,
                        entityRef: isLastLayer ? widget.entityRef : null,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: PillLayerNavigation(
        labels: widget.navLabels,
        selectedIndex: _currentLayer,
        // Everything from here on is still to be earned. Ungated stories pass
        // the full count, so every pill stays open.
        unlockedCount: _unlocked,
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
    required this.onContinue,
    required this.nextLabel,
    required this.nextIsLocked,
    required this.entityRef,
  });

  final DiscoverLayer layer;
  final int layerIndex;
  final int layerCount;
  final String layerLabel;
  final bool isLastLayer;
  final VoidCallback? onBeginQuiz;

  /// Finishes this layer and opens the next. Null on the final layer, where the
  /// quiz is the way forward.
  final VoidCallback? onContinue;

  /// The name of the layer [onContinue] opens, so the button says what it does.
  final String? nextLabel;

  /// Whether the next layer is still shut. False when the reader is re-reading a
  /// layer of a story they have already been further into — in which case saying
  /// "layer 3 opens when you continue" would be untrue.
  final bool nextIsLocked;

  final EntityRef? entityRef;

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

        // The way forward, at the end of the layer. Deliberately here and not in
        // the pill bar: reaching it means having scrolled through the layer, and
        // "finished reading" is the one thing the gate is entitled to infer.
        if (onContinue != null) ...[
          const SizedBox(height: 30),
          MizanButton(
            label: nextLabel == null ? 'Continue' : 'Continue — $nextLabel',
            trailingIcon: Icons.arrow_forward_rounded,
            kind: MizanButtonKind.primary,
            expand: true,
            onPressed: onContinue!,
          ),
          const SizedBox(height: 10),
          if (nextIsLocked)
            Text(
              'Layer ${layerIndex + 2} of $layerCount opens when you continue.',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
            ),
        ],

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
        // The graph, at the end of the story. Renders nothing when this entity
        // has no neighbours, so the layout above is untouched either way.
        if (entityRef != null) ConnectedSections(entityRef: entityRef!),
        const SizedBox(height: 40),
      ],
    );
  }
}

/// The references for this layer, plus the named source. Each row is a claim
/// about where the words came from, which is the whole point of them.
///
/// Stacked full width rather than wrapped side by side, and this is deliberate:
/// a citation is somebody else's sentence, so its length is not ours to predict.
/// "Quran 9:40 — 'the second of the two, when they were in the cave'" is a
/// perfectly ordinary reference that ran 156px past the screen edge as a pill.
/// A full-width row cannot overflow horizontally — the text simply wraps — so
/// no citation has to be shortened, guessed at, or clipped to fit the layout.
///
/// The rows now open. Same geometry, same colours, same order — a Qur'an ref
/// still takes the one filled row and the source still carries the sage
/// provenance mark — but tapping one shows the ayah with its translation, or
/// the hadith with its narrator and grade, or the tafsir passage itself. That is
/// Evidence Mode: a citation you cannot check is a claim, and this app's whole
/// premise is that it does not make unchecked claims.
///
/// Parsed through [ReferenceParser], the same parser the graph is built with, so
/// what a reader can tap is exactly what the graph reasoned over. The raw source
/// string always survives as its own row, so nothing the corpus wrote is lost to
/// a parse.
class _CitationChips extends StatelessWidget {
  const _CitationChips({required this.layer});

  final DiscoverLayer layer;

  @override
  Widget build(BuildContext context) {
    return EvidenceRows(
      evidence: ReferenceParser.parseLayer(
        quranRef: layer.quranRef,
        hadithRef: layer.hadithRef,
        source: layer.source,
      ),
      showLabel: false,
    );
  }
}
