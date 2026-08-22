/// Layer Screen — Friday release version
/// Tab bar at bottom, all layers unlocked, reflection gates next ayah
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/layer_providers.dart';
import '../data/layer_content.dart';
import '../data/surah_metadata.dart';
import '../models/layer_unlock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class LayerScreen extends ConsumerStatefulWidget {
  const LayerScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.arabicText,
    required this.translation,
  });

  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final String arabicText;
  final String translation;

  @override
  ConsumerState<LayerScreen> createState() => _LayerScreenState();
}

class _LayerScreenState extends ConsumerState<LayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;
  String get _ayahKey => '${widget.surahNumber}:${widget.ayahNumber}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentKey =
        '$_ayahKey|||${widget.arabicText}|||${widget.translation}';
    final contentAsync = ref.watch(layerContentProvider(contentKey));
    final content = contentAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.cardQuranBg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _buildHeader(context),

          // ── Tab content ──────────────────────────────────────
          Expanded(
            child: contentAsync.when(
              loading: () =>  Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              ),
              error: (_, __) => _buildTabViews(null),
              data: (c) => _buildTabViews(c),
            ),
          ),

          // ── Tab bar at BOTTOM ────────────────────────────────
          _buildBottomTabBar(),
        ],
      ),
    );
  }

  Widget _buildTabViews(LayerData? content) {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _WordsLayer(content: content),
        _ContextLayer(content: content, surahNumber: widget.surahNumber),
        _ScholarsLayer(content: content),
        _IsnadLayer(content: content),
        _ReflectionLayer(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          ayahKey: _ayahKey,
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.cardQuranBg,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child:  Icon(Icons.close_rounded,
                    color: AppColors.muted, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '${widget.surahName} ${widget.surahNumber}:${widget.ayahNumber}',
                style: AppTypography.labelMedium(color: AppColors.muted),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.jade.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('5 Layers',
                    style: AppTypography.caption(color: AppColors.jade)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.arabicText,
            style: AppTypography.arabicBody(color: AppColors.textPrimary),
            textDirection: ui.TextDirection.rtl,
          ),
          const SizedBox(height: 6),
          Text(
            widget.translation,
            style: AppTypography.quoteItalic(color: AppColors.quranMuted),
          ),
           Divider(color: AppColors.quranSurface, height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomTabBar() {
    return Container(
      decoration:  BoxDecoration(
        color: AppColors.quranSurfaceDim,
        border: Border(top: BorderSide(color: AppColors.quranSurface, width: 1)),
      ),
      padding: EdgeInsets.only(
        bottom: 12,
        top: 8,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(5, (index) {
            final isActive = _currentTab == index;
            final isReflection = index == 4;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!isActive) HapticFeedback.selectionClick();
                  _tabController.animateTo(index);
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Active indicator dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 20 : 0,
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isReflection && isActive
                            ? AppColors.jade
                            : AppColors.gold,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      key: ValueKey('tab-icon-$index-$isActive'),
                      tween: Tween(begin: isActive ? 0.6 : 1.0, end: 1.0),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Text(
                        LayerMeta.icons[index],
                        style: TextStyle(fontSize: isActive ? 22 : 18),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LayerMeta.names[index],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? (isReflection ? AppColors.jade : AppColors.gold)
                            : AppColors.muted,
                        fontFamily: 'Inter',
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Words Layer ───────────────────────────────────────────────
class _WordsLayer extends StatefulWidget {
  const _WordsLayer({required this.content});
  final LayerData? content;

  @override
  State<_WordsLayer> createState() => _WordsLayerState();
}

class _WordsLayerState extends State<_WordsLayer> {
  final Set<int> _revealed = {};

  @override
  Widget build(BuildContext context) {
    if (widget.content == null) return _NoCuratedContent(layerIndex: 0);

    final wordsText = widget.content!.words;
    final wordLines =
        wordsText.split('\n').where((l) => l.contains(' — ')).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Word by word',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Tap each word to reveal its meaning',
              style: AppTypography.bodySmall(color: AppColors.muted)),
          const SizedBox(height: 20),
          if (wordLines.isNotEmpty)
            ...List.generate(wordLines.length, (i) {
              final parts = wordLines[i].split(' — ');
              final arabic = parts[0].trim();
              final meaning = parts.length > 1 ? parts[1].trim() : '';
              final isRevealed = _revealed.contains(i);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(
                      () => isRevealed ? _revealed.remove(i) : _revealed.add(i));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isRevealed
                        ? AppColors.jade.withValues(alpha: 0.12)
                        : AppColors.quranSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRevealed
                          ? AppColors.jade.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: isRevealed
                        ? Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  arabic,
                                  style:  TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 24,
                                    color: AppColors.gold,
                                    height: 1.6,
                                  ),
                                  textDirection: ui.TextDirection.rtl,
                                ),
                              ),
                              Container(
                                  width: 1,
                                  height: 40,
                                  color: AppColors.quranBorder),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  meaning,
                                  style: AppTypography.bodyMedium(
                                      color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                arabic,
                                style: TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 24,
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  height: 1.6,
                                ),
                                textDirection: ui.TextDirection.rtl,
                              ),
                               Icon(Icons.touch_app_rounded,
                                  color: AppColors.muted, size: 18),
                            ],
                          ),
                  ),
                ),
              );
            })
          else
            _RichArabicText(text: wordsText),
          const SizedBox(height: 24),
          _TomorrowTeaser(
              text: widget.content!.tomorrowTeasers.isNotEmpty
                  ? widget.content!.tomorrowTeasers[0]
                  : ''),
        ],
      ),
    );
  }
}

