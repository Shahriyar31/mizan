/// VocabWord — a saved Quranic word in the Vocabulary Bank
///
/// Why a separate model from AyahWord:
/// AyahWord is API data — temporary, fetched per session.
/// VocabWord is persisted data — saved by the user, lives in SQLite.
/// They have different fields and different lifecycles.
///
/// Spaced repetition fields:
/// reviewCount   — how many times reviewed
/// nextReviewAt  — when to show it again (null = show immediately)
/// The algorithm: 0 reviews → 1 day, 1 review → 3 days,
///                2 reviews → 7 days, 3+ reviews → 30 days
library;

class VocabWord {
  const VocabWord({
    this.id,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    required this.root,
    required this.insight,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.savedAt,
    this.reviewCount = 0,
    this.nextReviewAt,
  });

  final int? id;               // SQLite auto-increment ID
  final String arabic;         // بِسْمِ
  final String transliteration;// bis'mi
  final String meaning;        // In (the) name
  final String root;           // س-م-و
  final String insight;        // scholarly insight text
  final int surahNumber;       // 1
  final int ayahNumber;        // 1
  final String surahName;      // Al-Fatihah
  final DateTime savedAt;      // when the user saved it
  final int reviewCount;       // spaced repetition counter
  final DateTime? nextReviewAt;// when to show next in Wird

  /// Whether this word is due for review in today's Wird
  bool get isDueForReview {
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  /// Reference string shown in UI — e.g. "Al-Fatihah 1:1"
  String get reference => '$surahName $surahNumber:$ayahNumber';

  /// Next review interval based on review count
  Duration get nextInterval {
    return switch (reviewCount) {
      0 => const Duration(days: 1),
      1 => const Duration(days: 3),
      2 => const Duration(days: 7),
      _ => const Duration(days: 30),
    };
  }

  /// Returns a copy with review count incremented and next review scheduled
  VocabWord markReviewed() {
    return copyWith(
      reviewCount: reviewCount + 1,
      nextReviewAt: DateTime.now().add(nextInterval),
    );
  }

  // ── SQLite conversion ─────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'arabic': arabic,
      'transliteration': transliteration,
      'meaning': meaning,
      'root': root,
      'insight': insight,
      'surah_number': surahNumber,
      'ayah_number': ayahNumber,
      'surah_name': surahName,
      'saved_at': savedAt.toIso8601String(),
      'review_count': reviewCount,
      'next_review_at': nextReviewAt?.toIso8601String(),
    };
  }

  factory VocabWord.fromMap(Map<String, dynamic> map) {
    return VocabWord(
      id: map['id'] as int?,
      arabic: map['arabic'] as String,
      transliteration: map['transliteration'] as String,
      meaning: map['meaning'] as String,
      root: map['root'] as String,
      insight: map['insight'] as String,
      surahNumber: map['surah_number'] as int,
      ayahNumber: map['ayah_number'] as int,
      surahName: map['surah_name'] as String,
      savedAt: DateTime.parse(map['saved_at'] as String),
      reviewCount: map['review_count'] as int? ?? 0,
      nextReviewAt: map['next_review_at'] != null
          ? DateTime.parse(map['next_review_at'] as String)
          : null,
    );
  }

  VocabWord copyWith({
    int? id,
    String? arabic,
    String? transliteration,
    String? meaning,
    String? root,
    String? insight,
    int? surahNumber,
    int? ayahNumber,
    String? surahName,
    DateTime? savedAt,
    int? reviewCount,
    DateTime? nextReviewAt,
  }) {
    return VocabWord(
      id: id ?? this.id,
      arabic: arabic ?? this.arabic,
      transliteration: transliteration ?? this.transliteration,
      meaning: meaning ?? this.meaning,
      root: root ?? this.root,
      insight: insight ?? this.insight,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      surahName: surahName ?? this.surahName,
      savedAt: savedAt ?? this.savedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }
}
