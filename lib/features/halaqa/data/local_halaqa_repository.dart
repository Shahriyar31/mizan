/// LocalHalaqaRepository — SQLite implementation of [HalaqaRepository].
///
/// This is the "now" implementation: everything lives in the on-device
/// `mizan.db`. It is deliberately the ONLY place that knows about tables
/// and columns for circles. Because it implements [HalaqaRepository], the rest
/// of the app is insulated from it — swapping in a Supabase version later is a
/// one-line change in the provider.
///
/// Notes on a couple of choices:
///  • Feed reactions are fetched in a single `IN (...)` query and aggregated in
///    Dart, so rendering a feed is two queries total, not two-per-card.
///  • Invite codes are generated with a short retry loop to dodge the (tiny)
///    chance of a UNIQUE collision.
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/logger.dart';
import '../../../services/database/database_service.dart';
import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/user_profile.dart';
import '../models/halaqa_models.dart';
import 'halaqa_repository.dart';

class LocalHalaqaRepository implements HalaqaRepository {
  LocalHalaqaRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  static const String _tag = 'LocalHalaqaRepository';

  static const String _halaqas = 'halaqas';
  static const String _members = 'halaqa_members';
  static const String _shares = 'halaqa_shares';
  static const String _reactions = 'halaqa_reactions';

  @override
  Future<List<Halaqa>> getHalaqasForUser(String userId) async {
    final db = await _db.database;
    // Circles this user belongs to, newest circle first.
    final rows = await db.rawQuery('''
      SELECT h.* FROM $_halaqas h
      INNER JOIN $_members m ON m.halaqa_id = h.id
      WHERE m.user_id = ?
      ORDER BY h.created_at DESC
    ''', [userId]);
    return rows.map(Halaqa.fromMap).toList();
  }

  @override
  Future<Halaqa?> getHalaqaById(String halaqaId) async {
    final db = await _db.database;
    final rows =
        await db.query(_halaqas, where: 'id = ?', whereArgs: [halaqaId], limit: 1);
    return rows.isEmpty ? null : Halaqa.fromMap(rows.first);
  }

  @override
  Future<Halaqa?> getHalaqaByInviteCode(String inviteCode) async {
    final code = HalaqaInviteCode.canonical(inviteCode);
    if (code.isEmpty) return null;
    final db = await _db.database;
    final rows = await db.query(_halaqas,
        where: 'invite_code = ?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : Halaqa.fromMap(rows.first);
  }

  @override
  Future<Halaqa> createHalaqa({
    required String name,
    required UserProfile creator,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const HalaqaException(
          HalaqaErrorKind.invalidName, 'A circle needs a name.');
    }

    final db = await _db.database;
    final now = DateTime.now();
    final halaqa = Halaqa(
      id: IdGenerator.uuid(),
      name: trimmed,
      createdBy: creator.id,
      inviteCode: await _uniqueInviteCode(db),
      maxMembers: AppConstants.maxHalaqaMembers,
      createdAt: now,
    );

    // Circle + creator-as-first-member in one transaction so we never end up
    // with an empty circle if something fails midway.
    await db.transaction((txn) async {
      await txn.insert(_halaqas, halaqa.toMap());
      await txn.insert(
        _members,
        HalaqaMember(
          id: IdGenerator.uuid(),
          halaqaId: halaqa.id,
          userId: creator.id,
          displayName: creator.displayName,
          joinedAt: now,
          lastActiveAt: now,
        ).toMap(),
      );
    });

    AppLogger.info('Created halaqa "${halaqa.name}" (${halaqa.inviteCode})',
        tag: _tag);
    return halaqa;
  }

  @override
  Future<Halaqa> joinHalaqa({
    required String inviteCode,
    required UserProfile user,
  }) async {
    final halaqa = await getHalaqaByInviteCode(inviteCode);
    if (halaqa == null) {
      throw const HalaqaException(
          HalaqaErrorKind.notFound, 'No circle found for that code.');
    }

    final db = await _db.database;

    // Already in it? Idempotent — just return the circle.
    final existing = await db.query(_members,
        where: 'halaqa_id = ? AND user_id = ?',
        whereArgs: [halaqa.id, user.id],
        limit: 1);
    if (existing.isNotEmpty) {
      throw const HalaqaException(
          HalaqaErrorKind.alreadyMember, "You're already in this circle.");
    }

    final count = await memberCount(halaqa.id);
    if (count >= halaqa.maxMembers) {
      throw HalaqaException(HalaqaErrorKind.full,
          'This circle is full (${halaqa.maxMembers} members).');
    }

    final now = DateTime.now();
    await db.insert(
      _members,
      HalaqaMember(
        id: IdGenerator.uuid(),
        halaqaId: halaqa.id,
        userId: user.id,
        displayName: user.displayName,
        joinedAt: now,
        lastActiveAt: now,
      ).toMap(),
    );
    AppLogger.info('${user.displayName} joined "${halaqa.name}"', tag: _tag);
    return halaqa;
  }

  @override
  Future<void> leaveHalaqa({
    required String halaqaId,
    required String userId,
  }) async {
    final db = await _db.database;
    await db.delete(_members,
        where: 'halaqa_id = ? AND user_id = ?', whereArgs: [halaqaId, userId]);

    // If the circle is now empty, clean it up entirely (shares + reactions).
    final remaining = await memberCount(halaqaId);
    if (remaining == 0) {
      await db.transaction((txn) async {
        final shareRows = await txn.query(_shares,
            columns: ['id'], where: 'halaqa_id = ?', whereArgs: [halaqaId]);
        final shareIds =
            shareRows.map((r) => r['id'] as String).toList();
        if (shareIds.isNotEmpty) {
          final placeholders = List.filled(shareIds.length, '?').join(',');
          await txn.delete(_reactions,
              where: 'share_id IN ($placeholders)', whereArgs: shareIds);
        }
        await txn.delete(_shares, where: 'halaqa_id = ?', whereArgs: [halaqaId]);
        await txn.delete(_halaqas, where: 'id = ?', whereArgs: [halaqaId]);
      });
      AppLogger.info('Deleted empty halaqa $halaqaId', tag: _tag);
    }
  }

  @override
  Future<List<HalaqaMember>> getMembers(String halaqaId) async {
    final db = await _db.database;
    final rows = await db.query(_members,
        where: 'halaqa_id = ?', whereArgs: [halaqaId], orderBy: 'joined_at ASC');
    return rows.map(HalaqaMember.fromMap).toList();
  }

  @override
  Future<int> memberCount(String halaqaId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_members WHERE halaqa_id = ?', [halaqaId]);
    return (result.first['c'] as int?) ?? 0;
  }

  @override
  Future<List<HalaqaShareView>> getFeed({
    required String halaqaId,
    required String currentUserId,
  }) async {
    final db = await _db.database;

    final shareRows = await db.query(_shares,
        where: 'halaqa_id = ?', whereArgs: [halaqaId], orderBy: 'shared_at DESC');
    if (shareRows.isEmpty) return const [];

    final shares = shareRows.map(HalaqaShare.fromMap).toList();
    final shareIds = shares.map((s) => s.id).toList();

    // One query for every reaction on this page of shares.
    final placeholders = List.filled(shareIds.length, '?').join(',');
    final reactionRows = await db.query(_reactions,
        where: 'share_id IN ($placeholders)', whereArgs: shareIds);

    // Aggregate counts per share, and note which are the current user's.
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
        HalaqaShareView(
          share: share,
          counts: counts[share.id] ?? const {},
          myReactions: mine[share.id] ?? const {},
        ),
    ];
  }

