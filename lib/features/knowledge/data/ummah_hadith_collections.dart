/// The bridge between *our* collection slugs and UmmahAPI's.
///
/// It exists because the two vocabularies do not line up, and one of the
/// mismatches is dangerous rather than merely inconvenient:
///
///  - Our `nawawi` slug is **Riyad as-Salihin**, an-Nawawi's large anthology.
///    UmmahAPI's tenth collection is **Nawawi's Forty**, a completely different
///    book of forty hadiths. Binding them would make "Riyad as-Salihin 1421"
///    fetch hadith 1421 of a book that has forty, or — worse, if the service
///    wraps or clamps — return an unrelated hadith under a citation that says
///    Riyad as-Salihin. That is a fabricated citation, so [carriesForty] refuses
///    the pairing outright and no amount of alias fuzz can talk it into it.
///
///  - Musnad Ahmad, Sunan ad-Darimi, Bulugh al-Maram and Riyad as-Salihin are
///    cited by our corpus and are not carried by UmmahAPI at all. Those live in
///    [notCarried] and short-circuit *before* any request is made, so a story
///    citing eight Musnad Ahmad hadiths costs zero network calls instead of
///    eight 404s.
///
/// Everything else is resolved by name against the live `/api/hadith/collections`
/// catalogue rather than a hardcoded slug list, because the PDF documents the
/// endpoint but not the spellings it answers with. [resolveFrom] does that
/// matching; [candidatesFor] is the fallback used before the catalogue has been
/// fetched, holding the spellings hadith services actually use.
library;

import '../../../core/knowledge/hadith_ref.dart';
import '../../../core/network/ummah_api_client.dart';

abstract final class UmmahHadithCollections {
  /// Path of the catalogue endpoint.
  static const String collectionsPath = '/api/hadith/collections';

  /// Our slugs that UmmahAPI does not carry. Asked for by name so the reason is
  /// legible at the call site: this is not "unmapped yet", it is "not there".
  static const Set<String> notCarried = {
    'ahmad', // Musnad Ahmad
    'darimi', // Sunan ad-Darimi
    'bulugh', // Bulugh al-Maram
    'nawawi', // our nawawi is Riyad as-Salihin — see the class comment
  };

  /// True when [name] looks like *Nawawi's Forty* rather than Riyad as-Salihin.
  ///
  /// Deliberately broad: "40", "forty" and "arba'in" all appear in the wild, and
  /// a false positive here only costs us a collection we already decline to map.
  static bool carriesForty(String name) {
    final n = name.toLowerCase();
    return n.contains('40') ||
        n.contains('forty') ||
        n.contains('arbain') ||
        n.contains("arba'in") ||
        n.contains('arbaeen');
  }

  /// The spellings to try for [slug] before the catalogue is known.
  ///
  /// Order is "most likely first"; all of them are cheap because a wrong guess
  /// is one 404 that is never retried (the client does not retry a 4xx) and the
  /// collection is then remembered as unresolved for the session.
  static List<String> candidatesFor(String slug) => switch (slug) {
        'bukhari' => const ['bukhari', 'sahih-bukhari', 'sahih_bukhari'],
        'muslim' => const ['muslim', 'sahih-muslim', 'sahih_muslim'],
        'abudawud' => const [
            'abudawud',
            'abu-dawud',
            'abudawood',
            'sunan-abu-dawud',
          ],
        'tirmidhi' => const ['tirmidhi', 'at-tirmidhi', 'jami-tirmidhi'],
        'nasai' => const ['nasai', 'an-nasai', 'sunan-nasai'],
        'ibnmajah' => const ['ibnmajah', 'ibn-majah', 'sunan-ibn-majah'],
        'malik' => const ['malik', 'muwatta', 'muwatta-malik'],
        _ => const [],
      };

  // ── Catalogue resolution ────────────────────────────────────────────

  /// slug → the API's own identifier, filled in once the catalogue is fetched.
  static final Map<String, String> _resolved = {};

