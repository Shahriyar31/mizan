/// AudioRepository — where a recitation URL comes from.
///
/// The brief asks for UmmahAPI audio with MP3Quran/everyayah kept as a fallback
/// "until migration is verified". This is that, made literal: the app's five
/// hand-written reciters stay exactly as they are and are always offered, and
/// anything UmmahAPI reports is added *after* them. A bad response, a renamed
/// field or a dead network can therefore never take a working reciter away —
/// the worst case is the app behaves like it did before.
///
/// ── Why a repository at all ───────────────────────────────────────────
/// The existing URLs are guessed. `kAyahReciters` hardcodes strings like
/// `Abdul_Basit_Murattal_192kbps`, which are everyayah.com directory names
/// nobody has verified; a typo in one is a 404 on every ayah for that reciter and
/// there is no way to find out except by listening. What UmmahAPI genuinely buys
/// here is *verified* reciter identity and URLs that came from a catalogue rather
/// than from memory — which matters more than any audio-quality difference,
/// because the quality problem was never the source (see [RecitationCache]).
///
/// ── Two ways to get a URL ─────────────────────────────────────────────
///  1. **A pattern**, computed on the device with no request. This is how the
///     everyayah reciters work and it is why playback can start on the first tap.
///  2. **A lookup**, `/api/quran/audio/{surah}/{ayah}`, for reciters that arrive
///     without a usable pattern. Slower on the first ayah of a session and then
///     free, because the response is cached by [UmmahApiClient] and the audio
///     itself by [RecitationCache].
///
/// Pattern reciters never hit the network for a URL, so the fast path stays fast.
library;

import '../../../core/network/ummah_api_client.dart';
import '../../../core/utils/logger.dart';
import '../domain/ayah_audio_provider.dart';

class AudioRepository {
  AudioRepository({UmmahApiClient? client})
      : _client = client ?? UmmahApiClient.instance;

  static final AudioRepository instance = AudioRepository();

  static const String _tag = 'AudioRepository';

  /// Catalogue of reciters with per-ayah audio.
  static const String recitersPath = '/api/quran/reciters';

  /// Per-ayah audio for one ayah across reciters.
  static const String audioPath = '/api/quran/audio';

  final UmmahApiClient _client;

  List<AyahReciter>? _catalogue;

  // ── Reciters ────────────────────────────────────────────────────────

  /// Every reciter the app can offer: the five verified local ones first, then
  /// whatever UmmahAPI adds. Falls back to the local list alone on any failure,
  /// and the result is memoised for the session.
  Future<List<AyahReciter>> reciters() async {
    final held = _catalogue;
    if (held != null) return held;

    final merged = <AyahReciter>[...kAyahReciters];
    final seenIds = {for (final r in merged) r.id};
    final seenNames = {for (final r in merged) _normalise(r.name)};

    try {
      final rows = await _client.fetchList(
        recitersPath,
        maxAge: CachePolicy.catalogue,
        nestedKeys: const ['reciters', 'items', 'list', 'data'],
      );
      for (final row in rows) {
        final reciter = _reciterFrom(row);
        if (reciter == null) continue;
        // Same reciter under a different id is still the same reciter — showing
        // Alafasy twice would look like a bug, so name is deduplicated too.
        if (seenIds.contains(reciter.id)) continue;
        if (seenNames.contains(_normalise(reciter.name))) continue;
        seenIds.add(reciter.id);
        seenNames.add(_normalise(reciter.name));
        merged.add(reciter);
      }
    } catch (e) {
      AppLogger.info('reciter catalogue unavailable — using bundled list',
          tag: _tag);
    }

    _catalogue = merged;
    return merged;
  }

  /// Builds a reciter from one catalogue row, or null if the row cannot produce
  /// a playable URL. Tolerant about field names on purpose — the documentation
  /// lists paths, not schemas.
  static AyahReciter? _reciterFrom(Map<String, dynamic> row) {
    final id = UmmahApiClient.stringAt(row, const [
      'id',
      'identifier',
      'slug',
      'key',
      'reciter_id',
      'reciterId',
    ]);
    final name = UmmahApiClient.stringAt(row, const [
      'name',
      'english_name',
      'englishName',
      'title',
      'reciter',
      'reciter_name',
      'arabic_name',
    ]);
    if (id == null || name == null) return null;

    final template = UmmahApiClient.stringAt(row, const [
      'url_template',
      'urlTemplate',
      'template',
      'audio_url_template',
      'pattern',
    ]);
    final base = UmmahApiClient.stringAt(row, const [
      'base_url',
      'baseUrl',
      'server',
      'audio_url',
      'audioUrl',
      'url',
      'folder',
      'path',
    ]);

    return AyahReciter(
      id: 'ummah_$id',
      name: name,
      // Not an everyayah folder, so the pattern is never guessed from it.
      folder: '',
      remoteId: id,
      urlTemplate: template ?? _templateFromBase(base),
    );
  }

