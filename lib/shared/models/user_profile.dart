/// UserProfile — the "who am I" for social features.
///
/// The app currently has no login. Halaqa and Al-Minbar still need a stable
/// identity ("me" vs the other members of my circle), so we create a
/// lightweight *local* profile on first run: a random [id] (device-generated
/// UUID) and a [displayName] the user can edit.
///
/// This maps 1:1 onto a future Supabase `users` row — when real auth is added,
/// [id] becomes the auth user id and nothing else about the app has to change.
library;

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  final String id; // uuid — future Supabase auth user id
  final String displayName; // editable, shown in circles and on shares
  final DateTime createdAt;

  UserProfile copyWith({String? displayName}) => UserProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        displayName: map['display_name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