// ── Context Layer ─────────────────────────────────────────────
class _ContextLayer extends StatelessWidget {
  const _ContextLayer({required this.content, required this.surahNumber});
  final LayerData? content;
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    if (content == null) return _NoCuratedContent(layerIndex: 1);

    // Get structured metadata for this surah
    final meta = SurahMetadata.get(surahNumber);
    final location = meta?.location ?? '';
    final period = meta?.period ?? '';
    final theme = meta?.theme ?? '';

    // Body text is Ibn Kathir's commentary — used as scene description
    final bodyText = content!.context.isNotEmpty
        ? content!.context
        : 'Historical context for this ayah is being prepared.';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Context',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          if (theme.isNotEmpty)
            Text(theme, style: AppTypography.bodySmall(color: AppColors.muted)),
          const SizedBox(height: 20),

          // ── Two stat pills ───────────────────────────────────
          if (location.isNotEmpty || period.isNotEmpty)
            Row(
              children: [
                if (location.isNotEmpty)
                  Expanded(
                    child: _StatPill(
                      label: 'REVEALED IN',
                      value: location,
                      emoji: '🕌',
                      gradientColors: location == 'Madinah'
                          ? [const Color(0xFF0D2A24), const Color(0xFF1A3530)]
                          : [const Color(0xFF1A1A0D), const Color(0xFF2A2510)],
                      borderColor: location == 'Madinah'
                          ? AppColors.jade
                          : AppColors.gold,
                    ),
                  ),
                if (location.isNotEmpty && period.isNotEmpty)
                  const SizedBox(width: 12),
                if (period.isNotEmpty)
                  Expanded(
                    child: _StatPill(
                      label: 'PERIOD',
                      value: period,
                      emoji: '📅',
                      gradientColors: [
                        const Color(0xFF1A1525),
                        const Color(0xFF251A35),
                      ],
                      borderColor: const Color(0xFF7B5EA7),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // ── Scene description — what was happening at revelation ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.quranSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About this Surah',
                    style: AppTypography.caption(color: AppColors.gold)
                        .copyWith(letterSpacing: 0.8)),
                const SizedBox(height: 10),
                Text(
                  theme.isNotEmpty ? theme : content!.context,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(height: 1.7),
                ),
                if (content!.context.isNotEmpty && theme.isNotEmpty) ...[
                  const SizedBox(height: 14),
                   Divider(color: AppColors.quranBorder),
                  const SizedBox(height: 14),
                  Text("Ibn Kathir's Introduction",
                      style: AppTypography.caption(color: AppColors.muted)
                          .copyWith(letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  _ParagraphFlow(
                    text: _contextIntro(content!.context),
                    style: AppTypography.bodySmall(color: AppColors.textPrimary)
                        .copyWith(height: 1.7),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          _TomorrowTeaser(
              text: content!.tomorrowTeasers.length > 1
                  ? content!.tomorrowTeasers[1]
                  : ''),
        ],
      ),
    );
  }
}

// ── Context intro helper ─────────────────────────────────────
String _contextIntro(String fullText) {
  // Return first 2 paragraphs of Ibn Kathir as the intro
  final paragraphs = fullText
      .split('\n\n')
      .where((p) => p.trim().length > 50)
      .take(2)
      .join('\n\n');
  return paragraphs.isNotEmpty
      ? paragraphs
      : fullText.substring(0, fullText.length.clamp(0, 400));
}

// ── Stat Pill ─────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.emoji,
    required this.gradientColors,
    required this.borderColor,
  });

