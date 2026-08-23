/// Quran Repository
///
/// The repository pattern explained:
/// - UI asks repository for data
/// - Repository checks local cache first
/// - If cache is fresh → return cached data (fast, offline works)
/// - If cache is stale or empty → fetch from API, cache it, return it
///
/// The UI never knows or cares where data came from.
/// This is why we can add offline support without changing any UI code.
library;

import '../../../services/quran/quran_api_service.dart';
import '../../../shared/models/surah.dart';
import '../../../shared/models/ayah.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

class QuranRepository {
  QuranRepository({QuranApiService? apiService})
      : _apiService = apiService ?? QuranApiService();

  final QuranApiService _apiService;
  static const String _tag = 'QuranRepository';

  // ── In-memory cache ───────────────────────────────────────────
  // Simple cache for this phase — Phase 3 adds SQLite persistence
  // List of surahs cached after first fetch
  List<Surah>? _cachedSurahs;

  // Cache of ayat, keyed by surah *and* translation ('2:85').
  //
  // The translation has to be part of the key. Keying on surah alone means
  // switching translation keeps serving the old English under the new setting
  // for every surah already opened this session — the setting appears to do
  // nothing. Keying on both also makes switching back instant.
  final Map<String, List<Ayah>> _cachedAyat = {};

  String _ayatKey(int surahNumber, int translationId) =>
      '$surahNumber:$translationId';

  // ── Surahs ────────────────────────────────────────────────────

  /// Gets all 114 surahs
  /// Returns cached data if available, otherwise fetches from API
  Future<List<Surah>> getSurahs() async {
    // Return cache if we have it
    if (_cachedSurahs != null) {
      AppLogger.info('Returning cached surahs', tag: _tag);
      return _cachedSurahs!;
    }

    AppLogger.info('Fetching surahs from API', tag: _tag);

    // Fetch from API
    final rawSurahs = await _apiService.getSurahs();

    // Convert raw JSON to typed Surah objects
    final surahs = rawSurahs.map((json) => Surah.fromJson(json)).toList();

    // Cache for next time
    _cachedSurahs = surahs;

    AppLogger.info('Cached ${surahs.length} surahs', tag: _tag);
    return surahs;
  }

  /// Gets a single surah by number
  Future<Surah?> getSurahByNumber(int number) async {
    final surahs = await getSurahs();
    try {
      return surahs.firstWhere((s) => s.number == number);
    } catch (_) {
      return null;
    }
  }

  // ── Ayat ──────────────────────────────────────────────────────

  /// Gets all ayat for a surah in the given translation.
  ///
  /// [translationId] is a Quran.com resource id — see [kQuranTranslations].
  /// Caches per surah *and* translation, so opening Al-Baqarah twice fetches
  /// once, and switching translation fetches once more and then never again.
  Future<List<Ayah>> getAyatForSurah(
    int surahNumber, {
    int translationId = ApiConstants.translationEnglish,
  }) async {
    final key = _ayatKey(surahNumber, translationId);

    // Return cache if we have it for this surah in this translation
    if (_cachedAyat.containsKey(key)) {
      AppLogger.info(
        'Returning cached ayat for surah $surahNumber (translation $translationId)',
        tag: _tag,
      );
      return _cachedAyat[key]!;
    }

    AppLogger.info(
      'Fetching ayat for surah $surahNumber (translation $translationId)',
      tag: _tag,
    );

    final ayat = await _apiService.getAyatForSurah(
      surahNumber,
      translationId: translationId,
    );

    // Cache this surah's ayat in this translation
    _cachedAyat[key] = ayat;

    AppLogger.info(
      'Cached ${ayat.length} ayat for surah $surahNumber',
      tag: _tag,
    );
    return ayat;
  }

  /// Clears all caches — useful for refresh or language change
  void clearCache() {
    _cachedSurahs = null;
    _cachedAyat.clear();
    AppLogger.info('Cache cleared', tag: _tag);
  }
}
