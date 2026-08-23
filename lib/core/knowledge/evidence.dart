/// Evidence — the reason a claim or an edge exists.
///
/// The app's one hard content rule is that a scholarly claim carries a Qur'anic
/// ayah, a hadith with book and number, or a named tafsir — or it does not ship.
/// This file is that rule expressed as a type. A section without evidence renders
/// no chips; a section with evidence renders exactly what it has, and the sheet
/// behind each chip shows the source rather than a paraphrase of it.
///
/// The hierarchy is `sealed`, so `switch` over it is exhaustive and adding a kind
/// is a compile error everywhere it needs handling rather than a silent gap in
/// the UI.
///
/// [CitationEvidence] is the honest floor. 408 of the corpus's hadith references
/// are prose — some name two collections, some name a biography rather than a
/// hadith, some quote the text and no number. Those become a citation that is
/// *displayed as written and attributed*, and is not tappable, because we cannot
/// fetch what we cannot identify. Dropping them would hide a source; guessing a
/// number would invent one.
library;

import 'entity_ref.dart';
import 'hadith_ref.dart';

sealed class Evidence {
  const Evidence();

  /// One line, for a chip. Short enough to sit in a row and specific enough to
  /// be checked.
  String get label;

  /// The entity this evidence points at, when it points at one. Null for
  /// [CitationEvidence], which is exactly what makes it non-tappable.
  EntityRef? get target;

  /// Sort key so a mixed evidence list always reads Qur'an, then hadith, then
  /// tafsir, then scholar, then bare citations.
  int get order => switch (this) {
        QuranEvidence() => 0,
        HadithEvidence() => 1,
        TafsirEvidence() => 2,
        ScholarEvidence() => 3,
        CitationEvidence() => 4,
      };

  /// A stable identity, so the same ayah cited by two sections de-duplicates in a
  /// set without an `==` override on every subclass.
  String get key;

  static int compare(Evidence a, Evidence b) {
    final byKind = a.order.compareTo(b.order);
    return byKind != 0 ? byKind : a.key.compareTo(b.key);
  }
}

/// An ayah, or a run of ayat. Opens the reader at the first ayah, where the five
/// layers already live.
///
/// 229 of the corpus's 583 Qur'an references are ranges and 364 name more than one
/// passage, so a model that held a single ayah would either lose information or
/// force the parser to lie about what was cited. [throughAyah] keeps the chip
/// reading "Qur'an 2:124–129" while the graph still gets one node per ayah.
class QuranEvidence extends Evidence {
  const QuranEvidence({
    required this.surah,
    required this.ayah,
    this.throughAyah,
    this.quotedText,
    this.surahName,
  });

  final int surah;
  final int ayah;

  /// The last ayah of a cited run, when the citation gave a range. Null for a
  /// single ayah.
  final int? throughAyah;

  /// The fragment the corpus quoted alongside the reference, if any. Shown in the
  /// sheet under the Arabic so the reader sees why this ayah was cited — never
  /// used as a substitute for the translation, which comes from the chosen
  /// translator.
  final String? quotedText;

  /// Present only when the citation named the surah. We do not look it up here;
  /// the reader knows surah names and this layer stays I/O-free.
  final String? surahName;

  bool get isRange => throughAyah != null && throughAyah! > ayah;

  /// Every ayah the citation covers. Capped, because a malformed range like
  /// `2:1-286` should not put 286 nodes in the graph off one citation.
  List<int> get ayatCovered {
    if (!isRange) return [ayah];
    final last = throughAyah!;
    final end = (last - ayah) > 20 ? ayah + 20 : last;
    return [for (var a = ayah; a <= end; a++) a];
  }

  String get reference => isRange ? '$surah:$ayah-$throughAyah' : '$surah:$ayah';

  @override
  String get label {
    final ref = isRange ? '$surah:$ayah–$throughAyah' : '$surah:$ayah';
    return surahName == null ? 'Qur\'an $ref' : 'Qur\'an $ref · $surahName';
  }

  @override
  EntityRef get target => EntityRef.verse(surah, ayah);

  @override
  String get key => 'q:$surah:$ayah:${throughAyah ?? ''}';
}

/// A hadith citation. [number] is nullable, and that is the important part.
///
/// The brief assumed refs shaped `{"collection": "bukhari", "number": "3326"}`.
/// The corpus has 408 hadith references and **13** contain a number of any kind,
/// several of which are volume/page (`Sahih Muslim 1/92`) rather than a hadith
/// number. The other 395 read like:
///
///   "Sahih al-Bukhari — argument between Adam and Moses"
///   "Sahih Muslim, Book of Hajj, narrated by Jabir ibn Abdullah — the Farewell Hajj"
///
/// That is a real citation: it names the collection, often the book within it, the
/// narrator, and what the hadith says. It is simply not a *number*. So a numbered
/// citation gets an entity, a page and a fetch; an unnumbered one is displayed
/// with everything it does state and is not tappable, because there is nothing
/// honest to open. The number is never filled in from memory.
class HadithEvidence extends Evidence {
  const HadithEvidence({
    required this.collection,
    this.number,
    this.locator,
    this.bookName,
    this.detail,
    this.quotedText,
    this.narrator,
    this.gradeNote,
  });

