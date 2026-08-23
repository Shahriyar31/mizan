/// DISCOVER — the index for the four story libraries.
///
/// The *detail* page in `Mizan Light.pdf` / `Mizan Dark.pdf` page 5 is
/// [LayerStoryScaffold], not this file; this is the list you arrive from. What
/// the rebuild changed here:
///
///   • **Two bottom tab bars.** This screen supplied its own
///     `bottomNavigationBar` while living inside the app shell's `ShellRoute`,
///     so the section switcher stacked directly on top of the real tab bar.
///     The sections are chips under the header now, which is where every other
///     rebuilt screen puts its filters.
///   • **Emoji tabs** (🕌 ⚔️ ✨ 📜) are gone. The design system draws with line
///     icons, Arabic and the arch; an emoji renders as somebody else's artwork
///     at somebody else's colour.
///   • The header is on Mizan tokens: Arabic in bronze/gold above the English
///     (Rule #6, never alone), and "FIVE LAYERS" as an outlined bronze pill.
///
/// The four tab bodies and their cards still read `AppColors`. That file now
/// aliases every token onto [MizanPalette], so they already paint the Mizan
/// palette in both themes — their *layout* is the next pass, and the chrome
/// being right first is what makes the screen usable in the meantime.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taddabur/core/theme/app_colors.dart';
import 'package:taddabur/core/theme/app_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../providers/discover_providers.dart';
import '../models/discover_models.dart';
import '../widgets/discover_browser.dart';

/// Reading state used by the browser's filter chips. Kept in one place so all
/// four sections classify entries identically.
DiscoverItemStatus _statusOf(DiscoverProgress? p) {
  if (p == null || p.layersUnlocked == 0) return DiscoverItemStatus.fresh;
  if (p.entryCompleted) return DiscoverItemStatus.complete;
  return DiscoverItemStatus.reading;
}

/// Rail bucket for an alphabetical section: 'A'–'Z', or '#' for anything that
/// does not start with a Latin letter (e.g. an Arabic-only English field).
String _alphaGroup(String name) {
  final trimmed = name.trimLeft();
  if (trimmed.isEmpty) return '#';
  final c = trimmed[0].toUpperCase();
  return (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) ? c : '#';
}

const List<String> _alphabet = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#',
];

