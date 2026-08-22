/// Account storage — backed by real Supabase Auth.
///
/// The authenticated user's id always comes from
/// `Supabase.instance.client.auth.currentUser!.id` — never client-generated.
/// A `display_name` is kept in both the auth user's metadata (so it's
/// available immediately after sign-in) and mirrored to `public.users`
/// (kept in sync with `auth.users.id` by a DB trigger — see
/// supabase/migrations/002_auth_rls.sql) so it's queryable from SQL/joins.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Account {
  const Account({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // Remembers, locally, whether this device has ever completed a sign-up or
  // login — purely cosmetic (drives "Log in" vs "Create account" copy on the
  // Settings screen). The real account lives in Supabase, not here.
  static const _kEverAuthed = 'auth_ever_authed';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> hasAccount() async =>
      (await _prefs).getBool(_kEverAuthed) ?? false;

  String _displayName(User user) =>
      (user.userMetadata?['display_name'] as String?)?.trim().isNotEmpty ==
              true
          ? (user.userMetadata!['display_name'] as String).trim()
          : (user.email?.split('@').first ?? 'You');

  /// The signed-in account, or null when nobody is signed in.
  Future<Account?> session() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return Account(id: user.id, name: _displayName(user), email: user.email ?? '');
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().length < 2) return 'Please enter your name.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'That email does not look right.';
    }
    if (password.length < 6) return 'Use at least 6 characters.';

    try {
      final res = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'display_name': name.trim()},
      );
      if (res.user == null) return 'Something went wrong. Try again.';
      await (await _prefs).setBool(_kEverAuthed, true);
      if (res.session == null) {
        // Email confirmation is required by the Supabase project — not an
        // error, just a different next step.
        return 'Check your email to confirm your account, then log in.';
      }
      await _syncProfile(res.user!.id, name.trim(), email.trim().toLowerCase());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<String?> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (res.user == null) return 'Wrong email or password.';
      await (await _prefs).setBool(_kEverAuthed, true);
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'Please confirm your email first, then log in.';
      }
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<void> logOut() async => _client.auth.signOut();

  Future<String?> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) return 'Please enter your name.';
    final user = _client.auth.currentUser;
    if (user == null) return 'Not signed in.';
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'display_name': trimmed}),
      );
      await _client
          .from('users')
          .update({'display_name': trimmed}).eq('id', user.id);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save your name. Try again.';
    }
  }

  /// Signs out and forgets this device's "ever signed in" flag. The
  /// Supabase auth account itself is not deleted — self-service account
  /// deletion needs a service-role/Edge Function, which never belongs in
  /// client code.
  Future<void> deleteAccount() async {
    await _client.auth.signOut();
    await (await _prefs).remove(_kEverAuthed);
  }

  /// Best-effort mirror into `public.users` right after sign-up — the DB
  /// trigger already does this, so failures here are non-fatal.
  Future<void> _syncProfile(String id, String name, String email) async {
    try {
      await _client.from('users').upsert({
        'id': id,
        'email': email,
        'display_name': name,
      });
    } catch (_) {
      // Trigger-created row already covers this — ignore.
    }
  }
}
