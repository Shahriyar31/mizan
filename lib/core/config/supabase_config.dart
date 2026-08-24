/// Reads and validates the Supabase configuration once, at startup.
///
/// ── Why this exists ────────────────────────────────────────────────────
/// The old two lines were:
///
/// ```dart
/// url: dotenv.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321',
/// anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
/// ```
///
/// Every part of that fails silently, and in a release build there is nothing on
/// screen and nothing in the log to say so:
///
///  * An **empty anon key** satisfies supabase's only guard,
///    `assert(publishableKey != null || anonKey != null)` — the assert tests for
///    null, not for content, and asserts are stripped from release anyway. The
///    client is built and every request goes out unauthenticated.
///  * An **empty `SUPABASE_URL`** never reaches the fallback. `flutter_dotenv`
///    returns `''` for a key that is present but blank, and `''` is not null, so
///    `??` does not fire. `SupabaseClient` does no URL validation, so the app
///    starts up pointed at nothing.
///  * The **localhost fallback** is worse than no fallback. It looks like it
///    helps, but `127.0.0.1:54321` is only reachable from a desktop simulator
///    running a local stack; on a real phone it cannot resolve. And it silently
///    sets the session storage key, because supabase derives that from the host:
///    `persistSessionKey: "sb-${Uri.parse(url).host.split(".").first}-auth-token"`.
///    So a build that once ran with the fallback stored its session under
///    `sb-127-auth-token`, and the moment a real URL is configured every stored
///    session becomes unreadable and everybody is silently signed out.
///
/// The cost of all this lands on somebody else: a friend creates an account, is
/// told it worked, and then finds their circle empty and their Minbar posts
/// missing, with no way to tell that the build they were given was misconfigured.
///
/// ── What this does instead ─────────────────────────────────────────────
/// Validates before use, and when the configuration is unusable says so in words
/// on the screen where the person is trying to sign in, rather than failing as a
/// generic network error. It deliberately does *not* stop the app from starting:
/// reading, the layers, the Qur'an audio and the whole local record work without
/// Supabase, and refusing to open would take all of that away to punish a
/// problem the reader did not cause and cannot fix.
///
/// It never logs or exposes the key itself — only its length and whether it
/// looks structurally right.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/logger.dart';

class SupabaseConfig {
  const SupabaseConfig._({required this.url, required this.key, this.problem});

  /// The URL to hand to `Supabase.initialize`.
  ///
  /// When [isUsable] is false this is [unconfiguredUrl] — a host under the
  /// RFC 2606 `.invalid` TLD, which is reserved precisely so that it can never
  /// resolve. That matters for two reasons: the client still gets built, so
  /// `Supabase.instance.client` does not throw an `AssertionError` from the
  /// dozen files that touch it, and every request fails immediately instead of
  /// hanging on a connect timeout.
  final String url;

  final String key;

  /// What is wrong, in a sentence, or null when the configuration is fine.
  final String? problem;

  bool get isUsable => problem == null;

  /// Reserved by RFC 2606 to be guaranteed unresolvable. Also readable in a
  /// stack trace, which `127.0.0.1` is not — anybody seeing this host knows
  /// immediately that they are looking at a configuration failure and not at a
  /// server that happens to be down.
  static const unconfiguredUrl = 'https://unconfigured.invalid';

  static SupabaseConfig? _cached;

  /// The configuration for this build. Computed once.
  static SupabaseConfig get current => _cached ??= _read();

  /// Overrides the configuration. Tests only.
  static void debugOverride(SupabaseConfig config) => _cached = config;