  /// Turns a bare directory or base URL into a pattern.
  ///
  /// Only done when the base clearly *is* a directory — a URL that already ends
  /// in a file name is a single file, not a per-ayah pattern, and guessing would
  /// produce 404s. When this returns null the reciter falls back to the lookup
  /// path, which is slower but correct.
  static String? _templateFromBase(String? base) {
    if (base == null || base.isEmpty) return null;
    if (!base.startsWith('http')) return null;
    if (base.toLowerCase().endsWith('.mp3')) return null;
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed/{surah3}{ayah3}.mp3';
  }

  // ── URLs ────────────────────────────────────────────────────────────

  /// The URL for one ayah in one reciter, or null when there is none.
  ///
  /// Pattern reciters answer without a request. Lookup reciters ask the API once
  /// per ayah and are cached from then on.
  Future<String?> urlFor(AyahReciter reciter, int surahNumber, int ayahNumber) async {
    final local = reciter.urlFor(surahNumber, ayahNumber);
    if (local != null) return local;

    final remoteId = reciter.remoteId;
    if (remoteId == null) return null;

    try {
      final data = await _client.fetch('$audioPath/$surahNumber/$ayahNumber');
      final found = _urlFrom(data, remoteId, ayahNumber);
      if (found != null) return found;
    } catch (e) {
      AppLogger.info('audio lookup failed for $surahNumber:$ayahNumber', tag: _tag);
    }

    // The surah-level payload sometimes carries every ayah; worth one try
    // before telling the listener there is nothing.
    try {
      final data = await _client.fetch('$audioPath/$surahNumber');
      return _urlFrom(data, remoteId, ayahNumber);
    } catch (_) {
      return null;
    }
  }

  /// Digs an audio URL out of whatever arrived.
  ///
  /// Handles the three shapes these endpoints plausibly use: a map keyed by
  /// reciter, a list of `{reciter, url}` rows, and a single row for one reciter.
  static String? _urlFrom(Object? data, String remoteId, int ayahNumber) {
    if (data is Map) {
      final map = data.cast<String, dynamic>();

      // Keyed directly by reciter id.
      final direct = map[remoteId];
      if (direct is String && direct.startsWith('http')) return direct;
      if (direct is Map) {
        final url = _urlField(direct.cast<String, dynamic>());
        if (url != null) return url;
      }

      // A single-reciter payload.
      final own = _urlField(map);
      if (own != null && _matchesAyah(map, ayahNumber)) return own;

      // Anything nested one level down.
      for (final row in UmmahApiClient.listFrom(map,
          nestedKeys: const ['audio', 'files', 'ayahs', 'verses', 'reciters'])) {
        final url = _rowUrl(row, remoteId, ayahNumber);
        if (url != null) return url;
      }
      if (own != null) return own;
      return null;
    }

    for (final row in UmmahApiClient.listFrom(data)) {
      final url = _rowUrl(row, remoteId, ayahNumber);
      if (url != null) return url;
    }
    return null;
  }

  static String? _rowUrl(Map<String, dynamic> row, String remoteId, int ayahNumber) {
    final rowReciter = UmmahApiClient.stringAt(row, const [
      'reciter',
      'reciter_id',
      'reciterId',
      'identifier',
      'id',
      'slug',
    ]);
    if (rowReciter != null && rowReciter != remoteId) return null;
    if (!_matchesAyah(row, ayahNumber)) return null;
    return _urlField(row);
  }

  /// True when the row is for this ayah, or says nothing about which ayah it is.
  /// Silence is treated as a match because a per-ayah endpoint's rows are often
  /// implicitly about the requested ayah.
  static bool _matchesAyah(Map<String, dynamic> row, int ayahNumber) {
    final rowAyah = UmmahApiClient.intAt(
        row, const ['ayah', 'ayah_number', 'ayahNumber', 'verse', 'number']);
    return rowAyah == null || rowAyah == ayahNumber;
  }

  static String? _urlField(Map<String, dynamic> row) {
    final url = UmmahApiClient.stringAt(row, const [
      'url',
      'audio',
      'audio_url',
      'audioUrl',
      'file',
      'file_url',
      'link',
      'mp3',
      'src',
    ]);
    if (url == null || !url.startsWith('http')) return null;
    return url;
  }

  static String _normalise(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
}
