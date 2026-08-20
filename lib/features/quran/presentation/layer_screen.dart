/// Layer Screen — the 5-layer tafseer system
///
/// Opened when user taps the "Layers" button on any ayah.
/// Shows 5 tab buttons at the top. Locked layers show a lock icon
/// with countdown timer. Unlocked layers show full content.
/// Layer 5 (Reflection) has a text field for private notes.
library;

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/layer_providers.dart';
import '../data/layer_content.dart';
import '../models/layer_unlock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

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
      setState(() => _currentTab = _tabController.index);
    });
    // Record that Words layer was opened
    _recordOpen(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _recordOpen(int layerIndex) async {
    final repo = ref.read(layerRepositoryProvider);
    await repo.recordUnlock(
      widget.surahNumber,
      widget.ayahNumber,
      layerIndex,
    );
    // Refresh unlock states
    ref.invalidate(layerStatesProvider(_ayahKey));
  }

  @override
  Widget build(BuildContext context) {
    // Use ScholarAI provider — fetches from Groq if not hardcoded
    final contentKey = '$_ayahKey|||${widget.arabicText}|||${widget.translation}';
    final contentAsync = ref.watch(layerContentProvider(contentKey));
    final content = contentAsync.valueOrNull;
    final layerStatesAsync = ref.watch(layerStatesProvider(_ayahKey));

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _LayerHeader(
            surahName: widget.surahName,
            ayahNumber: widget.ayahNumber,
            surahNumber: widget.surahNumber,
            arabicText: widget.arabicText,
            translation: widget.translation,
          ),

          // ── Tab Bar ──────────────────────────────────────────
          layerStatesAsync.when(
            loading: () => _buildTabBar(List.generate(
              5,
              (i) => LayerState(
                index: i,
                isUnlocked: i == 0,
                unlockedAt: null,
                availableAt: null,
              ),
            )),
            error: (_, __) => const SizedBox.shrink(),
            data: (states) => _buildTabBar(states),
          ),

          // ── Tab Content ──────────────────────────────────────
          Expanded(
            child: layerStatesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (states) => TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Layer 0 — Words
                  _LayerContent(
                    layerIndex: 0,
                    state: states[0],
                    content: content,
                    ayahKey: _ayahKey,
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    onLayerOpened: _recordOpen,
                    onNext: states[1].isUnlocked
                        ? () => _tabController.animateTo(1)
                        : null,
                    teaser: content?.tomorrowTeasers[0],
                  ),
                  // Layer 1 — Context
                  _LayerContent(
                    layerIndex: 1,
                    state: states[1],
                    content: content,
                    ayahKey: _ayahKey,
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    onLayerOpened: _recordOpen,
                    onNext: states[2].isUnlocked
                        ? () => _tabController.animateTo(2)
                        : null,
                    teaser: content?.tomorrowTeasers[1],
                  ),
                  // Layer 2 — Scholars
                  _LayerContent(
                    layerIndex: 2,
                    state: states[2],
                    content: content,
                    ayahKey: _ayahKey,
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    onLayerOpened: _recordOpen,
                    onNext: states[3].isUnlocked
                        ? () => _tabController.animateTo(3)
                        : null,
                    teaser: content?.tomorrowTeasers[2],
                  ),
                  // Layer 3 — Isnad
                  _LayerContent(
                    layerIndex: 3,
                    state: states[3],
                    content: content,
                    ayahKey: _ayahKey,
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    onLayerOpened: _recordOpen,
                    onNext: states[4].isUnlocked
                        ? () => _tabController.animateTo(4)
                        : null,
                    teaser: content?.tomorrowTeasers[3],
                  ),
                  // Layer 4 — Reflection
                  _LayerContent(
                    layerIndex: 4,
                    state: states[4],
                    content: content,
                    ayahKey: _ayahKey,
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    onLayerOpened: _recordOpen,
                    onNext: null,
                    teaser: null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(List<LayerState> states) {
    return Container(
      color: AppColors.slate,
      child: Row(
        children: List.generate(5, (index) {
          final state = states[index];
          final isActive = _currentTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: state.isUnlocked
                  ? () {
                      _tabController.animateTo(index);
                      _recordOpen(index);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? AppColors.gold : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LayerMeta.icons[index],
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LayerMeta.names[index],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppColors.gold
                            : state.isUnlocked
                                ? AppColors.white
                                : AppColors.muted,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (!state.isUnlocked)
                      const Icon(
                        Icons.lock_rounded,
                        size: 8,
                        color: AppColors.muted,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Layer Header ──────────────────────────────────────────────
class _LayerHeader extends StatelessWidget {
  const _LayerHeader({
    required this.surahName,
    required this.ayahNumber,
    required this.surahNumber,
    required this.arabicText,
    required this.translation,
  });

  final String surahName;
  final int ayahNumber;
  final int surahNumber;
  final String arabicText;
  final String translation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$surahName $surahNumber:$ayahNumber',
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
                child: Text(
                  '5 Layers',
                  style: AppTypography.caption(color: AppColors.jade),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            arabicText,
            style: AppTypography.arabicBody(color: AppColors.white),
            textDirection: ui.TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Text(
            translation,
            style: AppTypography.quoteItalic(
              color: const Color(0xFF9CADB8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Layer Content ─────────────────────────────────────────────
class _LayerContent extends ConsumerWidget {
  const _LayerContent({
    required this.layerIndex,
    required this.state,
    required this.content,
    required this.ayahKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.onLayerOpened,
    required this.onNext,
    required this.teaser,
  });

  final int layerIndex;
  final LayerState state;
  final LayerData? content;
  final String ayahKey;
  final int surahNumber;
  final int ayahNumber;
  final Function(int) onLayerOpened;
  final VoidCallback? onNext;
  final String? teaser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Locked state
    if (!state.isUnlocked) {
      return _LockedLayer(
        layerIndex: layerIndex,
        state: state,
      );
    }

    // No content curated yet
    if (content == null) {
      return _NoCuratedContent(layerIndex: layerIndex);
    }

    // Reflection layer — special UI
    if (layerIndex == 4) {
      return _ReflectionLayer(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        ayahKey: ayahKey,
      );
    }

    // Content layers 0–3
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Layer content
          _buildLayerBody(context),

          // Tomorrow teaser
          if (teaser != null && onNext == null) ...[
            // Last content layer before reflection
            const SizedBox(height: 32),
            _TomorrowTeaser(text: teaser!),
          ] else if (teaser != null) ...[
            const SizedBox(height: 32),
            _TomorrowTeaser(text: teaser!),
          ],

          // Next layer button if next is already unlocked
          if (onNext != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onNext,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.slate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to ${LayerMeta.names[layerIndex + 1]}',
                      style: AppTypography.labelLarge(color: AppColors.white),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLayerBody(BuildContext context) {
    switch (layerIndex) {
      case 0:
        return _WordsLayerBody(content: content!);
      case 1:
        return _ContextLayerBody(content: content!);
      case 2:
        return _ScholarsLayerBody(content: content!);
      case 3:
        return _IsnadLayerBody(content: content!);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Words Layer Body ──────────────────────────────────────────
class _WordsLayerBody extends StatelessWidget {
  const _WordsLayerBody({required this.content});
  final LayerData content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('🔤 Word Analysis'),
        const SizedBox(height: 12),
        _ContentCard(text: content.words),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.jade.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.jade.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: AppColors.jade, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any word in the reader above to see its full root and meaning',
                  style: AppTypography.bodySmall(color: AppColors.jade),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Context Layer Body ────────────────────────────────────────
class _ContextLayerBody extends StatelessWidget {
  const _ContextLayerBody({required this.content});
  final LayerData content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('📍 Historical Context'),
        const SizedBox(height: 12),
        _ContentCard(text: content.context),
      ],
    );
  }
}

// ── Scholars Layer Body ───────────────────────────────────────
class _ScholarsLayerBody extends StatelessWidget {
  const _ScholarsLayerBody({required this.content});
  final LayerData content;

  @override
  Widget build(BuildContext context) {
    final scholar = content.scholars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('📚 Scholar Insight'),
        const SizedBox(height: 12),

        // Scholar identity card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppColors.violet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scholar.scholarName,
                      style: AppTypography.labelLarge(color: AppColors.white),
                    ),
                    Text(
                      '${scholar.scholarEra} · ${scholar.work}',
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Arabic quote
        if (scholar.arabicQuote.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.night,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                right: const BorderSide(color: AppColors.violet, width: 3),
              ),
            ),
            child: Text(
              scholar.arabicQuote,
              style: AppTypography.arabicSmall(
                color: AppColors.muted,
              ),
              textDirection: ui.TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 12),
        ],

        _ContentCard(text: scholar.insight),
      ],
    );
  }
}

// ── Isnad Layer Body ──────────────────────────────────────────
class _IsnadLayerBody extends StatelessWidget {
  const _IsnadLayerBody({required this.content});
  final LayerData content;

  @override
  Widget build(BuildContext context) {
    final isnad = content.isnad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('🔗 Chain of Narration (Isnad)'),
        const SizedBox(height: 12),

        // The hadith
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: const BorderSide(color: AppColors.gold, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${isnad.hadithText}"',
                style: AppTypography.quoteItalic(
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '— ${isnad.narrator}',
                    style: AppTypography.caption(color: AppColors.muted),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.jade.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isnad.grade,
                      style: AppTypography.caption(color: AppColors.jade),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isnad.reference,
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'NARRATORS',
          style: AppTypography.caption(color: AppColors.muted),
        ),
        const SizedBox(height: 8),

        // Chain of narrators
        ...List.generate(isnad.chain.length, (index) {
          final link = isnad.chain[index];
          return Column(
            children: [
              _NarratorCard(link: link, position: index + 1),
              if (index < isnad.chain.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Row(
                    children: [
                      Container(
                        width: 1,
                        height: 20,
                        color: AppColors.border,
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _NarratorCard extends StatefulWidget {
  const _NarratorCard({required this.link, required this.position});
  final ChainLink link;
  final int position;

  @override
  State<_NarratorCard> createState() => _NarratorCardState();
}

class _NarratorCardState extends State<_NarratorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.night,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.position}',
                      style: AppTypography.caption(color: AppColors.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.link.name,
                        style:
                            AppTypography.labelMedium(color: AppColors.white),
                      ),
                      Text(
                        '${widget.link.arabicName} · ${widget.link.role} · d. ${widget.link.died}',
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                  size: 16,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(
                widget.link.bio,
                style: AppTypography.bodySmall(
                  color: const Color(0xFF9CADB8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reflection Layer ──────────────────────────────────────────
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('✍️ Your Reflection'),
          const SizedBox(height: 8),
          Text(
            'This is private. Only you will ever see this.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          reflectionAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (existing) {
              // Pre-fill if existing reflection
              if (existing != null && _controller.text.isEmpty) {
                _controller.text = existing;
              }
              return Column(
                children: [
                  // Text field
                  TextField(
                    controller: _controller,
                    maxLines: 8,
                    style: AppTypography.bodyMedium(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText:
                          'What does this ayah mean for YOUR life right now? '
                          'Not what the scholars say — what do YOU feel when '
                          'you sit with this?',
                      hintStyle:
                          AppTypography.bodySmall(color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.slate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.jade,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() => _saved = false),
                  ),
                  const SizedBox(height: 12),

                  // Save button
                  GestureDetector(
                    onTap: () async {
                      if (_controller.text.trim().isEmpty) return;
                      final repo = ref.read(layerRepositoryProvider);
                      await repo.saveReflection(
                        widget.surahNumber,
                        widget.ayahNumber,
                        _controller.text.trim(),
                      );
                      ref.invalidate(reflectionProvider(widget.ayahKey));
                      setState(() => _saved = true);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _saved ? AppColors.jade : AppColors.slate,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _saved
                              ? AppColors.jade
                              : AppColors.jade.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _saved ? Icons.check_rounded : Icons.save_rounded,
                            color: _saved ? AppColors.white : AppColors.jade,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _saved ? 'Reflection saved' : 'Save reflection',
                            style: AppTypography.labelLarge(
                              color: _saved ? AppColors.white : AppColors.jade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (existing != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Last saved: ${DateFormat('d MMM y').format(DateTime.now())}',
                      style: AppTypography.caption(),
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

// ── Locked Layer ──────────────────────────────────────────────
class _LockedLayer extends StatelessWidget {
  const _LockedLayer({required this.layerIndex, required this.state});
  final int layerIndex;
  final LayerState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.slate,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.muted,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${LayerMeta.names[layerIndex]} unlocks',
              style: AppTypography.labelLarge(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              state.availableAt != null
                  ? 'Available in ${state.timeUntilUnlock}'
                  : 'Open the previous layer first',
              style: AppTypography.bodySmall(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (state.availableAt != null) ...[
              const SizedBox(height: 20),
              Text(
                DateFormat('d MMM · h:mm a').format(state.availableAt!),
                style: AppTypography.caption(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── No Content ────────────────────────────────────────────────
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
            const Text('📖', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              '${LayerMeta.names[layerIndex]} content',
              style: AppTypography.labelLarge(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Scholarly content for this ayah is being curated. '
              'Al-Fatihah is complete. More surahs added with each update.',
              style: AppTypography.bodySmall(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.displaySmall(color: AppColors.white),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTypography.bodyMedium(
          color: const Color(0xFFD4DDE4),
        ),
      ),
    );
  }
}

class _TomorrowTeaser extends StatelessWidget {
  const _TomorrowTeaser({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.night,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_twilight_rounded,
                color: AppColors.gold,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'TOMORROW',
                style: AppTypography.caption(color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTypography.bodySmall(
              color: const Color(0xFF9CADB8),
            ),
          ),
        ],
      ),
    );
  }
}
