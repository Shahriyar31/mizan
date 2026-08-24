/// The session gate — how the app decides whether somebody is signed in, before
/// the first frame and on every navigation after it.
///
/// Sign-in is required: Mizan does not open without an account, because
/// everything it keeps is keyed to a user id and a local-then-merge guest mode
/// would be a second copy of every feature.
///
/// ── The race this exists to close ─────────────────────────────────────
/// `Supabase.initialize` does *not* wait for the stored session to be restored.
/// It wraps `recoverSession` in a `CancelableOperation` and returns immediately,
/// so for a returning user there is a window of a few hundred milliseconds where
/// `auth.currentSession` is null even though a perfectly good session is on disk.
/// A router that reads `currentSession` inside that window sends a signed-in
/// person back to the welcome flow — the single worst first impression this app
/// could make on somebody reopening it.
///
/// So [settle] is awaited in `main()`, and it is asymmetric on purpose:
///
///  * **No stored session** → returns immediately. Nothing is going to be
///    recovered, so there is nothing to wait for, and a signed-out person should
///    not pay a splash-screen delay for somebody else's problem.
///  * **A stored session** → polls until `currentSession` appears, up to a
///    ceiling. Recovery normally lands in well under 100ms; the ceiling exists
///    so a dead network cannot hold the app on a blank screen.
///
/// Whether a session is stored is answered by reading gotrue's own
/// SharedPreferences key rather than by guessing. supabase_flutter builds that
/// key as `sb-<first label of the host>-auth-token`, and
/// `SharedPreferencesLocalStorage` is what writes it.
///
/// ── Why it also reads "has this device ever had an account" ────────────
/// Because the router has to choose between two different screens for a
/// signed-out cold start, and getting it wrong wastes the person's time in both
/// directions. Somebody who has an account and signed out wants the log-in form;
/// somebody who reached sign-in during onboarding and quit before finishing
/// wants the create-account form, and would otherwise come back to a screen that
/// says "Welcome back" and rejects the email they are about to type as already
/// registered. Both are read in the same prefs round trip [settle] was already
/// making.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/utils/logger.dart';
import '../../settings/data/auth_repository.dart';

abstract final class SessionGate {
  static const _tag = 'SessionGate';

  /// Long enough for a local read and a token refresh to finish; short enough
  /// that a hung network is a one-second annoyance rather than a hang.
  static const _ceiling = Duration(milliseconds: 1200);
  static const _step = Duration(milliseconds: 25);

  static bool _everSignedIn = false;

  /// True when this device has completed a sign-up or a log-in at some point.
  ///
  /// Read synchronously by the router, so it is filled in by [settle] rather
  /// than read on demand. False until then, which is the safe direction: it only
  /// ever decides which *mode* the sign-in screen opens in.
  static bool get everSignedIn => _everSignedIn;

  /// True when there is a live session right now.
  ///
  /// Read synchronously by the router, so it must never do IO.
  static bool get signedIn {
    if (!SupabaseConfig.current.isUsable) return false;
    return Supabase.instance.client.auth.currentSession != null;
  }

  /// The key supabase_flutter persists the session under.
  ///
  /// Derived exactly as `Supabase.initialize` derives it — from the first label
  /// of the project host — so the two cannot drift apart without this comment
  /// being wrong in an obvious place.
  static String _persistKey(String url) =>
      'sb-${Uri.parse(url).host.split('.').first}-auth-token';

  /// Waits for session recovery to finish, when and only when there is
  /// something to recover. Called once, from `main()`, before `runApp`.
  static Future<void> settle() async {
    final config = SupabaseConfig.current;

    // Read first, and unconditionally: this one is needed even when there is no
    // session to wait for, which is exactly the case the early returns below
    // cover.
    bool? storedSession;
    try {
      final prefs = await SharedPreferences.getInstance();
      _everSignedIn = prefs.getBool(AuthRepository.kEverAuthed) ?? false;
      if (config.isUsable) {
        storedSession = prefs.containsKey(_persistKey(config.url));
      }
    } catch (e) {
      // If we cannot tell, assume there is a session and wait. Waiting a second
      // for nothing is recoverable; skipping the wait for somebody who *is*
      // signed in is not.
      AppLogger.debug('Could not read the session keys: $e', tag: _tag);
    }

    if (!config.isUsable) return;

    // Already there — recovery beat us to it.
    if (Supabase.instance.client.auth.currentSession != null) return;
    if (storedSession == false) return;

    final deadline = DateTime.now().add(_ceiling);
    while (DateTime.now().isBefore(deadline)) {
      if (Supabase.instance.client.auth.currentSession != null) return;
      await Future<void>.delayed(_step);
    }
    AppLogger.warning(
      'A stored session did not restore within ${_ceiling.inMilliseconds}ms; '
      'opening at the sign-in screen instead',
      tag: _tag,
    );
  }
}

/// A [Listenable] that ticks whenever the auth state changes, so GoRouter
/// re-evaluates its guard the moment somebody signs in or out.
///
/// Without this, signing out from Settings would leave the person sitting on a
/// signed-out Home screen until they happened to navigate.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    if (!SupabaseConfig.current.isUsable) return;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      // A stream error here must not take the router down with it.
      onError: (Object e) =>
          AppLogger.debug('Auth stream error: $e', tag: 'AuthRefreshNotifier'),
    );
  }

  StreamSubscription<AuthState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
