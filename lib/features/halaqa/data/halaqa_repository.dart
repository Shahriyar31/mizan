/// HalaqaRepository — the abstract contract for circle data.
///
/// This interface is the single most important architectural decision for
/// scaling later. Right now the only implementation is [LocalHalaqaRepository]
/// (SQLite on the device). When you add a real backend, you write a
/// `SupabaseHalaqaRepository implements HalaqaRepository` and swap ONE line in
/// the provider — the UI, the models, and the providers never change, because
/// they only ever talk to this interface. That is the whole payoff of the
/// repository pattern: the app doesn't know or care where the data lives.
///
/// Every method is async because a network-backed implementation will be, so
/// coding against the interface today means no rewrites tomorrow.
library;

import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/user_profile.dart';
import '../models/halaqa_models.dart';

/// Why a join to a circle failed — lets the UI show a precise message
/// instead of a generic error.
enum HalaqaErrorKind { notFound, full, alreadyMember, invalidName }

class HalaqaException implements Exception {
  const HalaqaException(this.kind, [this.message]);
  final HalaqaErrorKind kind;
  final String? message;

  @override
  String toString() => 'HalaqaException($kind): ${message ?? ''}';
}

abstract class HalaqaRepository {
  /// All circles the given user is a member of, newest first.
  Future<List<Halaqa>> getHalaqasForUser(String userId);

  Future<Halaqa?> getHalaqaById(String halaqaId);

  /// Look up a circle by its invite code (case-insensitive). Null if none.
  Future<Halaqa?> getHalaqaByInviteCode(String inviteCode);

  /// Create a new circle and add [creator] as its first member.
  /// Throws [HalaqaException] with [HalaqaErrorKind.invalidName] if empty.
  Future<Halaqa> createHalaqa({
    required String name,
    required UserProfile creator,
  });

  /// Join an existing circle by invite code. Throws [HalaqaException] if the
  /// code is unknown ([notFound]), the circle is at capacity ([full]), or the
  /// user is already a member ([alreadyMember]).
  Future<Halaqa> joinHalaqa({
    required String inviteCode,
    required UserProfile user,
  });

  /// Remove a member from a circle. If the last member leaves, the circle and
  /// all its shares are deleted.
  Future<void> leaveHalaqa({
    required String halaqaId,
    required String userId,
  });

  Future<List<HalaqaMember>> getMembers(String halaqaId);

  Future<int> memberCount(String halaqaId);

  /// The circle's feed as ready-to-render view-models (share + reaction
  /// counts + the current user's own reactions), newest first.
  Future<List<HalaqaShareView>> getFeed({
    required String halaqaId,
    required String currentUserId,
  });

  /// Share a piece of content into a circle with an optional ≤100-char note.
  /// The note is trimmed and truncated defensively to honour the rule.
  Future<HalaqaShare> shareToHalaqa({
    required String halaqaId,
    required UserProfile user,
    required SharedContent content,
    String? personalNote,
  });

  /// Toggle one reaction on one share for one user. If the user has already
  /// left this reaction it is removed; otherwise it is added. Members can hold
  /// several different reactions on the same share at once.
  Future<void> toggleReaction({
    required String shareId,
    required String userId,
    required ReactionType reaction,
  });

  /// Members who have gone quiet (inactive for [days] or more), excluding
  /// [excludeUserId] (normally the current user — you don't nudge yourself).
  Future<List<HalaqaMember>> quietMembers({
    required String halaqaId,
    int days,
    String? excludeUserId,
  });

  /// Record that a user was active in a circle now (opened it, shared,
  /// reacted). Keeps the nudge logic honest.
  Future<void> touchMember({
    required String halaqaId,
    required String userId,
  });
}
