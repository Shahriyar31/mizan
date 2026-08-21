/// IdentityRepository — reads/writes the single local user profile.
///
/// There is exactly one row in `user_profile`: the person using this device.
/// [ensureProfile] is the entry point everything else uses — it returns the
/// existing profile or creates one on first run. When real Supabase auth is
/// added later, this repository is the one place that changes: [ensureProfile]
/// would return the signed-in user instead of a locally-created one.
library;

import '../../../core/utils/id_generator.dart';
import '../../../core/utils/logger.dart';
import '../../../services/database/database_service.dart';
import '../../../shared/models/user_profile.dart';

class IdentityRepository {
  IdentityRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  static const String _tag = 'IdentityRepository';
  static const String _table = 'user_profile';

  /// Returns the current profile, or null if none exists yet.
  Future<UserProfile?> getProfile() async {
    final db = await _db.database;
    final rows = await db.query(_table, limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  /// Returns the current profile, creating a default one on first run.
  Future<UserProfile> ensureProfile({String defaultName = 'You'}) async {
    final existing = await getProfile();
    if (existing != null) return existing;

    final profile = UserProfile(
      id: IdGenerator.uuid(),
      displayName: defaultName,
      createdAt: DateTime.now(),
    );
    final db = await _db.database;
    await db.insert(_table, profile.toMap());
    AppLogger.info('Created local profile ${profile.id}', tag: _tag);
    return profile;
  }

  /// Updates the display name of the current profile.
  Future<UserProfile> updateDisplayName(String name) async {
    final current = await ensureProfile();
    final updated = current.copyWith(displayName: name.trim());
    final db = await _db.database;
    await db.update(
      _table,
      {'display_name': updated.displayName},
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    AppLogger.info('Updated display name to "${updated.displayName}"',
        tag: _tag);
    return updated;
  }
}
