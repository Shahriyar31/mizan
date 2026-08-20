/// Ayah data model — updated with word-level data
library;

import 'ayah_word.dart';

class Ayah {
  const Ayah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
    required this.translation,
    this.transliteration,
    this.words = const [],
  });

  final int surahNumber;
  final int ayahNumber;
  final String arabicText;
  final String translation;
  final String? transliteration;
  final List<AyahWord> words; // individual tappable words

  String get key => '$surahNumber:$ayahNumber';

  /// Whether this ayah has word-level data loaded
  bool get hasWords => words.isNotEmpty;

  /// Only actual words — excludes ayah number end markers
  List<AyahWord> get tappableWords =>
      words.where((w) => w.isWord).toList();

  factory Ayah.fromJson(Map<String, dynamic> json) {
    // Parse verse_key "1:1" into surah and ayah numbers
    final verseKey = json['verse_key'] as String? ?? '0:0';
    final parts = verseKey.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 0;
    final ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    // Extract translation safely — strip HTML tags Quran.com sometimes includes
    String translationText = '';
    final translations = json['translations'];
    if (translations != null &&
        translations is List &&
        translations.isNotEmpty) {
      final first = translations[0];
      if (first is Map) {
        translationText = (first['text'] as String? ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), '');
      }
    }

    // Parse word-level data if present in response
    final wordsList = json['words'] as List?;
    final words = wordsList
            ?.map((w) => AyahWord.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];

    return Ayah(
      surahNumber: surahNum,
      ayahNumber: ayahNum,
      arabicText: json['text_uthmani'] as String? ?? '',
      translation: translationText,
      words: words,
    );
  }
}
