/// Hadith API configuration — read once from the build, never from a widget.
///
/// The brief says "The application uses UmmahAPI." It does not, yet: there is no
/// endpoint, no key and no client anywhere in the repo, and
/// `services/hadith/hadith_api_service.dart` is a five-line stub. Rather than
/// hardcode a guess at somebody's URL shape, the fetcher is configured from the
/// build environment and the whole hadith system works without it — bundled and
/// cached texts resolve offline, and a numbered citation with no text yet says so
/// plainly.
///
/// Put these in `.env` and they reach the app through `--dart-define-from-file`;
/// see `build_config.dart`. Nothing here is passed by the release build script,
/// so setting `HADITH_API_KEY` affects development only until a proxy exists.
///
/// ```
/// HADITH_API_BASE_URL=https://api.example.com
/// HADITH_API_PATH=/hadiths/{collection}/{number}
/// HADITH_API_KEY=…
/// HADITH_API_KEY_HEADER=x-api-key      # or: HADITH_API_KEY_QUERY=apiKey
/// ```
///
/// `{collection}` and `{number}` are substituted. Nothing is logged and no key is
/// ever printed.
library;

import 'build_config.dart';

class HadithApiConfig {
  HadithApiConfig._();

  static String? get baseUrl {
    final raw = BuildConfig.hadithApiBaseUrl;
    if (raw == null) return null;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Path template. The default is the shape most hadith APIs use; override it
  /// per provider without touching code.
  static String get pathTemplate =>
      BuildConfig.hadithApiPath ?? '/hadiths/{collection}/{number}';

  static String? get apiKey => BuildConfig.hadithApiKey;

  /// Which header carries the key. Null with a key present means the key goes in
  /// the query string instead — see [apiKeyQueryParam].
  static String? get apiKeyHeader =>
      BuildConfig.hadithApiKeyHeader ??
      (apiKey != null && apiKeyQueryParam == null ? 'x-api-key' : null);

  static String? get apiKeyQueryParam => BuildConfig.hadithApiKeyQuery;

  /// A remote fetch is only attempted when a base URL is configured. Everything
  /// else about the hadith layer works either way.
  static bool get isConfigured => baseUrl != null;

  /// Builds the request URI for one hadith, or null when unconfigured.
  static Uri? uriFor(String collection, String number) {
    final base = baseUrl;
    if (base == null) return null;
    final path = pathTemplate
        .replaceAll('{collection}', Uri.encodeComponent(collection))
        .replaceAll('{number}', Uri.encodeComponent(number));
    final uri = Uri.parse('$base${path.startsWith('/') ? '' : '/'}$path');
    final queryKey = apiKeyQueryParam;
    final key = apiKey;
    if (queryKey != null && key != null) {
      return uri.replace(queryParameters: {...uri.queryParameters, queryKey: key});
    }
    return uri;
  }

  /// Headers for the request. Returns an empty map when there is no key.
  static Map<String, String> headers() {
    final key = apiKey;
    final header = apiKeyHeader;
    if (key == null || header == null) return const {'Accept': 'application/json'};
    return {'Accept': 'application/json', header: key};
  }
}
