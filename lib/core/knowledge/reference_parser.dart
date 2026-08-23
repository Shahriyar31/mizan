/// ReferenceParser — turns the corpus's prose citations into structured evidence.
///
/// The corpus was written by a human for a human, so a reference reads like a
/// sentence. This file is the one place that reads those sentences, and it is
/// written against the strings that are actually on disk — the counts below are
/// from `assets/data/discover`, not from a guess:
///
///   583 `quran_ref` values · 543 contain S:A · 364 name more than one passage ·
///   229 contain a range · 49 omit the word "Quran"
///   408 `hadith_ref` values · 13 contain a number of any kind · 79 name a narrator
///   930 `source` values across 200 distinct books
///
/// Two rules govern every branch here.
///
/// **Extract, never infer.** A hadith number is produced only when the citation
/// contains one. `Sahih al-Bukhari — argument between Adam and Moses` becomes a
/// collection-level [HadithEvidence] with the description kept whole; it does not
/// become a number looked up from memory.
///
/// **Never drop a source.** Anything that does not parse comes back as
/// [CitationEvidence] holding the original string, so it is still shown and still
/// attributed. The floor of this parser is "display what the author wrote".
library;

import 'evidence.dart';
import 'hadith_ref.dart';

/// Scholars and compilers named often enough in `source` strings to be worth an
/// entity. Keys are slugs; values are the spellings that occur, longest first at
/// match time.
///
/// Deliberately short. A name is listed here only because the corpus cites it,
/// which is why al-Baihaqi and Ibn Abi Shaybah appear and a general "great
/// scholars" list does not.
const Map<String, List<String>> kScholarAliases = {
  'ibn-kathir': ['ibn kathir', 'ibn katheer'],
  'al-tabari': ['al-tabari', 'at-tabari', 'ibn jarir', 'tabari'],
  'al-qurtubi': ['al-qurtubi', 'qurtubi'],
  'ibn-ashur': ['ibn ashur', "ibn 'ashur", 'ibn aashoor'],
  'ibn-uthaymeen': [
    'ibn uthaymeen',
    'ibn uthaymin',
    'ibn al-uthaymeen',
    'uthaymeen',
  ],
  'al-mubarakpuri': ['al-mubarakpuri', 'mubarakpuri', 'safiur-rahman'],
  'ibn-sad': ["ibn sa'd", 'ibn sad'],
  'ibn-hisham': ['ibn hisham', 'ibn hishaam'],
  'al-baihaqi': ['al-baihaqi', 'al-bayhaqi', 'baihaqi'],
  'ibn-abi-shaybah': ["ibn abi shaybah", 'ibn abi shayba'],
  'al-nawawi': ['al-nawawi', 'an-nawawi', 'nawawi'],
  'ibn-hajar': ['ibn hajar', 'ibn hajr'],
};

/// Books whose presence in a `source` string means the citation is a tafsir of a
/// specific passage rather than a general history.
const Set<String> kTafsirWorkMarkers = {
  'tafsir',
  'tafseer',
  'commentary',
};

abstract final class ReferenceParser {
  /// `2:30`, `2:124-129`, `2:124–129` (en dash), with an optional `Quran`/`Surah`
  /// prefix handled by the caller. Bounded to 1–3 digits for the surah and 1–3 for
  /// the ayah so a volume/page number like `1/545` cannot masquerade as a verse.
  static final RegExp _verse =
      RegExp(r'(\d{1,3})\s*:\s*(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?');

  /// `no. 3620`, `no 3620`, `#3620`, `hadith 3620`, and a bare number directly
  /// after a collection name (`Sahih al-Bukhari 3377`, `3378-3380`).
  static final RegExp _hadithNumberLabelled =
      RegExp(r'(?:no\.?|#|hadith|hadeeth)\s*(\d{1,5}[a-z]?)', caseSensitive: false);

  /// Volume/page, which must be *rejected* as a hadith number: `1/545`, `2/24-25`.
  static final RegExp _volumePage = RegExp(r'\b\d{1,3}\s*/\s*\d{1,4}');