  /// Slugs we have looked for in the catalogue and could not place, so we stop
  /// guessing. Session-scoped: a catalogue that gains a book is picked up on the
  /// next run.
  static final Set<String> _unresolved = {};

  /// True once [learn] has seen a catalogue, successfully or not.
  static bool _catalogueSeen = false;

  static bool get catalogueSeen => _catalogueSeen;

  /// The API identifier for [slug], or null when we should not ask.
  ///
  /// Returns a *guess* from [candidatesFor] until the catalogue has been seen,
  /// which is what makes the first hadith of a session resolve without waiting
  /// on a second round trip.
  static String? apiSlugFor(String slug) {
    final key = slug.toLowerCase();
    if (notCarried.contains(key)) return null;
    final known = _resolved[key];
    if (known != null) return known;
    if (_unresolved.contains(key)) return null;
    if (_catalogueSeen) return null;
    final guesses = candidatesFor(key);
    return guesses.isEmpty ? null : guesses.first;
  }

  /// Reads the catalogue payload and binds every collection it can.
  ///
  /// Matching is by *name*, not by position: the payload's own identifier is
  /// paired with our slug when any of that collection's aliases appears in the
  /// name the API gave. Aliases already exist for the parser
  /// ([HadithCollections.aliasIndex]), so no second table of spellings is kept
  /// here and the two cannot drift apart.
  static void learn(List<Map<String, dynamic>> catalogue) {
    _catalogueSeen = true;
    if (catalogue.isEmpty) return;

    for (final entry in catalogue) {
      final id = UmmahApiClient.stringAt(entry, const [
        'collection',
        'slug',
        'id',
        'name',
        'key',
      ]);
      if (id == null || id.isEmpty) continue;

      final label = UmmahApiClient.stringAt(entry, const [
            'title',
            'name',
            'english',
            'englishName',
            'title_en',
          ]) ??
          id;

      // Nawawi's Forty has no home in our table. Skip it before matching, or
      // the bare alias "an-nawawi" inside its title would bind it to Riyad
      // as-Salihin.
      if (carriesForty('$id $label')) continue;

      final matched = HadithCollections.matchIn('$label $id');
      if (matched == null) continue;
      if (notCarried.contains(matched.slug)) continue;
      _resolved.putIfAbsent(matched.slug, () => id);
    }

    for (final c in HadithCollections.all) {
      if (notCarried.contains(c.slug)) continue;
      if (_resolved.containsKey(c.slug)) continue;
      _unresolved.add(c.slug);
    }
  }

  /// Test/debug seam: forget what was learned.
  static void reset() {
    _resolved.clear();
    _unresolved.clear();
    _catalogueSeen = false;
  }

  /// Our slug for an API collection identifier — the direction needed when a
  /// search result names its own collection and we have to turn that into a
  /// [HadithRef] the rest of the app can open.
  ///
  /// Returns null rather than a nearest guess, and never returns `nawawi`.
  static String? appSlugFor(String? apiSlug) {
    if (apiSlug == null || apiSlug.trim().isEmpty) return null;
    final raw = apiSlug.trim();

    for (final entry in _resolved.entries) {
      if (entry.value.toLowerCase() == raw.toLowerCase()) return entry.key;
    }

    if (carriesForty(raw)) return null;

    // Tried twice: as it arrived, then with apostrophes removed. The aliases are
    // written without them — "an-nasai", "jami at-tirmidhi" — so a payload that
    // spells the collection "An-Nasa'i" or "Jami‘ at-Tirmidhī" matches nothing
    // on the first pass and the row would be dropped as uncitable. Only
    // apostrophes are stripped; hyphens and spaces are part of the aliases.
    final matched = HadithCollections.matchIn(raw) ??
        HadithCollections.matchIn(_withoutApostrophes(raw));
    if (matched == null) return null;
    if (notCarried.contains(matched.slug)) return null;
    return matched.slug;
  }

  static String _withoutApostrophes(String value) =>
      value.replaceAll(RegExp("['’‘`ʿʾ]"), '');
}
