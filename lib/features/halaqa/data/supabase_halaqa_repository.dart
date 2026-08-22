/// SupabaseHalaqaRepository — real backend implementation of
/// [HalaqaRepository], for signed-in (Supabase Auth) users.
///
/// Ownership is always `auth.uid()` on the server (enforced by RLS —
/// supabase/migrations/002_auth_rls.sql + 003_halaqa_minbar_online.sql).
/// The [UserProfile] passed in here must already carry the authenticated
/// user's real id (see halaqa_providers.dart's `effectiveUserProvider`) —
/// this repository never invents an id.
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
    final row = await _c
        .from('halaqas')
        .select()
        .eq('invite_code', inviteCode.trim().toUpperCase())
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

    await _c.from('halaqa_members').insert({
      'halaqa_id': halaqa.id,
      'user_id': creator.id,
      'display_name': creator.displayName,
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

    try {
      await _c.from('halaqa_members').insert({
        'halaqa_id': halaqa.id,
        'user_id': user.id,
        'display_name': user.displayName,
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
    final rows = await _c
        .from('halaqa_members')
        .select()
        .eq('halaqa_id', halaqaId)
        .order('joined_at', ascending: true);
    return (rows as List)
        .map((r) => HalaqaMember.fromMap(r as Map<String, dynamic>))
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
