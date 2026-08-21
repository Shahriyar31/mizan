/// ReactionType — the only responses a person can leave on a share.
///
/// Your README is deliberate about this: Halaqa and Al-Minbar have **no text
/// replies, ever**. The single social gesture is a reaction, and there are
/// exactly three. Keeping them in one shared enum means the Halaqa feed and the
/// Al-Minbar feed can never drift apart, and a future Supabase table can store
/// the exact same [wireName] strings.
///
///   • Du'a       — "I made du'a for you / for this." A prayer, not a like.
///   • Resonated  — "This landed with me."
///   • Moved      — "This moved my heart."
///
/// We intentionally avoid a generic "like": every reaction here is an act of
/// worship or sincere acknowledgement, which is the whole point of the app.
library;

enum ReactionType { dua, resonated, moved }

extension ReactionTypeX on ReactionType {
  /// Stable string stored in the database — never change these.
  String get wireName => switch (this) {
        ReactionType.dua => 'dua',
        ReactionType.resonated => 'resonated',
        ReactionType.moved => 'moved',
      };

  /// Short label shown under the icon on a card.
  String get label => switch (this) {
        ReactionType.dua => "Du'a",
        ReactionType.resonated => 'Resonated',
        ReactionType.moved => 'Moved',
      };

  /// A one-line meaning, used in tooltips / the first-time hint.
  String get meaning => switch (this) {
        ReactionType.dua => 'I made du\'a for you',
        ReactionType.resonated => 'This resonated with me',
        ReactionType.moved => 'This moved my heart',
      };

  static ReactionType fromWire(String? s) => switch (s) {
        'dua' => ReactionType.dua,
        'resonated' => ReactionType.resonated,
        'moved' => ReactionType.moved,
        _ => ReactionType.dua,
      };

  /// Canonical display order (matches the README's Du'a / Resonated / Moved).
  static const List<ReactionType> ordered = [
    ReactionType.dua,
    ReactionType.resonated,
    ReactionType.moved,
  ];
}
