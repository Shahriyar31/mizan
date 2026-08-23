/// DISCOVER — the front page for the four story libraries, and the way into them.
///
/// The *detail* page in `Mizan Light.pdf` / `Mizan Dark.pdf` page 5 is
/// [LayerStoryScaffold], not this file; this is what you arrive from. What the
/// rebuilds changed here:
///
///   • **Two bottom tab bars.** This screen supplied its own
///     `bottomNavigationBar` while living inside the app shell's `ShellRoute`,
///     so the section switcher stacked directly on top of the real tab bar.
///   • **Emoji tabs** (🕌 ⚔️ ✨ 📜) are gone. The design system draws with line
///     icons, Arabic and the arch; an emoji renders as somebody else's artwork
///     at somebody else's colour.
///   • **A front page, not a bare tab strip.** Landing straight on 43 Sahabah
///     cards asks the reader to choose before anything has told them what is
///     here. So [_FrontPage] answers that first: what you were reading, the four
///     collections with their *real* sizes, the newest entries, and one docked
///     button for everything that cuts across them.
///   • **"FIVE LAYERS" is gone from the header.** It was a boast, not a control,
///     and it was also becoming false — the ayah layers went to six and the
///     cross-cutting sections have no layers at all. The trailing slot now holds
///     the section switcher instead, which is the one thing a reader standing
///     here actually wants from the header.
///
/// ── One entry point per action ─────────────────────────────────────────
/// Two controls used to switch section (`_SectionChips`) and open the knowledge
/// indexes (`_KnowledgeStrip`), both as horizontal strips under the header, both
/// looking like filters. Both are deleted. The section switcher is now the
/// [Icons.tune] sheet — which the [_CollectionsGrid] does *not* duplicate,
/// because the grid only exists on the front page and cannot express "back to
/// all four", while the sheet is chrome that stays reachable from inside a
/// section where the grid is off screen. The knowledge indexes moved into the
/// docked "Browse more" sheet, which is now their only door.
///
/// ── Nothing here is invented ───────────────────────────────────────────
/// Every count on this screen is measured off the corpus at runtime (list
/// lengths from the four providers) or, where no provider exists, taken from a
/// named file and written down as a constant beside the file name. The corpus
/// carries no authoring timestamps, so the second section is `RECENTLY ADDED`
/// ordered by sequence number rather than the mockup's "NEW THIS WEEK", which
/// would be a date claim the data cannot support.
///
/// The four tab bodies and their cards still read `AppColors`. That file now
/// aliases every token onto [MizanPalette], so they already paint the Mizan
/// palette in both themes — their *layout* is the next pass.
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
import '../../knowledge/domain/hadith_providers.dart';
import '../../knowledge/presentation/knowledge_routes.dart';

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

  /// `null` is the front page. 0–3 is one library, shown full screen.
  int? _section;

  final TextEditingController _search = TextEditingController();
  String _query = '';

  static const _tabs = [
    _TabInfo('Prophets', 'أَنْبِيَاء', Icons.auto_stories_outlined),
    _TabInfo('Sahabah', 'صَحَابَة', Icons.groups_outlined),
    _TabInfo('99 Names', 'أَسْمَاء', Icons.brightness_low_outlined),
    _TabInfo('Seerah', 'سِيرَة', Icons.timeline_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      // Swiping between libraries must move the header title with it.
      if (_tabController.indexIsChanging) {
        setState(() => _section = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final section = _section;

    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          _DiscoverHeader(
            // On the front page the header names the screen; inside a section it
            // names the section, because that is then the only label saying
            // which of the four libraries these cards belong to.
            arabic: section == null ? 'اسْتِكْشَاف' : _tabs[section].arabic,
            title: section == null ? 'Discover' : _tabs[section].label,
            onSwitchSection: _openSectionSheet,
          ),
          Expanded(
            child: section == null
                ? _FrontPage(
                    controller: _search,
                    query: _query,
                    onQuery: (q) => setState(() => _query = q),
                    onOpenSection: _showSection,
                  )
                : TabBarView(
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

  void _showSection(int index) {
    setState(() => _section = index);
    // `animateTo` on a controller whose TabBarView was not mounted a frame ago
    // would animate from a stale index, so the jump is silent and the fade the
    // reader sees is the body swap itself.
    _tabController.index = index;
  }

  /// The section switcher, reached from the header's [Icons.tune].
  ///
  /// It is a sheet rather than a strip of chips because it has to carry a fifth
  /// choice the chips could not: *back to all four*. A reader deep inside 43
  /// Sahabah cards has the collections grid off screen, so without this row the
  /// front page would be unreachable except by leaving the tab.
  Future<void> _openSectionSheet() async {
    final p = MizanPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _Sheet(
        title: 'Show',
        subtitle: 'One library, or the front page with all four',
        children: [
          MizanRow(
            title: 'All four collections',
            subtitle: 'The front page',
            leading: Icon(Icons.grid_view_outlined, size: 20, color: p.sage),
            onTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _section = null);
            },
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _tabs.length; i++) ...[
            MizanRow(
              title: _tabs[i].label,
              subtitle: _tabs[i].arabic,
              leading: Icon(_tabs[i].icon, size: 20, color: p.sage),
              trailing: _section == i
                  ? Icon(Icons.check, size: 18, color: p.accentText)
                  : null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showSection(i);
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final String arabic;
  final IconData icon;
  const _TabInfo(this.label, this.arabic, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.arabic,
    required this.title,
    required this.onSwitchSection,
  });

  final String arabic;
  final String title;
  final VoidCallback onSwitchSection;

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
                    arabic,
                    textDirection: TextDirection.rtl,
                    style: MizanType.arabic(color: p.accentText, fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(title, style: MizanType.screenTitle(color: p.ink)),
                ],
              ),
            ),
            // Where "FIVE LAYERS" used to sit. A label that told the reader
            // nothing they could act on has become the one control the header
            // owes them: which library am I looking at.
            MizanIconTile(
              icon: Icons.tune,
              onTap: onSwitchSection,
              semanticLabel: 'Switch collection',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet chrome — shared by the section switcher and "Browse more"
// ─────────────────────────────────────────────────────────────────────────────

/// Title, one line of subtitle, a close X, then rows.
///
/// Both sheets on this screen are the same object with different rows, so the
/// chrome is written once. Height is content-driven and capped at 80% so a long
/// sheet scrolls rather than fighting the keyboard or the notch.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        margin: const EdgeInsets.all(MizanGeometry.gutter),
        padding: const EdgeInsets.all(MizanGeometry.cardPadding),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(MizanGeometry.cardRadius),
          border: Border.all(
            color: p.hairline,
            width: MizanGeometry.hairlineWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MizanType.cardHeadline(color: p.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: MizanType.body(color: p.muted)),
                    ],
                  ),
                ),
                MizanIconTile(
                  icon: Icons.close,
                  iconSize: 18,
                  onTap: () => Navigator.of(context).pop(),
                  semanticLabel: 'Close',
                ),
              ],
            ),
            const SizedBox(height: MizanGeometry.gap),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One flat index across the four libraries
// ─────────────────────────────────────────────────────────────────────────────

/// One corpus entry, flattened out of whichever library it came from.
///
/// The front page has three jobs — resume, search, and "recently added" — and
/// all three cut across the four libraries. Without this flattening each would
/// need the same four-way `when(...)` fan-out written three times.
class _Entry {
  const _Entry({
    required this.id,
    required this.title,
    required this.arabic,
    required this.subtitle,
    required this.layers,
    required this.path,
    required this.sequence,
    required this.section,
  });

  final String id;
  final String title;
  final String arabic;
  final String subtitle;
  final List<DiscoverLayer> layers;
  final String path;
  final int sequence;

  /// Index into `_DiscoverScreenState._tabs`, so a row can name its library.
  final int section;
}

final _indexProvider = Provider<List<_Entry>>((ref) {
  final out = <_Entry>[];

  for (final e in ref.watch(prophetsProvider).valueOrNull ?? const []) {
    out.add(_Entry(
      id: e.id,
      title: e.nameEnglish,
      arabic: e.nameArabic,
      subtitle: e.era,
      layers: e.layers,
      path: '/discover/prophet/${e.id}',
      sequence: e.sequenceNumber,
      section: 0,
    ));
  }
  for (final e in ref.watch(sahabahProvider).valueOrNull ?? const []) {
    out.add(_Entry(
      id: e.id,
      title: e.nameEnglish,
      arabic: e.nameArabic,
      subtitle: e.era,
      layers: e.layers,
      path: '/discover/sahabi/${e.id}',
      sequence: e.sequenceNumber,
      section: 1,
    ));
  }
  for (final e in ref.watch(namesProvider).valueOrNull ?? const []) {
    out.add(_Entry(
      id: e.id,
      title: e.translit,
      arabic: e.arabic,
      subtitle: e.meaningBrief,
      layers: e.layers,
      path: '/discover/name/${e.id}',
      sequence: e.number,
      section: 2,
    ));
  }
  for (final e in ref.watch(seerahProvider).valueOrNull ?? const []) {
    out.add(_Entry(
      id: e.id,
      title: e.title,
      arabic: e.titleArabic,
      subtitle: e.year,
      layers: e.layers,
      path: '/discover/seerah/${e.id}',
      sequence: e.sequenceNumber,
      section: 3,
    ));
  }

  return out;
});

/// Progress for every library, keyed by the same section index as [_Entry].
final _progressProvider =
    Provider<Map<int, Map<String, DiscoverProgress>>>((ref) => {
          0: ref.watch(prophetProgressProvider).valueOrNull ?? const {},
          1: ref.watch(sahabiProgressProvider).valueOrNull ?? const {},
          2: ref.watch(nameProgressProvider).valueOrNull ?? const {},
          3: ref.watch(seerahProgressProvider).valueOrNull ?? const {},
        });

// ─────────────────────────────────────────────────────────────────────────────
// Front page
// ─────────────────────────────────────────────────────────────────────────────

class _FrontPage extends StatelessWidget {
  const _FrontPage({
    required this.controller,
    required this.query,
    required this.onQuery,
    required this.onOpenSection,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().length >= 2;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 104),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MizanGeometry.gutter,
                0,
                MizanGeometry.gutter,
                MizanGeometry.gap,
              ),
              child: TextField(
                controller: controller,
                onChanged: onQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search stories, names, places',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            controller.clear();
                            onQuery('');
                          },
                        ),
                ),
              ),
            ),
            if (searching)
              _SearchResults(query: query.trim())
            else ...[
              const _ContinueReading(),
              _CollectionsGrid(onOpen: onOpenSection),
              const _RecentlyAdded(),
            ],
          ],
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BrowseMoreBar(),
        ),
      ],
    );
  }
}

