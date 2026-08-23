/// MINBAR — Al-Minbar, the public feed.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 7 (screen 06 of 08).
/// Behaviour carried over from the previous version unchanged: pull-to-refresh,
/// infinite scroll off [MinbarFeedNotifier.loadMore], optimistic reactions.
///
/// ── The three filter chips, and what each one really is ───────────────
/// The mockup draws "For you · Following · Most liked". All three are here, but
/// two of them are renamed to match what the app can actually do:
///
///   • **"For you" became "Recent"** — the feed is strictly newest-first, and
///     "For you" implies a personalisation model that does not exist.
///
///   • **"Most liked" became "Most reactions"**, because there is no like here —
///     there are three reactions. It sorts client-side over the posts already
///     loaded, which is honest as an *ordering* (a view concern) in a way that a
///     fabricated global ranking would not be. `MinbarRepository.getFeed` takes
///     only `limit`/`offset`, so a true site-wide "top posts" needs a server-side
///     sort; until then the chip reorders what you can see.
///
///   • **"Following" became "Your circles"**, and this one is a change of
///     meaning, not of wording. There is no follow graph in this app — no table,
///     no repository method, nothing — so a "Following" tab could only have shown
///     the same posts as Recent, quietly telling you that you follow everyone.
///     Halaqa membership, though, is a real relationship that already exists in
///     the schema, so the third feed filters the public feed down to people you
///     share a circle with (see `circleMemberIdsProvider`). Same shape as the
///     mockup, backed by a relation that is actually there.
///
/// ── What "filters what you can see" costs ─────────────────────────────
/// Recent and Most reactions are orderings, so they always show every loaded
/// post. Your circles is a *filter*, so it can come back empty even when the
/// feed has posts — the first page simply may not contain anyone you know. That
/// is why its empty state offers "Load more posts" while more pages exist,
/// instead of claiming your circles have been quiet. A server-side filter would
/// be better and needs `getFeed` to take an author list.
///
/// ── Why the compose button does not open a text box ───────────────────
/// You cannot write a post on Al-Minbar. Every share is a snapshot of content
/// already in the app, so it arrives with a citation attached — that single
/// design decision is what makes an uncited post impossible. The compose button
/// therefore sends you to the content, where the existing share sheet takes
/// over.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../halaqa/domain/halaqa_providers.dart';
import '../../identity/domain/identity_providers.dart';
import '../domain/minbar_providers.dart';
import '../models/minbar_models.dart';
import 'widgets/minbar_post_tile.dart';

/// The three feeds. Two are orderings over everything loaded; the third is a
/// filter. See the library comment for what that difference costs.
enum _FeedView {
  recent('Recent'),
  mostReactions('Most reactions'),
  circles('Your circles');

  const _FeedView(this.label);
  final String label;
}

class MinbarScreen extends ConsumerStatefulWidget {
  const MinbarScreen({super.key});

  @override
  ConsumerState<MinbarScreen> createState() => _MinbarScreenState();
}

