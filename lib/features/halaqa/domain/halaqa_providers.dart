/// Halaqa providers — the bridge between the repository and the UI.
///
/// The UI only ever watches these; it never touches SQLite or the repository
/// directly. That keeps widgets dumb and testable.
///
/// [halaqaRepositoryProvider] is the ONE line you change to go from local to a
/// real backend later: return a `SupabaseHalaqaRepository()` and everything
/// above keeps working unchanged.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/logger.dart';
import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../identity/domain/identity_providers.dart';
import '../data/halaqa_repository.dart';
import '../data/local_halaqa_repository.dart';
import '../data/supabase_halaqa_repository.dart';
import '../models/halaqa_models.dart';

// ── Repository ────────────────────────────────────────────────────
// Signed in (Supabase Auth) → real backend. Signed out → on-device SQLite,
// unchanged from before real auth existed.
final halaqaRepositoryProvider = Provider<HalaqaRepository>((ref) {
  final online = ref.watch(isOnlineIdentityProvider);
  return online ? SupabaseHalaqaRepository() : LocalHalaqaRepository();
});

// ── My circles ────────────────────────────────────────────────────
// The list of circles the current user belongs to. Drives the Halaqa tab's
// top-level state: empty (create/join) vs. a list of circles.
final myHalaqasProvider =
    AsyncNotifierProvider<MyHalaqasNotifier, List<Halaqa>>(
  MyHalaqasNotifier.new,
);

class MyHalaqasNotifier extends AsyncNotifier<List<Halaqa>> {
  @override
  Future<List<Halaqa>> build() async {
    final user = await ref.watch(effectiveUserProvider.future);
    final repo = ref.watch(halaqaRepositoryProvider);
    return repo.getHalaqasForUser(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(effectiveUserProvider.future);
      return ref.read(halaqaRepositoryProvider).getHalaqasForUser(user.id);
    });
  }

  /// Create a new circle. Returns it so the UI can navigate straight in.
  Future<Halaqa> create(String name) async {
    final user = await ref.read(effectiveUserProvider.future);
    final halaqa =
        await ref.read(halaqaRepositoryProvider).createHalaqa(
              name: name,
              creator: user,
            );
    await refresh();
    return halaqa;
  }

  /// Join a circle by invite code. Throws [HalaqaException] on failure so the
  /// UI can show the precise reason (not found / full / already a member).
  Future<Halaqa> join(String inviteCode) async {
    final user = await ref.read(effectiveUserProvider.future);
    final halaqa = await ref.read(halaqaRepositoryProvider).joinHalaqa(
          inviteCode: inviteCode,
          user: user,
        );
    await refresh();
    return halaqa;
  }

  /// The circle behind an invite code, without joining it.
  ///
  /// Used for one case only: [join] threw [HalaqaErrorKind.alreadyMember], which
  /// is not really a failure — the person typed a code for a circle they are in,
  /// and what they wanted was to be inside it. The join sheet looks the circle up
  /// and opens it instead of showing an error about it.
  Future<Halaqa?> lookUp(String inviteCode) =>
      ref.read(halaqaRepositoryProvider).getHalaqaByInviteCode(inviteCode);

  Future<void> leave(String halaqaId) async {
    final user = await ref.read(effectiveUserProvider.future);
    await ref
        .read(halaqaRepositoryProvider)
        .leaveHalaqa(halaqaId: halaqaId, userId: user.id);
    await refresh();
  }
}

// ── A single circle ───────────────────────────────────────────────
final halaqaByIdProvider =
    FutureProvider.family<Halaqa?, String>((ref, halaqaId) async {
  ref.watch(myHalaqasProvider); // refresh if membership changes
  return ref.read(halaqaRepositoryProvider).getHalaqaById(halaqaId);
});

// ── Member count (lightweight — for the circle list) ──────────────
// Deliberately does NOT go through the feed provider, so simply listing your
// circles never marks you "active" in all of them (that would break nudges).
final halaqaMemberCountProvider =
    FutureProvider.family<int, String>((ref, halaqaId) async {
  ref.watch(myHalaqasProvider); // refresh if membership changes
  return ref.read(halaqaRepositoryProvider).memberCount(halaqaId);
});

