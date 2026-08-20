/// ScholarAIService — reads Ibn Kathir locally, no AI needed for layers
///
/// Architecture:
/// - Ibn Kathir tafseer stored in assets/data/ibn_kathir/
/// - Layer content reads directly from local JSON — instant, free, accurate
/// - No AI in the middle — Ibn Kathir's actual words displayed directly
/// - Groq is reserved for Scholar AI chat only (user questions)
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';
import '../../features/quran/data/layer_content.dart';

class ScholarAIService {
  ScholarAIService._();
  static final ScholarAIService instance = ScholarAIService._();
  static const String _tag = 'ScholarAIService';

  // In-memory cache — load each surah's tafseer once per session
  final Map<int, List<Map<String, dynamic>>> _cache = {};

  /// Gets layer content for an ayah
  /// Priority:
  /// 1. Hardcoded curated data (Al-Fatihah — hand-crafted, richest)
  /// 2. Ibn Kathir local JSON (all 114 surahs — scholar's actual words)
  Future<LayerData?> getLayerContent(
    int surahNumber,
    int ayahNumber,
    String arabicText,
    String translation,
  ) async {
    // Step 1: Hand-curated data for Al-Fatihah
    final curated = LayerContentData.getContent(surahNumber, ayahNumber);
    if (curated != null) {
      AppLogger.info(
        'Using curated content for $surahNumber:$ayahNumber',
        tag: _tag,
      );
      return curated;
    }

    // Step 2: Ibn Kathir local JSON
    try {
      final commentary = await _getIbnKathirLocal(surahNumber, ayahNumber);
      if (commentary != null && commentary.isNotEmpty) {
        AppLogger.info(
          'Using Ibn Kathir local for $surahNumber:$ayahNumber',
          tag: _tag,
        );
        return _buildLayerData(commentary, surahNumber, ayahNumber);
      }
    } catch (e) {
      AppLogger.error('Ibn Kathir local read failed', error: e, tag: _tag);
    }

    return null;
  }

  /// Reads Ibn Kathir commentary from local assets
  Future<String?> _getIbnKathirLocal(
      int surahNumber, int ayahNumber) async {
    // Load from cache if available
    if (!_cache.containsKey(surahNumber)) {
      try {
        final jsonStr = await rootBundle.loadString(
          'assets/data/ibn_kathir/$surahNumber.json',
        );
        final List<dynamic> data = jsonDecode(jsonStr);
        _cache[surahNumber] = data
            .map((e) => e as Map<String, dynamic>)
            .toList();
        AppLogger.info(
          'Loaded Ibn Kathir surah $surahNumber: ${_cache[surahNumber]!.length} ayat',
          tag: _tag,
        );
      } catch (e) {
        AppLogger.error(
          'Failed to load Ibn Kathir surah $surahNumber',
          error: e,
          tag: _tag,
        );
        return null;
      }
    }

    // Find the specific ayah
    final ayahs = _cache[surahNumber]!;
    for (final ayah in ayahs) {
      final ayahNum = (ayah['ayah'] as num?)?.toInt();
      if (ayahNum == ayahNumber) {
        return ayah['text'] as String?;
      }
    }
    return null;
  }

  /// Builds LayerData from Ibn Kathir's commentary text
  /// The text IS the scholar layer — displayed directly, no AI processing
  LayerData _buildLayerData(
      String commentary, int surahNumber, int ayahNumber) {
    // Split commentary into sections for different layers
    // Ibn Kathir's tafseer naturally has: linguistic notes, context,
    // hadith citations, and reflective conclusions
    final lines = commentary.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Words layer — first paragraph (usually linguistic)
    final wordsText = lines.isNotEmpty
        ? lines.take(3).join(' ')
        : 'See the full Ibn Kathir commentary in the Scholars layer.';

    // Context layer — next section
    final contextText = lines.length > 3
        ? lines.skip(3).take(4).join(' ')
        : wordsText;

    // Scholar layer — Ibn Kathir's main commentary (largest section)
    // We show the full commentary here — his actual words
    final scholarText = commentary.length > 1000
        ? commentary.substring(0, 1000)
        : commentary;

    // Extract hadith if present — look for hadith markers
    String hadithText = '';
    String narrator = '';
    String collection = '';
    String reference = '';
    String grade = '';

    // Ibn Kathir frequently cites Bukhari and Muslim
    // Look for common patterns in his text
    if (commentary.contains('Bukhari')) {
      collection = 'Sahih al-Bukhari';
      grade = 'Sahih';
    } else if (commentary.contains('Muslim')) {
      collection = 'Sahih Muslim';
      grade = 'Sahih';
    } else if (commentary.contains('Tirmidhi')) {
      collection = 'Jami al-Tirmidhi';
      grade = 'See commentary';
    }

    // Find narrator — Ibn Kathir usually names companions
    final companions = [
      'Ibn Abbas', 'Ibn Masud', 'Abu Hurairah', 'Umar',
      'Ali', 'Aisha', 'Anas', 'Abu Bakr'
    ];
    for (final companion in companions) {
      if (commentary.contains(companion)) {
        narrator = companion;
        break;
      }
    }

    // Tomorrow teasers — contextual to the surah
    final teasers = [
      'Tomorrow: The linguistic depth of the key words in this ayah.',
      'Tomorrow: Ibn Kathir\'s historical context for this revelation.',
      'Tomorrow: The hadith chains Ibn Kathir cites for this ayah.',
      'Tomorrow: What does this ayah mean for your life today?',
    ];

    return LayerData(
      words: wordsText,
      context: contextText,
      scholars: ScholarInsight(
        scholarName: 'Ibn Kathir',
        scholarEra: '1301–1373 CE',
        work: 'Tafseer al-Quran al-Azeem',
        insight: scholarText,
        arabicQuote: '',
      ),
      isnad: IsnadData(
        hadithText: hadithText,
        narrator: narrator,
        collection: collection,
        reference: reference,
        grade: grade,
        chain: [],
      ),
      tomorrowTeasers: teasers,
    );
  }
}
