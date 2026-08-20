/// ScholarAIService — Layer content from verified scholarly sources
///
/// Architecture (correct, final):
/// ─────────────────────────────
/// Words layer    → Quran.com word morphology (handled by QuranApiService)
/// Context layer  → Quran.com Tafsir API (ID 169, Ibn Kathir Abridged)
///                  Returns surah introduction + revelation context
///                  Fetched live, cached in memory per session
/// Scholars layer → Local Ibn Kathir JSON (assets/data/ibn_kathir/)
///                  Downloaded once, stored in app assets, never changes
///                  Full ayah commentary, Ibn Kathir's actual words
/// Isnad layer    → Hadith references extracted from Scholars text
/// Reflection     → User's private input (no service needed)
///
/// Al-Fatihah (1:x) uses hand-curated data from layer_content.dart
/// for the best possible first experience.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../features/quran/data/layer_content.dart';

class ScholarAIService {
  ScholarAIService._();
  static final ScholarAIService instance = ScholarAIService._();
  static const String _tag = 'ScholarAIService';

  // ── In-memory caches ──────────────────────────────────────────
  // Raw Ibn Kathir text per surah (loaded from assets)
  final Map<int, List<Map<String, dynamic>>> _ibnKathirCache = {};

  // Context text per ayah key "surah:ayah" (fetched from Quran.com API)
  final Map<String, String> _contextCache = {};

  // ── Public API ────────────────────────────────────────────────

  /// Get complete layer content for an ayah.
  /// Returns null only if no data is available at all.
  Future<LayerData?> getLayerContent(
    int surahNumber,
    int ayahNumber,
    String arabicText,
    String translation,
  ) async {
    // Step 1: Hand-curated Al-Fatihah data (best quality, instant)
    final curated = LayerContentData.getContent(surahNumber, ayahNumber);
    if (curated != null) {
      AppLogger.info(
        'Using curated content for $surahNumber:$ayahNumber',
        tag: _tag,
      );
      return curated;
    }

    // Step 2: Load from real data sources
    final scholarText = await _loadScholarText(surahNumber, ayahNumber);
    final contextText = await _loadContextText(surahNumber, ayahNumber);

    if (scholarText.isEmpty && contextText.isEmpty) {
      AppLogger.info(
        'No content available for $surahNumber:$ayahNumber',
        tag: _tag,
      );
      return null;
    }

    return _buildLayerData(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      scholarText: scholarText,
      contextText: contextText,
    );
  }

  // ── Scholars Layer — Local Ibn Kathir JSON ────────────────────

  /// Load Ibn Kathir's commentary for a specific ayah from local assets.
  /// Source: assets/data/ibn_kathir/{surah}.json
  /// These files were downloaded once and never change.
  Future<String> _loadScholarText(int surahNumber, int ayahNumber) async {
    try {
      // Load and cache the surah file if not already loaded
      if (!_ibnKathirCache.containsKey(surahNumber)) {
        AppLogger.info(
          'Loading Ibn Kathir surah $surahNumber from assets',
          tag: _tag,
        );
        final jsonStr = await rootBundle.loadString(
          'assets/data/ibn_kathir/$surahNumber.json',
        );
        final List<dynamic> data = jsonDecode(jsonStr);
        _ibnKathirCache[surahNumber] =
            data.map((e) => e as Map<String, dynamic>).toList();
      }

      // Find the specific ayah
      final ayahs = _ibnKathirCache[surahNumber]!;
      for (final ayah in ayahs) {
        final num = (ayah['ayah'] as num?)?.toInt() ?? 0;
        if (num == ayahNumber) {
          final text = (ayah['text'] as String? ?? '').trim();
          AppLogger.info(
            'Ibn Kathir commentary: ${text.length} chars for $surahNumber:$ayahNumber',
            tag: _tag,
          );
          return text;
        }
      }

      AppLogger.info(
        'Ayah $ayahNumber not found in surah $surahNumber',
        tag: _tag,
      );
      return '';
    } catch (e) {
      AppLogger.error(
        'Failed to load Ibn Kathir for $surahNumber:$ayahNumber',
        error: e,
        tag: _tag,
      );
      return '';
    }
  }

  // ── Context Layer — Quran.com Tafsir API ──────────────────────

