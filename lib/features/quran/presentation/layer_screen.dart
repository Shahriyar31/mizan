/// Layer Screen — Friday release version
/// Tab bar at bottom, all layers unlocked, reflection gates next ayah
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/layer_providers.dart';
import '../domain/tafsir_providers.dart';
import '../data/layer_content.dart';
import '../data/mutashabihat_repository.dart';
import '../data/surah_metadata.dart';
import '../data/tafsir_repository.dart';
import '../data/word_analysis_repository.dart';
import '../models/layer_unlock.dart';
import '../../../core/knowledge/entity_ref.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../home/domain/todays_mizan.dart';
import '../../knowledge/presentation/widgets/connected_sections.dart';

class LayerScreen extends ConsumerStatefulWidget {
  const LayerScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.arabicText,
    required this.translation,
    this.initialLayer = 0,
  });

  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final String arabicText;
  final String translation;

  /// Which layer to open on, as a **storage** index — see [LayerMeta]. The
  /// layers sheet is the only caller that passes anything but the default: the
  /// reader picks a layer there, so landing on Words first and making them find
  /// it again in the tab bar would waste the choice they already made.
  final int initialLayer;

  @override
  ConsumerState<LayerScreen> createState() => _LayerScreenState();
}

class _LayerScreenState extends ConsumerState<LayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Position in the tab bar, not a storage index. [LayerMeta.displayOrder]
  /// converts between the two.
  int _currentTab = 0;

  String get _ayahKey => '${widget.surahNumber}:${widget.ayahNumber}';

  @override
  void initState() {
    super.initState();
    _currentTab =
        LayerMeta.positionOf(widget.initialLayer).clamp(0, LayerMeta.count - 1);
    _tabController = TabController(
      length: LayerMeta.count,
      initialIndex: _currentTab,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
        _recordOpen(LayerMeta.displayOrder[_tabController.index]);
      }
    });
    _recordOpen(widget.initialLayer);
  }

  /// Writes the "this layer was opened" row the unlock schedule is built on.
  ///
  /// Nothing called [LayerRepository.recordUnlock] before the layers sheet
  /// existed, so `layer_unlocks` stayed empty on every device: every layer past
  /// the first read as permanently locked and the sheet would have reported
  /// "0 read" forever. Recording on *arrival* is what the table means — one row
  /// per layer first opened — and the UNIQUE constraint makes the repeat calls
  /// on every tab tap free.
  ///
  /// The states provider is invalidated afterwards so the sheet, which is the
  /// only reader of that cache, recomputes on the way back instead of showing
  /// the counts as they were before this visit.
  Future<void> _recordOpen(int storageIndex) async {
    await ref
        .read(layerRepositoryProvider)
        .recordUnlock(widget.surahNumber, widget.ayahNumber, storageIndex);
    if (!mounted) return;
    ref.invalidate(layerStatesProvider(_ayahKey));

    // Opening a layer is the app's most common act of learning, so this is the
    // busiest input to Today's Mizan — and it costs nothing to call repeatedly,
    // because `mark` returns immediately once the facet is already lit today.
    ref.read(todaysMizanProvider.notifier).mark(MizanFacet.learned);
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
    // Built in display order, so tab position N and view N line up. The switch
    // below is on the storage index, which is what each layer is identified by
    // everywhere else — see LayerMeta.
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final index in LayerMeta.displayOrder) _viewFor(index, content),
      ],
    );
  }

  Widget _viewFor(int storageIndex, LayerData? content) {
    switch (storageIndex) {
      case 0:
        return _WordsLayer(
          content: content,
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        );
      case 1:
        return _ContextLayer(content: content, surahNumber: widget.surahNumber);
      case 2:
        return _ScholarsLayer(
          content: content,
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        );
      case 3:
        return _IsnadLayer(content: content);
      case 5:
        return _SimilarVersesLayer(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        );
      default:
        return _ReflectionLayer(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          ayahKey: _ayahKey,
        );
    }
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
                child: Text('${LayerMeta.count} Layers',
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
    final p = MizanPalette.of(context);
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
          // Walks display order, so `position` is where the tab sits and
          // `index` is the layer it stands for. Six tabs now fit where five did
          // by dropping the label to 8pt and letting it ellipsize rather than
          // overflow — the icon above it carries the recognition.
          children: List.generate(LayerMeta.count, (position) {
            final index = LayerMeta.displayOrder[position];
            final isActive = _currentTab == position;
            final isReflection = index == 4;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!isActive) HapticFeedback.selectionClick();
                  _tabController.animateTo(position);
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
                      child: Icon(
                        LayerMeta.icons[index],
                        // Tokens, because the glyph is no longer an emoji drawn
                        // by the platform font — see [LayerMeta.icons].
                        size: isActive ? 22 : 18,
                        color: isActive ? p.accentText : p.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        LayerMeta.names[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? (isReflection ? AppColors.jade : AppColors.gold)
                              : AppColors.muted,
                          fontFamily: 'Inter',
                          letterSpacing: 0.2,
                        ),
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
//
// Two sources feed this layer, rendered by the same cards:
//
//   • The curated `words` string on [LayerData], written by hand and only for
//     al-Fātihah. Where it exists it is the better text, so it wins.
//   • Per-word morphology from UmmahAPI, which covers the rest of the Qur'an —
//     the 6,229 ayat that used to show "Content for this ayah is being prepared."
//
// Both are normalised to [QuranWord] first so there is one render path, not two.
class _WordsLayer extends ConsumerStatefulWidget {
  const _WordsLayer({
    required this.content,
    required this.surahNumber,
    required this.ayahNumber,
  });

  final LayerData? content;
  final int surahNumber;
  final int ayahNumber;

  @override
  ConsumerState<_WordsLayer> createState() => _WordsLayerState();
}

class _WordsLayerState extends ConsumerState<_WordsLayer> {
  final Set<int> _revealed = {};

  /// Turns one curated `"العربية — meaning"` line into the same shape the API
  /// rows arrive in, so the render loop below never has to know which it got.
  static QuranWord _fromCuratedLine(String line, int position) {
    final parts = line.split(' — ');
    return QuranWord(
      position: position,
      arabic: parts[0].trim(),
      translation: parts.length > 1 ? parts[1].trim() : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final curated = widget.content?.words ?? '';
    final curatedLines =
        curated.split('\n').where((l) => l.contains(' — ')).toList();

    final remote =
        ref.watch(ayahWordsProvider('${widget.surahNumber}:${widget.ayahNumber}'));

    final words = curatedLines.isNotEmpty
        ? [
            for (var i = 0; i < curatedLines.length; i++)
              _fromCuratedLine(curatedLines[i], i + 1),
          ]
        : (remote.value ?? const <QuranWord>[]);

    // Nothing yet and still asking — a spinner rather than an empty state that
    // would be replaced a moment later.
    if (words.isEmpty && curated.trim().isEmpty && remote.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
      );
    }

    if (words.isEmpty && curated.trim().isEmpty) {
      return _NoCuratedContent(layerIndex: 0);
    }

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
          if (words.isNotEmpty)
            ...List.generate(words.length, (i) {
              final word = words[i];
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  word.arabic,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      word.gloss,
                                      style: AppTypography.bodyMedium(
                                          color: AppColors.textPrimary),
                                    ),
                                    // Transliteration and grammar only exist on
                                    // API rows; curated lines skip both.
                                    if (word.transliteration.isNotEmpty &&
                                        word.translation.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(word.transliteration,
                                          style: AppTypography.caption()),
                                    ],
                                    if (word.detail.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(word.detail,
                                          style: AppTypography.caption(
                                              color: AppColors.muted)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                word.arabic,
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
            _RichArabicText(text: curated),
          const SizedBox(height: 24),
          _TomorrowTeaser(
              text: (widget.content?.tomorrowTeasers.isNotEmpty ?? false)
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
//
// Already the layer where classical commentary lives — this adds a source
// switcher above the card it already had, and a second place the text can come
// from. The order is: the selected tafsīr from UmmahAPI, and if that source has
// nothing for this ayah, the bundled commentary the app has always shipped. So
// switching source can add commentary but never take it away.
//
// The switcher stays on screen in the empty case on purpose: a source with
// nothing for this ayah is a reason to offer another one, not a dead end.
class _ScholarsLayer extends ConsumerStatefulWidget {
  const _ScholarsLayer({
    required this.content,
    required this.surahNumber,
    required this.ayahNumber,
  });

  final LayerData? content;
  final int surahNumber;
  final int ayahNumber;

  @override
  ConsumerState<_ScholarsLayer> createState() => _ScholarsLayerState();
}

class _ScholarsLayerState extends ConsumerState<_ScholarsLayer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ayahKey = '${widget.surahNumber}:${widget.ayahNumber}';
    final selected = ref.watch(selectedTafsirProvider);
    final sources =
        ref.watch(tafsirSourcesProvider).value ?? const <TafsirSource>[kBundledTafsir];
    final remote = ref.watch(ayahTafsirProvider(ayahKey));

    final passage = remote.value;
    final curated = widget.content?.scholars;

    // Remote first, bundled second. `passage` is null both while loading and
    // when the source has nothing, which is why the loading check comes before
    // the empty check further down.
    final body = passage?.text ?? curated?.insight ?? '';
    final arabic = passage != null ? passage.arabic : (curated?.arabicQuote ?? '');

    final title = passage?.sourceName ??
        (selected.isBundled ? (curated?.scholarName ?? selected.name) : selected.name);
    final subtitle = passage != null
        ? (passage.author.isNotEmpty ? passage.author : selected.attribution)
        : (curated != null && selected.isBundled
            ? '${curated.scholarEra} · ${curated.work}'
            : selected.attribution);

    final isTruncatable = body.length > 500;
    final shown = _expanded || !isTruncatable ? body : body.substring(0, 500);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scholar insight',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),

          // Only worth a row when there is something to switch between.
          if (sources.length > 1) ...[
            const SizedBox(height: 14),
            _TafsirSourceChips(sources: sources, selectedKey: selected.key),
          ],

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
                      Text(title,
                          style:
                              AppTypography.labelLarge(color: AppColors.textPrimary)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: AppTypography.caption()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (body.isEmpty && arabic.isEmpty)
            _TafsirEmpty(isLoading: remote.isLoading, sourceName: selected.shortName)
          else ...[
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
                    text: shown,
                    style: AppTypography.bodyMedium(
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            if (arabic.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  arabic,
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
            if (isTruncatable) ...[
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
          ],
          const SizedBox(height: 24),
          _TomorrowTeaser(
              text: (widget.content?.tomorrowTeasers.length ?? 0) > 2
                  ? widget.content!.tomorrowTeasers[2]
                  : ''),
        ],
      ),
    );
  }
}

/// The tafsīr switcher — one chip per source, scrolling horizontally so a long
/// catalogue cannot overflow the row.
class _TafsirSourceChips extends ConsumerWidget {
  const _TafsirSourceChips({required this.sources, required this.selectedKey});

  final List<TafsirSource> sources;
  final String selectedKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final source in sources) ...[
            GestureDetector(
              onTap: () {
                if (source.key == selectedKey) return;
                HapticFeedback.selectionClick();
                ref.read(tafsirSourceProvider.notifier).select(source.key);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: source.key == selectedKey
                      ? AppColors.jade.withValues(alpha: 0.15)
                      : AppColors.quranSurface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: source.key == selectedKey
                        ? AppColors.jade.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  source.shortName,
                  style: AppTypography.labelMedium(
                    color: source.key == selectedKey
                        ? AppColors.jade
                        : AppColors.muted,
                  ),
                ),
              ),
            ),
            if (source != sources.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Shown when the selected tafsīr has nothing for this ayah. Deliberately small
/// and inline rather than a full-screen empty state, so the switcher above it
/// stays reachable.
class _TafsirEmpty extends StatelessWidget {
  const _TafsirEmpty({required this.isLoading, required this.sourceName});

  final bool isLoading;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.quranSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              )
            : Text(
                '$sourceName has no commentary on this ayah.',
                style: AppTypography.bodySmall(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
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
                      // Writing about an ayah is the "reflected" facet by
                      // definition. Marked after the save, so the strip never
                      // claims a reflection that failed to persist.
                      ref
                          .read(todaysMizanProvider.notifier)
                          .mark(MizanFacet.reflected);
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

          // Everything in the app that rests on this ayah — the prophets and
          // companions whose stories cite it, the hadith cited beside it, the
          // themes it belongs to. Drawn from the graph, so it appears only
          // where a real citation exists and renders nothing where none does.
          ConnectedSections(
            entityRef: EntityRef.verse(widget.surahNumber, widget.ayahNumber),
            // No "Connected Verses" here: neighbouring ayat are the reader's
            // job, and the reader is one tap away.
            exclude: const {EntityType.verse},
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

// ── Similar Verses Layer (mutashabihat) ───────────────────────
//
// Storage index 5, shown between Isnad and Reflection. See LayerMeta for why
// those two numbers differ.
//
// Tapping a verse closes this sheet and routes to the reader the app already
// has, at that ayah. Nothing here duplicates the reader or opens a second one.
class _SimilarVersesLayer extends ConsumerWidget {
  const _SimilarVersesLayer({
    required this.surahNumber,
    required this.ayahNumber,
  });

  final int surahNumber;
  final int ayahNumber;

  void _open(BuildContext context, SimilarVerse verse) {
    HapticFeedback.selectionClick();
    // Pop first: leaving the layer sheet stacked over the reader would mean the
    // reader scrolls to the new ayah behind a sheet still showing the old one.
    Navigator.of(context).pop();
    context.go(verse.location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(similarVersesProvider('$surahNumber:$ayahNumber'));
    final verses = async.value ?? const <SimilarVerse>[];

    if (verses.isEmpty && async.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
      );
    }

    if (verses.isEmpty) {
      // Not a failure — most ayat have no mutashabihat, and saying so plainly is
      // more useful than "content is being prepared", which implies it is coming.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔀', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('No similar verses',
                  style:
                      AppTypography.labelLarge(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'This ayah has no close parallel elsewhere in the Qur’an.',
                style: AppTypography.bodySmall(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Similar verses',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            verses.length == 1
                ? 'One other ayah resembles this one'
                : '${verses.length} other ayat resemble this one',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          for (final verse in verses) ...[
            _SimilarVerseCard(verse: verse, onTap: () => _open(context, verse)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          // The reason the layer exists, stated once at the bottom rather than
          // as a header nobody reads twice.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.quranSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Verses that resemble each other are where recitation slips from '
              'one sūrah into another. Knowing them is how the slip is '
              'caught.',
              style: AppTypography.bodySmall(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarVerseCard extends StatelessWidget {
  const _SimilarVerseCard({required this.verse, required this.onTap});

  final SimilarVerse verse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.quranSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(verse.label,
                      style:
                          AppTypography.labelMedium(color: AppColors.gold)),
                ),
                if (verse.matchType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.jade.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(verse.matchType,
                        style: AppTypography.caption(color: AppColors.jade)),
                  ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.muted, size: 12),
              ],
            ),
            if (verse.arabic.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                verse.arabic,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  color: AppColors.textPrimary,
                  height: 1.9,
                ),
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
            ],
            if (verse.translation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(verse.translation,
                  style: AppTypography.bodySmall(color: AppColors.quranMuted)),
            ],
            if (verse.sharedPhrase.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shared: ',
                      style: AppTypography.caption(color: AppColors.muted)),
                  Expanded(
                    child: Text(
                      verse.sharedPhrase,
                      style: AppTypography.caption(color: AppColors.jade),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
