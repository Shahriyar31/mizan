/// WORD-BY-WORD ANALYSIS — the Words layer's content source.
///
/// The Words layer (`layer_screen.dart`, storage index 0) has always rendered a
/// hand-written `words` string out of [LayerData], and that string exists for
/// al-Fātihah and nothing else. Every other ayah in the Qur'an showed
/// "Content for this ayah is being prepared." — 6,229 of 6,236 ayat.
///
/// UmmahAPI's `/api/quran/words` endpoint closes that gap: it is per-word
/// morphology for the whole Qur'an, which is exactly the layer's subject.
///
/// ── Why the field lookups are so forgiving ────────────────────────────
/// The documentation gives paths, not schemas. Rather than guess one spelling of
/// "transliteration" and render a column of blanks when the guess is wrong,
/// every plausible spelling is tried. The one genuinely ambiguous field is
/// `text`, which is the Arabic in some payloads and the English in others — so
/// it is never read positionally, only after checking whether it actually
/// contains Arabic letters. See [_looksArabic].
///
/// ── Request shape ─────────────────────────────────────────────────────
/// `/api/quran/words/{surah}/{ayah}` first. If that answers with nothing, the
/// whole surah is fetched once from `/api/quran/words/{surah}` and filtered
/// locally — which costs one larger response but then serves every remaining
/// ayah of that surah from cache with no request at all.
///
/// Word data never changes, so both are cached with [CachePolicy.immutable].
library;

import '../../../core/network/ummah_api_client.dart';
import '../../../core/utils/logger.dart';

/// One word of an ayah, with whatever the source knows about it.
///
/// Every field except [arabic] may be empty: the layer renders what is present
/// rather than requiring a complete row, because a word with Arabic and a
/// meaning is already useful even with no grammar tag.
class QuranWord {
  const QuranWord({
    required this.position,
    required this.arabic,
    this.transliteration = '',
    this.translation = '',
    this.root = '',
    this.grammar = '',
  });

  /// 1-based position in the ayah, used only for ordering.
  final int position;

  final String arabic;
  final String transliteration;

  /// The word's meaning in English.
  final String translation;

  /// The triliteral root, when the source supplies one.
  final String root;

  /// Part of speech / morphology tag, when the source supplies one.
  final String grammar;

  /// Whether this word carries anything worth revealing on tap.
  bool get hasMeaning =>
      translation.isNotEmpty || transliteration.isNotEmpty || root.isNotEmpty;

  /// The single line shown under the Arabic once revealed.
  String get gloss {
    if (translation.isNotEmpty) return translation;
    if (transliteration.isNotEmpty) return transliteration;
    return root;
  }

  /// The dim line under the gloss — root and grammar, whichever exist.
  String get detail {
    final parts = <String>[
      if (root.isNotEmpty) 'root $root',
      if (grammar.isNotEmpty) grammar,
    ];
    return parts.join(' · ');
  }
}

class WordAnalysisRepository {
  WordAnalysisRepository();

  static final WordAnalysisRepository instance = WordAnalysisRepository();

  static const String _tag = 'WordAnalysis';
  static const String basePath = '/api/quran/words';

  /// Surah word lists already resolved this session, so reading straight through
  /// a surah does not re-parse the same payload once per ayah. A null value is a
  /// remembered miss — the surah has no word data, so it is not asked for again.
  final Map<int, List<_AyahWord>?> _surahCache = {};

