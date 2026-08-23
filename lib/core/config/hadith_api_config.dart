/// Hadith API configuration — read once from `.env`, never from a widget.
///
/// The brief says "The application uses UmmahAPI." It does not, yet: there is no
/// endpoint, no key and no client anywhere in the repo, and
/// `services/hadith/hadith_api_service.dart` is a five-line stub. Rather than
/// hardcode a guess at somebody's URL shape, the fetcher is configured from
/// `.env` and the whole hadith system works without it — bundled and cached texts
/// resolve offline, and a numbered citation with no text yet says so plainly.
///
/// Set these to switch the remote fetch on:
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

import 'package:flutter_dotenv/flutter_dotenv.dart';

class HadithApiConfig {
  HadithApiConfig._();

  static String? _value(String key) {
    final raw = dotenv.maybeGet(key)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static String? get baseUrl {
    final raw = _value('HADITH_API_BASE_URL');
    if (raw == null) return null;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Path template. The default is the shape most hadith APIs use; override it
  /// per provider without touching code.
  static String get pathTemplate =>
      _value('HADITH_API_PATH') ?? '/hadiths/{collection}/{number}';

  static String? get apiKey => _value('HADITH_API_KEY');

  /// Which header carries the key. Null with a key present means the key goes in
  /// the query string instead — see [apiKeyQueryParam].
  static String? get apiKeyHeader =>
      _value('HADITH_API_KEY_HEADER') ??
      (apiKey != null && apiKeyQueryParam == null ? 'x-api-key' : null);

  static String? get apiKeyQueryParam => _value('HADITH_API_KEY_QUERY');

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