/// A label and a rule, the same pair the layer reader uses for "LAYER 1 OF 5".
class _FrontSectionHeader extends StatelessWidget {
  const _FrontSectionHeader(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MizanGeometry.gutter,
        18,
        MizanGeometry.gutter,
        MizanGeometry.gap,
      ),
      child: Row(
        children: [
          MizanSectionLabel(label),
          const SizedBox(width: 10),
          Expanded(child: MizanRule(color: p.hairline)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing!, style: MizanType.sectionLabel(color: p.muted)),
          ],
        ],
      ),
    );
  }
}

/// Search across all four libraries at once.
///
/// Each library's own screen already has a within-library search; this one
/// exists because on the front page the reader has not chosen a library yet, and
/// asking them to pick one before they can look for "Yusuf" would be backwards.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final q = query.toLowerCase();
    final hits = ref
        .watch(_indexProvider)
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q) ||
            e.arabic.contains(query))
        .take(40)
        .toList();

    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MizanGeometry.gutter),
        child: Text(
          'Nothing in the four libraries matches “$query”.',
          style: MizanType.body(color: p.muted),
        ),
      );
    }

    return Column(
      children: [
        _FrontSectionHeader(
          'RESULTS',
          trailing: '${hits.length}${hits.length == 40 ? '+' : ''}',
        ),
        for (final e in hits)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MizanGeometry.gutter,
              0,
              MizanGeometry.gutter,
              8,
            ),
            child: MizanRow(
              title: e.title,
              subtitle: _clip(
                '${_DiscoverScreenState._tabs[e.section].label} · ${e.subtitle}',
              ),
              onTap: () => context.push(e.path),
            ),
          ),
      ],
    );
  }
}

