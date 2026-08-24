/// SupabaseMinbarRepository — real backend implementation of
/// [MinbarRepository], for signed-in (Supabase Auth) users.
///
/// The public feed is readable by anyone (RLS: anon + authenticated);
/// writes always carry `auth.uid()` as `shared_by`/`user_id`, enforced
/// server-side — see supabase/migrations/003_halaqa_minbar_online.sql.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/user_profile.dart';
import '../models/minbar_models.dart';
import 'minbar_repository.dart';

class SupabaseMinbarRepository implements MinbarRepository {
  SupabaseClient get _c => Supabase.instance.client;
  static const String _tag = 'SupabaseMinbarRepository';

  @override
  Future<List<MinbarShareView>> getFeed({
    required String currentUserId,
    int limit = AppConstants.minbarPageSize,
    int offset = 0,
  }) async {
    final shareRows = await _c
        .from('minbar_shares')
        .select()
        .order('shared_at', ascending: false)
        .range(offset, offset + limit - 1);
    final shares = (shareRows as List)
        .map((r) => _shareFromRow(r as Map<String, dynamic>))
        .toList();
    if (shares.isEmpty) return const [];

    final shareIds = shares.map((s) => s.id).toList();
    final reactionRows = await _c
        .from('minbar_reactions')
        .select()
        .inFilter('share_id', shareIds);

    final counts = <String, Map<ReactionType, int>>{};
    final mine = <String, Set<ReactionType>>{};
    for (final row in (reactionRows as List).cast<Map<String, dynamic>>()) {
      final shareId = row['share_id'] as String;
      final type = ReactionTypeX.fromWire(row['reaction'] as String?);
      final map = counts.putIfAbsent(shareId, () => <ReactionType, int>{});
      map[type] = (map[type] ?? 0) + 1;
      if (row['user_id'] as String == currentUserId) {
        mine.putIfAbsent(shareId, () => <ReactionType>{}).add(type);
      }
    }

    return [
      for (final share in shares)
        MinbarShareView(
          share: share,
          counts: counts[share.id] ?? const {},
          myReactions: mine[share.id] ?? const {},
        ),
    ];
  }

  @override
  Future<int> feedCount() async {
    // A HEAD request carrying `Prefer: count=exact` — Postgres does the
    // counting and sends no rows at all. `PostgrestQueryBuilder.count` resolves
    // straight to an `int` (postgrest 2.9.1). The previous `.select('id')` +
    // `.length` pulled every id in the table across the network purely to
    // measure it, so the cost of asking "is the feed empty?" grew with the feed.
    return _c.from('minbar_shares').count(CountOption.exact);
  }

  @override
  Future<MinbarShare> shareToMinbar({
    required UserProfile user,
    required SharedContent content,
  }) async {
    final row = await _c
        .from('minbar_shares')
        .insert({
          'shared_by': user.id,
          'shared_by_name': user.displayName,
          'content_id': content.contentId,
          'content_type': content.contentType.wireName,
          'content_json': content.encode(),
        })
        .select()
        .single();
    AppLogger.info('Published ${content.contentType.wireName} to Al-Minbar',
        tag: _tag);
    return _shareFromRow(row);
  }

  @override
  Future<void> toggleReaction({
    required String shareId,
    required String userId,
    required ReactionType reaction,
  }) async {
    final existing = await _c
        .from('minbar_reactions')
        .select('id')
        .eq('share_id', shareId)
        .eq('user_id', userId)
        .eq('reaction', reaction.wireName)
        .maybeSingle();

    if (existing != null) {
      await _c.from('minbar_reactions').delete().eq('id', existing['id']);
    } else {
      await _c.from('minbar_reactions').insert({
        'share_id': shareId,
        'user_id': userId,
        'reaction': reaction.wireName,
      });
    }
  }

  /// Author-only self-deletion. See [MinbarRepository.deleteShare].
  ///
  /// `shared_by` is the column [shareToMinbar] inserts `user.id` into. It is in
  /// the filter as well as the id, so this is defence in depth rather than
  /// belt-and-braces duplication: RLS already enforces `auth.uid() = shared_by`
  /// on DELETE independently (minbar_shares_delete_own, see
  /// supabase/migrations/005_fix_rls_and_backfill.sql), and the client filter
  /// means the request never asks for something the policy will refuse. Either
  /// one alone would be enough; neither is trusted to be the only one.
  ///
  /// The reactions are removed by the database — minbar_reactions.share_id is
  /// `REFERENCES minbar_shares(id) ON DELETE CASCADE`, so no second call is
  /// needed here. The local repository has to delete them by hand because
  /// on-device SQLite carries no such foreign key.
  @override
  Future<void> deleteShare({
    required String shareId,
    required String userId,
  }) async {
    try {
      await _c
          .from('minbar_shares')
          .delete()
          .eq('id', shareId)
          .eq('shared_by', userId);
    } on PostgrestException catch (e) {
      // 23503 here has exactly one possible cause: a reaction row refused to
      // go, meaning the cascade this method depends on is absent from the live
      // database. Worth naming, because that constraint is *declared* in
      // 003 — and 005 and 006 both exist because this database was built from a
      // schema dump that carried the table definitions and none of the rules
      // attached to them. supabase/migrations/007_fix_delete_cascades.sql
      // verifies and repairs it.
      if (e.code == '23503') {
        AppLogger.error(
            'Post $shareId will not delete: minbar_reactions.share_id is '
            'missing its ON DELETE CASCADE — run migration 007',
            tag: _tag);
      }
      rethrow;
    }
    AppLogger.info('Removed an Al-Minbar post and its reactions', tag: _tag);
  }

  MinbarShare _shareFromRow(Map<String, dynamic> row) {
    final json = row['content_json'] as String?;
    return MinbarShare(
      id: row['id'] as String,
      sharedBy: row['shared_by'] as String,
      sharedByName: (row['shared_by_name'] as String?) ?? '',
      content: json != null
          ? SharedContent.decode(json)
          : SharedContent(
              contentType:
                  ContentTypeX.fromWire(row['content_type'] as String?),
              contentId: row['content_id'] as String? ?? '',
              title: '',
              excerpt: '',
              citationSource: '',
            ),
      sharedAt: DateTime.parse(row['shared_at'] as String),
    );
  }
}
