/// AyahReciter — one voice with a complete ayah-by-ayah recitation.
///
/// Split out of `ayah_audio_provider.dart` so that [AudioRepository] can build
/// reciters without importing the player, and re-exported from there so every
/// existing `import 'ayah_audio_provider.dart'` keeps working unchanged.
///
/// ── Two kinds of reciter ──────────────────────────────────────────────
/// **Pattern reciters** know their own URLs. everyayah.com has a completely
/// deterministic layout:
///
///     https://everyayah.com/data/<folder>/<surah:3><ayah:3>.mp3
///     e.g.  .../data/Alafasy_128kbps/002255.mp3   → Al-Baqarah 255
///
/// No index request, no key, no parsing — which is why playback can begin on the
/// first tap. The one thing that can go wrong is a wrong [folder]: that is a 404
/// on every ayah for that voice, surfacing as this player's error state naming
/// the reciter rather than as silence.
///
/// **Lookup reciters** come from UmmahAPI's catalogue with no usable pattern, so
/// [urlFor] returns null and [AudioRepository] asks the API for the URL. They pay
/// one request on first use and nothing after, because the answer is cached.
///
/// [id] is a stable key, never a list index, so the catalogue can grow or be
/// reordered without silently changing somebody's saved reciter.
library;

class AyahReciter {
  const AyahReciter({
    required this.id,
    required this.name,
    required this.folder,
    this.remoteId,
    this.urlTemplate,
  });

  final String id;
  final String name;

  /// everyayah.com directory. Empty for reciters that did not come from there.
  final String folder;

  /// This reciter's id in UmmahAPI's own catalogue, used when a URL has to be
  /// looked up. Null for the bundled everyayah voices.
  final String? remoteId;

  /// A URL pattern supplied by the catalogue. Placeholders: `{surah}`, `{ayah}`
  /// for plain numbers and `{surah3}`, `{ayah3}` for the zero-padded form.
  final String? urlTemplate;

  /// True when a URL can be computed on the device with no request.
  bool get hasPattern => urlTemplate != null || folder.isNotEmpty;

  /// The URL for one ayah, or null when it has to be looked up.
  String? urlFor(int surahNumber, int ayahNumber) {
    final s3 = surahNumber.toString().padLeft(3, '0');
    final a3 = ayahNumber.toString().padLeft(3, '0');

    final template = urlTemplate;
    if (template != null) {
      return template
          .replaceAll('{surah3}', s3)
          .replaceAll('{ayah3}', a3)
          .replaceAll('{surah:3}', s3)
          .replaceAll('{ayah:3}', a3)
          .replaceAll('{surah}', surahNumber.toString())
          .replaceAll('{ayah}', ayahNumber.toString());
    }

    if (folder.isEmpty) return null;
    return 'https://everyayah.com/data/$folder/$s3$a3.mp3';
  }
}

/// The bundled reciters. Always offered, whatever the network is doing — see
/// [AudioRepository] for why the remote catalogue only ever adds to this list.
const List<AyahReciter> kAyahReciters = [
  AyahReciter(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    folder: 'Alafasy_128kbps',
  ),
  AyahReciter(
    id: 'husary',
    name: 'Mahmoud Khalil Al-Husary',
    folder: 'Husary_128kbps',
  ),
  AyahReciter(
    id: 'abdulbasit',
    name: 'Abdul Basit (Murattal)',
    folder: 'Abdul_Basit_Murattal_192kbps',
  ),
  AyahReciter(
    id: 'minshawy',
    name: 'Muhammad Siddiq Al-Minshawi',
    folder: 'Minshawy_Murattal_128kbps',
  ),
  AyahReciter(
    id: 'sudais',
    name: 'Abdurrahman As-Sudais',
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
  ),
];