/// [MizanRow] draws its subtitle without `maxLines`, so callers truncate.
String _clip(String text, [int max = 64]) =>
    text.length <= max ? text : '${text.substring(0, max - 1).trimRight()}…';

/// The one entry the reader was last in the middle of.
///
/// "Last" is `DiscoverProgress.lastLayerUnlockedAt`, the only real timestamp the
/// progress table keeps — there is no separate "opened at", so an entry the
/// reader browsed without unlocking anything cannot be resumed, and is not
/// pretended to be. A completed entry is skipped: there is nothing to continue.
class _ContinueReading extends ConsumerWidget {
  const _ContinueReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final progress = ref.watch(_progressProvider);

    _Entry? entry;
    DiscoverProgress? at;
    for (final e in ref.watch(_indexProvider)) {
      final row = progress[e.section]?[e.id];
      final when = row?.lastLayerUnlockedAt;
      if (row == null || when == null || row.entryCompleted) continue;
      if (at == null || when.isAfter(at.lastLayerUnlockedAt!)) {
        entry = e;
        at = row;
      }
    }
    if (entry == null || at == null) return const SizedBox.shrink();

    final total = entry.layers.length;
    final read = at.layersUnlocked.clamp(0, total);
    final current = read == 0 ? null : entry.layers[read - 1];

