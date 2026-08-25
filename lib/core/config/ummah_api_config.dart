/// UmmahAPI configuration — one place that knows the base URL and the key.
///
/// The key comes from [BuildConfig], read at call time rather than captured into
/// a field, so there is exactly one definition of where it comes from and a build
/// made without it degrades instead of crashing.
///
/// ── The key is not in the bundle any more ──────────────────────────────
/// It used to be, because `.env` was a declared asset and therefore a plaintext
/// file inside the APK. It is now a `--dart-define` and the release build script
/// does not pass it. So a release carries no key, sends no `X-API-Key`, and falls
/// back to the anonymous rate limit — which is survivable precisely because of
/// the paragraph below. The real fix is a proxy that holds the key server-side;
/// see `build_config.dart`.
///
/// It is sent **only** as the `X-API-Key` header. The documentation also accepts
/// `?apikey=…`, and that form is deliberately unused: a key in a query string
/// lands in server access logs, proxy logs, crash reports, `Referer` headers and
/// — worst for a client that caches — in the cache key itself, which would mean
/// storing a response under a filename containing the secret.
///
/// Every endpoint on this API answers without a key; the key only lifts the rate
/// limit from 5,000/15min to unlimited. So [isAuthenticated] is a statement about
/// quota, never about access, and nothing in the app is gated on it.
library;

import 'build_config.dart';

class UmmahApiConfig {
  UmmahApiConfig._();

  /// Overridable so a staging host can be pointed at without a code change.
  static String get baseUrl {
    final raw = BuildConfig.ummahApiBaseUrl;
    final base = (raw == null || raw.isEmpty) ? 'https://ummahapi.com' : raw;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static const String keyHeader = 'X-API-Key';

  static String? get apiKey => BuildConfig.ummahApiKey;

  /// Whether requests will carry a key. Affects rate limits only.
  static bool get isAuthenticated => apiKey != null;

  static Map<String, String> headers() {
    final key = apiKey;
    return {
      'Accept': 'application/json',
      if (key != null) keyHeader: key,
    };
  }

  /// Builds a request URI. [path] is relative (`/api/tafsir`), and [query] values
  /// are encoded by [Uri].
  ///
  /// The key is never added here — it goes in the headers — so a URI produced by
  /// this method is safe to log, cache under, and show in an error message.
  static Uri uri(String path, [Map<String, String>? query]) {
    final normalised = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalised').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }
}