  /// The words of one ayah, or an empty list when the source has none.
  ///
  /// Never throws: the Words layer falls back to its curated string, and a
  /// failed lookup must not replace a working screen with an error.
  Future<List<QuranWord>> forAyah(int surahNumber, int ayahNumber) async {
    try {
      final rows = await UmmahApiClient.instance.fetchList(
        '$basePath/$surahNumber/$ayahNumber',
        maxAge: CachePolicy.immutable,
        nestedKeys: const ['words', 'word', 'tokens', 'segments', 'verse'],
      );
      final words = _parse(rows);
      if (words.isNotEmpty) return words;
    } on UmmahApiException catch (e) {
      AppLogger.warning('Words unavailable for $surahNumber:$ayahNumber ($e)',
          tag: _tag);
    } catch (e) {
      AppLogger.error('Words parse failed for $surahNumber:$ayahNumber',
          error: e, tag: _tag);
    }

    // One request for the surah, then every ayah of it is free.
    final surah = await _forSurah(surahNumber);
    if (surah == null) return const [];
    return surah.where((w) => w.ayahNumber == ayahNumber).map((w) => w.word).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<List<_AyahWord>?> _forSurah(int surahNumber) async {
    if (_surahCache.containsKey(surahNumber)) return _surahCache[surahNumber];
    try {
      final rows = await UmmahApiClient.instance.fetchList(
        '$basePath/$surahNumber',
        maxAge: CachePolicy.immutable,
        nestedKeys: const ['words', 'verses', 'ayahs', 'ayat'],
      );
      final flat = _flatten(rows);
      return _surahCache[surahNumber] = flat.isEmpty ? null : flat;
    } on UmmahApiException catch (e) {
      AppLogger.warning('Surah words unavailable for $surahNumber ($e)', tag: _tag);
      return _surahCache[surahNumber] = null;
    } catch (e) {
      AppLogger.error('Surah words parse failed for $surahNumber',
          error: e, tag: _tag);
      return _surahCache[surahNumber] = null;
    }
  }

  /// A surah payload is either a flat list of words each carrying an ayah
  /// number, or a list of ayah objects each carrying a list of words. Both are
  /// handled, because which one arrives is not knowable from the documentation.
  static List<_AyahWord> _flatten(List<Map<String, dynamic>> rows) {
    final out = <_AyahWord>[];

    for (final row in rows) {
      final ayah = UmmahApiClient.intAt(row, const [
            'ayah',
            'ayah_number',
            'verse',
            'verse_number',
            'number',
          ]) ??
          0;

      final nested = UmmahApiClient.listFrom(row,
          nestedKeys: const ['words', 'word', 'tokens', 'segments']);

      if (nested.isNotEmpty) {
        var position = 0;
        for (final wordRow in nested) {
          final word = _wordFrom(wordRow, ++position);
          if (word != null) out.add(_AyahWord(ayah, word));
        }
        continue;
      }

      final word = _wordFrom(row, out.length + 1);
      if (word != null) out.add(_AyahWord(ayah, word));
    }

    return out;
  }

  static List<QuranWord> _parse(List<Map<String, dynamic>> rows) {
    // A single-element response whose one element holds the word list.
    if (rows.length == 1) {
      final nested = UmmahApiClient.listFrom(rows.first,
          nestedKeys: const ['words', 'word', 'tokens', 'segments']);
      if (nested.isNotEmpty) return _parse(nested);
    }

    final out = <QuranWord>[];
    for (final row in rows) {
      final word = _wordFrom(row, out.length + 1);
      if (word != null) out.add(word);
    }
    out.sort((a, b) => a.position.compareTo(b.position));
    return out;
  }

  static QuranWord? _wordFrom(Map<String, dynamic> row, int fallbackPosition) {
    var arabic = UmmahApiClient.stringAt(row, const [
          'arabic',
          'arabic_text',
          'text_uthmani',
          'uthmani',
          'text_arabic',
          'ar',
          'word',
          'word_arabic',
        ]) ??
        '';

    var translation = UmmahApiClient.stringAt(row, const [
          'translation',
          'english',
          'en',
          'meaning',
          'translation_en',
          'text_translation',
        ]) ??
        '';

    // `text` is the Arabic in some payloads and the English in others, so it is
    // only read once its script has been checked.
    final ambiguous = UmmahApiClient.stringAt(row, const ['text', 'value']) ?? '';
    if (ambiguous.isNotEmpty) {
      if (arabic.isEmpty && _looksArabic(ambiguous)) {
        arabic = ambiguous;
      } else if (translation.isEmpty && !_looksArabic(ambiguous)) {
        translation = ambiguous;
      }
    }

    if (arabic.isEmpty) return null;

    return QuranWord(
      position: UmmahApiClient.intAt(row, const [
            'position',
            'word_number',
            'index',
            'order',
            'char_type_position',
          ]) ??
          fallbackPosition,
      arabic: arabic,
      transliteration: UmmahApiClient.stringAt(row, const [
            'transliteration',
            'translit',
            'romanization',
            'romanized',
          ]) ??
          '',
      translation: translation,
      root: UmmahApiClient.stringAt(row, const [
            'root',
            'root_word',
            'rootWord',
            'root_arabic',
          ]) ??
          '',
      grammar: UmmahApiClient.stringAt(row, const [
            'grammar',
            'part_of_speech',
            'pos',
            'morphology',
            'tag',
            'grammar_description',
          ]) ??
          '',
    );
  }

  /// True when the string contains at least one Arabic letter. Used to decide
  /// which side of the word a `text` field belongs on.
  static bool _looksArabic(String value) {
    for (final rune in value.runes) {
      // Arabic (0600–06FF) and Arabic Presentation Forms (FB50–FDFF, FE70–FEFF).
      if ((rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0xFB50 && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        return true;
      }
    }
    return false;
  }
}

/// A word together with the ayah it belongs to — only needed while filtering a
/// surah payload down to one ayah.
class _AyahWord {
  const _AyahWord(this.ayahNumber, this.word);
  final int ayahNumber;
  final QuranWord word;
}