  final String label;
  final String value;
  final String emoji;
  final List<Color> gradientColors;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption(color: AppColors.muted)
                  .copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value,
                    style: AppTypography.labelLarge(color: AppColors.white)
                        .copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Scholars Layer ────────────────────────────────────────────
class _ScholarsLayer extends StatefulWidget {
  const _ScholarsLayer({required this.content});
  final LayerData? content;

  @override
  State<_ScholarsLayer> createState() => _ScholarsLayerState();
}

class _ScholarsLayerState extends State<_ScholarsLayer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.content == null) return _NoCuratedContent(layerIndex: 2);
    final scholar = widget.content!.scholars;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scholar insight',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 20),

          // Scholar card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.quranSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    // Was a malformed 5-byte hex literal (0xFF5B21B622,
                    // overflowing 32-bit ARGB) — this is what it was
                    // clearly meant to be: violet at ~13% opacity.
                    color: AppColors.violetDim.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🎓', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scholar.scholarName,
                          style:
                              AppTypography.labelLarge(color: AppColors.textPrimary)),
                      Text('${scholar.scholarEra} · ${scholar.work}',
                          style: AppTypography.caption()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Key insight
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.quranSurface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border(left: BorderSide(color: AppColors.violet, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡  Key insight',
                    style: AppTypography.caption(color: AppColors.jade)),
                const SizedBox(height: 10),
                _ParagraphFlow(
                  text: _expanded
                      ? scholar.insight
                      : (scholar.insight.length > 500
                          ? scholar.insight.substring(0, 500)
                          : scholar.insight),
                  style: AppTypography.bodyMedium(
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          if (scholar.arabicQuote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                scholar.arabicQuote,
                style:  TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  color: AppColors.gold,
                  height: 1.9,
                ),
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
            ),
          ],
          if (scholar.insight.length > 500) ...[
            // Continuation shown directly after preview — no gap
            // Continuation now inside the single card above — nothing here
            // Button always at the very bottom — after all content
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.quranSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _expanded ? 'Show less ▲' : 'Read full commentary ▼',
                    style: AppTypography.labelMedium(color: AppColors.jade),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _TomorrowTeaser(
              text: widget.content!.tomorrowTeasers.length > 2
                  ? widget.content!.tomorrowTeasers[2]
                  : ''),
        ],
      ),
    );
  }
}

// ── Isnad Layer ───────────────────────────────────────────────
class _IsnadLayer extends StatelessWidget {
  const _IsnadLayer({required this.content});
  final LayerData? content;

  @override
  Widget build(BuildContext context) {
    if (content == null) return _NoCuratedContent(layerIndex: 3);
    final isnad = content!.isnad;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hadith & narration',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          if (isnad.hadithText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.quranSurface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border(left: BorderSide(color: AppColors.gold, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${isnad.hadithText}"',
                      style: AppTypography.quoteItalic(color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (isnad.narrator.isNotEmpty)
                        Expanded(
                          child: Text('— ${isnad.narrator}',
                              style: AppTypography.caption()),
                        ),
                      if (isnad.grade.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.jade.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(isnad.grade,
                              style:
                                  AppTypography.caption(color: AppColors.jade)),
                        ),
                    ],
                  ),
                  if (isnad.collection.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(isnad.collection,
                        style: AppTypography.caption(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.quranSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'The narrations for this ayah are embedded within '
                'Ibn Kathir\'s full commentary in the Scholars layer. '
                'The chain of transmission for Al-Baqarah traces back '
                'through the companions of the Prophet ﷺ.',
                style: AppTypography.bodyMedium(color: AppColors.quranMuted),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _TomorrowTeaser(
              text: content!.tomorrowTeasers.length > 3
                  ? content!.tomorrowTeasers[3]
                  : ''),
        ],
      ),
    );
  }
}

// ── Reflection Layer — THE GATE ───────────────────────────────
class _ReflectionLayer extends ConsumerStatefulWidget {
  const _ReflectionLayer({
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahKey,
  });
  final int surahNumber;
  final int ayahNumber;
  final String ayahKey;

  @override
  ConsumerState<_ReflectionLayer> createState() => _ReflectionLayerState();
}

