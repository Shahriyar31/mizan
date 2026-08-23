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

/// One place that decides what an invite code *is*, so a code that was shared
/// and a code that was typed can never disagree.
///
/// ── Why this exists ───────────────────────────────────────────────────
/// Codes travel by hand: a friend copies one out of the circle screen and sends
/// it over WhatsApp, and it arrives wrapped in a sentence, or with a trailing
/// newline, or the sender broke it up as `K7P2-QM` to make it readable. Both
/// repositories used to normalise with `trim().toUpperCase()` only, so every one
/// of those pastes missed a circle that exists and the user was told "no circle
/// found with that code" — the least useful thing to say when the code is right.
///
/// [IdGenerator.inviteCode] draws from `A–Z` minus I/O plus `2–9`, so nothing
/// outside `[A-Z0-9]` can ever be part of a real code and stripping the rest is
/// lossless. Digits are kept even though 0 and 1 are never generated: a code
/// that came back with one in it should fail as "not found", not be silently
/// rewritten into a different circle's code.
class HalaqaInviteCode {
  HalaqaInviteCode._();

  static final RegExp _notCode = RegExp(r'[^A-Z0-9]');

  /// The comparable form of [raw] — uppercased, with spaces, dashes, quotes and
  /// anything else that is not a code character removed.
  static String canonical(String raw) =>
      raw.toUpperCase().replaceAll(_notCode, '');
}

abstract class HalaqaRepository {
  /// All circles the given user is a member of, newest first.
  Future<List<Halaqa>> getHalaqasForUser(String userId);

  Future<Halaqa?> getHalaqaById(String halaqaId);

  /// Look up a circle by its invite code. The code is put through
  /// [HalaqaInviteCode.canonical] first, so case, spaces and dashes in a pasted
  /// code do not matter. Null if no circle has it.
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
