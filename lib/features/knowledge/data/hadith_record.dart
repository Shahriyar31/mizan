/// One hadith, however we came to have it.
///
/// [origin] is part of the model rather than a detail of the fetch, because the
/// screen has to be able to say where the text came from. A hadith read from the
/// bundle and a hadith fetched from a configured endpoint are not the same claim,
/// and a reader checking a citation deserves to know which one they are looking
/// at.
library;

import '../../../core/knowledge/hadith_ref.dart';

enum HadithOrigin {
  /// Shipped with the app.
  bundled('Bundled with the app'),

  /// Fetched earlier and kept in the local database.
  cached('Saved on this device'),

  /// Just fetched from the configured endpoint.
  remote('Fetched from the hadith service');

  const HadithOrigin(this.label);

  final String label;
}

class HadithRecord {
  const HadithRecord({
    required this.collection,
    required this.number,
    this.arabic,
    this.english,
    this.narrator,
    this.grade,
    this.bookName,
    this.chapter,
    this.origin = HadithOrigin.remote,
    this.fetchedAt,
  });

  final String collection;
  final String number;

  final String? arabic;
  final String? english;
  final String? narrator;

  /// Only ever what the source said. We never assign a grade ourselves, and the
  /// two Sahihs are not silently stamped "sahih" here — that claim belongs to the
  /// collection, and the collection page says it.
  final String? grade;

  final String? bookName;
  final String? chapter;

  final HadithOrigin origin;
  final DateTime? fetchedAt;

  HadithRef get ref => HadithRef(collection: collection, number: number);

  HadithCollection? get book => HadithCollections.bySlug(collection);

  String get collectionTitle => book?.title ?? collection;

  /// "Sahih al-Bukhari 3326".
  String get display => '$collectionTitle $number';

  bool get hasText =>
      (arabic != null && arabic!.trim().isNotEmpty) ||
      (english != null && english!.trim().isNotEmpty);

  HadithRecord copyWith({HadithOrigin? origin, DateTime? fetchedAt}) =>
      HadithRecord(
        collection: collection,
        number: number,
        arabic: arabic,
        english: english,
        narrator: narrator,
        grade: grade,
        bookName: bookName,
        chapter: chapter,
        origin: origin ?? this.origin,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  // ── Local database ──────────────────────────────────────────────────

  Map<String, Object?> toRow() => {
        'collection': collection,
        'number': number,
        'arabic': arabic,
        'english': english,
        'narrator': narrator,
        'grade': grade,
        'book_name': bookName,
        'chapter': chapter,
        'fetched_at': (fetchedAt ?? DateTime.now()).toIso8601String(),
      };

  static HadithRecord fromRow(Map<String, Object?> row) => HadithRecord(
        collection: row['collection'] as String? ?? '',
        number: row['number'] as String? ?? '',
        arabic: row['arabic'] as String?,
        english: row['english'] as String?,
        narrator: row['narrator'] as String?,
        grade: row['grade'] as String?,
        bookName: row['book_name'] as String?,
        chapter: row['chapter'] as String?,
        origin: HadithOrigin.cached,
        fetchedAt: DateTime.tryParse(row['fetched_at'] as String? ?? ''),
      );

  // ── JSON ────────────────────────────────────────────────────────────

  /// Forgiving on purpose. The endpoint is configurable, so the field names are
  /// not knowable in advance; every plausible spelling is tried and a response
  /// that yields no text at all returns null rather than an empty record.
  static HadithRecord? fromJson(
    Map<String, dynamic> json, {
    required String collection,
    required String number,
    HadithOrigin origin = HadithOrigin.remote,
  }) {
    // Providers commonly wrap the payload.
    final body = _mapAt(json, const ['data', 'hadith', 'result', 'hadiths']) ??
        json;

    final arabic = _stringAt(body, const [
      'arabic',
      'arab',
      'hadith_arabic',
      'hadithArabic',
      'text_ar',
      'arabicText',
      'body_ar',
    ]);
    final english = _stringAt(body, const [
      'english',
      'hadith_english',
      'hadithEnglish',
      'text_en',
      'englishText',
      'translation',
      'body',
      'text',
    ]);
    final narrator = _stringAt(body, const [
      'narrator',
      'narrated_by',
      'narratedBy',
      'reporter',
    ]);
    final grade = _stringAt(body, const [
      'grade',
      'status',
      'authenticity',
      'grades',
      'hadith_grade',
    ]);
    final bookName = _stringAt(body, const [
      'book',
      'book_name',
      'bookName',
      'bookSlug',
    ]);
    final chapter = _stringAt(body, const [
      'chapter',
      'chapter_name',
      'chapterName',
      'section',
      'title',
    ]);

    if ((arabic == null || arabic.isEmpty) &&
        (english == null || english.isEmpty)) {
      return null;
    }

    return HadithRecord(
      collection: collection,
      number: number,
      arabic: arabic,
      english: english,
      narrator: narrator,
      grade: grade,
      bookName: bookName,
      chapter: chapter,
      origin: origin,
      fetchedAt: DateTime.now(),
    );
  }

  static Map<String, dynamic>? _mapAt(
      Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) return value;
      if (value is List && value.isNotEmpty && value.first is Map) {
        return (value.first as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  static String? _stringAt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      // Some providers nest the grade as [{grade: 'Sahih', scholar: '…'}].
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
        if (first is Map) {
          for (final inner in const ['grade', 'name', 'text', 'body']) {
            final v = first[inner];
            if (v is String && v.trim().isNotEmpty) return v.trim();
          }
        }
      }
      if (value is Map) {
        for (final inner in const ['text', 'body', 'name', 'value']) {
          final v = value[inner];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    }
    return null;
  }
}
