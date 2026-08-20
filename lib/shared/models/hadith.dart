/// Hadith data model
library;

enum HadithGrade { sahih, hasan, daif, mawdu, unknown }

class Hadith {
  const Hadith({
    required this.collection,
    required this.bookNumber,
    required this.hadithNumber,
    required this.arabicText,
    required this.englishText,
    required this.narrator,
    required this.grade,
  });

  final String collection;    // e.g. "Sahih Muslim"
  final int bookNumber;
  final int hadithNumber;
  final String arabicText;
  final String englishText;
  final String narrator;
  final HadithGrade grade;

  String get reference => '$collection $hadithNumber';

  String get gradeDisplay => switch (grade) {
        HadithGrade.sahih  => 'Sahih — Authentic',
        HadithGrade.hasan  => 'Hasan — Good',
        HadithGrade.daif   => 'Da\'if — Weak',
        HadithGrade.mawdu  => 'Mawdu\' — Fabricated',
        HadithGrade.unknown => 'Grade unknown',
      };

  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      collection: json['collection'] as String? ?? '',
      bookNumber: json['bookNumber'] as int? ?? 0,
      hadithNumber: json['hadithNumber'] as int? ?? 0,
      arabicText: json['body'] as String? ?? '',
      englishText: json['translation']?['body'] as String? ?? '',
      narrator: json['narrator'] as String? ?? '',
      grade: _parseGrade(json['grade'] as String?),
    );
  }

  static HadithGrade _parseGrade(String? grade) {
    return switch (grade?.toLowerCase()) {
      'sahih'           => HadithGrade.sahih,
      'hasan'           => HadithGrade.hasan,
      'da\'if' || 'daif' => HadithGrade.daif,
      'mawdu\''         => HadithGrade.mawdu,
      _                 => HadithGrade.unknown,
    };
  }
}
