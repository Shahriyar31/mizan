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

enum AuthOutcome { ok, notice, failure }

/// The outcome of a sign-up or a sign-in — three states, not two.
///
/// The third one is load-bearing. When the Supabase project requires email
/// confirmation, `signUp` succeeds and returns no session: the account exists,
/// and the next step is to open an inbox. That used to come back through the
/// same `String?` channel as a failure, so it was painted in the red error box
/// under the form — telling somebody who had just succeeded that something had
/// gone wrong, and leaving them retrying a sign-up that would now correctly
/// answer "already registered".
class AuthResult {
  const AuthResult._(this.outcome, this.message);

  const AuthResult.ok() : this._(AuthOutcome.ok, null);

  /// Succeeded, but there is something the user must do next.
  const AuthResult.notice(String message)
      : this._(AuthOutcome.notice, message);

  const AuthResult.failure(String message)
      : this._(AuthOutcome.failure, message);

  final AuthOutcome outcome;
  final String? message;

  bool get isOk => outcome == AuthOutcome.ok;
  bool get isFailure => outcome == AuthOutcome.failure;
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

  /// Validates locally, then creates the account.
  ///
  /// The checks below run before any network call on purpose: a typo in an email
  /// address should not cost a round trip, and on a slow connection it would
  /// otherwise take several seconds to be told the password is too short.
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final localError = validateSignUp(
      name: name,
      email: email,
      password: password,
    );
    if (localError != null) return AuthResult.failure(localError);

    try {
      final res = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'display_name': name.trim()},
      );
      if (res.user == null) {
        return const AuthResult.failure('Something went wrong. Try again.');
      }
      await (await _prefs).setBool(_kEverAuthed, true);
      if (res.session == null) {
        // Email confirmation is required by the Supabase project. The account
        // exists; this is the next step, not a failure.
        return const AuthResult.notice(
          'Account created. Check your email to confirm it, then log in.',
        );
      }
      await _syncProfile(res.user!.id, name.trim(), email.trim().toLowerCase());
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.failure(_readable(e));
    } catch (_) {
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<AuthResult> logIn({
    required String email,
    required String password,
  }) async {
    final localError = validateLogIn(email: email, password: password);
    if (localError != null) return AuthResult.failure(localError);

    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (res.user == null) {
        return const AuthResult.failure('Wrong email or password.');
      }
      await (await _prefs).setBool(_kEverAuthed, true);
      // Also mirrored on sign-up, and a DB trigger writes it too — but a
      // `public.users` row is a hard prerequisite for joining a Halaqa
      // (`halaqa_members.user_id` is a foreign key to it), and a login is the
      // last chance to notice it is missing. An account created before the
      // trigger existed, or one whose row was removed, would otherwise fail
      // every circle it tried to join with nothing on screen to explain why.
      final user = res.user!;
      await _syncProfile(
        user.id,
        _displayName(user),
        user.email ?? email.trim().toLowerCase(),
      );
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.failure(_readable(e));
    } catch (_) {
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  // ── Validation, shared with the form ──────────────────────────────
  //
  // Public so the screen can grey out the button before the user taps it,
  // rather than having two copies of the same rules drift apart.

  /// The first problem with these sign-up details, or null when they are fine.
  static String? validateSignUp({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().length < 2) return 'Please enter your name.';
    final emailError = _emailError(email);
    if (emailError != null) return emailError;
    if (password.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  static String? validateLogIn({
    required String email,
    required String password,
  }) {
    final emailError = _emailError(email);
    if (emailError != null) return emailError;
    if (password.isEmpty) return 'Enter your password.';
    return null;
  }

  /// Deliberately loose. This is not RFC 5322 — it only catches the mistakes a
  /// person actually makes on a phone keyboard (no `@`, no dot after it, a
  /// trailing space). Anything stricter starts rejecting valid addresses, and
  /// the server is the real authority anyway.
  static String? _emailError(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'Enter your email address.';
    final at = value.indexOf('@');
    if (at <= 0 || at != value.lastIndexOf('@')) {
      return 'That email does not look right.';
    }
    final domain = value.substring(at + 1);
    if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) {
      return 'That email does not look right.';
    }
    if (value.contains(' ')) return 'That email does not look right.';
    return null;
  }

  /// Turns a Supabase message into one a person can act on.
  ///
  /// Supabase's own strings are written for developers — "Invalid login
  /// credentials", "User already registered" — and one of them is actively
  /// misleading to show: a wrong password and an email that has no account both
  /// come back as "Invalid login credentials", so the message must not claim
  /// which of the two it was. Anything unrecognised is passed through rather
  /// than swallowed, because a message we have not seen before is still more
  /// use than "Something went wrong".
  static String _readable(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'That email already has an account. Log in instead.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first, then log in.';
    }
    if (m.contains('password should be at least')) {
      return 'Use at least 6 characters.';
    }
    if (m.contains('for security purposes') || m.contains('rate limit')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (m.contains('failed host lookup') ||
        m.contains('socketexception') ||
        m.contains('network')) {
      return 'Could not reach the server. Check your connection.';
    }
    return e.message;
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

  /// Best-effort mirror into `public.users` — the DB trigger already does this
  /// on sign-up, so failures here are non-fatal. Called after sign-up *and*
  /// after every login, because `halaqa_members` and the Minbar both hold
  /// foreign keys to this row and read the display name from it.
  Future<void> _syncProfile(String id, String name, String email) async {
    if (email.isEmpty) return; // `users.email` is NOT NULL UNIQUE.
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
