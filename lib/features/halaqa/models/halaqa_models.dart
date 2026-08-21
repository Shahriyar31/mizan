/// Halaqa models — the data shapes for a private study circle.
///
/// A Halaqa is a small (2–8 person) circle. Members share a piece of content
/// (an ayah, a hadith, a companion's story…) with an optional ≤100-character
/// note, and the only responses are the three reactions in [ReactionType].
///
/// Four persisted shapes map 1:1 onto database rows:
///   • [Halaqa]        — the circle itself (name, invite code, size cap).
///   • [HalaqaMember]  — a person in a circle (with last-active for nudges).
///   • [HalaqaShare]   — one shared item (wraps a [SharedContent] snapshot).
///   • [HalaqaReaction]— one member's single reaction on one share.
///
/// [HalaqaShareView] is NOT persisted — it's a read-model the repository builds
/// by joining a share with its reactions, so the feed can render counts and the
/// current user's own reactions without extra queries in the UI.
library;

import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';

/// A private study circle.
class Halaqa {
  const Halaqa({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    required this.createdAt,
    this.maxMembers = 8,
  });

  final String id;
  final String name;
  final String createdBy; // user id of the creator
  final String inviteCode; // short code others type to join
  final int maxMembers; // 8 per the README (2–8 range)
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_by': createdBy,
        'invite_code': inviteCode,
        'max_members': maxMembers,
        'created_at': createdAt.toIso8601String(),
      };

  factory Halaqa.fromMap(Map<String, dynamic> m) => Halaqa(
        id: m['id'] as String,
        name: m['name'] as String,
        createdBy: m['created_by'] as String,
        inviteCode: m['invite_code'] as String,
        maxMembers: (m['max_members'] as int?) ?? 8,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// A person who belongs to a circle.
class HalaqaMember {
  const HalaqaMember({
    required this.id,
    required this.halaqaId,
    required this.userId,
    required this.displayName,
    required this.joinedAt,
    this.lastActiveAt,
  });

  final String id;
  final String halaqaId;
  final String userId;
  final String displayName;
  final DateTime joinedAt;

  /// Last time this member did something in the circle (opened it, shared,
  /// reacted). Drives the gentle "nudge" for members who've gone quiet.
  final DateTime? lastActiveAt;

  /// True when this member hasn't been active for [days] or more (or never
  /// has). Used to decide who can be nudged. README default: 3 days.
  bool isQuiet({required int days, DateTime? now}) {
    final ref = lastActiveAt;
    if (ref == null) return true;
    final elapsed = (now ?? DateTime.now()).difference(ref);
    return elapsed.inDays >= days;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'halaqa_id': halaqaId,
        'user_id': userId,
        'display_name': displayName,
        'joined_at': joinedAt.toIso8601String(),
        'last_active_at': lastActiveAt?.toIso8601String(),
      };

  factory HalaqaMember.fromMap(Map<String, dynamic> m) => HalaqaMember(
        id: m['id'] as String,
        halaqaId: m['halaqa_id'] as String,
        userId: m['user_id'] as String,
        displayName: m['display_name'] as String,
        joinedAt: DateTime.parse(m['joined_at'] as String),
        lastActiveAt: (m['last_active_at'] as String?) != null
            ? DateTime.parse(m['last_active_at'] as String)
            : null,
      );
}

/// One shared item inside a circle. The shared content is stored as a JSON
/// snapshot ([SharedContent]) so the card renders instantly and never breaks.
class HalaqaShare {
  const HalaqaShare({
    required this.id,
    required this.halaqaId,
    required this.sharedBy,
    required this.sharedByName,
    required this.content,
    required this.sharedAt,
    this.personalNote,
  });

  final String id;
  final String halaqaId;
  final String sharedBy; // user id
  final String sharedByName; // denormalised for instant display
  final SharedContent content;

  /// Optional ≤100-char note the sharer added. Enforced when creating.
  final String? personalNote;
  final DateTime sharedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'halaqa_id': halaqaId,
        'shared_by': sharedBy,
        'shared_by_name': sharedByName,
        'content_json': content.encode(),
        'personal_note': personalNote,
        'shared_at': sharedAt.toIso8601String(),
      };

  factory HalaqaShare.fromMap(Map<String, dynamic> m) => HalaqaShare(
        id: m['id'] as String,
        halaqaId: m['halaqa_id'] as String,
        sharedBy: m['shared_by'] as String,
        sharedByName: m['shared_by_name'] as String,
        content: SharedContent.decode(m['content_json'] as String),
        personalNote: m['personal_note'] as String?,
        sharedAt: DateTime.parse(m['shared_at'] as String),
      );
}

/// One member's single reaction on one share.
class HalaqaReaction {
  const HalaqaReaction({
    required this.id,
    required this.shareId,
    required this.userId,
    required this.reaction,
    required this.createdAt,
  });

  final String id;
  final String shareId;
  final String userId;
  final ReactionType reaction;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'share_id': shareId,
        'user_id': userId,
        'reaction': reaction.wireName,
        'created_at': createdAt.toIso8601String(),
      };

  factory HalaqaReaction.fromMap(Map<String, dynamic> m) => HalaqaReaction(
        id: m['id'] as String,
        shareId: m['share_id'] as String,
        userId: m['user_id'] as String,
        reaction: ReactionTypeX.fromWire(m['reaction'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Read-model for the feed: a [HalaqaShare] plus its reaction summary.
///
/// [counts] is how many of each reaction the share has; [myReactions] is the
/// set the current user has toggled on (so the UI can highlight them). Built by
/// the repository — the UI never has to run its own reaction query.
class HalaqaShareView {
  const HalaqaShareView({
    required this.share,
    required this.counts,
    required this.myReactions,
  });

  final HalaqaShare share;
  final Map<ReactionType, int> counts;
  final Set<ReactionType> myReactions;

  int countFor(ReactionType r) => counts[r] ?? 0;
  bool reactedWith(ReactionType r) => myReactions.contains(r);
  int get totalReactions => counts.values.fold(0, (a, b) => a + b);
}
