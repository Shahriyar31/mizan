/// ScholarAIService — reads preprocessed Ibn Kathir JSON
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';
import '../../features/quran/data/layer_content.dart';

class ScholarAIService {
  ScholarAIService._();
  static final ScholarAIService instance = ScholarAIService._();
  static const String _tag = 'ScholarAIService';

  final Map<int, List<Map<String, dynamic>>> _cache = {};

  Future<LayerData?> getLayerContent(
    int surahNumber,
    int ayahNumber,
    String arabicText,
    String translation,
  ) async {
    // Step 1: Hand-curated Al-Fatihah data
    final curated = LayerContentData.getContent(surahNumber, ayahNumber);
    if (curated != null) return curated;

    // Step 2: Preprocessed Ibn Kathir
    try {
      final ayahData = await _loadProcessedAyah(surahNumber, ayahNumber);
      if (ayahData != null) {
        return _buildFromProcessed(ayahData);
      }
    } catch (e) {
      AppLogger.error('Processed data load failed', error: e, tag: _tag);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadProcessedAyah(
      int surahNumber, int ayahNumber) async {
    if (!_cache.containsKey(surahNumber)) {
      try {
        final jsonStr = await rootBundle.loadString(
          'assets/data/ibn_kathir_processed/$surahNumber.json',
        );
        final List<dynamic> data = jsonDecode(jsonStr);
        _cache[surahNumber] =
            data.map((e) => e as Map<String, dynamic>).toList();
      } catch (e) {
        return null;
      }
    }

    final ayahs = _cache[surahNumber]!;
    for (final ayah in ayahs) {
      if ((ayah['ayah'] as int?) == ayahNumber) return ayah;
    }
    return null;
  }

  LayerData _buildFromProcessed(Map<String, dynamic> data) {
    final fullCommentary = data['full_commentary'] as String? ?? '';
    final keyInsight     = data['key_insight'] as String? ?? '';
    final teasers        = data['tomorrow_teaser'] as String? ?? '';
    final contextMap     = data['context'] as Map<String, dynamic>? ?? {};
    final location       = contextMap['location'] as String? ?? 'Unknown';
    final hadiths        = (data['hadiths'] as List? ?? [])
        .map((h) => h as Map<String, dynamic>)
        .toList();
    final hadith = hadiths.isNotEmpty ? hadiths.first : null;

    // Layer 1 — Words: first meaningful sentence from Ibn Kathir
    final wordsText = keyInsight.isNotEmpty
        ? keyInsight
        : fullCommentary.substring(0, fullCommentary.length.clamp(0, 300));

    // Layer 2 — Context: full commentary with location prefix
    final locationPrefix = (location != 'Unknown' && location.isNotEmpty)
        ? 'Revealed in $location\n\n'
        : '';
    final contextText = locationPrefix + fullCommentary;

    // Layer 3 — Scholars: full commentary under Ibn Kathir attribution
    final scholarInsightText =
        fullCommentary.isNotEmpty ? fullCommentary : keyInsight;

    // Tomorrow teasers — use stored or sensible defaults
    final teaserList = teasers.isNotEmpty
        ? [teasers, teasers, teasers, teasers]
        : [
            'Tomorrow: Explore the historical context of this ayah.',
            'Tomorrow: What scholars said about the words in this ayah.',
            'Tomorrow: Trace the chain of narration behind this hadith.',
            'Tomorrow: Sit with this ayah — what does it mean for your life right now?',
          ];

    return LayerData(
      words: wordsText.isNotEmpty
          ? wordsText
          : 'Tap each word above to explore its root and meaning.',
      context: contextText.isNotEmpty
          ? contextText
          : "Ibn Kathir's commentary for this ayah.",
      scholars: ScholarInsight(
        scholarName: 'Ibn Kathir',
        scholarEra: '1301–1373 CE',
        work: 'Tafseer al-Quran al-Azeem',
        insight: scholarInsightText,
        arabicQuote: '',
      ),
      isnad: IsnadData(
        hadithText: hadith?['text'] as String? ?? '',
        narrator:   hadith?['narrator'] as String? ?? '',
        collection: hadith?['collection'] as String? ?? '',
        reference:  hadith?['reference'] as String? ?? '',
        grade:      hadith?['grade'] as String? ?? '',
        chain: [],
      ),
      tomorrowTeasers: teaserList,
    );
  }
}

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
