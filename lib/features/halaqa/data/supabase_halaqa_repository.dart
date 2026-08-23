/// SupabaseHalaqaRepository — real backend implementation of
/// [HalaqaRepository], for signed-in (Supabase Auth) users.
///
/// Ownership is always `auth.uid()` on the server (enforced by RLS —
/// supabase/migrations/002_auth_rls.sql + 003_halaqa_minbar_online.sql).
/// The [UserProfile] passed in here must already carry the authenticated
/// user's real id (see halaqa_providers.dart's `effectiveUserProvider`) —
/// this repository never invents an id.
///
/// ── A member's name is read, never written ────────────────────────────
/// `halaqa_members` has no `display_name` column — 001 defines it as
/// `(id, halaqa_id, user_id, joined_at, last_opened_at)` and 003 adds only
/// `last_active_at`. This file used to insert `display_name` anyway on both
/// create and join, which meant Postgres rejected every member insert a
/// signed-in user made: creating a circle wrote the `halaqas` row and then
/// failed, leaving a circle with no members holding a burnt invite code, and
/// joining one failed outright. Names now come from `users.display_name`
/// through the `user_id` foreign key, which is also the only way a member list
/// can show a *current* name — a copy written at join time would still say
/// whatever the person was called months ago.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/user_profile.dart';
import '../models/halaqa_models.dart';
import 'halaqa_repository.dart';

class SupabaseHalaqaRepository implements HalaqaRepository {
  SupabaseClient get _c => Supabase.instance.client;
  static const String _tag = 'SupabaseHalaqaRepository';