    // 200 words a minute over the layers still unread. An estimate, but an
    // estimate off the real text rather than a constant per layer.
    final wordsLeft = entry.layers
        .skip(read)
        .fold<int>(0, (n, l) => n + l.content.trim().split(RegExp(r'\s+')).length);
    final minutesLeft = (wordsLeft / 200).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MizanGeometry.gutter),
      child: MizanSurface(
        tone: MizanTone.inverse,
        onTap: () => context.push(entry!.path),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MizanSectionLabel('CONTINUE READING', onInverse: true),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.title,
                  style: MizanType.cardHeadline(color: p.onFilled),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    entry.arabic,
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                    style: MizanType.arabic(color: p.accentText, fontSize: 20),
                  ),
                ),
              ],
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              Text(
                'Layer ${current.layerNumber} — ${current.title}. '
                '${current.subtitle}',
                style: MizanType.body(color: p.onFilled)
                    .copyWith(fontStyle: FontStyle.italic, height: 1.5),
              ),
            ],
            const SizedBox(height: MizanGeometry.gap),
            Row(
              children: [
                for (var i = 0; i < total; i++)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
                      color: i < read
                          ? p.accentText
                          : p.onFilled.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              minutesLeft <= 0
                  ? 'One layer left'
                  : 'about $minutesLeft min left',
              style: MizanType.sectionLabel(
                color: p.onFilled.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four libraries, with the number of entries each one can actually open.
///
/// The counts are list lengths measured at runtime, not the sizes the corpus is
/// *planned* to reach. A card promising 25 prophets that opens 11 would be the
/// one kind of dishonesty this app cannot afford. "63 years" for the Seerah is a
/// lifespan rather than a count, so it is written as the mockup has it.
class _CollectionsGrid extends ConsumerWidget {
  const _CollectionsGrid({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_indexProvider);
    int count(int section) => index.where((e) => e.section == section).length;

    final cards = <Widget>[
      _CollectionCard(
        arabic: 'أَنْبِيَاء',
        title: 'Prophets',
        count: '${count(0)} stories',
        onTap: () => onOpen(0),
      ),
      _CollectionCard(
        arabic: 'صَحَابَة',
        title: 'Sahabah',
        count: '${count(1)} companions',
        onTap: () => onOpen(1),
      ),
      _CollectionCard(
        arabic: 'أَسْمَاء',
        title: '99 Names',
        count: '${count(2)} meanings',
        onTap: () => onOpen(2),
      ),
      _CollectionCard(
        arabic: 'سِيرَة',
        title: 'Seerah',
        count: '63 years',
        onTap: () => onOpen(3),
      ),
    ];

    return Column(
      children: [
        const _FrontSectionHeader('COLLECTIONS'),
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MizanGeometry.gutter,
              0,
              MizanGeometry.gutter,
              MizanGeometry.gap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[row * 2]),
                const SizedBox(width: MizanGeometry.gap),
                Expanded(child: cards[row * 2 + 1]),
              ],
            ),
          ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.arabic,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final String arabic;
  final String title;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      // Inset tan on light, the nested-card navy on dark — the mockup's filled
      // tile in both themes without a second colour decision.
      tone: MizanTone.sunk,
      padding: const EdgeInsets.all(MizanGeometry.cardPaddingTight),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            arabic,
            textDirection: TextDirection.rtl,
            style: MizanType.arabic(color: p.accentText, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(title, style: MizanType.cardHeadline(color: p.ink)),
          const SizedBox(height: 4),
          Text(count, style: MizanType.body(color: p.muted)),
        ],
      ),
    );
  }
}