  @override
  Future<HalaqaShare> shareToHalaqa({
    required String halaqaId,
    required UserProfile user,
    required SharedContent content,
    String? personalNote,
  }) async {
    final db = await _db.database;
    final note = _sanitizeNote(personalNote);
    final share = HalaqaShare(
      id: IdGenerator.uuid(),
      halaqaId: halaqaId,
      sharedBy: user.id,
      sharedByName: user.displayName,
      content: content,
      personalNote: note,
      sharedAt: DateTime.now(),
    );
    await db.insert(_shares, share.toMap());
    await touchMember(halaqaId: halaqaId, userId: user.id);
    AppLogger.info('Shared ${content.contentType.wireName} to circle $halaqaId',
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
        HalaqaReaction(
          id: IdGenerator.uuid(),
          shareId: shareId,
          userId: userId,
          reaction: reaction,
          createdAt: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Reacting counts as being active — keep the sharer's circle "warm".
    final shareRow = await db.query(_shares,
        columns: ['halaqa_id'], where: 'id = ?', whereArgs: [shareId], limit: 1);
    if (shareRow.isNotEmpty) {
      await touchMember(
          halaqaId: shareRow.first['halaqa_id'] as String, userId: userId);
    }
  }

  @override
  Future<List<HalaqaMember>> quietMembers({
    required String halaqaId,
    int days = AppConstants.daysBeforeNudge,
    String? excludeUserId,
  }) async {
    final now = DateTime.now();
    final members = await getMembers(halaqaId);
    return members
        .where((m) => m.userId != excludeUserId)
        .where((m) => m.isQuiet(days: days, now: now))
        .toList();
  }

  @override
  Future<void> touchMember({
    required String halaqaId,
    required String userId,
  }) async {
    final db = await _db.database;
    await db.update(
      _members,
      {'last_active_at': DateTime.now().toIso8601String()},
      where: 'halaqa_id = ? AND user_id = ?',
      whereArgs: [halaqaId, userId],
    );
  }

  // ── helpers ────────────────────────────────────────────────────

  /// Trim, collapse, and hard-cap the personal note at the README's limit.
  String? _sanitizeNote(String? note) {
    if (note == null) return null;
    final trimmed = note.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= AppConstants.personalNoteMaxLength
        ? trimmed
        : trimmed.substring(0, AppConstants.personalNoteMaxLength);
  }

  /// Generate an invite code not already used. Retries a few times before
  /// falling back to a longer code (collision odds become astronomically low).
  Future<String> _uniqueInviteCode(Database db) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = IdGenerator.inviteCode(length: attempt < 4 ? 6 : 8);
      final hit = await db.query(_halaqas,
          columns: ['id'], where: 'invite_code = ?', whereArgs: [code], limit: 1);
      if (hit.isEmpty) return code;
    }
    // Extremely unlikely; make it effectively certain to be unique.
    return IdGenerator.inviteCode(length: 10);
  }
}
