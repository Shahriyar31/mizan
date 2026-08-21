/// LocalMinbarRepository — SQLite implementation of [MinbarRepository].
///
/// The public feed, stored on-device for now. Mirrors the Halaqa local repo:
/// the feed is fetched in two queries (posts, then all reactions for that page
/// in one `IN (...)`), aggregated in Dart. Pagination via LIMIT/OFFSET keeps it
/// scalable as the feed grows.
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/logger.dart';
import '../../../services/database/database_service.dart';
import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/user_profile.dart';
import '../models/minbar_models.dart';
import 'minbar_repository.dart';

class LocalMinbarRepository implements MinbarRepository {
  LocalMinbarRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  static const String _tag = 'LocalMinbarRepository';
  static const String _shares = 'minbar_shares';
  static const String _reactions = 'minbar_reactions';

  @override
  Future<List<MinbarShareView>> getFeed({
    required String currentUserId,
    int limit = AppConstants.minbarPageSize,
    int offset = 0,
  }) async {
    final db = await _db.database;

    final shareRows = await db.query(
      _shares,
      orderBy: 'shared_at DESC',
      limit: limit,
      offset: offset,
    );
    if (shareRows.isEmpty) return const [];

    final shares = shareRows.map(MinbarShare.fromMap).toList();
    final shareIds = shares.map((s) => s.id).toList();

    final placeholders = List.filled(shareIds.length, '?').join(',');
    final reactionRows = await db.query(_reactions,
        where: 'share_id IN ($placeholders)', whereArgs: shareIds);

    final counts = <String, Map<ReactionType, int>>{};
    final mine = <String, Set<ReactionType>>{};
    for (final row in reactionRows) {
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
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_shares');
    return (result.first['c'] as int?) ?? 0;
  }

  @override
  Future<MinbarShare> shareToMinbar({
    required UserProfile user,
    required SharedContent content,
  }) async {
    final db = await _db.database;
    final share = MinbarShare(
      id: IdGenerator.uuid(),
      sharedBy: user.id,
      sharedByName: user.displayName,
      content: content,
      sharedAt: DateTime.now(),
    );
    await db.insert(_shares, share.toMap());
    AppLogger.info('Published ${content.contentType.wireName} to Al-Minbar',
        tag: _tag);
    return share;
  }

  @override
  Future<void> toggleReaction({
    required String shareId,
    required String userId,
    required ReactionType reaction,
  }) async {
    final db = await _db.database;
    final existing = await db.query(
      _reactions,
      where: 'share_id = ? AND user_id = ? AND reaction = ?',
      whereArgs: [shareId, userId, reaction.wireName],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.delete(_reactions,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert(
        _reactions,
        MinbarReaction(
          id: IdGenerator.uuid(),
          shareId: shareId,
          userId: userId,
          reaction: reaction,
          createdAt: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
