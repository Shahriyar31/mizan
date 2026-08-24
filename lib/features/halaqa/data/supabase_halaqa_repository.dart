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

  /// How many times [createHalaqa] will mint a fresh invite code and try the
  /// insert again after the server rejects one as already taken.
  static const int _createAttempts = 4;

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

    // ── The insert, not the lookup, decides the code ──────────────────
    // [_uniqueInviteCode] reads before it writes, so it can only lower the
    // odds of a clash, never rule one out: two people creating a circle in the
    // same second are both told the same code is free and both try to use it.
    // The UNIQUE constraint on `halaqas.invite_code` is the only real arbiter,
    // and its 23505 used to escape this method raw — the create sheet has no
    // way to read a Postgrest error, so it showed "Could not create the circle.
    // Check your connection", blaming the network for a collision. Now the loser
    // simply mints another code and tries again, with the length escalating
    // because a run of clashes means the 6-character space is crowded rather
    // than that we were unlucky twice.
    Map<String, dynamic>? row;
    for (var attempt = 0; attempt < _createAttempts; attempt++) {
      final inviteCode =
          await _uniqueInviteCode(length: attempt < 2 ? 6 : 8);
      try {
        row = await _c
            .from('halaqas')
            .insert({
              'name': trimmed,
              'created_by': creator.id,
              'invite_code': inviteCode,
              'max_members': AppConstants.maxHalaqaMembers,
            })
            .select()
            .single();
        break;
      } on PostgrestException catch (e) {
        if (!_isInviteCodeCollision(e)) rethrow;
        AppLogger.warning(
            'Invite code $inviteCode was already taken — retrying '
            '(${attempt + 1}/$_createAttempts)',
            tag: _tag);
      }
    }

    if (row == null) {
      // Every code we offered was rejected as taken. At this scale that is not
      // bad luck, it is a signal — so say so instead of pretending the network
      // failed. `full` is the nearest existing kind (a space that has run out of
      // room); a dedicated `inviteCodeUnavailable` member would read better, but
      // the exhaustive switch in halaqa_sheets.dart has to grow with it.
      AppLogger.error(
          'All $_createAttempts invite codes were taken — aborting create',
          tag: _tag);
      throw const HalaqaException(
        HalaqaErrorKind.full,
        'Could not reserve an invite code for this circle. Please try again.',
      );
    }

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

  /// Creator-only circle deletion — see [HalaqaRepository.deleteHalaqa].
  ///
  /// ── Delete the parent only. Do not "clean up" the children ────────────
  /// The obvious implementation is to sweep downward first — reactions, then
  /// shares, then members, then the circle — and it is wrong here, twice over.
  ///
  ///  1. **RLS would silently drop most of the work.** DELETE on
  ///     `halaqa_shares` is restricted to `shared_by = auth.uid()`, and on
  ///     `halaqa_reactions` to the reacting user (002/003). A creator sweeping
  ///     the circle's shares therefore removes only their *own*; every other
  ///     member's row is filtered out of the statement and the request still
  ///     comes back successful. Nothing would tell this client it had deleted
  ///     almost nothing.
  ///  2. **The failure would then land on the wrong statement.** The `halaqas`
  ///     delete that followed would hit a foreign-key violation raised by
  ///     exactly those surviving rows — so the visible error blames the parent
  ///     delete for children the client was never permitted to touch, and the
  ///     circle stays half-emptied.
  ///
  /// A cascade runs *as part of* the parent delete and is not subject to the
  /// children's own policies, so one scoped statement removes the circle
  /// correctly and completely. That is why this method is a single line.
  ///
  /// The cascades it relies on:
  ///   • `halaqa_members.halaqa_id → halaqas.id` ON DELETE CASCADE
  ///   • `halaqa_shares.halaqa_id  → halaqas.id` ON DELETE CASCADE
  ///   • `halaqa_reactions.share_id → halaqa_shares.id` ON DELETE CASCADE
  ///     (reached transitively, as the shares go)
  ///
  /// `created_by` in the filter states the creator-only rule client-side as well
  /// as in the policy: a non-creator's request matches no row and deletes
  /// nothing, so the two layers agree instead of one relying on the other.
  @override
  Future<void> deleteHalaqa({
    required String halaqaId,
    required String userId,
  }) async {
    try {
      await _c
          .from('halaqas')
          .delete()
          .eq('id', halaqaId)
          .eq('created_by', userId);
    } on PostgrestException catch (e) {
      // 23503 on *this* statement can only mean a child row refused to go, i.e.
      // one of the cascades listed above is missing from the live database. The
      // person holding the phone gets `readableError`'s sentence; this line
      // exists so whoever reads the log is told which constraint to go and add
      // instead of inferring it from a Postgres string.
      if (e.code == '23503') {
        AppLogger.error(
            'Circle $halaqaId will not delete: a child table is missing its '
            'ON DELETE CASCADE (expected halaqa_members.halaqa_id, '
            'halaqa_shares.halaqa_id, halaqa_reactions.share_id)',
            tag: _tag);
      }
      rethrow;
    }
    AppLogger.info('Deleted halaqa $halaqaId', tag: _tag);
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

  /// One page of a circle's feed, newest first.
  ///
  /// [limit]/[offset] are extra optional parameters on top of the interface's
  /// signature, so every existing caller compiles unchanged and simply gets the
  /// first page. They are not optional to the *server*: an unbounded select
  /// returned every share a circle had ever posted, and then every one of those
  /// ids went into a single `in.(…)` filter for the reactions — a request URI
  /// that grows without limit and that the server eventually refuses outright.
  /// Shape mirrors SupabaseMinbarRepository.getFeed: a ranged page, then one
  /// batched reaction fetch for exactly that page's shares. The default page
  /// size is `AppConstants.minbarPageSize` — the one feed page size the app
  /// defines; a circle feed is the smaller of the two, so a page that is
  /// comfortable for Al-Minbar is comfortable here.
  @override
  Future<List<HalaqaShareView>> getFeed({
    required String halaqaId,
    required String currentUserId,
    int limit = AppConstants.minbarPageSize,
    int offset = 0,
  }) async {
    final shareRows = await _c
        .from('halaqa_shares')
        .select()
        .eq('halaqa_id', halaqaId)
        .order('shared_at', ascending: false)
        .range(offset, offset + limit - 1);
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

  /// Author-only share deletion — see [HalaqaRepository.deleteShare].
  ///
  /// `shared_by` is in the filter even though the RLS policy on `halaqa_shares`
  /// already restricts DELETE to `shared_by = auth.uid()`. That is deliberate
  /// duplication, not a missing cleanup: the same contract is implemented by
  /// [LocalHalaqaRepository] against a SQLite file with no policies at all, so
  /// the rule has to be stated by the repository to hold in both. It also keeps
  /// a mistaken call harmless — it matches no row rather than being refused —
  /// and it means a change to the policy cannot quietly widen what this app
  /// does.
  ///
  /// The share's reactions are removed by the
  /// `halaqa_reactions.share_id → halaqa_shares.id` ON DELETE CASCADE. They
  /// cannot be deleted from here: a reaction belongs to whoever left it, and RLS
  /// restricts DELETE to that person, so an author sweeping their share's
  /// reactions would clear only their own and then the share delete would fail
  /// on the rest. The cascade is not subject to those policies.
  @override
  Future<void> deleteShare({
    required String shareId,
    required String userId,
  }) async {
    try {
      await _c
          .from('halaqa_shares')
          .delete()
          .eq('id', shareId)
          .eq('shared_by', userId);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        AppLogger.error(
            'Share $shareId will not delete: halaqa_reactions.share_id is '
            'missing its ON DELETE CASCADE',
            tag: _tag);
      }
      rethrow;
    }
    AppLogger.info('Deleted share $shareId', tag: _tag);
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

  /// True when [e] is the UNIQUE violation on `halaqas.invite_code` and not
  /// some other duplicate-key error. Postgres names the offending constraint in
  /// the message ("...violates unique constraint \"halaqas_invite_code_key\"")
  /// and repeats the column in `details`, so both are searched; anything else
  /// carrying 23505 is a different bug and must not be retried into a loop.
  bool _isInviteCodeCollision(PostgrestException e) {
    if (e.code != '23505') return false;
    final haystack =
        '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'.toLowerCase();
    return haystack.contains('invite_code');
  }

  /// A code that is *probably* free, at [length] characters (escalating callers
  /// pass a longer one). This is a check-then-insert and therefore advisory
  /// only — see the note in [createHalaqa]; the UNIQUE constraint is what
  /// actually guarantees uniqueness.
  Future<String> _uniqueInviteCode({int length = 6}) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final code =
          IdGenerator.inviteCode(length: attempt < 4 ? length : length + 2);
      final hit = await _c
          .from('halaqas')
          .select('id')
          .eq('invite_code', code)
          .maybeSingle();
      if (hit == null) return code;
    }
    // Every probe hit something. Hand back a longer, unprobed code rather than
    // burning more round trips — [createHalaqa] is prepared to be told no.
    return IdGenerator.inviteCode(length: length + 4);
  }
}
