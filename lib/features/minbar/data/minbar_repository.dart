/// MinbarRepository — the abstract contract for the public feed.
///
/// Same idea as [HalaqaRepository]: the UI and providers depend only on this
/// interface, so the current [LocalMinbarRepository] (SQLite) can be replaced
/// by a `SupabaseMinbarRepository` later by changing one provider line. When
/// the feed goes truly global, that swap is where real-time and pagination
/// against a server would live — nothing above this contract changes.
library;

import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/user_profile.dart';
import '../models/minbar_models.dart';

abstract class MinbarRepository {
  /// A page of the public feed as ready-to-render view-models (post +
  /// reaction counts + the current user's own reactions), newest first.
  /// [limit]/[offset] page the feed so it scales past a handful of posts.
  Future<List<MinbarShareView>> getFeed({
    required String currentUserId,
    int limit,
    int offset,
  });

  /// Total number of posts (used to know when pagination has reached the end).
  Future<int> feedCount();

  /// Publish a piece of content to the public feed.
  Future<MinbarShare> shareToMinbar({
    required UserProfile user,
    required SharedContent content,
  });

  /// Toggle one reaction on one post for one user (add if absent, remove if
  /// present). A user may hold several different reactions on the same post.
  Future<void> toggleReaction({
    required String shareId,
    required String userId,
    required ReactionType reaction,
  });

  /// Withdraw a post from the public feed. **Author-only self-deletion** — this
  /// is not a moderation hook.
  ///
  /// [userId] is not passed so the implementation can check it and then decide;
  /// it is part of the delete predicate itself, so a post belonging to anyone
  /// else matches no row and the call is a no-op rather than a refusal. Both
  /// implementations enforce that independently of the UI, and the Supabase one
  /// independently of RLS as well: a caller that reaches this contract from
  /// somewhere new cannot accidentally acquire the power to remove other
  /// people's posts. There is deliberately no "delete any post" method to add
  /// that power to — the only way to remove a post is to have published it.
  ///
  /// The post's reactions go with it. A reaction is a response to one specific
  /// post and cannot outlive it, so leaving the ledger behind would keep counts
  /// for something nobody can read.
  Future<void> deleteShare({
    required String shareId,
    required String userId,
  });
}