  /// Fetch context/introduction from Quran.com Tafsir API.
  /// Resource ID 169 = Ibn Kathir Abridged (en-tafisr-ibn-kathir)
  /// Returns surah introduction for ayah 1, ayah context for others.
  Future<String> _loadContextText(int surahNumber, int ayahNumber) async {
    final cacheKey = '$surahNumber:$ayahNumber';

    if (_contextCache.containsKey(cacheKey)) {
      return _contextCache[cacheKey]!;
    }

    try {
      final url =
          'https://api.quran.com/api/v4/tafsirs/169/by_ayah/$surahNumber:$ayahNumber';

      AppLogger.info('Fetching context from Quran.com: $url', tag: _tag);

      final response = await http.get(Uri.parse(url), headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        AppLogger.info(
          'Quran.com API returned ${response.statusCode}',
          tag: _tag,
        );
        return '';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tafsir = data['tafsir'] as Map<String, dynamic>? ?? {};
      final htmlText = tafsir['text'] as String? ?? '';

      if (htmlText.isEmpty) return '';

      // Strip HTML tags to get clean text
      final cleanText = _stripHtml(htmlText);

      _contextCache[cacheKey] = cleanText;

      AppLogger.info(
        'Context loaded: ${cleanText.length} chars for $surahNumber:$ayahNumber',
        tag: _tag,
      );

      return cleanText;
    } catch (e) {
      AppLogger.error(
        'Context fetch failed for $surahNumber:$ayahNumber',
        error: e,
        tag: _tag,
      );
      return '';
    }
  }

  // ── Build LayerData ───────────────────────────────────────────

  LayerData _buildLayerData({
    required int surahNumber,
    required int ayahNumber,
    required String scholarText,
    required String contextText,
  }) {
    // Words layer: first meaningful sentence from Ibn Kathir
    // (The word cards from Quran.com API are handled separately in the UI)
    final wordsText = _extractKeyInsight(scholarText);

    // Extract hadith from scholar text for Isnad layer
    final hadithInfo = _extractHadith(scholarText);

    // Tomorrow teasers — meaningful progression
    const teasers = [
      'Tomorrow: Explore the historical context behind this ayah.',
      'Tomorrow: What Ibn Kathir said about the deeper meaning.',
      'Tomorrow: Trace the chain of narration behind this hadith.',
      'Tomorrow: Sit with this ayah — what does it mean for your life?',
    ];

    return LayerData(
      // Words: key insight from Ibn Kathir
      words: wordsText.isNotEmpty
          ? wordsText
          : 'Tap each word above to explore its root and meaning.',

      // Context: from Quran.com API (surah intro + revelation circumstances)
      // Falls back to first paragraph of Ibn Kathir if API unavailable
      context: contextText.isNotEmpty
          ? contextText
          : _extractFirstParagraph(scholarText),

      // Scholars: full Ibn Kathir commentary, properly attributed
      scholars: ScholarInsight(
        scholarName: 'Ibn Kathir',
        scholarEra: '1301–1373 CE',
        work: 'Tafseer al-Quran al-Azeem',
        insight: scholarText.isNotEmpty
            ? scholarText
            : 'Commentary for this ayah is being prepared.',
        arabicQuote: '',
      ),

      // Isnad: hadith references found in Ibn Kathir's commentary
      isnad: IsnadData(
        hadithText: hadithInfo['text'] ?? '',
        narrator: hadithInfo['narrator'] ?? '',
        collection: hadithInfo['collection'] ?? '',
        reference: hadithInfo['reference'] ?? '',
        grade: hadithInfo['grade'] ?? '',
        chain: [],
      ),

      tomorrowTeasers: teasers,
    );
  }

  // ── Text Processing Helpers ───────────────────────────────────

  /// Strip HTML tags from Quran.com API response
  String _stripHtml(String html) {
    // Replace block-level tags with newlines for readability
    String text = html
        .replaceAll(RegExp(r'<h[1-6][^>]*>'), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>'), '\n')
        .replaceAll(RegExp(r'<p[^>]*>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n');

    // Remove remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode common HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    // Clean up excess whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return text;
  }

  /// Extract first meaningful sentence for the Words layer key insight
  String _extractKeyInsight(String text) {
    if (text.isEmpty) return '';

    // Split on sentence boundaries
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));

    for (final sentence in sentences) {
      final s = sentence.trim();
      // Must be a complete English sentence, not a heading or Arabic text
      if (s.length > 60 &&
          !RegExp(r'[\u0600-\u06FF]').hasMatch(s) &&
          !s.startsWith('"') &&
          s[0] == s[0].toUpperCase()) {
        return s;
      }
    }

    // Fallback: first 200 chars
    return text.length > 200 ? '${text.substring(0, 200)}...' : text;
  }

  /// Extract first paragraph for context fallback
  String _extractFirstParagraph(String text) {
    if (text.isEmpty) return '';
    final paragraphs = text.split('\n\n');
    for (final p in paragraphs) {
      if (p.trim().length > 100) return p.trim();
    }
    return text.length > 400 ? text.substring(0, 400) : text;
  }

  /// Extract hadith information from Ibn Kathir's text
  Map<String, String> _extractHadith(String text) {
    // Look for collection references
    final collectionPatterns = [
      'Sahih Al-Bukhari',
      'Sahih Muslim',
      'At-Tirmidhi',
      'Abu Dawud',
      "An-Nasa'i",
      'Ibn Majah',
      'Musnad Ahmad',
    ];

    String collection = '';
    String grade = '';

    for (final pattern in collectionPatterns) {
      if (text.contains(pattern)) {
        collection = pattern;
        // Sahih Bukhari and Muslim are automatically Sahih
        if (pattern == 'Sahih Al-Bukhari' || pattern == 'Sahih Muslim') {
          grade = 'Sahih';
        }
        break;
      }
    }

    // Look for grading
    if (grade.isEmpty) {
      if (text.contains('graded it Sahih') || text.contains('Hasan Sahih')) {
        grade = 'Sahih';
      } else if (text.contains('Hasan Gharib') || text.contains('Hasan')) {
        grade = 'Hasan';
      }
    }

    // Extract narrator — look for "narrated by X" or "X said"
    String narrator = '';
    final narratorMatch =
        RegExp(r'Abu (?:Hurayrah|Bakr|Sa.id)|Ibn (?:Abbas|Umar|Mas.ud)')
            .firstMatch(text);
    if (narratorMatch != null) {
      narrator = narratorMatch.group(0) ?? '';
    }

    // Extract a short hadith quote if available
    String hadithText = '';
    final quoteMatch = RegExp(r'"([^"]{40,200})"').firstMatch(text);
    if (quoteMatch != null) {
      hadithText = quoteMatch.group(1) ?? '';
    }

    return {
      'text': hadithText,
      'narrator': narrator,
      'collection': collection,
      'reference': '',
      'grade': grade,
    };
  }
}
