/// TRANSLATION — which rendering of the meaning is shown under each ayah.
///
/// The ids are Quran.com "resource" ids, passed straight through as
/// `?translations=<id>` by [QuranApiService.getAyatForSurah]. Two consequences
/// worth knowing before adding to [kQuranTranslations]:
///
///   • An id that Quran.com has retired comes back as an empty `translations`
///     array, which shows as an ayah with Arabic and no English rather than as
///     an error. That has already happened once in this app: Saheeh
///     International (id 20) was removed from the API, which is why the English
///     default is Abdul Haleem. So every id in this list is one that has been
///     seen working, and new ones get checked on a device before they ship.
///   • The Arabic, the word-by-word data and the transliteration do not change
///     with this setting — only the translation line does. Nothing about the
///     revelation is being switched; the translator is.
///
/// Machine translation is never an option here, and never will be: each entry is
/// a named human translator's published work, which is what makes it quotable.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';

class QuranTranslation {
  const QuranTranslation({
    required this.id,
    required this.translator,
    required this.language,
    this.note,
  });

  /// Quran.com resource id. See the library comment before changing one.
  final int id;

  /// The named human translator — this is the attribution, so it is required.
  final String translator;

  final String language;

  /// A short line about the translation's character, shown under the name.
  final String? note;

  /// "Abdul Haleem · English" — the Settings subtitle in the design.
  String get label => '$translator · $language';
}

const List<QuranTranslation> kQuranTranslations = [
  QuranTranslation(
    id: ApiConstants.translationEnglish,
    translator: 'M. A. S. Abdul Haleem',
    language: 'English',
    note: 'Plain modern English, phrased for reading aloud.',
  ),
  QuranTranslation(
    id: 131,
    translator: 'Dr. Mustafa Khattab',
    language: 'English',
    note: 'The Clear Quran — the most widely used contemporary English text.',
  ),
  QuranTranslation(
    id: ApiConstants.translationBengali,
    translator: 'Muhiuddin Khan',
    language: 'Bengali',
    note: 'বাংলা — the standard Bengali rendering.',
  ),
  QuranTranslation(
    id: ApiConstants.translationHindi,
    translator: 'Fateh Muhammad Jalandhri',
    language: 'Hindi',
    note: 'हिन्दी',
  ),
];

class TranslationNotifier extends StateNotifier<QuranTranslation> {
  TranslationNotifier() : super(kQuranTranslations.first) {
    _load();
  }

  static const _key = 'quran_translation_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_key);
    if (id == null) return;
    for (final t in kQuranTranslations) {
      if (t.id == id) {
        state = t;
        return;
      }
    }
    // A saved id that is no longer offered (list changed between versions)
    // falls back to the default rather than showing ayat with no translation.
  }

  Future<void> select(QuranTranslation translation) async {
    if (translation.id == state.id) return;
    state = translation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, translation.id);
  }
}

/// The chosen translation. [ayatProvider] watches this, so selecting a new one
/// re-fetches every open surah — no manual refresh, no stale English under new
/// Arabic.
final selectedTranslationProvider =
    StateNotifierProvider<TranslationNotifier, QuranTranslation>(
  (ref) => TranslationNotifier(),
);