class _MinbarScreenState extends ConsumerState<MinbarScreen> {
  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;
  _FeedView _view = _FeedView.recent;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _maybeLoadMore();
    }
  }

  Future<void> _maybeLoadMore() async {
    final notifier = ref.read(minbarFeedProvider.notifier);
    if (_loadingMore || !notifier.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await notifier.loadMore();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Applies the selected feed to the loaded posts. Sorts a *copy* — the
  /// notifier's list is shared state.
  List<MinbarShareView> _visible(
    List<MinbarShareView> feed,
    Set<String> circleIds,
  ) {
    switch (_view) {
      case _FeedView.recent:
        return feed;

      case _FeedView.mostReactions:
        final copy = [...feed];
        copy.sort((a, b) {
          final byCount = b.totalReactions.compareTo(a.totalReactions);
          // Ties fall back to newest-first so the order is stable rather than
          // arbitrary between rebuilds.
          return byCount != 0
              ? byCount
              : b.share.sharedAt.compareTo(a.share.sharedAt);
        });
        return copy;

      case _FeedView.circles:
        // Newest-first is kept: this chip changes *who* you see, not the order.
        return feed
            .where((v) => circleIds.contains(v.share.sharedBy))
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final feed = ref.watch(minbarFeedProvider);
    final myId = ref.watch(effectiveUserProvider).valueOrNull?.id;

    // Only resolved when the circles chip is active, so belonging to no circle
    // costs a Halaqa read on the other two feeds. `valueOrNull` treats "still
    // loading" as "no one yet", which shows the load-more empty state for a
    // moment rather than a spinner over a feed that is already on screen.
    final circleIds = _view == _FeedView.circles
        ? ref.watch(circleMemberIdsProvider).valueOrNull ?? const <String>{}
        : const <String>{};
    final inNoCircles = _view == _FeedView.circles &&
        (ref.watch(myHalaqasProvider).valueOrNull?.isEmpty ?? false);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(minbarFeedProvider.notifier).refresh(),
          color: p.link,
          backgroundColor: p.card,
          child: ListView(
            controller: _scroll,
            // Always scrollable so pull-to-refresh still works on an empty or
            // errored feed.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              MizanGeometry.gutter,
              10,
              MizanGeometry.gutter,
              MizanGeometry.scrollBottomPadding,
            ),
            children: [
              const _Header(),
              const SizedBox(height: 16),
              _ViewChips(
                view: _view,
                onChanged: (v) => setState(() => _view = v),
              ),
              const SizedBox(height: 18),
              MizanRule(color: p.hairline),
              const SizedBox(height: 20),
              ...switch (feed) {
                AsyncData(:final value) when value.isEmpty => const [
                    _EmptyFeed(),
                  ],
                AsyncData(:final value) => [
                    ..._buildPosts(_visible(value, circleIds),
                        myId: myId, inNoCircles: inNoCircles),
                    if (_loadingMore) const _LoadingMore(),
                  ],
                AsyncError(:final error) => [
                    _FeedError(
                      message: '$error',
                      onRetry: () => ref.invalidate(minbarFeedProvider),
                    ),
                  ],
                _ => const [_FeedLoading()],
              },
            ],
          ),
        ),
      ),
    );
  }

  /// The posts, or the reason there are none. Reached only when the feed itself
  /// is non-empty, so an empty list here means the circles filter removed
  /// everything — never that Al-Minbar is quiet.
  List<Widget> _buildPosts(
    List<MinbarShareView> posts, {
    required String? myId,
    required bool inNoCircles,
  }) {
    if (posts.isEmpty) {
      return [
        _NoCirclePosts(
          inNoCircles: inNoCircles,
          // Read, not watched: `hasMore` is notifier state that changes only as
          // a result of a load we just triggered, which rebuilds this anyway.
          canLoadMore: ref.read(minbarFeedProvider.notifier).hasMore,
          onLoadMore: _maybeLoadMore,
          onOpenHalaqa: () => context.go('/halaqa'),
        ),
      ];
    }

    return [
      for (final view in posts)
        MinbarPostTile(
          view: view,
          isMine: myId != null && view.share.sharedBy == myId,
          onReact: (r) =>
              ref.read(minbarFeedProvider.notifier).react(view.share.id, r),
          onOpen: view.share.content.routePath == null
              ? null
              : () => context.go(view.share.content.routePath!),
        ),
    ];
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
              // Bronze on cream, gold on navy — Rule #1, because this is text.
              // Paired with the transliteration on the next line, so Rule #6
              // holds too.
              Text(
                'المِنْبَر',
                textDirection: TextDirection.rtl,
                style: MizanType.arabic(color: p.accentText, fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text('Al-Minbar', style: MizanType.screenTitle(color: p.ink)),
              const SizedBox(height: 2),
              Text(
                'Reflections shared with the whole Ummah.',
                style: MizanType.body(color: p.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // The compose button flips with the theme, and it has to: `filled`
        // means navy on light but *gold* on dark, so a hardcoded gold pencil
        // was a gold glyph on a gold disc — an empty coin in the corner.
        // Gold on navy in light, navy on gold in dark; legible either way.
        MizanIconTile(
          icon: Icons.edit_outlined,
          circle: true,
          filled: true,
          size: 54,
          iconSize: 22,
          iconColor: p.isLight ? p.accent : p.onFilled,
          semanticLabel: 'Share something to Al-Minbar',
          onTap: () => _showComposeHint(context),
        ),
      ],
    );
  }
}

/// Explains where sharing starts instead of offering a text box that would
/// produce an uncited post. Both destinations are real screens.
void _showComposeHint(BuildContext context) {
  final p = MizanPalette.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(MizanGeometry.gutter),
      child: MizanSurface(
        tone: MizanTone.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MizanSectionLabel('Share to Al-Minbar'),
            const SizedBox(height: 10),
            Text(
              'Sharing starts with the words, not the post.',
              style: MizanType.cardHeadline(color: p.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Open an ayah or a story, then use share on that screen. '
              'The citation travels with it, so nothing reaches the feed '
              'without its source.',
              style: MizanType.translation(color: p.muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: MizanButton(
                    label: 'Open Quran',
                    kind: MizanButtonKind.primary,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go('/quran');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MizanButton(
                    label: 'Open Discover',
                    kind: MizanButtonKind.secondary,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go('/discover');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════
//  FEED CHIPS
// ══════════════════════════════════════════════════════════════════════

/// Three chips, and they must all be reachable — the whole reason the third one
/// exists is that only two were visible.
///
/// At 13px they measure roughly 75 + 132 + 118 with gaps, which fits a 411dp
/// phone but not a 360dp one, and not either at a large text scale. So the row
/// scrolls horizontally: on a normal screen all three sit there with nothing to
/// scroll, and on a narrow one you can reach the third instead of meeting a
/// yellow overflow stripe. `clipBehavior: none` keeps the selected chip's shadow
/// from being sliced off at the edges of the viewport.
class _ViewChips extends StatelessWidget {
  const _ViewChips({required this.view, required this.onChanged});

  final _FeedView view;
  final ValueChanged<_FeedView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final v in _FeedView.values)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: MizanButton(
                label: v.label,
                // `chip` + `selected` gives the mockup's filled-navy active pill
                // and outlined inactive pills, and the selected state reads
                // through fill and label colour rather than depth.
                kind: MizanButtonKind.chip,
                selected: v == view,
                onPressed: () => onChanged(v),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  NON-CONTENT STATES
// ══════════════════════════════════════════════════════════════════════

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

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

class _LoadingMore extends StatelessWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 20),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          // MizanArch paints at Size.infinite, so it must be given a box — in a
          // Column an unbounded height is a layout exception, not a big arch.
          SizedBox(
            width: 108,
            height: 84,
            child: MizanArch(color: p.accent, rings: 2, opacity: 0.45),
          ),
          const SizedBox(height: 18),
          Text(
            'The minbar is quiet.',
            style: MizanType.cardHeadline(color: p.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing has been shared publicly yet. When someone shares an ayah '
            'or a story, it appears here with its source.',
            textAlign: TextAlign.center,
            style: MizanType.translation(color: p.muted),
          ),
        ],
      ),
    );
  }
}

/// Shown when the circles filter emptied a feed that does have posts. Says which
/// of the two reasons applies rather than one vague line covering both, because
/// the fix is different: join a circle, or keep reading.
class _NoCirclePosts extends StatelessWidget {
  const _NoCirclePosts({
    required this.inNoCircles,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.onOpenHalaqa,
  });

  final bool inNoCircles;
  final bool canLoadMore;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenHalaqa;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: MizanSurface(
        tone: MizanTone.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inNoCircles
                  ? 'You are not in a circle yet.'
                  : 'Nothing from your circles on this page.',
              style: MizanType.cardHeadline(color: p.ink),
            ),
            const SizedBox(height: 8),
            Text(
              inNoCircles
                  ? 'A halaqa is two to eight people who read together. Once you '
                      'are in one, whatever they share publicly collects here.'
                  : 'This feed filters the posts already loaded, so the people '
                      'you read with may be further down. Recent shows everyone.',
              style: MizanType.translation(color: p.muted),
            ),
            const SizedBox(height: 16),
            if (inNoCircles)
              MizanButton(
                label: 'Open Halaqa',
                kind: MizanButtonKind.secondary,
                onPressed: onOpenHalaqa,
              )
            else if (canLoadMore)
              MizanButton(
                label: 'Load more posts',
                kind: MizanButtonKind.secondary,
                onPressed: onLoadMore,
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return MizanSurface(
      tone: MizanTone.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The feed could not be loaded.',
            style: MizanType.bodyStrong(color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(message, style: MizanType.body(color: p.muted)),
          const SizedBox(height: 14),
          MizanButton(
            label: 'Try again',
            kind: MizanButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
