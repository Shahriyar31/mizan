/// Ayah data model
/// Represents a single Quran verse with all associated data
library;

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
  final List<AyahWord> words;

  String get key => '$surahNumber:$ayahNumber';

  factory Ayah.fromJson(Map<String, dynamic> json) {
    // Parse verse_key "1:1" into surah and ayah numbers
    final verseKey = json['verse_key'] as String? ?? '0:0';
    final parts = verseKey.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 0;
    final ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    // Extract translation safely
    String translationText = '';
    final translations = json['translations'];
    if (translations != null &&
        translations is List &&
        translations.isNotEmpty) {
      final first = translations[0];
      if (first is Map) {
        translationText =
            (first['text'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '');
      }
    }

    return Ayah(
      surahNumber: surahNum,
      ayahNumber: ayahNum,
      arabicText: json['text_uthmani'] as String? ?? '',
      translation: translationText,
    );
  }
}

class AyahWord {
  const AyahWord({
    required this.arabic,
    required this.root,
    required this.meaning,
    this.insight,
  });

  final String arabic;
  final String root;
  final String meaning;
  final String? insight;
}