  @override
  Future<List<Halaqa>> getHalaqasForUser(String userId) async {
    final rows = await _c
        .from('halaqa_members')
        .select('halaqas(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);
    return (rows as List)
        .map((r) => Halaqa.fromMap(r['halaqas'] as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Halaqa?> getHalaqaById(String halaqaId) async {
    final row = await _c.from('halaqas').select().eq('id', halaqaId).maybeSingle();
    return row == null ? null : Halaqa.fromMap(row);
  }

  @override
  Future<Halaqa?> getHalaqaByInviteCode(String inviteCode) async {
    final code = HalaqaInviteCode.canonical(inviteCode);
    if (code.isEmpty) return null;
    final row = await _c
        .from('halaqas')
        .select()
        .eq('invite_code', code)
        .maybeSingle();
    return row == null ? null : Halaqa.fromMap(row);
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

    final inviteCode = await _uniqueInviteCode();
    final row = await _c
        .from('halaqas')
        .insert({
          'name': trimmed,
          'created_by': creator.id,
          'invite_code': inviteCode,
          'max_members': AppConstants.maxHalaqaMembers,
        })
        .select()
        .single();
    final halaqa = Halaqa.fromMap(row);

    // Two inserts, and Postgrest gives no transaction across them. If the
    // second one fails the first must be undone: a circle with no members is
    // invisible to its own creator (the list is built from memberships) while
    // still holding its invite code, so the code is spent on something nobody
    // can reach or delete.
    try {
      await _c.from('halaqa_members').insert({
        'halaqa_id': halaqa.id,
        'user_id': creator.id,
      });
    } catch (e) {
      AppLogger.error('Member insert failed, rolling back circle: $e',
          tag: _tag);
      try {
        await _c.from('halaqas').delete().eq('id', halaqa.id);
      } catch (cleanupError) {
        AppLogger.error('Rollback failed too: $cleanupError', tag: _tag);
      }
      rethrow;
    }

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

    try {
      await _c.from('halaqa_members').insert({
        'halaqa_id': halaqa.id,
        'user_id': user.id,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const HalaqaException(
            HalaqaErrorKind.alreadyMember, "You're already in this circle.");
      }
      if (e.code == 'P0001' || e.message.contains('halaqa_full')) {
        throw HalaqaException(HalaqaErrorKind.full,
            'This circle is full (${halaqa.maxMembers} members).');
      }
      // 23503 is a foreign-key violation, which here means there is no
      // `users` row for this account — the profile mirror never ran. Logged
      // plainly because the generic "could not join" message the UI shows
      // would otherwise hide a cause that is fixable.
      if (e.code == '23503') {
        AppLogger.error(
            'No users row for ${user.id} — profile mirror missing', tag: _tag);
      }
      rethrow;
    }

    AppLogger.info('${user.displayName} joined "${halaqa.name}"', tag: _tag);
    return halaqa;
  }

  @override
  Future<void> leaveHalaqa({
    required String halaqaId,
    required String userId,
  }) async {
    await _c
        .from('halaqa_members')
        .delete()
        .eq('halaqa_id', halaqaId)
        .eq('user_id', userId);
    // Server-side trigger deletes the circle once its last member leaves.
  }

  @override
  Future<List<HalaqaMember>> getMembers(String halaqaId) async {
    // `users(display_name)` follows the halaqa_members.user_id → users.id
    // foreign key, so each row arrives with a nested {display_name: …}. This is
    // the only FK from this table to `users`, so the embed is unambiguous, and
    // `users_select_authenticated` (002) makes the join readable by any
    // signed-in member.
    final rows = await _c
        .from('halaqa_members')
        .select('id, halaqa_id, user_id, joined_at, last_active_at, '
            'users(display_name)')
        .eq('halaqa_id', halaqaId)
        .order('joined_at', ascending: true);
    return (rows as List)
        .map((r) => _memberFromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> memberCount(String halaqaId) async {
    final rows = await _c
        .from('halaqa_members')
        .select('id')
        .eq('halaqa_id', halaqaId);
    return (rows as List).length;
  }

  @override
  Future<List<HalaqaShareView>> getFeed({
    required String halaqaId,
    required String currentUserId,
  }) async {
    final shareRows = await _c
        .from('halaqa_shares')
        .select()
        .eq('halaqa_id', halaqaId)
        .order('shared_at', ascending: false);
    final shares =
        (shareRows as List).map((r) => _shareFromRow(r as Map<String, dynamic>)).toList();
    if (shares.isEmpty) return const [];

    final shareIds = shares.map((s) => s.id).toList();
    final reactionRows = await _c
        .from('halaqa_reactions')
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
    final note = _sanitizeNote(personalNote);
    final row = await _c
        .from('halaqa_shares')
        .insert({
          'halaqa_id': halaqaId,
          'shared_by': user.id,
          'shared_by_name': user.displayName,
          'content_id': content.contentId,
          'content_type': content.contentType.wireName,
          'content_json': content.encode(),
          'personal_note': note,
        })
        .select()
        .single();
    await touchMember(halaqaId: halaqaId, userId: user.id);
    AppLogger.info('Shared ${content.contentType.wireName} to circle $halaqaId',
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
        .from('halaqa_reactions')
        .select('id')
        .eq('share_id', shareId)
        .eq('user_id', userId)
        .eq('reaction', reaction.wireName)
        .maybeSingle();

    if (existing != null) {
      await _c.from('halaqa_reactions').delete().eq('id', existing['id']);
    } else {
      await _c.from('halaqa_reactions').insert({
        'share_id': shareId,
        'user_id': userId,
        'reaction': reaction.wireName,
      });
    }

    final shareRow = await _c
        .from('halaqa_shares')
        .select('halaqa_id')
        .eq('id', shareId)
        .maybeSingle();
    if (shareRow != null) {
      await touchMember(
          halaqaId: shareRow['halaqa_id'] as String, userId: userId);
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
    await _c
        .from('halaqa_members')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('halaqa_id', halaqaId)
        .eq('user_id', userId);
  }

  // ── helpers ────────────────────────────────────────────────────

  /// A member row plus its embedded profile. The name lives in `users`, not in
  /// `halaqa_members`, so it is unwrapped here rather than in
  /// [HalaqaMember.fromMap] — that factory reads flat SQLite rows and should not
  /// have to know about Postgrest's nested embeds.
  ///
  /// A missing name falls back to "Member": the FK guarantees a `users` row
  /// exists, but `display_name` arriving empty must not take down a member list
  /// that is otherwise perfectly readable.
  HalaqaMember _memberFromRow(Map<String, dynamic> row) {
    final profile = row['users'];
    final name = profile is Map<String, dynamic>
        ? (profile['display_name'] as String?)?.trim()
        : null;
    return HalaqaMember(
      id: row['id'] as String,
      halaqaId: row['halaqa_id'] as String,
      userId: row['user_id'] as String,
      displayName: (name == null || name.isEmpty) ? 'Member' : name,
      joinedAt: DateTime.parse(row['joined_at'] as String),
      lastActiveAt: (row['last_active_at'] as String?) != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
    );
  }

  HalaqaShare _shareFromRow(Map<String, dynamic> row) {
    // content_json is the source of truth; content_id/content_type columns
    // exist only to satisfy 001's legacy NOT NULL/CHECK constraints.
    final json = row['content_json'] as String?;
    return HalaqaShare(
      id: row['id'] as String,
      halaqaId: row['halaqa_id'] as String,
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
      personalNote: row['personal_note'] as String?,
      sharedAt: DateTime.parse(row['shared_at'] as String),
    );
  }

  String? _sanitizeNote(String? note) {
    if (note == null) return null;
    final trimmed = note.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= AppConstants.personalNoteMaxLength
        ? trimmed
        : trimmed.substring(0, AppConstants.personalNoteMaxLength);
  }

  Future<String> _uniqueInviteCode() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = IdGenerator.inviteCode(length: attempt < 4 ? 6 : 8);
      final hit = await _c
          .from('halaqas')
          .select('id')
          .eq('invite_code', code)
          .maybeSingle();
      if (hit == null) return code;
    }
    return IdGenerator.inviteCode(length: 10);
  }
}