/// Decade bucket for the 99 Names — '1–10', '11–20', … so the rail is short.
String _decadeGroup(int number) {
  final start = ((number - 1) ~/ 10) * 10 + 1;
  return '$start–${start + 9}';
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  static const _tabs = [
    _TabInfo('Prophets', 'أَنْبِيَاء'),
    _TabInfo('Sahabah', 'صَحَابَة'),
    _TabInfo('99 Names', 'أَسْمَاء'),
    _TabInfo('Seerah', 'سِيرَة'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
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
    final p = MizanPalette.of(context);

    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          _DiscoverHeader(tab: _tabs[_currentTab]),
          // The four sections used to be a second bottom nav bar, stacked
          // directly above the app shell's real one — two tab bars on one
          // screen. They are chips under the header now, which is also where
          // every other rebuilt screen puts its filters.
          _SectionChips(
            tabs: _tabs,
            currentIndex: _currentTab,
            onTap: (i) {
              setState(() => _currentTab = i);
              _tabController.animateTo(i);
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ProphetsTab(),
                _SahabahTab(),
                _NamesTab(),
                _SeerahTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final String arabic;
  const _TabInfo(this.label, this.arabic);
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverHeader extends StatelessWidget {
  final _TabInfo tab;
  const _DiscoverHeader({required this.tab});

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MizanGeometry.gutter,
          10,
          MizanGeometry.gutter,
          14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bronze on cream, gold on navy — Rule #1, since this is text.
                  // The English sits on the very next line, Rule #6.
                  Text(
                    tab.arabic,
                    textDirection: TextDirection.rtl,
                    style: MizanType.arabic(color: p.accentText, fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(tab.label, style: MizanType.screenTitle(color: p.ink)),
                ],
              ),
            ),
            // True of every entry in all four sections, which is why it can sit
            // in the header rather than on each card.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
                border: Border.all(
                  color: p.accentText.withValues(alpha: 0.45),
                  width: MizanGeometry.hairlineWidth,
                ),
              ),
              child: Text(
                'FIVE LAYERS',
                style: MizanType.sectionLabel(color: p.accentText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section chips
// ─────────────────────────────────────────────────────────────────────────────

class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_TabInfo> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(MizanGeometry.gutter, 0, 12, 16),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: MizanButton(
                label: tabs[i].label,
                // Filled navy when active, outlined when not — selection reads
                // through fill and label colour, never through depth.
                kind: MizanButtonKind.chip,
                selected: i == currentIndex,
                onPressed: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prophets Tab — Immersive cards with era context
// ─────────────────────────────────────────────────────────────────────────────

class _ProphetsTab extends ConsumerWidget {
  const _ProphetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(prophetListProvider);
    return listAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(e.toString()),
      data: (items) => DiscoverBrowser<ProphetListItem>(
        items: items,
        searchHint: 'Search 25 prophets',
        // Entries arrive sorted by sequenceNumber, so first-seen group order is
        // already chronological — no explicit groupOrder needed.
        groupOf: (i) => i.entry.group ?? i.entry.era,
        searchTerms: (i) => [
          i.entry.nameEnglish,
          i.entry.nameTranslit,
          i.entry.nameArabic,
          i.entry.era,
          i.entry.teaser,
        ],
        statusOf: (i) => _statusOf(i.progress),
        itemBuilder: (context, i) => _ProphetCard(
          entry: i.entry,
          isUnlocked: i.isUnlocked,
          layersRead: i.progress?.layersUnlocked ?? 0,
          onTap: () => context.push('/discover/prophet/${i.entry.id}'),
        ),
      ),
    );
  }
}

class _ProphetCard extends StatelessWidget {
  final ProphetEntry entry;
  final bool isUnlocked;
  final int layersRead;
  final VoidCallback onTap;

  const _ProphetCard({
    required this.entry,
    required this.isUnlocked,
    required this.layersRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: layersRead > 0
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.gold.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with era + number
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.era,
                      style: AppTypography.labelSmall(color: AppColors.gold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${entry.sequenceNumber}',
                    style: AppTypography.labelSmall(
                        color: AppColors.muted.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            // Names
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.nameArabic,
                          style: AppTypography.arabicDisplay(
                              color: AppColors.gold, size: 26),
                        ),
                        Text(
                          entry.nameEnglish,
                          style: AppTypography.displaySmall(
                              color: AppColors.parchment),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.gold.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ],
              ),
            ),
            // Teaser
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                entry.teaser,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall(color: AppColors.muted),
              ),
            ),
            // Layer progress bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$layersRead / 5 layers',
                        style: AppTypography.labelSmall(
                            color: AppColors.muted.withValues(alpha: 0.6)),
                      ),
                      const Spacer(),
                      if (layersRead == 5)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.jade.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Complete',
                              style: AppTypography.labelSmall(
                                  color: AppColors.jade)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: layersRead / 5,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(AppColors.gold),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sahabah Tab — Horizontal scroll hero + list
// ─────────────────────────────────────────────────────────────────────────────

class _SahabahTab extends ConsumerWidget {
  const _SahabahTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(sahabiListProvider);
    return listAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(e.toString()),
      data: (items) => DiscoverBrowser<SahabiListItem>(
        items: items,
        searchHint: 'Search by name, kunyah or tribe',
        // A–Z is the only grouping that scales to 100 entries: the rail turns
        // "scroll to the 100th" into one tap.
        groupOf: (i) => _alphaGroup(i.entry.nameEnglish),
        groupOrder: _alphabet,
        showRail: true,
        searchTerms: (i) => [
          i.entry.nameEnglish,
          i.entry.nameArabic,
          i.entry.kunyah,
          i.entry.tribe,
          i.entry.era,
          i.entry.teaser,
        ],
        statusOf: (i) => _statusOf(i.progress),
        itemBuilder: (context, i) => _SahabiCard(
          entry: i.entry,
          layersRead: i.progress?.layersUnlocked ?? 0,
          onTap: () => context.push('/discover/sahabi/${i.entry.id}'),
        ),
      ),
    );
  }
}

class _SahabiCard extends StatelessWidget {
  final SahabiEntry entry;
  final int layersRead;
  final VoidCallback onTap;

  const _SahabiCard({
    required this.entry,
    required this.layersRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Same neutral card material Prophet cards use — no per-category
          // brown/gold tint.
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: layersRead > 0
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.gold.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kunyah badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.kunyah.isNotEmpty ? entry.kunyah : entry.tribe,
                      style: AppTypography.labelSmall(color: AppColors.gold),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: AppColors.gold.withValues(alpha: 0.4), size: 14),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.nameArabic,
                style: AppTypography.arabicDisplay(
                    color: AppColors.gold, size: 24),
              ),
              Text(
                entry.nameEnglish,
                style: AppTypography.displaySmall(color: AppColors.parchment),
              ),
              const SizedBox(height: 6),
              Text(
                entry.era,
                style: AppTypography.labelSmall(
                    color: AppColors.muted.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 8),
              Text(
                entry.teaser,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              // Layer dots
              Row(
                children: List.generate(5, (i) {
                  final filled = i < layersRead;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: filled ? 24 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.gold
                          : AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 99 Names Tab — Grid layout, compact cards
// ─────────────────────────────────────────────────────────────────────────────

class _NamesTab extends ConsumerWidget {
  const _NamesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(nameListProvider);
    return listAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(e.toString()),
      data: (items) => DiscoverBrowser<NameListItem>(
        items: items,
        searchHint: 'Search a Name or its meaning',
        groupOf: (i) => _decadeGroup(i.entry.number),
        showRail: true,
        // '1–10' is too wide for a 34px rail — show only the upper bound.
        railLabelFor: (g) => g.split('–').last,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        searchTerms: (i) => [
          i.entry.translit,
          i.entry.arabic,
          i.entry.meaningBrief,
          '${i.entry.number}',
        ],
        statusOf: (i) => _statusOf(i.progress),
        itemBuilder: (context, i) => _NameCard(
          entry: i.entry,
          layersRead: i.progress?.layersUnlocked ?? 0,
          onTap: () => context.push('/discover/name/${i.entry.id}'),
        ),
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  final DivineName entry;
  final int layersRead;
  final VoidCallback onTap;

  const _NameCard({
    required this.entry,
    required this.layersRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardNameBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: layersRead > 0
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.gold.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Background watermark calligraphy
            Positioned(
              right: -8,
              bottom: -8,
              child: Text(
                entry.arabic,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 72,
                  color: AppColors.gold.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Number badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.15),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.number}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Arabic name
                  Text(
                    entry.arabic,
                    style: AppTypography.arabicDisplay(
                        color: AppColors.gold, size: 22),
                  ),
                  const SizedBox(height: 4),
                  // Transliteration
                  Text(
                    entry.translit,
                    style: AppTypography.labelSmall(color: AppColors.goldSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Meaning
                  Text(
                    entry.meaningBrief,
                    style: AppTypography.bodySmall(color: AppColors.parchment2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Progress dots
                  Row(
                    children: List.generate(5, (i) {
                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        width: i < layersRead ? 14 : 6,
                        height: 3,
                        decoration: BoxDecoration(
                          color: i < layersRead
                              ? AppColors.gold
                              : AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seerah Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SeerahTab extends ConsumerWidget {
  const _SeerahTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(seerahListProvider);
    return listAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(e.toString()),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ﷺ',
                    style: TextStyle(fontSize: 56, color: AppColors.gold)),
                const SizedBox(height: 20),
                Text('The Seerah',
                    style: AppTypography.displayMedium(
                        color: AppColors.parchment)),
                const SizedBox(height: 12),
                Text(
                  'Coming soon — the chronological\nlife of the Prophet ﷺ',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(color: AppColors.muted),
                ),
              ],
            ),
          );
        }
        return DiscoverBrowser<SeerahListItem>(
          items: items,
          searchHint: 'Search the Seerah',
          groupOf: (i) => i.entry.group ?? i.entry.era,
          searchTerms: (i) => [
            i.entry.title,
            i.entry.titleArabic,
            i.entry.year,
            i.entry.era,
            i.entry.teaser,
          ],
          statusOf: (i) => _statusOf(i.progress),
          itemBuilder: (context, i) => _SeerahCard(
            entry: i.entry,
            layersRead: i.progress?.layersUnlocked ?? 0,
            onTap: () => context.push('/discover/seerah/${i.entry.id}'),
          ),
        );
      },
    );
  }
}

class _SeerahCard extends StatelessWidget {
  final SeerahEntry entry;
  final int layersRead;
  final VoidCallback onTap;

  const _SeerahCard({
    required this.entry,
    required this.layersRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSeerahBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                AppColors.gold.withValues(alpha: layersRead > 0 ? 0.4 : 0.12),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(entry.year,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.labelSmall(color: AppColors.gold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('#${entry.sequenceNumber}',
                      style: AppTypography.labelSmall(
                          color: AppColors.muted.withValues(alpha: 0.4))),
                ],
              ),
              const SizedBox(height: 12),
              Text(entry.titleArabic,
                  style: AppTypography.arabicDisplay(
                      color: AppColors.gold, size: 22)),
              Text(entry.title,
                  style:
                      AppTypography.displaySmall(color: AppColors.parchment)),
              const SizedBox(height: 4),
              Text(entry.era,
                  style: AppTypography.labelSmall(
                      color: AppColors.muted.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Text(entry.teaser,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('$layersRead / 5 layers',
                      style: AppTypography.labelSmall(
                          color: AppColors.muted.withValues(alpha: 0.5))),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppColors.gold.withValues(alpha: 0.4)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: layersRead / 5,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppColors.gold),
        strokeWidth: 2,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall(color: AppColors.error),
        ),
      ),
    );
  }
}