  static final RegExp _narrator = RegExp(
    r"narrated\s+(?:by|from)\s+([^:—–,\.;]{3,45})",
    caseSensitive: false,
  );

  static final RegExp _bookWithin = RegExp(
    r'Book of ([^,—–;\.]{3,60})',
    caseSensitive: false,
  );

  /// A quotation in double quotes. Unambiguous — a double quote has no second
  /// job in English or in transliterated Arabic — so it is tried first.
  static final RegExp _quotedDouble = RegExp('["“]([^"”]{8,240})["”]');

  /// A quotation in single quotes, guarded, because in this corpus the
  /// apostrophe does double duty as the transliteration of hamza and ayn.
  ///
  /// `Sahih al-Bukhari — Abu Musa al-Ash'ari narration on Adam's creation from
  /// mixed clay` contains no quotation at all. An unguarded `'…'` pair reads the
  /// apostrophe of *al-Ash'ari* as an opening quote and the apostrophe of
  /// *Adam's* as the closing one, capturing `ari narration on Adam` — which
  /// reached the evidence card as a highlighted excerpt clipped mid-word. It did
  /// that to 28 of the 408 hadith references in the corpus.
  ///
  /// So a straight apostrophe only delimits at a word boundary: it may not open
  /// while glued to the right of a letter or digit, and may not close with a
  /// letter following it. That also *frees* the body to contain apostrophes,
  /// which the old character class forbade — `'the Prophet's saying'` used to
  /// truncate at *Prophet* and now survives whole. Non-greedy so a citation with
  /// two quotations yields the first rather than everything between them.
  static final RegExp _quotedSingle = RegExp(
    r"(?<![\p{L}\p{N}])['‘](.{8,240}?)['’](?![\p{L}])",
    unicode: true,
  );

  /// The quotation in [text], or null when the text merely *describes* the
  /// passage. Never returns a fragment cut out of the middle of a word.
  static String? quotedIn(String text) {
    final m = _quotedDouble.firstMatch(text) ?? _quotedSingle.firstMatch(text);
    final quote = m?.group(1)?.trim();
    return (quote == null || quote.isEmpty) ? null : quote;
  }

  // ── Qur'an ──────────────────────────────────────────────────────────

  /// Every passage named in [raw].
  ///
  /// `Quran 2:124-129, 14:37-38, 37:108-111` yields three pieces of evidence, each
  /// keeping its own range. A citation that names a surah without an ayah
  /// (`Surah Maryam (19) — Ja'far recited its opening verses`) yields nothing here
  /// and is picked up as a plain citation by [parseAny]: we will not invent
  /// "ayah 1" to make it tappable.
  static List<QuranEvidence> parseQuran(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final text = raw.trim();

    // The quoted fragment, if any, belongs to the whole citation rather than to
    // one of its passages, so it is attached to the first.
    final quoted = quotedIn(text);

    final out = <QuranEvidence>[];
    for (final m in _verse.allMatches(text)) {
      final surah = int.tryParse(m.group(1)!);
      final ayah = int.tryParse(m.group(2)!);
      if (surah == null || ayah == null) continue;
      if (surah < 1 || surah > 114 || ayah < 1 || ayah > 286) continue;
      final through = m.group(3) == null ? null : int.tryParse(m.group(3)!);
      out.add(
        QuranEvidence(
          surah: surah,
          ayah: ayah,
          throughAyah: (through != null && through > ayah) ? through : null,
          quotedText: out.isEmpty ? quoted : null,
        ),
      );
    }
    return out;
  }

  // ── Hadith ──────────────────────────────────────────────────────────

  /// The hadith citation in [raw], or null if no collection is named.
  ///
  /// Returns collection-level evidence when there is no number, which is the
  /// normal case. The descriptive tail after the em dash is preserved as
  /// [HadithEvidence.detail] because for an unnumbered citation that description
  /// is the only thing identifying which hadith is meant.
  static HadithEvidence? parseHadith(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();

    final collection = HadithCollections.matchIn(text);
    if (collection == null) return null;

    return HadithEvidence(
      collection: collection.slug,
      number: _hadithNumberIn(text, collection),
      locator: _locatorIn(text),
      bookName: _bookWithin.firstMatch(text)?.group(1)?.trim(),
      detail: _detailTail(text),
      quotedText: quotedIn(text),
      narrator: narratorIn(text),
      gradeNote: collection.gradedThroughout ? 'Sahih' : null,
    );
  }

