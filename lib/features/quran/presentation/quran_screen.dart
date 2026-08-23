/// QURAN — the surah index.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 3 (screen 02 of 08).
/// Every colour comes off [MizanPalette]; the legacy `AppColors` palette this
/// screen used to draw from is gone.
///
/// ── What is bound to real data, and why that mattered ─────────────────
/// The mockup shows three things that would have been easy to hardcode and
/// dishonest to invent:
///
///   • **CONTINUE READING · Al-Baqarah · 2:2** — bound to [lastAyahProvider],
///     the same stored position the reader writes. When nothing has been read
///     yet the panel is simply absent rather than showing a fake position.
///
///   • **The IN SALAH chip on Al-Fatihah** — bound to `Surah.isRecitedInSalah`,
///     which is a curated set of 20 surah numbers already in the model. It is
///     not "surah 1 gets a badge".
///
///   • **Order of revelation** — bound to `SurahMeta.revelationOrder`, a real
///     field on real metadata. Chronological revelation order is a scholarly
///     ordering; had the repo not carried it, the control would have been
///     dropped rather than approximated.
///
/// ── Rule #1, the easiest one to break here ────────────────────────────
/// The surah numerals read as gold in the mockup. Gold *text* on cream is
/// forbidden, so they use `p.accentText` — bronze on light, gold on dark. The
/// only place `p.accent` (true gold) appears on this screen is as a fill or a
/// diamond.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/models/surah.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../home/domain/home_providers.dart';
import '../data/surah_metadata.dart';
import '../domain/quran_providers.dart';

/// How the index is ordered. The mockup's control toggles between exactly these
/// two; there is no third option and no "recently read" ordering, because the
/// app stores one last position rather than a history.
enum _SurahOrder {
  /// 1 → 114, the order of the printed Quran.
  mushaf,

  /// The order in which the surahs were revealed, per `SurahMeta`.
  revelation;

  String get label => switch (this) {
        _SurahOrder.mushaf => 'Surah order',
        _SurahOrder.revelation => 'Order of revelation',
      };

