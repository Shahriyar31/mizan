/// One translator from a thrown object into a sentence a person can read.
///
/// ── Why this exists ───────────────────────────────────────────────────
/// The social screens used to render `'$error'` straight into the error card.
/// When a row-level-security policy refused an insert, the person holding the
/// phone read:
///
///     PostgrestException(message: new row violates row-level security policy
///     for table "minbar_shares", code: 42501, details: Forbidden, hint: null)
///
/// and on a train with no signal they read `ClientException with
/// SocketException: Failed host lookup`. Both are true, neither is usable, and
/// both name internal tables to a stranger. This file is the single place that
/// decides what is said instead.
///
/// ── The message and the cause are different audiences ─────────────────
/// [readableError] always logs the real exception — its runtime type, its code
/// and its own `toString()` — through [AppLogger] before it returns anything.
/// A message a user can read must never mean a cause the developer cannot see.
/// The log is debug-only (see AppLogger), so nothing here reaches a release
/// build's output.
///
/// ── Tone ──────────────────────────────────────────────────────────────
/// Learned from `AuthRepository._readable`: short, plain, no code, no table
/// name, never blaming the person reading it, and where there is something to
/// do next it says what. Where two causes are equally likely — signed out, or
/// no longer a member — the sentence covers both rather than guessing at one
/// and being confidently wrong.
///
/// Deliberately *not* handled here: `HalaqaException`. Its messages are already
/// written for people at the repository boundary, and `halaqa_sheets.dart` maps
/// its kinds to copy that knows which sheet is open. `core/` also has no
/// business importing a feature.
library;

import 'dart:async' show TimeoutException;
// Matches core/network/ummah_api_client.dart, which already narrows dart:io to
// the one type it needs.
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import '../utils/logger.dart';

const String _tag = 'ReadableError';

const String _offline = 'You are offline. This needs a connection.';
const String _timedOut =
    'The connection timed out. Try again in a moment.';
const String _noAccess =
    'You do not have access to this. If you are signed out, log in from '
    'Settings.';
const String _signIn = 'Sign in to see this. You can log in from Settings.';
const String _notSetUp =
    'Your account is not fully set up yet. Sign out and back in from '
    'Settings, then try again.';
const String _alreadyDone = 'You have already done that.';
const String _generic = 'This could not be loaded. Try again in a moment.';

/// A short, calm sentence for [error], and a log line carrying the truth.
///
/// Safe to call from `build` — repeated calls with the same error object log
/// once (see [_firstSighting]), so an error card that rebuilds on every scroll
/// does not bury the rest of the log.
///
/// Pass [tag] to say which screen or provider the failure came from; it only
/// affects the log, never the returned sentence.
String readableError(Object? error, {String? tag}) {
  _log(error, tag: tag);

  if (error == null) return _generic;
  if (error is PostgrestException) return _postgrest(error);
  if (error is AuthException) return _networkMessage(error.message) ?? _signIn;
  if (error is TimeoutException) return _timedOut;
  if (error is SocketException) return _offline;
  if (error is ClientException) return _offline;

  // Anything else, including a wrapper around one of the above — Riverpod and
  // the http client both re-throw inside other objects, so the text is checked
  // as well as the type.
  return _fromText(error.toString());
}

/// Postgres and PostgREST codes, which are the only reliable signal — the
/// accompanying messages are English prose written for whoever wrote the SQL.
String _postgrest(PostgrestException e) {
  switch (e.code) {
    // RLS refused the row: either nobody is signed in, or this account is not
    // a member of the circle the row belongs to.
    case '42501':
    case '403':
      return _noAccess;

    // Foreign key. In this app it means there is no `public.users` row for the
    // account, so every membership and share insert will fail until the
    // profile mirror runs — which a fresh sign-in does.
    case '23503':
      return _notSetUp;

    // Unique violation: the membership, or the reaction, is already there.
    case '23505':
      return _alreadyDone;

    case '401':
      return _signIn;

    // PGRST116: `.single()` matched no row. PGRST200: the embed named a
    // relationship PostgREST cannot see. The second is a schema bug rather
    // than anything the user did, and neither name means a thing to them.
    case 'PGRST116':
    case 'PGRST200':
      return _generic;
  }

  // PGRST301 and its neighbours are expired or malformed JWTs — a session that
  // has run out rather than a request that was wrong.
  if (e.code?.startsWith('PGRST30') ?? false) return _signIn;

  return _fromText('${e.message} ${e.details ?? ''}');
}

/// Last resort: read the text for the causes that arrive without a code.
String _fromText(String raw) {
  final network = _networkMessage(raw);
  if (network != null) return network;

  final m = raw.toLowerCase();
  if (m.contains('row-level security') ||
      m.contains('row level security') ||
      m.contains('permission denied') ||
      m.contains('42501')) {
    return _noAccess;
  }
  if (m.contains('jwt') ||
      m.contains('no session') ||
      m.contains('session missing') ||
      m.contains('not signed in') ||
      m.contains('not authenticated')) {
    return _signIn;
  }
  return _generic;
}

/// The offline and timeout sentences, or null when [raw] is neither. Shared so
/// a network failure wrapped in an [AuthException] reads the same as a bare
/// [SocketException].
String? _networkMessage(String raw) {
  final m = raw.toLowerCase();
  if (m.contains('failed host lookup') ||
      m.contains('socketexception') ||
      m.contains('clientexception') ||
      m.contains('connection refused') ||
      m.contains('connection closed') ||
      m.contains('connection reset') ||
      m.contains('network is unreachable') ||
      m.contains('no address associated')) {
    return _offline;
  }
  if (m.contains('timeout') || m.contains('timed out')) return _timedOut;
  return null;
}

// ── Logging ───────────────────────────────────────────────────────────

/// Errors already written to the log. An [Expando] holds its keys weakly, so
/// remembering an exception here cannot keep it alive.
final Expando<bool> _logged = Expando<bool>('readableError');

void _log(Object? error, {String? tag}) {
  final where = tag ?? _tag;
  if (error == null) {
    AppLogger.error('readableError called with no error object', tag: where);
    return;
  }
  if (!_firstSighting(error)) return;

  final code = switch (error) {
    PostgrestException(:final code) => code,
    AuthException(:final code, :final statusCode) => code ?? statusCode,
    _ => null,
  };
  AppLogger.error(
    '${error.runtimeType}${code == null ? '' : ' [$code]'}',
    error: error,
    tag: where,
  );
}

/// True the first time this exact object is seen.
///
/// [readableError] is called from `build`, and a Riverpod error state rebuilds
/// on every scroll, theme change and tab switch. Without this, one failed
/// request would print the same stack of lines dozens of times and push the
/// rest of the log out of the terminal.
bool _firstSighting(Object error) {
  try {
    if (_logged[error] == true) return false;
    _logged[error] = true;
    return true;
  } catch (_) {
    // Strings, numbers, bools and records cannot key an Expando. There is
    // nothing to remember, so log every time rather than not at all.
    return true;
  }
}