  /// A print locator — volume over page, with any page range or second page kept
  /// as written: `1/2,3`, `1/162-164`, `2/340`.
  ///
  /// Returned separately from the hadith number precisely because it is not one.
  /// Twelve corpus references cite a printed edition this way, and dropping the
  /// volume and page would leave a citation the reader cannot check — so it is
  /// displayed beside the collection while [_hadithNumberIn] still refuses to
  /// treat it as fetchable.
  static String? _locatorIn(String text) {
    final m = RegExp(r'\b(\d{1,3}\s*/\s*\d{1,4}(?:\s*[-–,]\s*\d{1,4})?)')
        .firstMatch(text);
    return m?.group(1)?.replaceAll(' ', '');
  }

  /// A hadith number, or null. Rejects volume/page pairs outright, and only
  /// accepts a bare number when it sits immediately after the collection name —
  /// which is how `Sahih al-Bukhari 3377` is written and how `Ibn Sa'd 1/63` is
  /// not.
  static String? _hadithNumberIn(String text, HadithCollection collection) {
    final labelled = _hadithNumberLabelled.firstMatch(text);
    if (labelled != null) return labelled.group(1);

    final lower = text.toLowerCase();
    for (final alias in collection.aliases) {
      final at = lower.indexOf(alias);
      if (at < 0) continue;
      final tail = text.substring(at + alias.length);
      // Anything other than spaces or a comma between the name and the digits
      // means the number belongs to something else in the sentence.
      final m = RegExp(r'^[\s,]{0,3}(\d{1,5}[a-z]?)(?:\s*[-–]\s*\d{1,5})?')
          .firstMatch(tail);
      if (m == null) continue;
      // `1/545` — a volume and page, not a hadith.
      final after = tail.substring(m.end);
      if (after.startsWith('/')) continue;
      if (_volumePage.hasMatch(m.group(0)!)) continue;
      return m.group(1);
    }
    return null;
  }

  /// The description the author wrote after the dash, cleaned of a leading
  /// "narrated by …" that is already captured separately.
  static String? _detailTail(String text) {
    final emDash = text.indexOf('—');
    final cut = emDash >= 0 ? emDash : text.indexOf('–');
    if (cut < 0 || cut == text.length - 1) return null;
    var tail = text.substring(cut + 1).trim();
    tail = tail.replaceFirst(
      RegExp(r'^(?:narrated\s+(?:by|from)\s+[^:,]{3,45}[:,]\s*)',
          caseSensitive: false),
      '',
    );
    return tail.isEmpty ? null : tail;
  }

  /// "narrated by Anas ibn Malik" → "Anas ibn Malik". 79 of the 408 hadith refs
  /// carry one, which is what makes the narrator edges worth building.
  static String? narratorIn(String? raw) {
    if (raw == null) return null;
    final m = _narrator.firstMatch(raw);
    if (m == null) return null;
    var name = m.group(1)!.trim();
    // Chains — "Ibn Abbas from Abu Dharr" — name two people; the first is the one
    // this citation is attributed through, and the second is left to the text.
    final from = RegExp(r'\s+from\s+', caseSensitive: false).firstMatch(name);
    if (from != null) name = name.substring(0, from.start).trim();
    return name.isEmpty ? null : name;
  }

  // ── Sources: tafsir and scholars ────────────────────────────────────

