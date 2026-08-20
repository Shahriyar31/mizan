/// All API base URLs and endpoint paths
/// Never hardcode these in service files
library;

class ApiConstants {
  ApiConstants._();

  // ── Quran.com API ─────────────────────────────────────────────
  static const String quranBaseUrl = 'https://api.quran.com/api/v4';
  static const String quranChapters = '/chapters';
  static const String quranVersesByChapter = '/verses/by_chapter';
  static const String quranVerseByKey = '/verses/by_key';

  // Default translation IDs from Quran.com
  static const int translationEnglish =
      85; // Abdul Haleem (replaces Sahih International which was removed from API)
  static const int translationBengali = 213; // Muhammad Muhiuddin Khan
  static const int translationHindi = 462; // Fateh Muhammad Jalandhri

  // ── Sunnah.com API ────────────────────────────────────────────
  static const String hadithBaseUrl = 'https://api.sunnah.com/v1';
  static const String hadithCollections = '/collections';
  static const String hadithRandom = '/hadiths/random';

  // ── Azure OpenAI ──────────────────────────────────────────────
  // Values loaded from .env — never hardcode keys here
  static const String azureOpenAiVersion = '2024-02-01';

  // ── Timeouts ──────────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration aiTimeout = Duration(seconds: 60);
}
