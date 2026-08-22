library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/discover/models/discover_models.dart';
import 'narrative_text.dart';
import 'pill_layer_navigation.dart';

/// One scaffold for every "5 layers + quiz" Discover detail screen —
/// Prophet, Sahabi, Seerah, Divine Name. Previously each screen duplicated
/// ~250 lines of near-identical layout; now a visual upgrade (motion,
/// progress dots, paragraph typography) lands on all four at once instead
/// of being rebuilt four times.
class LayerStoryScaffold extends StatefulWidget {
   LayerStoryScaffold({
    super.key,
    required this.layers,
    required this.navLabels,
    required this.headerTitle,
    required this.headerSubtitle,
    this.headerTrailing,
    Color? backgroundColor,
    Color? accent,
    this.onBeginQuiz,
    this.onShare,
    this.initialLayer = 0,
  })  : _accent = accent, _backgroundColor = backgroundColor;

  final List<DiscoverLayer> layers;
  final List<String> navLabels;

  /// Large Arabic/display title in the header (e.g. entry.nameArabic).
  final String headerTitle;

  /// One-line subtitle under the title (e.g. "Adam — The First Human").
  final String headerSubtitle;

  /// Optional small trailing label in the header (e.g. "#12").
  final String? headerTrailing;

  final Color? _backgroundColor;

  Color get backgroundColor => _backgroundColor ?? AppColors.night;
  final Color? _accent;

  Color get accent => _accent ?? AppColors.gold;

  /// Called when "Begin Quiz" is tapped on the final layer. Null hides it.
  final VoidCallback? onBeginQuiz;

  /// Called when the header share button is tapped. Null hides the button.
  /// Wired to the share-target sheet so a story can be shared into a circle or
  /// to Al-Minbar. One hook here gives all four Discover screens a share action.
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

  @override
  Widget build(BuildContext context) {
    final layer =
        _currentLayer < widget.layers.length ? widget.layers[_currentLayer] : null;
    final isLastLayer = _currentLayer == widget.layers.length - 1;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: widget.headerTitle,
              subtitle: widget.headerSubtitle,
              trailing: widget.headerTrailing,
              accent: widget.accent,
              onShare: widget.onShare,
              progressCount: widget.layers.length,
              progressCurrent: _currentLayer,
              progressVisited: _visited,
            ),
            Expanded(
              child: layer == null
                  ? const SizedBox()
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
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: _LayerBody(
                          layer: layer,
                          layerIndex: _currentLayer,
                          layerLabel: widget.navLabels.length > _currentLayer
                              ? widget.navLabels[_currentLayer]
                              : layer.title,
                          accent: widget.accent,
                          isLastLayer: isLastLayer,
                          onBeginQuiz: widget.onBeginQuiz,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PillLayerNavigation(
        labels: widget.navLabels,
        selectedIndex: _currentLayer,
        accent: widget.accent,
        onSelected: _goTo,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.accent,
    required this.onShare,
    required this.progressCount,
    required this.progressCurrent,
    required this.progressVisited,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final Color accent;
  final VoidCallback? onShare;
  final int progressCount;
  final int progressCurrent;
  final Set<int> progressVisited;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: accent, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.arabicDisplay(color: accent, size: 26)),
                Text(subtitle,
                    style: AppTypography.bodySmall(color: AppColors.muted)),
                const SizedBox(height: 8),
                _ProgressDots(
                  count: progressCount,
                  current: progressCurrent,
                  visited: progressVisited,
                  accent: accent,
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!,
                style: AppTypography.labelSmall(
                    color: AppColors.muted.withValues(alpha: 0.4))),
          if (onShare != null)
            IconButton(
              icon: Icon(Icons.share_rounded, color: accent, size: 20),
              tooltip: 'Share',
              onPressed: onShare,
            ),
        ],
      ),
    );
  }
}

/// A row of small dots showing which layers have been visited — a quiet
/// sense of "I'm making my way through this story" instead of an
/// undifferentiated tab strip.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.current,
    required this.visited,
    required this.accent,
  });

  final int count;
  final int current;
  final Set<int> visited;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isCurrent = i == current;
        final isVisited = visited.contains(i);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 6),
          width: isCurrent ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isCurrent
                ? accent
                : isVisited
                    ? accent.withValues(alpha: 0.55)
                    : accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _LayerBody extends StatelessWidget {
  const _LayerBody({
    required this.layer,
    required this.layerIndex,
    required this.layerLabel,
    required this.accent,
    required this.isLastLayer,
    required this.onBeginQuiz,
  });

  final DiscoverLayer layer;
  final int layerIndex;
  final String layerLabel;
  final Color accent;
  final bool isLastLayer;
  final VoidCallback? onBeginQuiz;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text('Layer ${layerIndex + 1}',
                style: AppTypography.labelSmall(color: accent)),
          ),
        ]),
        const SizedBox(height: 16),
        Text(layer.title,
            style: AppTypography.displayMedium(color: AppColors.parchment)),
        const SizedBox(height: 6),
        Text(layer.subtitle,
            style: AppTypography.quoteItalic(color: AppColors.muted)),
        const SizedBox(height: 20),
        Container(height: 1, color: accent.withValues(alpha: 0.15)),
        const SizedBox(height: 20),
        if (layer.quranRef != null) ...[
          _RefChip(
            icon: Icons.menu_book_rounded,
            text: layer.quranRef!,
            color: accent,
            background: accent.withValues(alpha: 0.08),
            border: accent.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
        ],
        if (layer.hadithRef != null) ...[
          _RefChip(
            icon: Icons.format_quote_rounded,
            text: layer.hadithRef!,
            color: AppColors.muted,
            background: AppColors.slate,
            border: accent.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
        ],
        NarrativeText(
          content: layer.content,
          accent: accent,
          momentLabel: layerLabel,
        ),
        const SizedBox(height: 20),
        ReflectionCard(subtitle: layer.subtitle, accent: accent),
        const SizedBox(height: 20),
        Row(children: [
           Icon(Icons.info_outline_rounded, size: 12, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(
              child: Text(layer.source,
                  style: AppTypography.labelSmall(
                      color: AppColors.muted.withValues(alpha: 0.6)),
                  overflow: TextOverflow.ellipsis)),
        ]),
        if (isLastLayer && onBeginQuiz != null) ...[
          const SizedBox(height: 32),
          _BeginQuizButton(accent: accent, onTap: onBeginQuiz!),
        ],
        const SizedBox(height: 100),
      ],
    );
  }
}

class _RefChip extends StatelessWidget {
  const _RefChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Flexible(
            child: Text(text,
                style: AppTypography.labelSmall(color: color),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _BeginQuizButton extends StatefulWidget {
  const _BeginQuizButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  State<_BeginQuizButton> createState() => _BeginQuizButtonState();
}

class _BeginQuizButtonState extends State<_BeginQuizButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Center(
            child: Text('Begin Quiz',
                style: AppTypography.labelLarge(color: Colors.black)),
          ),
        ),
      ),
    );
  }
}
