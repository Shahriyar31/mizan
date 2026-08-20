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
    return Ayah(
      surahNumber: json['chapter_id'] as int,
      ayahNumber: json['verse_number'] as int,
      arabicText: json['text_uthmani'] as String? ?? '',
      translation: json['translations']?[0]?['text'] as String? ?? '',
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
