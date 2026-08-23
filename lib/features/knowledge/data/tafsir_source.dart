/// Tafsir passages, read from the Ibn Kathir JSON already bundled with the app.
///
/// `assets/data/ibn_kathir/{surah}.json` is a list of `{surah, ayah, text}` and
/// covers all 114 surahs, so a tafsir citation resolves offline, today, with no
/// network and no key. That is the whole reason Evidence Mode can promise "tap a
/// tafsir reference and read the passage" rather than promising a fetch.
///
/// The processed variant (`ibn_kathir_processed`) is deliberately not used here.
/// Its `hadiths` array is the output of a rough extraction pass — entries like
/// `{"reference": "Muslim consultative council, or a group of righteous men…"}`
/// are sentence fragments that happen to contain a collection name, not
/// citations. Presenting those as hadith references would be exactly the kind of
/// invented attribution the Citation Lock exists to prevent.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One scholar's commentary on one ayah.
class TafsirPassage {
  const TafsirPassage({
    required this.scholar,
    required this.work,
    required this.surah,
    required this.ayah,
    required this.text,
  });

  final String scholar;
  final String work;
  final int surah;
  final int ayah;

  /// Verbatim. Never summarised, never trimmed for length — the reader is shown
  /// the passage or is shown nothing.
  final String text;

  bool get isEmpty => text.trim().isEmpty;
}

class TafsirSource {
  TafsirSource._();

  static const String scholarName = 'Ibn Kathir';
  static const String scholarId = 'ibn-kathir';
  static const String workTitle = "Tafsir al-Qur'an al-'Azim";

  /// surah → ayah → text. One surah file is a few hundred KB, and a reader
  /// checking three citations in one surah should read it once.
  static final Map<int, Map<int, String>> _cache = {};

  static Future<TafsirPassage?> forAyah(int surah, int ayah) async {
    final bySurah = await _load(surah);
    final text = bySurah?[ayah];
    if (text == null || text.trim().isEmpty) return null;
    return TafsirPassage(
      scholar: scholarName,
      work: workTitle,
      surah: surah,
      ayah: ayah,
      text: text.trim(),
    );
  }

  /// True when a passage exists, without paying for the string. Used to decide
  /// whether a "Commentary" row is worth drawing at all.
  static Future<bool> hasAyah(int surah, int ayah) async {
    final bySurah = await _load(surah);
    final text = bySurah?[ayah];
    return text != null && text.trim().isNotEmpty;
  }

  static Future<Map<int, String>?> _load(int surah) async {
    if (surah < 1 || surah > 114) return null;
    final cached = _cache[surah];
    if (cached != null) return cached;
    try {
      final raw =
          await rootBundle.loadString('assets/data/ibn_kathir/$surah.json');
      final decoded = json.decode(raw);
      if (decoded is! List) return null;
      final out = <int, String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final ayah = (item['ayah'] as num?)?.toInt();
        final text = item['text'] as String?;
        if (ayah == null || text == null) continue;
        // Some ayat appear more than once in the source; the first pass wins so
        // the passage shown is stable between runs.
        out.putIfAbsent(ayah, () => text);
      }
      _cache[surah] = out;
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('[tafsir] surah $surah not loaded: $e');
      return null;
    }
  }
}