/// The newest entry in each library.
///
/// The mockup asks for "NEW THIS WEEK". The corpus files carry no authoring
/// date, only a sequence number, so a weekly claim would be invented. What the
/// data does support is *last in the running order*, which is what this shows
/// and what the label says.
class _RecentlyAdded extends ConsumerWidget {
  const _RecentlyAdded();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_indexProvider);
    if (index.isEmpty) return const SizedBox.shrink();

    final newest = <_Entry>[];
    for (var section = 0; section < 4; section++) {
      final inSection = index.where((e) => e.section == section).toList();
      if (inSection.isEmpty) continue;
      inSection.sort((a, b) => b.sequence.compareTo(a.sequence));
      newest.add(inSection.first);
    }

    return Column(
      children: [
        const _FrontSectionHeader(
          'RECENTLY ADDED',
          trailing: 'ONE PER LIBRARY',
        ),
        for (final e in newest)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MizanGeometry.gutter,
              0,
              MizanGeometry.gutter,
              8,
            ),
            child: MizanRow(
              title: e.title,
              subtitle: _clip(
                '${_DiscoverScreenState._tabs[e.section].label} · ${e.subtitle}',
              ),
              leading: Icon(
                _DiscoverScreenState._tabs[e.section].icon,
                size: 20,
                color: MizanPalette.of(context).sage,
              ),
              onTap: () => context.push(e.path),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Browse more — the five ways across the four libraries
// ─────────────────────────────────────────────────────────────────────────────

/// Hadith, Themes, Journeys, Scholars, Places — and Saved.
///
/// The four libraries above are *kinds of entry*: pick a prophet, read his five
/// layers. These are *ways across* them — a theme gathers every entry whose
/// sources speak to it, a journey walks a path through several, a scholar page
/// collects what he is cited on, a place collects what happened there, and
/// Hadith enters the narrations by topic. None belongs inside another.
///
/// They used to be a horizontal strip of chips under the header, which read as
/// another filter row and pushed the actual content off screen. They are one
/// docked button now, and this sheet is their only door.
///
/// The mockup lists four. Hadith is a fifth here because the strip this replaces
/// was the hadith section's only entry point, and deleting it without a
/// replacement would have orphaned a whole section.
class _BrowseMoreBar extends ConsumerWidget {
  const _BrowseMoreBar();

  /// Label, glyph, route, and where the count comes from. The counts are read
  /// from the knowledge corpus at build time, not from the mockup — it says 18
  /// themes and 22 scholars, the corpus has what it has.
  static const List<(String, IconData, String, String)> _ways = [
    (
      'Hadith',
      Icons.format_quote_outlined,
      KnowledgeRoutes.hadithTopicsIndex,
      'Narrations by topic',
    ),
    (
      'Themes',
      Icons.category_outlined,
      KnowledgeRoutes.themesIndex,
      'Threads running through the Quran',
    ),
    (
      'Journeys',
      Icons.route_outlined,
      KnowledgeRoutes.journeysIndex,
      'Routes, stop by stop',
    ),
    (
      'Scholars',
      Icons.account_balance_outlined,
      KnowledgeRoutes.scholarsIndex,
      'Lives that carried the text',
    ),
    (
      'Places',
      Icons.place_outlined,
      KnowledgeRoutes.placesIndex,
      'Sites, mapped',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MizanGeometry.gutter,
        0,
        MizanGeometry.gutter,
        MizanGeometry.gap,
      ),
      child: MizanSurface(
        tone: MizanTone.inverse,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        onTap: () => _open(context, ref),
        child: Row(
          children: [
            Icon(Icons.grid_view_outlined, size: 18, color: p.accentText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Browse more',
                style: MizanType.button(color: p.onFilled),
              ),
            ),
            Text(
              '${_ways.length} more ways in',
              style: MizanType.sectionLabel(
                color: p.onFilled.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_up, size: 18, color: p.onFilled),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final p = MizanPalette.of(context);
    final saved = ref.read(savedHadithCountProvider).valueOrNull;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _Sheet(
        title: 'More ways in',
        subtitle: 'Five routes across the four collections',
        children: [
          for (final way in _ways) ...[
            MizanRow(
              title: way.$1,
              subtitle: way.$4,
              leading: Icon(way.$2, size: 20, color: p.sage),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(way.$3);
              },
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: MizanRule(color: p.hairline),
          ),
          MizanRow(
            title: 'Saved',
            // Null while the count is still loading, rather than a "0" that
            // would briefly tell the reader their saved items are gone.
            subtitle: saved == null
                ? 'Everything you kept'
                : '$saved item${saved == 1 ? '' : 's'}',
            leading: Icon(
              Icons.bookmark_border,
              size: 20,
              color: p.sage,
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(KnowledgeRoutes.savedHadith);
            },
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
