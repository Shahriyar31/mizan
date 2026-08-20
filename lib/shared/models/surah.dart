/// Surah data model
/// Represents one of the 114 chapters of the Quran
///
/// Data comes from Quran.com API /chapters endpoint
/// Example API response:
/// {
///   "id": 1,
///   "revelation_place": "makkah",
///   "name_simple": "Al-Fatihah",
///   "name_arabic": "الفاتحة",
///   "verses_count": 7,
///   "translated_name": {"name": "The Opening"}
/// }
library;

class Surah {
  const Surah({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.translatedName,
    required this.verseCount,
    required this.revelationPlace,
  });

  final int number;
  final String arabicName; // الفاتحة
  final String englishName; // Al-Fatihah
  final String translatedName; // The Opening
  final int verseCount;
  final RevelationPlace revelationPlace;

  /// Surahs that are commonly recited in salah
  /// These get a special badge in the UI
  /// Based on what most Muslims recite in their daily prayers
  static const Set<int> salahSurahs = {
    1, // Al-Fatihah — recited in every rakah
    112, // Al-Ikhlas
    113, // Al-Falaq
    114, // An-Nas
    108, // Al-Kawthar
    107, // Al-Ma'un
    106, // Quraysh
    105, // Al-Fil
    104, // Al-Humazah
    103, // Al-Asr
    102, // At-Takathur
    101, // Al-Qari'ah
    100, // Al-Adiyat
    99, // Az-Zalzalah
    98, // Al-Bayyinah
    87, // Al-A'la
    88, // Al-Ghashiyah
    93, // Ad-Duha
    94, // Ash-Sharh — our Ayah of the Week surah
    18, // Al-Kahf — recommended every Friday
  };

  /// Whether this surah is commonly recited in salah
  bool get isRecitedInSalah => salahSurahs.contains(number);

  /// Whether this surah is specifically Al-Kahf (Friday surah)
  bool get isFridaySurah => number == 18;

  /// Short display reference e.g. "7 ayat · Meccan"
  String get metaDisplay => '$verseCount ayat · ${revelationPlace.displayName}';

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['id'] as int,
      arabicName: json['name_arabic'] as String? ?? '',
      englishName: json['name_simple'] as String? ?? '',
      translatedName: (json['translated_name']
              as Map<String, dynamic>?)?['name'] as String? ??
          '',
      verseCount: json['verses_count'] as int? ?? 0,
      revelationPlace: RevelationPlace.fromString(
        json['revelation_place'] as String? ?? '',
      ),
    );
  }

  @override
  String toString() => 'Surah($number: $englishName)';
}

enum RevelationPlace {
  makkah,
  madinah,
  unknown;

  factory RevelationPlace.fromString(String value) {
    return switch (value.toLowerCase()) {
      'makkah' => RevelationPlace.makkah,
      'madinah' => RevelationPlace.madinah,
      _ => RevelationPlace.unknown,
    };
  }

  String get displayName => switch (this) {
        RevelationPlace.makkah => 'Meccan',
        RevelationPlace.madinah => 'Medinan',
        RevelationPlace.unknown => '',
      };
}