  /// The scholar slugs named in [raw], in the order they appear.
  ///
  /// A `source` string often names two — "al-Mubarakpuri, The Sealed Nectar,
  /// citing Ibn Hisham" — and both are real attributions, so both are returned.
  static List<String> scholarsIn(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final lower = raw.toLowerCase();
    final hits = <({int at, String slug})>[];
    for (final entry in kScholarAliases.entries) {
      var earliest = -1;
      for (final alias in entry.value) {
        final at = lower.indexOf(alias);
        if (at >= 0 && (earliest < 0 || at < earliest)) earliest = at;
      }
      if (earliest >= 0) hits.add((at: earliest, slug: entry.key));
    }
    hits.sort((a, b) => a.at.compareTo(b.at));
    return hits.map((h) => h.slug).toList();
  }

  /// Evidence for a layer's `source` string.
  ///
  /// A source that names a tafsir *and* a passage becomes [TafsirEvidence], which
  /// is tappable straight into the bundled Ibn Kathir text. A source that names a
  /// scholar becomes [ScholarEvidence] carrying the work as written. Anything else
  /// stays a [CitationEvidence] — the 200 distinct books in the corpus include
  /// biographies and histories that are not commentary on an ayah, and flattening
  /// them into "tafsir" would misdescribe them.
  static List<Evidence> parseSource(String? raw, {int? surah, int? ayah}) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final text = raw.trim();
    final lower = text.toLowerCase();
    final scholars = scholarsIn(text);

    final isTafsir = kTafsirWorkMarkers.any(lower.contains);
    if (isTafsir && scholars.isNotEmpty && surah != null && ayah != null) {
      return [
        TafsirEvidence(
          scholarId: scholars.first,
          scholarName: _titleCaseSlug(scholars.first),
          surah: surah,
          ayah: ayah,
        ),
        // The full string is kept alongside, because "Ibn Kathir, Tafsir of Surah
        // Sad" says which volume as well as which scholar.
        CitationEvidence(text),
      ];
    }

    if (scholars.isNotEmpty) {
      return [
        for (final slug in scholars)
          ScholarEvidence(
            scholarId: slug,
            scholarName: _titleCaseSlug(slug),
            work: _workIn(text),
          ),
        CitationEvidence(text),
      ];
    }

    return [CitationEvidence(text)];
  }

  /// The book title inside a source string: the segment after the first comma,
  /// trimmed of a publisher and of a "citing …" tail.
  static String? _workIn(String text) {
    final parts = text.split(',');
    if (parts.length < 2) return null;
    var work = parts[1].trim();
    work = work.split(RegExp(r'\s+(?:citing|quoting)\s+', caseSensitive: false)).first;
    work = work.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim();
    return work.isEmpty ? null : work;
  }

  /// `ibn-kathir` → `Ibn Kathir`. Only used for a display name when the scholar
  /// has no entity file yet; a real scholar entity supplies its own spelling.
  static String _titleCaseSlug(String slug) => slug
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  // ── Everything at once ──────────────────────────────────────────────

  /// All the evidence in one layer, de-duplicated and ordered.
  ///
  /// [quranRef] and [hadithRef] are the layer's own fields; [source] is the book
  /// it rests on. A Qur'an ref that named a surah without an ayah survives as a
  /// citation rather than vanishing, which is the whole point of the fallback.
  static List<Evidence> parseLayer({
    String? quranRef,
    String? hadithRef,
    String? source,
  }) {
    final out = <Evidence>[];

    final quran = parseQuran(quranRef);
    out.addAll(quran);
    if (quran.isEmpty && quranRef != null && quranRef.trim().isNotEmpty) {
      out.add(CitationEvidence(quranRef.trim()));
    }

    final hadith = parseHadith(hadithRef);
    if (hadith != null) {
      out.add(hadith);
    } else if (hadithRef != null && hadithRef.trim().isNotEmpty) {
      out.add(CitationEvidence(hadithRef.trim()));
    }

    // The first cited ayah is what a tafsir source is commenting on, when the
    // layer names both.
    out.addAll(
      parseSource(
        source,
        surah: quran.isEmpty ? null : quran.first.surah,
        ayah: quran.isEmpty ? null : quran.first.ayah,
      ),
    );

    final seen = <String>{};
    final unique = <Evidence>[];
    for (final e in out) {
      if (seen.add(e.key)) unique.add(e);
    }
    unique.sort(Evidence.compare);
    return unique;
  }
}