// ── Members of a circle ───────────────────────────────────────────
final halaqaMembersProvider =
    FutureProvider.family<List<HalaqaMember>, String>((ref, halaqaId) async {
  // Re-runs when the feed changes (activity updates last_active_at).
  ref.watch(halaqaFeedProvider(halaqaId));
  return ref.read(halaqaRepositoryProvider).getMembers(halaqaId);
});

// ── Quiet members (nudge candidates) ──────────────────────────────
final quietMembersProvider =
    FutureProvider.family<List<HalaqaMember>, String>((ref, halaqaId) async {
  ref.watch(halaqaFeedProvider(halaqaId));
  final user = await ref.read(effectiveUserProvider.future);
  return ref.read(halaqaRepositoryProvider).quietMembers(
        halaqaId: halaqaId,
        excludeUserId: user.id,
      );
});

// ── The circle feed ───────────────────────────────────────────────
// AsyncNotifier.family keyed by halaqaId. Handles reactions optimistically so
// a tap feels instant, then persists in the background.
final halaqaFeedProvider = AsyncNotifierProvider.family<HalaqaFeedNotifier,
    List<HalaqaShareView>, String>(
  HalaqaFeedNotifier.new,
);

class HalaqaFeedNotifier
    extends FamilyAsyncNotifier<List<HalaqaShareView>, String> {
  String get _halaqaId => arg;

  @override
  Future<List<HalaqaShareView>> build(String arg) async {
    final user = await ref.watch(effectiveUserProvider.future);
    final repo = ref.watch(halaqaRepositoryProvider);
    // Opening the circle counts as activity.
    await repo.touchMember(halaqaId: arg, userId: user.id);
    return repo.getFeed(halaqaId: arg, currentUserId: user.id);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(effectiveUserProvider.future);
      return ref
          .read(halaqaRepositoryProvider)
          .getFeed(halaqaId: _halaqaId, currentUserId: user.id);
    });
  }

  /// Share a piece of content into this circle, then refresh the feed.
  Future<void> share({
    required SharedContent content,
    String? personalNote,
  }) async {
    final user = await ref.read(effectiveUserProvider.future);
    await ref.read(halaqaRepositoryProvider).shareToHalaqa(
          halaqaId: _halaqaId,
          user: user,
          content: content,
          personalNote: personalNote,
        );
    await refresh();
  }

  /// Toggle a reaction. We update the in-memory feed immediately (so the tap
  /// is instant), then write to the database. If the write fails, we refresh
  /// to snap back to the true state.
  Future<void> react(String shareId, ReactionType reaction) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(_applyToggle(current, shareId, reaction));

    try {
      final user = await ref.read(effectiveUserProvider.future);
      await ref.read(halaqaRepositoryProvider).toggleReaction(
            shareId: shareId,
            userId: user.id,
            reaction: reaction,
          );
      // Keep dependent providers (members/quiet) in sync without a full reload.
      ref.invalidate(halaqaMembersProvider(_halaqaId));
      ref.invalidate(quietMembersProvider(_halaqaId));
    } catch (e, st) {
      AppLogger.error('Reaction failed, reverting: $e', tag: 'HalaqaFeed');
      state = AsyncValue.error(e, st);
      await refresh();
    }
  }

  /// Pure helper: return a new feed list with [reaction] toggled on [shareId]
  /// for the current user (count +/- 1, membership added/removed).
  List<HalaqaShareView> _applyToggle(
    List<HalaqaShareView> feed,
    String shareId,
    ReactionType reaction,
  ) {
    return [
      for (final view in feed)
        if (view.share.id != shareId)
          view
        else
          _toggleOne(view, reaction),
    ];
  }

  HalaqaShareView _toggleOne(HalaqaShareView view, ReactionType reaction) {
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
    return HalaqaShareView(
      share: view.share,
      counts: counts,
      myReactions: mine,
    );
  }
}