class _ReflectionLayerState extends ConsumerState<_ReflectionLayer> {
  late TextEditingController _controller;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reflectionAsync = ref.watch(reflectionProvider(widget.ayahKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Your reflection',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Private — only you will ever read this.',
              style: AppTypography.bodySmall(color: AppColors.muted)),
          const SizedBox(height: 20),

          // Gate explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.jade.withValues(alpha: 0.16),
                  AppColors.jade.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.jade.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✍️  Complete this ayah',
                    style: AppTypography.labelLarge(color: AppColors.jade)),
                const SizedBox(height: 8),
                Text(
                  'You have read the words, the context, the scholars, '
                  'and the narrations. Write one sentence — what does '
                  'this ayah mean for your life right now?',
                  style:
                      AppTypography.bodySmall(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          reflectionAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (existing) {
              if (existing != null && _controller.text.isEmpty) {
                _controller.text = existing;
                _saved = true;
              }
              return Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    style: AppTypography.bodyMedium(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          'Write your reflection here — even one sentence is enough...',
                      hintStyle:
                          AppTypography.bodySmall(color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.quranSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                             BorderSide(color: AppColors.jade, width: 1.5),
                      ),
                    ),
                    onChanged: (_) => setState(() => _saved = false),
                  ),
                  const SizedBox(height: 14),

                  // Save button — this completes the ayah
                  GestureDetector(
                    onTap: () async {
                      if (_controller.text.trim().isEmpty) {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Write at least one sentence to complete this ayah',
                              style: AppTypography.bodySmall(
                                  color: AppColors.white),
                            ),
                            backgroundColor: AppColors.muted,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        return;
                      }
                      final repo = ref.read(layerRepositoryProvider);
                      await repo.saveReflection(
                        widget.surahNumber,
                        widget.ayahNumber,
                        _controller.text.trim(),
                      );
                      ref.invalidate(reflectionProvider(widget.ayahKey));
                      HapticFeedback.mediumImpact();
                      setState(() => _saved = true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _saved ? AppColors.jade : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _saved
                              ? AppColors.jade
                              : AppColors.jade.withValues(alpha: 0.5),
                          width: _saved ? 0 : 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _saved
                                ? Icons.check_circle_rounded
                                : Icons.edit_rounded,
                            color: _saved ? AppColors.white : AppColors.jade,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _saved
                                ? 'Reflection saved — ayah complete ✓'
                                : 'Save reflection',
                            style: AppTypography.labelLarge(
                              color: _saved ? AppColors.white : AppColors.jade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_saved) ...[
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      index: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.jade.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.jade.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('🌟', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You have completed this ayah. '
                                'JazakAllah khayran.',
                                style: AppTypography.bodySmall(
                                    color: AppColors.jade),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────

class _RichArabicText extends StatelessWidget {
  const _RichArabicText({required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final segments = _split(text);
    final baseStyle =
        style ?? AppTypography.bodyMedium(color: AppColors.textPrimary);
    return RichText(
      softWrap: true,
      overflow: TextOverflow.visible,
      text: TextSpan(
        children: segments.map((seg) {
          if (seg['type'] == 'arabic') {
            return TextSpan(
              text: '  ${seg['text']}  ',
              style:  TextStyle(
                fontFamily: 'Amiri',
                fontSize: 20,
                color: AppColors.gold,
                height: 1.9,
              ),
            );
          }
          return TextSpan(text: seg['text'], style: baseStyle);
        }).toList(),
      ),
    );
  }

  List<Map<String, String>> _split(String text) {
    final segs = <Map<String, String>>[];
    final pattern =
        RegExp(r'([\u0600-\u06FF][\u0600-\u06FF\s\u064B-\u065F]{2,})');
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last)
        segs.add({'type': 'english', 'text': text.substring(last, m.start)});
      segs.add({'type': 'arabic', 'text': m.group(0)!.trim()});
      last = m.end;
    }
    if (last < text.length)
      segs.add({'type': 'english', 'text': text.substring(last)});
    return segs;
  }
}

/// Splits a long block of Ibn Kathir prose into paragraphs and fades each
/// one in with a short stagger — the same reading rhythm Discover uses,
/// applied here so a long tafsir doesn't land as one dense wall of text.
class _ParagraphFlow extends StatelessWidget {
  const _ParagraphFlow({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          FadeSlideIn(
            index: i,
            child: _RichArabicText(text: paragraphs[i], style: style),
          ),
        ],
      ],
    );
  }
}

class _TomorrowTeaser extends StatelessWidget {
  const _TomorrowTeaser({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardQuranBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🌅', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text('COMING UP',
                style: AppTypography.caption(color: AppColors.gold)),
          ]),
          const SizedBox(height: 8),
          Text(text,
              style: AppTypography.bodySmall(color: AppColors.quranMuted)),
        ],
      ),
    );
  }
}

class _NoCuratedContent extends StatelessWidget {
  const _NoCuratedContent({required this.layerIndex});
  final int layerIndex;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📖', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('${LayerMeta.names[layerIndex]} layer',
                style: AppTypography.labelLarge(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Content for this ayah is being prepared.',
              style: AppTypography.bodySmall(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
