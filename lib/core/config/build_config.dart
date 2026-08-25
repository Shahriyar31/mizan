/// Every value that comes from outside the source code, in one place.
///
/// ── The problem this replaces ──────────────────────────────────────────
/// Configuration used to be read from `.env` through `flutter_dotenv`, and for
/// that to work `.env` had to be declared in `pubspec.yaml`'s asset list. An
/// asset is a file inside the build. So the shipped APK contained:
///
/// ```
/// unzip -p app-release.apk assets/flutter_assets/.env
/// ```
///
/// — the whole file, in plaintext, readable by anybody who downloads the app. Not
/// obfuscated, not encrypted, not even buried: one command. And on a web build it
/// would be worse still, served at `<site>/assets/.env` to anyone who asks.
///
/// Two of those values had no business being there at all. `GROQ_API_KEY` was
/// read by nothing — Scholar AI is not built yet — so it was shipped to every
/// user purely because it shared a file with the values that were needed.
/// `UMMAH_API_KEY` was read, but by client code, which means it had to be in the
/// bundle to work.
///
/// ── What this changes, and what it honestly does not ───────────────────
/// Values now arrive as compile-time constants through `--dart-define`, and
/// `.env` is no longer an asset — so there is no file in the build to open, and
/// no path to fetch on web.
///
/// This is **not** encryption, and it should not be described as such. A string
/// compiled into a binary is still a string in that binary; `strings` will find
/// it. What changes is *control*: the build command decides which names exist in
/// the build, so the release script can pass the two public Supabase values and
/// nothing else, while `.env` keeps every key for local development. See
/// `tools/build_release.sh`, which is deliberately a whitelist rather than a
/// blocklist — a new secret added to `.env` is excluded by default instead of
/// shipping because somebody forgot to exclude it.
///
/// For a key that must stay secret while the client still needs the data, the
/// only real answer is that the client never holds it: the request goes to a
/// proxy that holds the key server-side. That is the Groq and UmmahAPI plan and
/// it has not been built yet. Until it is, this is the step that stops those two
/// keys travelling in a build — the key stays in `.env` where development needs
/// it, and no release carries it.
///
/// ── Running the app ───────────────────────────────────────────────────
/// `.env` is still the single source of truth, it is just delivered rather than
/// bundled:
///
/// ```sh
/// tools/run.sh                                   # or:
/// flutter run --dart-define-from-file=.env
/// ```
///
/// Miss the flag and the app still starts — every value here degrades to absent,
/// and [SupabaseConfig] turns that into a sentence on the sign-in screen naming
/// the fix rather than a silent failure.
///
/// ── Why `const`, every time ────────────────────────────────────────────
/// `String.fromEnvironment` is a const constructor and is only substituted at
/// compile time. Called outside a const context it can quietly return the
/// default on AOT targets, which would look like a missing variable on a phone
/// and a present one on the desktop debug build. Every read below is therefore a
/// `static const` field, and nothing else in the app calls `fromEnvironment` —
/// which is also why these cannot be looked up by a runtime string: a const needs
/// its name as a literal. One field per variable is the price of that, and it is
/// worth paying to keep the values reliable.
library;

class BuildConfig {
  const BuildConfig._();

  // ── Supabase ────────────────────────────────────────────────────────
  // Both are public by design and both are meant to be in the app: the anon key
  // identifies the project and carries no privileges of its own — every table is
  // reached through row-level security, so what it can see is decided by the
  // policies on the server, not by keeping the key hidden. These are the only two
  // values `tools/build_release.sh` passes.

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl => _supabaseUrl.trim();
  static String get supabaseAnonKey => _supabaseAnonKey.trim();

  // ── UmmahAPI ────────────────────────────────────────────────────────
  // The key lifts a rate limit and gates nothing, so its absence costs quota and
  // not access — which is exactly why leaving it out of a release build is a
  // survivable trade until the proxy exists.

  static const String _ummahApiKey = String.fromEnvironment('UMMAH_API_KEY');
  static const String _ummahApiBaseUrl =
      String.fromEnvironment('UMMAH_API_BASE_URL');

