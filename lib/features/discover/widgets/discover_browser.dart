// ─────────────────────────────────────────────────────────────────────────────
// discover_browser.dart
// Reusable browse shell for every Discover section.
//
// Why this exists: a plain ListView is fine for 10 entries and unusable for
// 100 — reaching the last sahabi meant a long, blind scroll. This widget gives
// three orthogonal ways to reach any entry in at most two taps:
//
//   1. Search      — matches English name, transliteration, Arabic, kunyah,
//                    tribe, era or teaser (whatever the screen supplies).
//   2. Status chips — All / New / Reading / Done, so "where was I?" is one tap.
//   3. Jump rail    — the vertical A–Z (or 1–10, 11–20…) strip on the right.
//                    Tapping a label FILTERS to that group instead of
//                    scroll-animating to an offset. Filtering is deterministic:
//                    no offset math, no dependence on item heights, and it works
//                    identically for lists and grids.
//
// It is generic so prophets / sahabah / names / seerah share one behaviour and
// one set of bugs. Sections only supply data accessors and their own card.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:mizan/core/theme/app_colors.dart';
import 'package:mizan/core/theme/app_typography.dart';

/// Reading state of one entry, used by the filter chips.
enum DiscoverItemStatus { fresh, reading, complete }

class DiscoverBrowser<T> extends StatefulWidget {
  final List<T> items;

  /// Everything the search box should match against for one item. Include the
  /// Arabic string too — users type Arabic.
  final List<String> Function(T item) searchTerms;

  /// Group heading an item belongs to ("Quraysh", "A", "1–10", "Makkah").
  final String Function(T item) groupOf;

  /// Explicit group ordering. Groups not listed are appended in first-seen
  /// order. Pass this whenever order is meaningful (chronology), because a
  /// Map's insertion order otherwise depends on the sort of `items`.
  final List<String>? groupOrder;

  final DiscoverItemStatus Function(T item) statusOf;

  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Non-null renders each group as a grid instead of a list.
  final SliverGridDelegate? gridDelegate;

  /// Show the vertical jump rail. Worth it above ~30 entries.
  final bool showRail;

  /// Shortens a group name for the narrow rail ("1–10" -> "10").
  final String Function(String group)? railLabelFor;

  final String searchHint;

  /// Vertical gap between cards in list mode.
  final double itemSpacing;

  const DiscoverBrowser({
    super.key,
    required this.items,
    required this.searchTerms,
    required this.groupOf,
    required this.statusOf,
    required this.itemBuilder,
    this.groupOrder,
    this.gridDelegate,
    this.showRail = false,
    this.railLabelFor,
    this.searchHint = 'Search',
    this.itemSpacing = 16,
  });

  @override
  State<DiscoverBrowser<T>> createState() => _DiscoverBrowserState<T>();
}