  _SurahOrder get other => switch (this) {
        _SurahOrder.mushaf => _SurahOrder.revelation,
        _SurahOrder.revelation => _SurahOrder.mushaf,
      };
}

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  late final TextEditingController _search;
  _SurahOrder _order = _SurahOrder.mushaf;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider so the field survives a tab switch with whatever
    // the user had typed still in it.
    _search = TextEditingController(text: ref.read(surahSearchQueryProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Sorts a copy — the provider's list is shared, and sorting it in place would
  /// reorder it for every other listener.
  List<Surah> _sorted(List<Surah> surahs) {
    if (_order == _SurahOrder.mushaf) return surahs;
    final copy = [...surahs];
    copy.sort((a, b) {
      // A surah with no metadata sorts last rather than to position zero, so a
      // gap in the table can never masquerade as "revealed first".
      final ao = SurahMetadata.get(a.number)?.revelationOrder ?? 1 << 20;
      final bo = SurahMetadata.get(b.number)?.revelationOrder ?? 1 << 20;
      return ao.compareTo(bo);
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final filtered = ref.watch(filteredSurahsProvider);
    final query = ref.watch(surahSearchQueryProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MizanGeometry.gutter,
            10,
            MizanGeometry.gutter,
            MizanGeometry.scrollBottomPadding,
          ),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            _SearchField(controller: _search),
            const SizedBox(height: MizanGeometry.gap),
            const _ContinueReading(),
            const SizedBox(height: 6),
            _OrderRow(
              order: _order,
              onSwap: () => setState(() => _order = _order.other),
            ),
            const SizedBox(height: 10),
            ...switch (filtered) {
              AsyncData(:final value) when value.isEmpty => [
                  _EmptyResult(query: query),
                ],
              AsyncData(:final value) => [
                  for (final surah in _sorted(value)) ...[
                    _SurahRow(surah: surah, order: _order),
                    const SizedBox(height: 10),
                  ],
                ],
              AsyncError(:final error) => [_LoadFailed(message: '$error')],
              _ => const [_IndexLoading()],
            },
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quran', style: MizanType.screenTitle(color: p.ink)),
              const SizedBox(height: 2),
              Text(
                'Words of Allah · 114 surahs',
                style: MizanType.body(color: p.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Reading preferences — script, translation, font size — already have a
        // screen behind Settings, so this is a shortcut into it rather than a
        // second copy of those controls.
        MizanIconTile(
          icon: Icons.tune_rounded,
          circle: true,
          semanticLabel: 'Reading preferences',
          onTap: () => context.go('/settings/personalisation'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SEARCH
// ══════════════════════════════════════════════════════════════════════

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      // A search field is an inset well, not a raised card — `sunk` is exactly
      // the token for this, and it is why no shadow is applied.
      tone: MizanTone.sunk,
      radius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      showBorder: false,
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 21, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (v) =>
                  ref.read(surahSearchQueryProvider.notifier).state = v,
              style: MizanType.body(color: p.ink),
              cursorColor: p.link,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search surah, ayah or number',
                hintStyle: MizanType.body(color: p.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller.clear();
                ref.read(surahSearchQueryProvider.notifier).state = '';
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, size: 19, color: p.muted),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CONTINUE READING
// ══════════════════════════════════════════════════════════════════════

/// The navy panel. Absent — not empty, not faked — until something has been read.
class _ContinueReading extends ConsumerWidget {
  const _ContinueReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastAyahProvider).valueOrNull;
    if (last == null) return const SizedBox.shrink();

    final surahNumber = last['surah'] as int?;
    final ayahNumber = last['ayah'] as int?;
    if (surahNumber == null || ayahNumber == null) {
      return const SizedBox.shrink();
    }
    final surahName = (last['surahName'] as String? ?? '').trim();

    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MizanSurface(
        tone: tone,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        onTap: () => context.go('/quran/$surahNumber?ayah=$ayahNumber'),
        child: Row(
          children: [
            // A gold-tinted tile on navy: `accent` is legal as a fill here, and
            // legal as an icon colour because the surface is dark.
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p.accent.withValues(alpha: 0.32),
                  width: MizanGeometry.hairlineWidth,
                ),
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 23, color: tone.accentTextOn(p)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MizanSectionLabel(
                    'Continue reading',
                    onInverse: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    surahName.isEmpty
                        ? 'Surah $surahNumber · $surahNumber:$ayahNumber'
                        : '$surahName · $surahNumber:$ayahNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MizanType.bodyStrong(color: tone.onColor(p))
                        .copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 24, color: tone.accentTextOn(p)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SECTION LABEL + ORDER TOGGLE
// ══════════════════════════════════════════════════════════════════════

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onSwap});

  final _SurahOrder order;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Row(
      children: [
        const MizanSectionLabel('All surahs'),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSwap,
          child: Semantics(
            button: true,
            // The label names the ordering you would switch *to*, which is how
            // the mockup reads it — a control, not a status line.
            label: 'Sort by ${order.other.label}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    order.other.label,
                    style: MizanType.body(color: p.link).copyWith(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.swap_vert_rounded, size: 18, color: p.link),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ONE SURAH
// ══════════════════════════════════════════════════════════════════════

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah, required this.order});

  final Surah surah;
  final _SurahOrder order;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final meta = SurahMetadata.get(surah.number);

    // In revelation order the mushaf number stops being the row's position, so
    // it is labelled to stay meaningful. In mushaf order it needs no label.
    final leadingNumber = order == _SurahOrder.revelation
        ? '${meta?.revelationOrder ?? surah.number}'
        : '${surah.number}';

    return MizanSurface(
      tone: MizanTone.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: MizanGeometry.rowBorderRadius,
      onTap: () => context.go('/quran/${surah.number}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              leadingNumber,
              textAlign: TextAlign.center,
              // Bronze on cream, gold on navy. Rule #1.
              style: MizanType.cardHeadline(color: p.accentText)
                  .copyWith(fontSize: 17),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        surah.englishName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MizanType.bodyStrong(color: p.ink)
                            .copyWith(fontSize: 15.5),
                      ),
                    ),
                    if (surah.isRecitedInSalah) ...[
                      const SizedBox(width: 8),
                      const _InSalahChip(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${surah.translatedName} · ${surah.metaDisplay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Rule #6: Amiri, RTL, and paired — the transliteration and the
          // English meaning sit in the same row, so the Arabic is never alone.
          Text(
            surah.arabicName,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: MizanType.arabic(color: p.ink, fontSize: 21),
          ),
        ],
      ),
    );
  }
}

/// The outlined micro-chip. Bronze label on light, gold on dark — never a fill,
/// because a filled gold chip would pull more weight than the surah name.
class _InSalahChip extends StatelessWidget {
  const _InSalahChip();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
        border: Border.all(
          color: p.accentText.withValues(alpha: 0.45),
          width: MizanGeometry.hairlineWidth,
        ),
      ),
      child: Text(
        'IN SALAH',
        style: MizanType.sectionLabel(color: p.accentText)
            .copyWith(fontSize: 8.5, letterSpacing: 0.12 * 8.5),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  NON-CONTENT STATES
// ══════════════════════════════════════════════════════════════════════

class _IndexLoading extends StatelessWidget {
  const _IndexLoading();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(
        children: [
          MizanDiamond(size: 8, filled: false, color: p.muted),
          const SizedBox(height: 14),
          Text(
            query.trim().isEmpty
                ? 'No surahs to show yet.'
                : 'Nothing matches “${query.trim()}”.',
            textAlign: TextAlign.center,
            style: MizanType.translation(color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: MizanSurface(
        tone: MizanTone.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The index could not be loaded.',
              style: MizanType.bodyStrong(color: p.ink),
            ),
            const SizedBox(height: 6),
            // Shown rather than swallowed: a silent empty list on a screen that
            // should always have 114 rows is worse than an ugly message.
            Text(message, style: MizanType.body(color: p.muted)),
          ],
        ),
      ),
    );
  }
}
