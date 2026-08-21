/// Al-Minbar models — the shapes for the public feed.
///
/// Al-Minbar ("the pulpit") is the global, public counterpart to a private
/// Halaqa. Anyone can share a piece of content to it; anyone can react with the
/// same three [ReactionType]s. Like Halaqa, there are **no text replies** — the
/// feed stays a place for signal, not comment threads.
///
/// A Minbar share is simpler than a Halaqa share: there's no circle to belong
/// to and no personal note (a public post is the content itself, presented
/// cleanly). The content is still a denormalised [SharedContent] snapshot so
/// cards render instantly and never break if source content changes.
library;

import '../../../shared/models/reaction_type.dart';
import '../../../shared/models/shared_content.dart';

/// One public post on Al-Minbar.
class MinbarShare {
  const MinbarShare({
    required this.id,
    required this.sharedBy,
    required this.sharedByName,
    required this.content,
    required this.sharedAt,
  });

  final String id;
  final String sharedBy; // user id
  final String sharedByName; // denormalised for instant display
  final SharedContent content;
  final DateTime sharedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'shared_by': sharedBy,
        'shared_by_name': sharedByName,
        'content_json': content.encode(),
        'shared_at': sharedAt.toIso8601String(),
      };

  factory MinbarShare.fromMap(Map<String, dynamic> m) => MinbarShare(
        id: m['id'] as String,
        sharedBy: m['shared_by'] as String,
        sharedByName: m['shared_by_name'] as String,
        content: SharedContent.decode(m['content_json'] as String),
        sharedAt: DateTime.parse(m['shared_at'] as String),
      );
}

/// One user's single reaction on one Minbar post.
class MinbarReaction {
  const MinbarReaction({
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

  factory MinbarReaction.fromMap(Map<String, dynamic> m) => MinbarReaction(
        id: m['id'] as String,
        shareId: m['share_id'] as String,
        userId: m['user_id'] as String,
        reaction: ReactionTypeX.fromWire(m['reaction'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Read-model for the feed: a [MinbarShare] plus its reaction summary. Built by
/// the repository so the UI never runs its own reaction query per card.
class MinbarShareView {
  const MinbarShareView({
    required this.share,
    required this.counts,
    required this.myReactions,
  });

  final MinbarShare share;
  final Map<ReactionType, int> counts;
  final Set<ReactionType> myReactions;

  int countFor(ReactionType r) => counts[r] ?? 0;
  bool reactedWith(ReactionType r) => myReactions.contains(r);
  int get totalReactions => counts.values.fold(0, (a, b) => a + b);
}
