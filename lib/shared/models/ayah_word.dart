/// AyahWord model — a single tappable word in an ayah
/// 
/// Data comes from Quran.com API words endpoint
/// Each word in an ayah is a separate object with:
/// - Arabic text (Uthmani script)
/// - English translation of just that word
/// - Transliteration (how to pronounce it)
/// - Position in the ayah
/// 
/// The root field is not provided by Quran.com API.
/// We use a local curated dataset for roots of common words.
/// For unknown words, root is left empty.
library;

class AyahWord {
  const AyahWord({
    required this.id,
    required this.position,
    required this.arabic,
    required this.translation,
    required this.transliteration,
    this.root = '',
    this.insight = '',
    this.charType = 'word',
  });

  final int id;
  final int position;
  final String arabic;          // بِسْمِ
  final String translation;     // In (the) name
  final String transliteration; // bis'mi
  final String root;            // س-م-و (curated locally)
  final String insight;         // curated scholarly insight
  final String charType;        // 'word' or 'end' (ayah marker)

  /// Only actual words — skip the ayah number end marker
  bool get isWord => charType == 'word';

  factory AyahWord.fromJson(Map<String, dynamic> json) {
    final translationMap = json['translation'] as Map<String, dynamic>?;
    final transliterationMap = json['transliteration'] as Map<String, dynamic>?;

    return AyahWord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? 0,
      arabic: json['text_uthmani'] as String? ?? '',
      translation: translationMap?['text'] as String? ?? '',
      transliteration: transliterationMap?['text'] as String? ?? '',
      charType: json['char_type_name'] as String? ?? 'word',
    );
  }
}
