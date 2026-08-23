/// TAFSIR — the Scholars layer's content source.
///
/// The Scholars layer (`layer_screen.dart`, storage index 2) is already where
/// classical commentary renders: it shows a scholar card, a key insight and an
/// Arabic quote, filled from [LayerData.scholars]. That content comes from two
/// bundled sources — a hand-curated set for al-Fātihah and a preprocessed Ibn
/// Kathīr asset — and where neither has anything, the layer shows
/// "Content for this ayah is being prepared."
///
/// This repository adds UmmahAPI's tafsir endpoints behind the same layer. No
/// new screen, no new tab: the existing card gains a row of source chips, and
/// the body below it is whichever source is selected.
///
/// ── The bundled source is a first-class choice, not a fallback ─────────
/// [kBundledTafsir] is always the first entry in [sources] and needs no network
/// at all. That is deliberate: it means the layer works on a plane, and it means
/// a bad response or a renamed field can never take away commentary that was
/// working before this file existed.
///
/// ── Why the source keys are not hardcoded ──────────────────────────────
/// The documentation names three tafāsīr — Ibn Kathīr, Maʿārif al-Qurʾān,
/// al-Muyassar — but not the slugs used in `/api/tafsir/{key}/...`, and a
/// guessed slug produces a 404 rather than a visible mistake. So the catalogue
/// is read from `/api/tafsir`, which is exactly what that endpoint is for, and
/// the keys come back with it. Nothing here invents an identifier.
///
/// ── Citation Lock ─────────────────────────────────────────────────────
/// Every passage carries the name of the tafsīr and its author, and the layer
/// renders them above the text. A passage that arrives without a source name is
/// dropped rather than shown unattributed — an unattributed commentary is
/// exactly what the rule exists to prevent.
library;

import '../../../core/network/ummah_api_client.dart';
import '../../../core/utils/logger.dart';

/// One tafsīr the reader can switch to.
class TafsirSource {
  const TafsirSource({
    required this.key,
    required this.name,
    this.author = '',
    this.era = '',
    this.language = 'en',
    this.isBundled = false,
  });

  /// The identifier used in the request path, or [bundledKey] for the offline
  /// source that needs no request.
  final String key;

  /// Display name of the work, e.g. "Tafsīr Ibn Kathīr".
  final String name;

  /// The author, shown under the name. Empty when the catalogue omits it.
  final String author;

  /// Death date or century, shown beside the author when known.
  final String era;

  final String language;

  /// True for the source that ships inside the app.
  final bool isBundled;

  /// The line under the source name in the scholar card.
  String get attribution {
    final parts = <String>[
      if (author.isNotEmpty) author,
      if (era.isNotEmpty) era,
    ];
    return parts.join(' · ');
  }

  /// The short label used on the switcher chips, so a long formal title does not
  /// push the row off-screen.
  String get shortName {
    const prefixes = ['Tafsir ', 'Tafsīr ', 'Tafseer ', 'Tafsir al-', 'Tafsīr al-'];
    var out = name;
    for (final prefix in prefixes) {
      if (out.toLowerCase().startsWith(prefix.toLowerCase())) {
        out = out.substring(prefix.length);
        break;
      }
    }
    return out.trim().isEmpty ? name : out.trim();
  }
}

/// The identifier of the tafsīr that ships with the app.
const String bundledTafsirKey = 'bundled-ibn-kathir';

/// The app's own preprocessed Ibn Kathīr — always available, never a request.
///
/// Its passages are not produced by this repository: [TafsirRepository.passage]
/// returns null for it, and the layer renders [LayerData.scholars] instead. This
/// entry exists so the bundled commentary appears in the switcher as a peer of
/// the remote ones rather than as an invisible fallback.
const TafsirSource kBundledTafsir = TafsirSource(
  key: bundledTafsirKey,
  name: 'Ibn Kathīr',
  author: 'Ismāʿīl ibn ʿUmar ibn Kathīr',
  era: 'd. 774 AH',
  isBundled: true,
);

/// A single ayah's commentary from one tafsīr.
class TafsirPassage {
  const TafsirPassage({
    required this.sourceKey,
    required this.sourceName,
    required this.text,
    this.arabic = '',
    this.author = '',
  });

  final String sourceKey;

  /// Never empty — a passage without a named source is not constructed. See the
  /// Citation Lock note in the library comment.
  final String sourceName;

  final String text;

  /// The Arabic of the commentary, when the source carries it. Rendered in the
  /// same quote block the layer already has.
  final String arabic;

  final String author;

  bool get isEmpty => text.trim().isEmpty && arabic.trim().isEmpty;
}

class TafsirRepository {
  TafsirRepository();

  static final TafsirRepository instance = TafsirRepository();

  static const String _tag = 'Tafsir';
  static const String basePath = '/api/tafsir';

  List<TafsirSource>? _catalogue;

  /// Every tafsīr on offer: the bundled one first, then whatever the catalogue
  /// adds. Never throws and never returns empty.
  Future<List<TafsirSource>> sources() async {
    final cached = _catalogue;
    if (cached != null) return cached;

    final out = <TafsirSource>[kBundledTafsir];
    final seen = <String>{kBundledTafsir.key};

    try {
      final rows = await UmmahApiClient.instance.fetchList(
        basePath,
        maxAge: CachePolicy.catalogue,
        nestedKeys: const ['tafsirs', 'tafasir', 'sources', 'editions', 'list'],
      );
      for (final row in rows) {
        final source = _sourceFrom(row);
        if (source == null) continue;
        // The catalogue's own Ibn Kathīr is kept — it is a different text from
        // the bundled asset (full commentary rather than a processed summary),
        // and dropping it would hide the fuller one behind the shorter one.
        if (!seen.add(source.key)) continue;
        out.add(source);
      }
    } on UmmahApiException catch (e) {
      AppLogger.warning('Tafsir catalogue unavailable ($e)', tag: _tag);
    } catch (e) {
      AppLogger.error('Tafsir catalogue parse failed', error: e, tag: _tag);
    }

    return _catalogue = out;
  }

