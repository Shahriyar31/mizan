/// MinbarScreen — the Al-Minbar tab (public feed).
///
/// A single scrolling feed of public posts, newest first. It:
///   • watches [minbarFeedProvider] and renders loading / error / empty / data,
///   • supports pull-to-refresh,
///   • loads more as you near the bottom (infinite scroll) using the notifier's
///     paging, so the feed scales past a handful of posts.
///
/// Reactions are the only response — tapping one goes straight to the notifier,
/// which updates optimistically. There are no text replies anywhere.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/minbar_providers.dart';
import '../models/minbar_models.dart';
import 'widgets/minbar_post_tile.dart';

class MinbarScreen extends ConsumerStatefulWidget {
  const MinbarScreen({super.key});

  @override
  ConsumerState<MinbarScreen> createState() => _MinbarScreenState();
}

class _MinbarScreenState extends ConsumerState<MinbarScreen> {
  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;

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
    final nearBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400;
    if (nearBottom) _maybeLoadMore();
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

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(minbarFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 8),
            Expanded(
              child: feed.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(minbarFeedProvider),
                ),
                data: (posts) => RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.surfaceElevated,
                  onRefresh: () =>
                      ref.read(minbarFeedProvider.notifier).refresh(),
                  child: posts.isEmpty
                      ? const _EmptyFeed()
                      : _buildList(posts),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<MinbarShareView> posts) {
    final count = posts.length;
    final hasMore = ref.read(minbarFeedProvider.notifier).hasMore;
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: count + (hasMore ? 1 : 0),
      separatorBuilder: (_, i) =>
          i < count - 1 ? const SizedBox(height: 22) : const SizedBox.shrink(),
      itemBuilder: (context, i) {
        if (i >= count) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.gold),
              ),
            ),
          );
        }
        final view = posts[i];
        return MinbarPostTile(
          view: view,
          onReact: (r) =>
              ref.read(minbarFeedProvider.notifier).react(view.share.id, r),
          onOpen: (view.share.content.routePath?.isNotEmpty ?? false)
              ? () => context.push(view.share.content.routePath!)
              : null,
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الْمِنْبَر',
              style: AppTypography.arabicDisplay(color: AppColors.gold, size: 20)),
          Text('Al-Minbar',
              style: AppTypography.displayLarge(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Reflections shared with the whole Ummah.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Empty & error states ──────────────────────────────────────────
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: AppColors.gold, size: 38),
              ),
              const SizedBox(height: 24),
              Text('The pulpit is quiet',
                  style:
                      AppTypography.displaySmall(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Be the first to share. Open the Qur\'an or Discover, find '
                'something worth passing on, and tap Share to Al-Minbar.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text('Could not load the feed',
              style: AppTypography.bodyLarge(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text('Try again',
                style: AppTypography.buttonSecondary(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}
