/// Qur'an → SharedContent mapper.
///
/// Turns an [Ayah] (plus its [Surah], when available) into the light
/// [SharedContent] snapshot that Halaqa and Al-Minbar store and render. Like the
/// Discover mappers, every field here is copied straight from already-shipped,
/// verified data — the ayah's own Arabic and translation and its exact
/// surah:ayah reference — so a shared card never invents or paraphrases scripture.
///
/// The [surah] is optional so callers that only know the surah number can still
/// build a valid snapshot; a [fallbackName] covers the rare case where the surah
/// list hasn't loaded yet.
library;

import '../../../shared/models/ayah.dart';
import '../../../shared/models/shared_content.dart';
import '../../../shared/models/surah.dart';

extension AyahShareX on Ayah {
  SharedContent toSharedContent({Surah? surah, String? fallbackName}) {
    final name = (surah?.englishName.trim().isNotEmpty ?? false)
        ? surah!.englishName
        : (fallbackName?.trim().isNotEmpty ?? false)
            ? fallbackName!
            : 'Surah $surahNumber';

    // Detail line after the citation: prefer the surah's meaning
    // (e.g. "The Opening"), else where it was revealed, else nothing.
    final translated = surah?.translatedName.trim() ?? '';
    final place = surah?.revelationPlace.displayName ?? '';
    final detail = translated.isNotEmpty
        ? translated
        : (place.isNotEmpty ? place : null);

    return SharedContent(
      contentType: ContentType.quran,
      contentId: key, // "2:255"
      title: '$name · Ayah $ayahNumber',
      titleArabic: arabicText,
      excerpt: translation,
      citationSource: 'Qur\'an $surahNumber:$ayahNumber',
      citationDetail: detail,
      routePath: '/quran/$surahNumber',
    );
  }
}