  static TafsirSource? _sourceFrom(Map<String, dynamic> row) {
    final key = UmmahApiClient.stringAt(row, const [
      'key',
      'slug',
      'id',
      'identifier',
      'tafsir_id',
      'edition',
    ]);
    final name = UmmahApiClient.stringAt(row, const [
      'name',
      'title',
      'english_name',
      'name_en',
      'tafsir_name',
      'display_name',
    ]);
    if (key == null || name == null) return null;

    return TafsirSource(
      key: key,
      name: name,
      author: UmmahApiClient.stringAt(row, const [
            'author',
            'author_name',
            'scholar',
            'mufassir',
            'writer',
          ]) ??
          '',
      era: UmmahApiClient.stringAt(row, const [
            'era',
            'death',
            'died',
            'century',
            'period',
          ]) ??
          '',
      language: UmmahApiClient.stringAt(row, const [
            'language',
            'lang',
            'language_name',
          ]) ??
          'en',
    );
  }

  /// The commentary on one ayah from one source.
  ///
  /// Null means "this source has nothing for this ayah" — including for
  /// [kBundledTafsir], whose text the layer already holds. Never throws.
  Future<TafsirPassage?> passage(
    TafsirSource source,
    int surahNumber,
    int ayahNumber,
  ) async {
    if (source.isBundled) return null;

    // The ayah endpoint first. If it answers with nothing, the surah is fetched
    // once and the ayah picked out of it — one larger response that then serves
    // the rest of the surah from cache.
    final direct = await _fetchPassage(
      '$basePath/${source.key}/surah/$surahNumber/ayah/$ayahNumber',
      source,
      ayahNumber,
      matchAyah: false,
    );
    if (direct != null) return direct;

    return _fetchPassage(
      '$basePath/${source.key}/surah/$surahNumber',
      source,
      ayahNumber,
      matchAyah: true,
    );
  }

  Future<TafsirPassage?> _fetchPassage(
    String path,
    TafsirSource source,
    int ayahNumber, {
    required bool matchAyah,
  }) async {
    try {
      final data = await UmmahApiClient.instance
          .fetch(path, maxAge: CachePolicy.immutable);
      if (data == null) return null;

      if (data is Map) {
        final map = data.cast<String, dynamic>();
        // A surah response wrapping its ayat one level down.
        final rows = UmmahApiClient.listFrom(map,
            nestedKeys: const ['ayahs', 'ayat', 'verses', 'tafsirs', 'text']);
        if (rows.isNotEmpty) {
          return _pick(rows, source, ayahNumber, matchAyah: matchAyah);
        }
        return _passageFrom(map, source);
      }

      if (data is List) {
        final rows = UmmahApiClient.listFrom(data);
        if (rows.isNotEmpty) {
          return _pick(rows, source, ayahNumber, matchAyah: matchAyah);
        }
      }

      return null;
    } on UmmahApiException catch (e) {
      AppLogger.warning('Tafsir unavailable: ${source.key} ($e)', tag: _tag);
      return null;
    } catch (e) {
      AppLogger.error('Tafsir parse failed for ${source.key}',
          error: e, tag: _tag);
      return null;
    }
  }

  static TafsirPassage? _pick(
    List<Map<String, dynamic>> rows,
    TafsirSource source,
    int ayahNumber, {
    required bool matchAyah,
  }) {
    for (final row in rows) {
      if (matchAyah) {
        final n = UmmahApiClient.intAt(row, const [
          'ayah',
          'ayah_number',
          'verse',
          'verse_number',
          'number',
          'numberInSurah',
        ]);
        if (n != null && n != ayahNumber) continue;
        if (n == null && rows.length > 1) continue;
      }
      final passage = _passageFrom(row, source);
      if (passage != null) return passage;
    }
    return null;
  }

  static TafsirPassage? _passageFrom(
    Map<String, dynamic> row,
    TafsirSource source,
  ) {
    final text = UmmahApiClient.stringAt(row, const [
          'text',
          'tafsir',
          'commentary',
          'content',
          'body',
          'translation',
          'english',
          'description',
        ]) ??
        '';

    final arabic = UmmahApiClient.stringAt(row, const [
          'arabic',
          'arabic_text',
          'text_arabic',
          'tafsir_arabic',
          'ar',
        ]) ??
        '';

    if (text.trim().isEmpty && arabic.trim().isEmpty) return null;

    // The response's own name wins over the catalogue's, since a per-ayah
    // payload sometimes carries a more precise edition title. Falling back to
    // the catalogue name is what guarantees the attribution is never empty.
    final name = UmmahApiClient.stringAt(row, const [
          'tafsir_name',
          'source',
          'edition',
          'name',
        ]) ??
        source.name;

    return TafsirPassage(
      sourceKey: source.key,
      sourceName: name,
      text: text,
      arabic: arabic,
      author: UmmahApiClient.stringAt(row, const ['author', 'scholar']) ??
          source.author,
    );
  }
}