  /// A collection slug from [HadithCollections].
  final String collection;

  /// The hadith number where the citation gave one. Null for the great majority.
  final String? number;

  /// A print locator — "1/545", volume over page — where the citation gave one
  /// instead of a hadith number. Twelve references in the corpus are written this
  /// way, and the volume and page are the only thing that makes them checkable,
  /// so they are carried and displayed rather than discarded as unparseable. It
  /// is deliberately not [number]: a page is not a hadith number, and treating
  /// one as the other would fetch the wrong hadith under the right citation.
  final String? locator;

  /// The book within the collection — "Book of Hajj" — where the citation named
  /// one. This is what makes an unnumbered citation findable by hand.
  final String? bookName;

  /// The descriptive tail the corpus wrote after the em dash. Kept verbatim: for
  /// an unnumbered citation it is the only thing that identifies *which* hadith.
  final String? detail;

  /// The wording the corpus quoted. Kept even after the full text is fetched — it
  /// is what the layer's author was pointing at.
  final String? quotedText;

  /// "narrated by Jabir ibn Abdullah", where the citation said so.
  final String? narrator;

  /// A grade only if the citation stated one, or if the collection grades
  /// throughout (the two Sahihs). We never assign a grade ourselves.
  final String? gradeNote;

  bool get isNumbered => number != null && number!.isNotEmpty;

  /// Present only when numbered. Non-null is exactly the condition for "this can
  /// be fetched and opened".
  HadithRef? get ref =>
      isNumbered ? HadithRef(collection: collection, number: number!) : null;

  HadithCollection? get book => HadithCollections.bySlug(collection);

  String get collectionTitle => book?.title ?? collection;

  @override
  String get label {
    if (isNumbered) return '$collectionTitle $number';
    if (locator != null) return '$collectionTitle $locator';
    return collectionTitle;
  }

  @override
  EntityRef? get target => ref?.entityRef;

  /// Unnumbered citations must not collapse into one another — two different
  /// Bukhari references on the same page are two references — so the descriptive
  /// tail is part of the identity.
  @override
  String get key => isNumbered
      ? 'h:${ref!.canonical}'
      : 'h:$collection:${locator ?? ''}:${bookName ?? ''}:'
          '${detail ?? quotedText ?? ''}';
}

/// A tafsir passage on a specific ayah. Ibn Kathir is bundled for all 114 surahs,
/// so this one resolves offline today.
class TafsirEvidence extends Evidence {
  const TafsirEvidence({
    required this.scholarName,
    required this.surah,
    required this.ayah,
    this.scholarId,
  });

  /// As written in the citation — "Ibn Kathir", "al-Tabari".
  final String scholarName;

  /// Slug, when the named scholar is one we have a page for. Null means the
  /// tafsir is named but the scholar has no entity yet.
  final String? scholarId;

  final int surah;
  final int ayah;

  @override
  String get label => 'Tafsir $scholarName · $surah:$ayah';

  /// Points at the *verse*, not the scholar: tapping a tafsir chip should land on
  /// the passage about that ayah. The scholar is reachable from there.
  @override
  EntityRef get target => EntityRef.verse(surah, ayah);

  @override
  String get key => 't:${scholarId ?? scholarName}:$surah:$ayah';
}

/// A named scholar's commentary on the topic at hand, without a specific ayah.
class ScholarEvidence extends Evidence {
  const ScholarEvidence({
    required this.scholarName,
    this.scholarId,
    this.work,
    this.remark,
  });

  final String scholarName;
  final String? scholarId;

  /// The book the citation named, e.g. "al-Bidaya wa'l-Nihaya".
  final String? work;

  /// The sentence the corpus attributed to them, verbatim.
  final String? remark;

  @override
  String get label => work == null ? scholarName : '$scholarName · $work';

  @override
  EntityRef? get target =>
      scholarId == null ? null : EntityRef(EntityType.scholar, scholarId!);

  @override
  String get key => 's:${scholarId ?? scholarName}:${work ?? ''}';
}

/// A source named in prose that cannot be resolved to a verse, a numbered hadith
/// or a tafsir passage. Rendered exactly as the corpus wrote it, and not
/// tappable — the citation is the whole of what we can honestly offer.
class CitationEvidence extends Evidence {
  const CitationEvidence(this.text);

  final String text;

  @override
  String get label => text;

  @override
  EntityRef? get target => null;

  @override
  String get key => 'c:$text';
}