  static SupabaseConfig _read() {
    // `dotenv.env` throws `NotInitializedError` if `load` was never called or
    // failed. A missing .env is itself one of the configurations this is here to
    // report, so it must not become an uncaught error during startup.
    Map<String, String> env;
    try {
      env = dotenv.env;
    } catch (_) {
      return const SupabaseConfig._(
        url: unconfiguredUrl,
        key: 'unconfigured',
        problem: 'This build has no .env file, so it cannot reach the server. '
            'Accounts and circles will not work.',
      );
    }

    final rawUrl = (env['SUPABASE_URL'] ?? '').trim();
    final rawKey = (env['SUPABASE_ANON_KEY'] ?? '').trim();

    final urlProblem = _urlProblem(rawUrl);
    final keyProblem = _keyProblem(rawKey);

    if (urlProblem == null && keyProblem == null) {
      // Trailing slashes are harmless but they change `Uri.parse(url).host`
      // handling in some paths, and they make logged URLs inconsistent.
      final url = rawUrl.endsWith('/')
          ? rawUrl.substring(0, rawUrl.length - 1)
          : rawUrl;
      AppLogger.info(
        'Supabase configured for ${Uri.parse(url).host} '
        '(key length ${rawKey.length})',
        tag: 'SupabaseConfig',
      );
      return SupabaseConfig._(url: url, key: rawKey);
    }

    // Logged so a debug build names the problem in the console. Never includes
    // the key — only which variable is at fault.
    AppLogger.error(
      'Supabase is misconfigured: ${urlProblem ?? keyProblem}',
      tag: 'SupabaseConfig',
    );

    return const SupabaseConfig._(
      url: unconfiguredUrl,
      key: 'unconfigured',
      // One sentence, aimed at whoever is holding the phone rather than at
      // whoever built it. The specifics are in the log.
      problem: 'This copy of Mizan is not set up to reach the server, so '
          'accounts, circles and Minbar are unavailable. Reading works as '
          'normal. Please tell whoever sent you the app.',
    );
  }

  /// Developer-facing detail, for the Settings diagnostic row. Safe to show:
  /// it names variables and lengths, never a value.
  String get detail {
    if (isUsable) return 'Connected to ${Uri.parse(url).host}';
    return 'SUPABASE_URL / SUPABASE_ANON_KEY missing or invalid in .env';
  }

  static String? _urlProblem(String url) {
    if (url.isEmpty) return 'SUPABASE_URL is empty or absent';
    final uri = Uri.tryParse(url);
    if (uri == null) return 'SUPABASE_URL is not a URL';
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'SUPABASE_URL must start with https://';
    }
    if (uri.host.isEmpty) return 'SUPABASE_URL has no host';
    // The commonest mistake: pasting the dashboard address rather than the API
    // one. It parses, it resolves, and every request 404s.
    if (uri.host == 'supabase.com' || uri.host == 'app.supabase.com') {
      return 'SUPABASE_URL points at the dashboard, not at the project API';
    }
    // Second commonest: leaving a placeholder in place.
    final lower = url.toLowerCase();
    if (lower.contains('your-project') ||
        lower.contains('example.com') ||
        lower.contains('xxxx')) {
      return 'SUPABASE_URL is still a placeholder';
    }
    // A phone cannot reach the developer's machine. Allowed only in a debug
    // build, where a simulator on the same host genuinely can.
    if (uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2') {
      return _isDebug ? null : 'SUPABASE_URL points at localhost';
    }
    return null;
  }

  static String? _keyProblem(String key) {
    if (key.isEmpty) return 'SUPABASE_ANON_KEY is empty or absent';
    final lower = key.toLowerCase();
    if (lower.contains('your-anon-key') ||
        lower.contains('your_anon_key') ||
        lower == 'anon' ||
        lower.contains('xxxx')) {
      return 'SUPABASE_ANON_KEY is still a placeholder';
    }
    // Two key shapes are valid: the legacy JWT (`eyJ…`, three dot-separated
    // parts, always well over 100 characters) and the newer publishable key
    // (`sb_publishable_…`). Anything much shorter than either is a truncated
    // paste — which otherwise produces a 401 on every request and looks exactly
    // like a permissions problem.
    final isJwt = key.startsWith('eyJ') && key.split('.').length == 3;
    final isPublishable = key.startsWith('sb_publishable_');
    if (!isJwt && !isPublishable) {
      return 'SUPABASE_ANON_KEY is not a recognised key format '
          '(expected eyJ… or sb_publishable_…)';
    }
    if (isJwt && key.length < 100) {
      return 'SUPABASE_ANON_KEY looks truncated';
    }
    return null;
  }

  // `assert` runs only in debug, so this flips itself on there and nowhere else.
  static bool get _isDebug {
    var debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }
}
