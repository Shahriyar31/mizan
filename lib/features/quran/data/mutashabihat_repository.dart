/// MUTASHĀBIHĀT — the verses of the Qur'an that resemble one another.
///
/// *Mutashābihāt* are ayat that are identical, near-identical, or share a
/// distinctive phrase. Knowing them is a classical discipline in its own right:
/// it is what stops a memoriser jumping from one sūrah into another mid-recital
/// at a phrase they share, and it is how the Qur'an's internal cross-references
/// become visible.
///
/// ── Where this appears ────────────────────────────────────────────────
/// As a sixth layer on the ayah, not a section of its own. The brief was explicit
/// — "Do not create a separate section" — and it is also the right call: a
/// similar verse is a fact *about this ayah*, so it belongs beside the ayah's
/// words and commentary rather than in a browser somewhere else.
///
/// ── Storage index 5, display position 5 of 6 ───────────────────────────
/// The new layer takes storage index 5 and is *shown* between Isnad and
/// Reflection. It is deliberately not renumbered into position 4, because
/// `layer_unlocks` rows in every existing install already mean
/// "4 = Reflection" — renumbering would silently reinterpret saved history.
/// See [LayerMeta.displayOrder].
///
/// ── Navigation ────────────────────────────────────────────────────────
/// Tapping a similar verse closes the layer sheet and routes to the existing
/// reader at that ayah (`/quran/{surah}?ayah={ayah}`). No second reader, no
/// duplicate route — the one the app already has.
library;

import '../../../core/network/ummah_api_client.dart';
import '../../../core/utils/logger.dart';

/// A verse that resembles the one being read.
class SimilarVerse {
  const SimilarVerse({
    required this.surahNumber,
    required this.ayahNumber,
    this.surahName = '',
    this.arabic = '',
    this.translation = '',
    this.matchType = '',
    this.sharedPhrase = '',
  });

  final int surahNumber;
  final int ayahNumber;

  /// The sūrah's name when the source supplies it. Empty is fine — the numeric
  /// reference below is unambiguous on its own.
  final String surahName;

  final String arabic;
  final String translation;

  /// How the two verses relate: identical, similar, or a shared phrase. Free
  /// text from the source, normalised only for casing.
  final String matchType;

  /// The words the two verses have in common, when the source isolates them.
  final String sharedPhrase;

  /// `2:255` — the form every Qur'an reference takes.
  String get reference => '$surahNumber:$ayahNumber';

  /// `Al-Baqarah 2:255`, or just `2:255` when the name is unknown.
  String get label => surahName.isEmpty ? reference : '$surahName $reference';

  /// The route into the existing reader.
  String get location => '/quran/$surahNumber?ayah=$ayahNumber';

  bool get isValid =>
      surahNumber >= 1 && surahNumber <= 114 && ayahNumber >= 1;
}

class MutashabihatRepository {
  MutashabihatRepository();

  static final MutashabihatRepository instance = MutashabihatRepository();

  static const String _tag = 'Mutashabihat';
  static const String basePath = '/api/quran/mutashabihat';

  /// Surah-level payloads already resolved this session. A null value is a
  /// remembered miss.
  final Map<int, List<_SurahEntry>?> _surahCache = {};

  /// Verses similar to this one, or an empty list when there are none.
  ///
  /// Most ayat have no mutashābihāt at all, so an empty result is the normal
  /// case and not an error. Never throws.
  Future<List<SimilarVerse>> forAyah(int surahNumber, int ayahNumber) async {
    try {
      final data = await UmmahApiClient.instance.fetch(
        '$basePath/$surahNumber/$ayahNumber',
        maxAge: CachePolicy.immutable,
      );
      final found = _parse(data, surahNumber, ayahNumber);
      if (found.isNotEmpty) return found;
    } on UmmahApiException catch (e) {
      AppLogger.warning(
          'Mutashabihat unavailable for $surahNumber:$ayahNumber ($e)',
          tag: _tag);
    } catch (e) {
      AppLogger.error('Mutashabihat parse failed for $surahNumber:$ayahNumber',
          error: e, tag: _tag);
    }

    final surah = await _forSurah(surahNumber);
    if (surah == null) return const [];
    for (final entry in surah) {
      if (entry.ayahNumber == ayahNumber) return entry.similar;
    }
    return const [];
  }