class _DiscoverBrowserState<T> extends State<DiscoverBrowser<T>> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  DiscoverItemStatus? _status; // null = All
  String? _activeGroup; // null = every group

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  bool _matchesQuery(T item) {
    if (_query.isEmpty) return true;
    for (final term in widget.searchTerms(item)) {
      if (term.toLowerCase().contains(_query)) return true;
    }
    return false;
  }

  /// Groups in display order. [source] is already query/status filtered.
  Map<String, List<T>> _group(List<T> source) {
    final buckets = <String, List<T>>{};
    for (final item in source) {
      buckets.putIfAbsent(widget.groupOf(item), () => []).add(item);
    }
    final order = widget.groupOrder;
    if (order == null) return buckets;

    final sorted = <String, List<T>>{};
    for (final key in order) {
      final bucket = buckets.remove(key);
      if (bucket != null) sorted[key] = bucket;
    }
    sorted.addAll(buckets); // anything the caller forgot to list
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final byStatus = _status == null
        ? widget.items
        : widget.items.where((i) => widget.statusOf(i) == _status).toList();
    final filtered = byStatus.where(_matchesQuery).toList();
    final groups = _group(filtered);

    // Rail labels come from the FULL set so the alphabet does not jump around
    // as the user filters; unavailable letters render dimmed.
    final allGroups = _group(widget.items).keys.toList();

    final active =
        (_activeGroup != null && groups.containsKey(_activeGroup)) ? _activeGroup : null;
    final visible = active == null
        ? groups
        : <String, List<T>>{active: groups[active]!};

    return Column(
      children: [
        _SearchField(
          controller: _searchCtrl,
          hint: widget.searchHint,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          onClear: () {
            _searchCtrl.clear();
            setState(() => _query = '');
          },
        ),
        _StatusChips(
          selected: _status,
          counts: _counts(),
          total: widget.items.length,
          onSelect: (s) => setState(() => _status = s),
        ),
        if (active != null)
          _ActiveGroupBanner(
            group: active,
            count: visible[active]!.length,
            onClear: () => setState(() => _activeGroup = null),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        query: _query,
                        onReset: () {
                          _searchCtrl.clear();
                          setState(() {
                            _query = '';
                            _status = null;
                            _activeGroup = null;
                          });
                        },
                      )
                    : _buildScroll(visible),
              ),
              if (widget.showRail && allGroups.length > 1)
                _JumpRail(
                  groups: allGroups,
                  available: groups.keys.toSet(),
                  active: active,
                  labelFor: widget.railLabelFor,
                  onTap: (g) => setState(
                      () => _activeGroup = _activeGroup == g ? null : g),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Map<DiscoverItemStatus, int> _counts() {
    final counts = {
      DiscoverItemStatus.fresh: 0,
      DiscoverItemStatus.reading: 0,
      DiscoverItemStatus.complete: 0,
    };
    for (final item in widget.items) {
      final s = widget.statusOf(item);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildScroll(Map<String, List<T>> visible) {
    final slivers = <Widget>[];
    // A single visible group means exactly one header, so pinning it cannot
    // stack with a second one — safe to make it sticky only in that case.
    final pin = visible.length == 1;

    visible.forEach((group, items) {
      slivers.add(SliverPersistentHeader(
        pinned: pin,
        delegate: _GroupHeaderDelegate(title: group, count: items.length),
      ));
      if (widget.gridDelegate != null) {
        slivers.add(SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
          sliver: SliverGrid(
            gridDelegate: widget.gridDelegate!,
            delegate: SliverChildBuilderDelegate(
              (context, i) => widget.itemBuilder(context, items[i]),
              childCount: items.length,
            ),
          ),
        ));
      } else {
        slivers.add(SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: EdgeInsets.only(bottom: widget.itemSpacing),
                child: widget.itemBuilder(context, items[i]),
              ),
              childCount: items.length,
            ),
          ),
        ));
      }
    });

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    return CustomScrollView(slivers: slivers);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded,
                size: 18, color: AppColors.gold.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: AppTypography.bodyMedium(color: AppColors.textPrimary),
                cursorColor: AppColors.gold,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: AppTypography.bodyMedium(color: AppColors.muted),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox(width: 14)
                  : IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: AppColors.muted),
                      onPressed: onClear,
                      splashRadius: 18,
                      tooltip: 'Clear search',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chips
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  final DiscoverItemStatus? selected;
  final Map<DiscoverItemStatus, int> counts;
  final int total;
  final ValueChanged<DiscoverItemStatus?> onSelect;

  const _StatusChips({
    required this.selected,
    required this.counts,
    required this.total,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final specs = <({String label, DiscoverItemStatus? status, int count})>[
      (label: 'All', status: null, count: total),
      (
        label: 'Reading',
        status: DiscoverItemStatus.reading,
        count: counts[DiscoverItemStatus.reading] ?? 0
      ),
      (
        label: 'Done',
        status: DiscoverItemStatus.complete,
        count: counts[DiscoverItemStatus.complete] ?? 0
      ),
      (
        label: 'New',
        status: DiscoverItemStatus.fresh,
        count: counts[DiscoverItemStatus.fresh] ?? 0
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: specs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final spec = specs[i];
          final active = spec.status == selected;
          return GestureDetector(
            onTap: () => onSelect(spec.status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.18)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active
                      ? AppColors.gold.withValues(alpha: 0.75)
                      : AppColors.border,
                ),
              ),
              child: Text(
                '${spec.label}  ${spec.count}',
                style: AppTypography.labelSmall(
                  color: active ? AppColors.goldSoft : AppColors.textSecondary,
                ).copyWith(letterSpacing: 0.3),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active group banner
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveGroupBanner extends StatelessWidget {
  final String group;
  final int count;
  final VoidCallback onClear;

  const _ActiveGroupBanner({
    required this.group,
    required this.count,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Icon(Icons.filter_alt_rounded,
              size: 14, color: AppColors.gold.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Showing $group · $count',
              style: AppTypography.labelSmall(color: AppColors.goldSoft),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('Show all',
                  style: AppTypography.labelSmall(color: AppColors.jadeLight)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group header
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;

  _GroupHeaderDelegate({required this.title, required this.count});

  static const _height = 40.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      height: _height,
      color: AppColors.night,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.labelSmall(color: AppColors.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.gold.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 10),
          Text('$count',
              style: AppTypography.labelSmall(
                  color: AppColors.muted.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_GroupHeaderDelegate old) =>
      old.title != title || old.count != count;
}

// ─────────────────────────────────────────────────────────────────────────────
// Jump rail
// ─────────────────────────────────────────────────────────────────────────────

class _JumpRail extends StatelessWidget {
  final List<String> groups;
  final Set<String> available;
  final String? active;
  final String Function(String)? labelFor;
  final ValueChanged<String> onTap;

  const _JumpRail({
    required this.groups,
    required this.available,
    required this.active,
    required this.labelFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      margin: const EdgeInsets.only(right: 4, top: 4, bottom: 8),
      child: SingleChildScrollView(
        child: Column(
          children: groups.map((g) {
            final enabled = available.contains(g);
            final isActive = g == active;
            return Semantics(
              button: true,
              selected: isActive,
              label: 'Jump to $g',
              child: GestureDetector(
                onTap: enabled ? () => onTap(g) : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.gold.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labelFor == null ? g : labelFor!(g),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: AppTypography.labelSmall(
                      color: !enabled
                          ? AppColors.muted.withValues(alpha: 0.28)
                          : isActive
                              ? AppColors.goldSoft
                              : AppColors.textSecondary,
                    ).copyWith(fontSize: 9, letterSpacing: 0),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onReset;

  const _EmptyState({required this.query, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 36, color: AppColors.gold.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              query.isEmpty ? 'Nothing here yet' : 'No matches for "$query"',
              textAlign: TextAlign.center,
              style: AppTypography.displaySmall(color: AppColors.parchment),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different spelling, or clear the filters.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onReset,
              child: Text('Reset',
                  style: AppTypography.buttonSecondary(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}