  static String? get ummahApiKey => _orNull(_ummahApiKey);
  static String? get ummahApiBaseUrl => _orNull(_ummahApiBaseUrl);

  // ── Hadith provider ─────────────────────────────────────────────────
  // Unset in every build so far; the hadith layer resolves from bundled and
  // cached text and says so plainly when a citation has no text yet.

  static const String _hadithBaseUrl =
      String.fromEnvironment('HADITH_API_BASE_URL');
  static const String _hadithPath = String.fromEnvironment('HADITH_API_PATH');
  static const String _hadithKey = String.fromEnvironment('HADITH_API_KEY');
  static const String _hadithKeyHeader =
      String.fromEnvironment('HADITH_API_KEY_HEADER');
  static const String _hadithKeyQuery =
      String.fromEnvironment('HADITH_API_KEY_QUERY');

  static String? get hadithApiBaseUrl => _orNull(_hadithBaseUrl);
  static String? get hadithApiPath => _orNull(_hadithPath);
  static String? get hadithApiKey => _orNull(_hadithKey);
  static String? get hadithApiKeyHeader => _orNull(_hadithKeyHeader);
  static String? get hadithApiKeyQuery => _orNull(_hadithKeyQuery);

  // ── Feature flags ───────────────────────────────────────────────────
  // Read as strings rather than through `bool.fromEnvironment`, which accepts
  // only the exact words `true` and `false`. `.env` has used `1` since the first
  // commit, and silently reading every `1` as `false` would turn three finished
  // features off in a release build.

  static const String _featureHalaqa = String.fromEnvironment('FEATURE_HALAQA');
  static const String _featureMinbar = String.fromEnvironment('FEATURE_MINBAR');
  static const String _featureScholarAi =
      String.fromEnvironment('FEATURE_SCHOLAR_AI');
  static const String _featureSeedSocial =
      String.fromEnvironment('FEATURE_SEED_SOCIAL');

  static bool get featureHalaqa => _flag(_featureHalaqa, fallback: true);
  static bool get featureMinbar => _flag(_featureMinbar, fallback: true);
  static bool get featureScholarAi => _flag(_featureScholarAi, fallback: true);
  static bool get featureSeedSocial => _flag(_featureSeedSocial, fallback: true);

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Absent and blank are the same thing.
  ///
  /// `String.fromEnvironment` cannot return null — an undefined name and an empty
  /// value both give `''`. Collapsing the two here lets every caller keep the
  /// nullable contract it already had, and means a variable someone left as
  /// `UMMAH_API_KEY=` behaves like one they never wrote, rather than sending an
  /// empty header.
  static String? _orNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// `1`, `true`, `on` and `yes` in any case. Anything else is off, and absent is
  /// [fallback].
  static bool _flag(String raw, {required bool fallback}) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return fallback;
    return value == '1' || value == 'true' || value == 'on' || value == 'yes';
  }

  /// True in a debug build and nowhere else.
  ///
  /// `assert` bodies are stripped from profile and release, so the closure runs
  /// only in debug. Deliberately not `kDebugMode`: that would pull
  /// `package:flutter/foundation.dart` into a config file that otherwise depends
  /// on nothing, and this is used by a plain Dart-testable path.
  static bool get isDebug {
    var debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }

  /// Which variables this build received, for the Settings diagnostic row.
  ///
  /// Names and lengths only, never a value — the whole point of this file is that
  /// the values are not casually readable, and printing them into a screen or a
  /// log would undo it. A length is enough to tell a truncated paste from a
  /// missing variable, which is the question this is asked to answer.
  static String describe() {
    final present = <String>[
      if (_supabaseUrl.trim().isNotEmpty) 'SUPABASE_URL',
      if (_supabaseAnonKey.trim().isNotEmpty)
        'SUPABASE_ANON_KEY(${_supabaseAnonKey.trim().length})',
      if (_ummahApiKey.trim().isNotEmpty)
        'UMMAH_API_KEY(${_ummahApiKey.trim().length})',
      if (_hadithBaseUrl.trim().isNotEmpty) 'HADITH_API_BASE_URL',
    ];
    if (present.isEmpty) {
      return 'No build variables. Run with --dart-define-from-file=.env';
    }
    return present.join(', ');
  }
}
