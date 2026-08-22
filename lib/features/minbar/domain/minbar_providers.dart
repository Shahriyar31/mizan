/// Al-Minbar providers — the bridge between the public-feed repository and UI.
///
/// [minbarRepositoryProvider] is the single swap-point for a future backend.
/// [minbarFeedProvider] loads the feed a page at a time ([loadMore]) so the UI
/// scales past a handful of posts, and toggles reactions optimistically so a
/// tap feels instant.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../identity/domain/identity_providers.dart';
import '../data/local_minbar_repository.dart';
import '../data/minbar_repository.dart';
import '../data/supabase_minbar_repository.dart';
import '../models/minbar_models.dart';

// ── Repository ────────────────────────────────────────────────────
// Signed in (Supabase Auth) → real backend. Signed out → on-device SQLite,
// unchanged from before real auth existed.
final minbarRepositoryProvider = Provider<MinbarRepository>((ref) {
  final online = ref.watch(isOnlineIdentityProvider);
  return online ? SupabaseMinbarRepository() : LocalMinbarRepository();
});

// ── The public feed ───────────────────────────────────────────────
final minbarFeedProvider =
    AsyncNotifierProvider<MinbarFeedNotifier, List<MinbarShareView>>(
  MinbarFeedNotifier.new,
);

class MinbarFeedNotifier extends AsyncNotifier<List<MinbarShareView>> {
  static const int _pageSize = AppConstants.minbarPageSize;

  int _loaded = 0; // how many posts we've pulled so far
  bool _hasMore = true; // is there another page to fetch?
  bool get hasMore => _hasMore;

  @override
  Future<List<MinbarShareView>> build() async {
    final user = await ref.watch(effectiveUserProvider.future);
    final repo = ref.watch(minbarRepositoryProvider);
    final firstPage = await repo.getFeed(
      currentUserId: user.id,
      limit: _pageSize,
      offset: 0,
    );
    _loaded = firstPage.length;
    _hasMore = firstPage.length == _pageSize;
    return firstPage;
  }

  /// Reload from the top (used by pull-to-refresh and after publishing).
  Future<void> refresh() async {
    _loaded = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(effectiveUserProvider.future);
      final page = await ref.read(minbarRepositoryProvider).getFeed(
            currentUserId: user.id,
            limit: _pageSize,
            offset: 0,
          );
      _loaded = page.length;
      _hasMore = page.length == _pageSize;
      return page;
    });
  }

  /// Fetch the next page and append it. Safe to call repeatedly; it no-ops
  /// once the end is reached or while a load is already in flight.
  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.value;
    if (current == null) return;

    final user = await ref.read(effectiveUserProvider.future);
    final next = await ref.read(minbarRepositoryProvider).getFeed(
          currentUserId: user.id,
          limit: _pageSize,
          offset: _loaded,
        );
    _loaded += next.length;
    _hasMore = next.length == _pageSize;
    state = AsyncValue.data([...current, ...next]);
  }

  /// Publish content to the public feed, then reload from the top.
  Future<void> share(SharedContent content) async {
    final user = await ref.read(effectiveUserProvider.future);
    await ref
        .read(minbarRepositoryProvider)
        .shareToMinbar(user: user, content: content);
    await refresh();
  }

  /// Toggle a reaction optimistically, then persist. Reverts on failure.
  Future<void> react(String shareId, ReactionType reaction) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(_applyToggle(current, shareId, reaction));

    try {
      final user = await ref.read(effectiveUserProvider.future);
      await ref.read(minbarRepositoryProvider).toggleReaction(
            shareId: shareId,
            userId: user.id,
            reaction: reaction,
          );
    } catch (e, st) {
      AppLogger.error('Minbar reaction failed, reverting: $e', tag: 'Minbar');
      state = AsyncValue.error(e, st);
      await refresh();
    }
  }

  List<MinbarShareView> _applyToggle(
    List<MinbarShareView> feed,
    String shareId,
    ReactionType reaction,
  ) {
    return [
      for (final view in feed)
        if (view.share.id != shareId) view else _toggleOne(view, reaction),
    ];
  }

  MinbarShareView _toggleOne(MinbarShareView view, ReactionType reaction) {
    final mine = Set<ReactionType>.from(view.myReactions);
    final counts = Map<ReactionType, int>.from(view.counts);
    if (mine.contains(reaction)) {
      mine.remove(reaction);
      counts[reaction] = (counts[reaction] ?? 1) - 1;
      if ((counts[reaction] ?? 0) <= 0) counts.remove(reaction);
    } else {
      mine.add(reaction);
      counts[reaction] = (counts[reaction] ?? 0) + 1;
    }
    return MinbarShareView(
      share: view.share,
      counts: counts,
      myReactions: mine,
    );
  }
}
