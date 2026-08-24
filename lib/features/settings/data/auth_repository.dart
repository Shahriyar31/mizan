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

import '../../../core/config/supabase_config.dart';
import '../../../core/utils/logger.dart';
import 'account_data_boundary.dart';

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

  /// Refuses early when this build cannot reach a server at all.
  ///
  /// Without this, a misconfigured `.env` surfaces as "Could not reach the
  /// server. Check your connection." — which sends the person off to fight their
  /// wifi over a problem in the build they were given. The distinction matters
  /// most for exactly the audience this app is being handed to: friends who will
  /// assume the fault is theirs.
  AuthResult? get _configProblem {
    final config = SupabaseConfig.current;
    if (config.isUsable) return null;
    return AuthResult.failure(config.problem!);
  }

  // Remembers, locally, whether this device has ever completed a sign-up or
  // login. It began as cosmetic — "Log in" versus "Create account" copy on the
  // Settings screen — but the router reads it too, through SessionGate, to
  // decide which of those two a signed-out cold start opens on. Public so there
  // is one copy of the string rather than two that can drift.
  static const kEverAuthed = 'auth_ever_authed';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> hasAccount() async =>
      (await _prefs).getBool(kEverAuthed) ?? false;

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
    final misconfigured = _configProblem;
    if (misconfigured != null) return misconfigured;

    try {
      final res = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'display_name': name.trim()},
      );
      if (res.user == null) {
        return const AuthResult.failure('Something went wrong. Try again.');
      }
      await (await _prefs).setBool(kEverAuthed, true);
      if (res.session == null) {
        // Email confirmation is required by the Supabase project. The account
        // exists; this is the next step, not a failure.
        return const AuthResult.notice(
          'Account created. Check your email to confirm it, then log in.',
        );
      }
      final syncProblem = await _syncProfile(
        res.user!.id,
        name.trim(),
        email.trim().toLowerCase(),
      );
      // A brand-new account on a phone that has been used offline *adopts* that
      // work rather than clearing it — see AccountDataBoundary.
      await AccountDataBoundary.onSignedIn(res.user!.id);
      if (syncProblem != null) return AuthResult.notice(syncProblem);
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
    final misconfigured = _configProblem;
    if (misconfigured != null) return misconfigured;

    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (res.user == null) {
        return const AuthResult.failure('Wrong email or password.');
      }
      await (await _prefs).setBool(kEverAuthed, true);
      final user = res.user!;
      // Runs before anything reads local data. If a different account owned this
      // phone's reflections, they are cleared here — see AccountDataBoundary for
      // why this is a switch boundary and not a sign-out boundary.
      await AccountDataBoundary.onSignedIn(user.id);
      // Also mirrored on sign-up, and a DB trigger writes it too — but a
      // `public.users` row is a hard prerequisite for joining a Halaqa
      // (`halaqa_members.user_id` is a foreign key to it), and a login is the
      // last chance to notice it is missing. An account created before the
      // trigger existed, or one whose row was removed, would otherwise fail
      // every circle it tried to join with nothing on screen to explain why.
      final syncProblem = await _syncProfile(
        user.id,
        _displayName(user),
        user.email ?? email.trim().toLowerCase(),
      );
      if (syncProblem != null) return AuthResult.notice(syncProblem);
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

  /// Just the email rule, for the screens that ask for an address on its own —
  /// the password-reset request and the resend-confirmation action.
  static String? validateEmail(String email) => _emailError(email);

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

  // ── Account recovery ──────────────────────────────────────────────
  //
  // Without this, a forgotten password is a permanent lockout: the reflections,
  // the circles and the record are all tied to an account there is no way back
  // into. For an app being handed to friends, that is not a missing feature, it
  // is a trap.
  //
  // This uses the six-digit code, not a reset link, and that is a deliberate
  // choice rather than the lazy one. A link has to land back inside the app,
  // which means an Android intent filter (the manifest has none — only
  // MAIN/LAUNCHER and the notification boot receiver), an iOS associated-domain
  // or URL-scheme entry, and a redirect allow-list in the Supabase dashboard
  // that has to be kept in step with both. Every one of those is a thing that
  // can be wrong in release and cannot be tested from here. A code the person
  // types needs none of it and behaves identically on both platforms.
  //
  // Supabase sends the code in the same recovery email as the link; the default
  // template includes `{{ .Token }}`. If the project's template has been edited
  // down to just the link, the code will not be in the email — that is the one
  // configuration this path depends on.

  /// Step 1 — asks Supabase to email a recovery code.
  ///
  /// Deliberately says the same thing whether or not the address has an account.
  /// "No account with that email" would turn this screen into a way for anybody
  /// holding the phone to test which of their friends' addresses are registered.
  /// Supabase itself does not distinguish the two cases either, so claiming to
  /// would be a lie as well as a leak.
  Future<AuthResult> requestPasswordReset(String email) async {
    final emailError = _emailError(email);
    if (emailError != null) return AuthResult.failure(emailError);
    final misconfigured = _configProblem;
    if (misconfigured != null) return misconfigured;
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
      return const AuthResult.notice(
        'If that address has an account, a six-digit code is on its way. '
        'Enter it below.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_readable(e));
    } catch (e) {
      AppLogger.error('reset request failed', error: e, tag: 'AuthRepository');
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Step 2 — exchanges the code for a session.
  ///
  /// On success gotrue saves the session and emits
  /// `AuthChangeEvent.passwordRecovery`, so from here the person is signed in
  /// and `updateUser` will be accepted. This is why [setNewPassword] does not
  /// need the old password: possession of a code sent to the address on the
  /// account is the proof.
  Future<AuthResult> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    final digits = code.trim();
    if (digits.length < 6) return const AuthResult.failure('Enter all six digits.');
    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: digits,
        type: OtpType.recovery,
      );
      if (res.session == null) {
        return const AuthResult.failure(
          'That code did not work. Ask for a new one.',
        );
      }
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.failure(_readableCode(e));
    } catch (e) {
      AppLogger.error('code verify failed', error: e, tag: 'AuthRepository');
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Step 3 — sets the new password on the session the code just opened.
  ///
  /// The account boundary runs here too. A recovery is a completely valid way to
  /// arrive on somebody else's phone — it is the obvious route for "let me just
  /// check my circle on your handset" — and it must not leave the previous
  /// owner's reflections on screen under the new name.
  Future<AuthResult> setNewPassword(String password) async {
    if (password.length < 6) {
      return const AuthResult.failure('Use at least 6 characters.');
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      return const AuthResult.failure(
        'That code has expired. Start again from your email address.',
      );
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      await (await _prefs).setBool(kEverAuthed, true);
      await AccountDataBoundary.onSignedIn(user.id);
      final syncProblem = await _syncProfile(
        user.id,
        _displayName(user),
        user.email ?? '',
      );
      if (syncProblem != null) return AuthResult.notice(syncProblem);
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.failure(_readable(e));
    } catch (e) {
      AppLogger.error('password update failed', error: e, tag: 'AuthRepository');
      return const AuthResult.failure(
        'Could not save the new password. Try again.',
      );
    }
  }

  /// Sends the confirmation email again.
  ///
  /// The other half of the lockout. Sign-up returns a notice telling the person
  /// to check their inbox, and if that email is lost, filtered or simply never
  /// arrives, the account exists but cannot be used: signing up again answers
  /// "that email already has an account", and logging in answers "please confirm
  /// your email first". A closed loop with no way out of it.
  Future<AuthResult> resendConfirmation(String email) async {
    final emailError = _emailError(email);
    if (emailError != null) return AuthResult.failure(emailError);
    final misconfigured = _configProblem;
    if (misconfigured != null) return misconfigured;
    try {
      await _client.auth.resend(
        email: email.trim().toLowerCase(),
        type: OtpType.signup,
      );
      return const AuthResult.notice(
        'Confirmation email sent again. Check your inbox, and your spam folder.',
      );
    } on AuthException catch (e) {
      // Supabase answers this when the address is already confirmed, which is
      // good news badly worded.
      if (e.message.toLowerCase().contains('already confirmed')) {
        return const AuthResult.notice(
          'That email is already confirmed — you can log in.',
        );
      }
      return AuthResult.failure(_readable(e));
    } catch (e) {
      AppLogger.error('resend failed', error: e, tag: 'AuthRepository');
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Like [_readable], but for the code screen, where "Token has expired or is
  /// invalid" needs to name the two different things the person might do about
  /// it rather than passing developer wording through.
  static String _readableCode(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('expired') || m.contains('invalid')) {
      return 'That code is wrong or has expired. Codes last one hour — '
          'ask for a new one.';
    }
    return _readable(e);
  }

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

  /// Signs out, clears this device's personal data, and forgets the "ever
  /// signed in" flag. The Supabase auth account itself is not deleted —
  /// self-service account deletion needs a service-role/Edge Function, which
  /// never belongs in client code.
  ///
  /// Unlike a plain sign-out this *does* wipe local data, because here the
  /// person has explicitly asked to be forgotten rather than merely to leave.
  Future<void> deleteAccount() async {
    await _client.auth.signOut();
    await AccountDataBoundary.forgetEverything();
    await (await _prefs).remove(kEverAuthed);
  }

  /// Mirrors the account into `public.users`, and reports when it genuinely
  /// failed.
  ///
  /// Returns null when the row is in place, or a sentence to show the person
  /// when it is not.
  ///
  /// This used to `catch (_) {}` with the comment "trigger-created row already
  /// covers this — ignore". That reasoning was half right and the half that was
  /// wrong was expensive. An *upsert* onto an existing row does not throw, so a
  /// throw here never meant "the row was already there"; it meant RLS refused
  /// the write, or the request never arrived. And this row is not decoration:
  /// `halaqa_members.user_id` and the Minbar both hold foreign keys to it. With
  /// the failure swallowed, login looked perfectly successful and then every
  /// attempt to join a circle failed on a foreign-key violation, with nothing
  /// anywhere connecting the two events. That is the worst shape a bug can have.
  ///
  /// So: log it always, then find out whether the row exists. If it does, the
  /// write was redundant and silence is correct. If it does not, say so — the
  /// person is about to hit a wall in Halaqa and deserves the warning here,
  /// where it is still explicable.
  ///
  /// ── Why the confirming read is no longer allowed to end in silence ────
  /// The second `catch` used to `return null` with the comment "do not cry wolf
  /// on a flaky connection". That misclassified the exact failure that shipped:
  /// when row-level security refuses `public.users`, BOTH the upsert and the
  /// confirming select throw a [PostgrestException], and the method returned
  /// null — so a completely broken login looked flawless, and the person only
  /// discovered it later when circles and Minbar failed with no connection to
  /// the sign-in that had gone wrong.
  ///
  /// A [PostgrestException] is a *server refusal*: the request arrived, was
  /// understood, and was denied. That is nothing like a dropped connection, and
  /// it is never transient. Only a genuine transport failure — no exception code
  /// at all, a socket that closed, a lookup that failed — earns the benefit of
  /// the doubt, because in that case the row may well be there and the phone
  /// simply cannot see it.
  Future<String?> _syncProfile(String id, String name, String email) async {
    if (email.isEmpty) return null; // `users.email` is NOT NULL UNIQUE.
    try {
      await _client.from('users').upsert({
        'id': id,
        'email': email,
        'display_name': name,
      });
      return null;
    } catch (e) {
      AppLogger.error('users row upsert failed', error: e, tag: 'AuthRepository');
      try {
        final existing = await _client
            .from('users')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        if (existing != null) return null; // The trigger did cover it.
      } on PostgrestException catch (e2) {
        // The server answered, and its answer was no. Say so.
        AppLogger.error(
          'users row read refused by the server',
          error: e2,
          tag: 'AuthRepository',
        );
        return _profileWarning;
      } catch (e2) {
        AppLogger.error(
          'could not confirm the users row either',
          error: e2,
          tag: 'AuthRepository',
        );
        // No code, so this is transport rather than refusal. The row is
        // probably there from the trigger, and the person will find out for
        // certain the moment they open Halaqa.
        return null;
      }
      return _profileWarning;
    }
  }
}

/// Shown when the account exists in Supabase Auth but its `public.users` mirror
/// does not. Deliberately does not name the table: the reader cannot act on
/// "public.users", and the two things they *can* do are in the sentence.
const String _profileWarning =
    'You are signed in, but your profile did not finish saving. Circles and '
    'Al-Minbar will not work yet. Try signing out and in again — if it keeps '
    'happening, tell whoever sent you the app.';