  Future<List<_SurahEntry>?> _forSurah(int surahNumber) async {
    if (_surahCache.containsKey(surahNumber)) return _surahCache[surahNumber];
    try {
      final rows = await UmmahApiClient.instance.fetchList(
        '$basePath/$surahNumber',
        maxAge: CachePolicy.immutable,
        nestedKeys: const ['mutashabihat', 'verses', 'ayahs', 'groups'],
      );
      final entries = <_SurahEntry>[];
      for (final row in rows) {
        final ayah = UmmahApiClient.intAt(row, const [
          'ayah',
          'ayah_number',
          'verse',
          'verse_number',
          'number',
        ]);
        if (ayah == null) continue;
        final similar = _parse(row, surahNumber, ayah);
        if (similar.isEmpty) continue;
        entries.add(_SurahEntry(ayah, similar));
      }
      return _surahCache[surahNumber] = entries.isEmpty ? null : entries;
    } on UmmahApiException catch (e) {
      AppLogger.warning('Surah mutashabihat unavailable for $surahNumber ($e)',
          tag: _tag);
      return _surahCache[surahNumber] = null;
    } catch (e) {
      AppLogger.error('Surah mutashabihat parse failed for $surahNumber',
          error: e, tag: _tag);
      return _surahCache[surahNumber] = null;
    }
  }

  /// Pulls similar verses out of whatever arrived, dropping the queried ayah
  /// itself — these payloads describe a *group* of resembling verses, and the
  /// verse you are reading is a member of its own group.
  static List<SimilarVerse> _parse(
    Object? data,
    int surahNumber,
    int ayahNumber,
  ) {
    final rows = UmmahApiClient.listFrom(data, nestedKeys: const [
      'similar',
      'similar_verses',
      'matches',
      'related',
      'verses',
      'mutashabihat',
      'ayahs',
      'group',
    ]);

    // Inherited from the wrapper when the individual rows omit it — a group
    // payload often states the relationship once for the whole group.
    final groupType = data is Map
        ? (UmmahApiClient.stringAt(data.cast<String, dynamic>(),
                const ['type', 'match_type', 'similarity', 'relation']) ??
            '')
        : '';
    final groupPhrase = data is Map
        ? (UmmahApiClient.stringAt(data.cast<String, dynamic>(),
                const ['phrase', 'shared', 'shared_text', 'common']) ??
            '')
        : '';

    final out = <SimilarVerse>[];
    final seen = <String>{'$surahNumber:$ayahNumber'};

    for (final row in rows) {
      final verse = _verseFrom(row, groupType, groupPhrase);
      if (verse == null || !verse.isValid) continue;
      if (!seen.add(verse.reference)) continue;
      out.add(verse);
    }

    return out;
  }

  static SimilarVerse? _verseFrom(
    Map<String, dynamic> row,
    String groupType,
    String groupPhrase,
  ) {
    var surah = UmmahApiClient.intAt(row, const [
      'surah',
      'surah_number',
      'chapter',
      'chapter_number',
      'sura',
    ]);
    var ayah = UmmahApiClient.intAt(row, const [
      'ayah',
      'ayah_number',
      'verse',
      'verse_number',
      'number',
      'numberInSurah',
    ]);

    // Some payloads carry only a combined `"2:255"` reference.
    if (surah == null || ayah == null) {
      final ref = UmmahApiClient.stringAt(row, const [
        'reference',
        'ref',
        'verse_key',
        'key',
        'id',
      ]);
      if (ref != null && ref.contains(':')) {
        final parts = ref.split(':');
        surah ??= int.tryParse(parts[0].trim());
        ayah ??= int.tryParse(parts[1].trim());
      }
    }

    if (surah == null || ayah == null) return null;

    return SimilarVerse(
      surahNumber: surah,
      ayahNumber: ayah,
      surahName: UmmahApiClient.stringAt(row, const [
            'surah_name',
            'surahName',
            'chapter_name',
            'name',
            'surah_english',
          ]) ??
          '',
      arabic: UmmahApiClient.stringAt(row, const [
            'arabic',
            'arabic_text',
            'text_uthmani',
            'text',
            'ar',
          ]) ??
          '',
      translation: UmmahApiClient.stringAt(row, const [
            'translation',
            'english',
            'en',
            'meaning',
          ]) ??
          '',
      matchType: UmmahApiClient.stringAt(row, const [
            'type',
            'match_type',
            'similarity',
            'relation',
            'category',
          ]) ??
          groupType,
      sharedPhrase: UmmahApiClient.stringAt(row, const [
            'phrase',
            'shared',
            'shared_text',
            'common',
            'matched_text',
          ]) ??
          groupPhrase,
    );
  }
}

class _SurahEntry {
  const _SurahEntry(this.ayahNumber, this.similar);
  final int ayahNumber;
  final List<SimilarVerse> similar;
}
