/// HadithRef — a structured pointer to one hadith, plus the collection table
/// that makes prose citations resolvable.
///
/// The corpus does not store refs as `{"collection": "bukhari", "number":
/// "3326"}`. It stores sentences, written by a human, such as:
///
///   "At-Tirmidhi no. 3620 — narration of Bahirah the monk"
///   "'The Throne of the Most Merciful shook…' — narrated by Jabir, Sahih
///    al-Bukhari and Sahih Muslim"
///   "Ibn Sa'd, Tabaqat, Vol. III"
///
/// The first yields a ref. The second names two collections and gives no number,
/// so it yields none. The third is a book, not a hadith. This file owns the
/// alias table that decides which is which; the decision itself lives in
/// `reference_parser.dart`.
///
/// A ref is only ever *extracted*, never inferred. If a number is absent we do
/// not go looking for one, because a hadith cited by the wrong number is worse
/// than a hadith cited by name alone.
library;

import 'entity_ref.dart';

/// One of the collections the app can point at.
///
/// [slug] is what goes in a ref and a filename. [aliases] are the spellings that
/// actually occur in the corpus and in ordinary English writing, lowercased; the
/// parser matches on these. Order matters inside the alias list only in that
/// longer, more specific spellings should come first so "sahih al-bukhari" is
/// matched before "bukhari" — [HadithCollections.matchIn] handles that by
/// sorting, so entries here can stay readable.
class HadithCollection {
  const HadithCollection({
    required this.slug,
    required this.title,
    required this.titleArabic,
    required this.aliases,
    this.gradedThroughout = false,
  });

  final String slug;
  final String title;
  final String titleArabic;
  final List<String> aliases;

  /// True for the two Sahihs, whose every hadith is sahih by the compiler's own
  /// criterion. Everywhere else the grade has to come from the source that
  /// states it — we do not assign grades.
  final bool gradedThroughout;
}

/// The nine books, plus the two Muwatta/Musnad collections the corpus cites.
abstract final class HadithCollections {
  static const List<HadithCollection> all = [
    HadithCollection(
      slug: 'bukhari',
      title: 'Sahih al-Bukhari',
      titleArabic: 'صحيح البخاري',
      aliases: [
        'sahih al-bukhari',
        'sahih al bukhari',
        'sahih bukhari',
        'al-bukhari',
        'bukhari',
        'bukhaari',
      ],
      gradedThroughout: true,
    ),
    HadithCollection(
      slug: 'muslim',
      title: 'Sahih Muslim',
      titleArabic: 'صحيح مسلم',
      aliases: ['sahih muslim', 'saheeh muslim', 'muslim'],
      gradedThroughout: true,
    ),
    HadithCollection(
      slug: 'abudawud',
      title: 'Sunan Abu Dawud',
      titleArabic: 'سنن أبي داود',
      aliases: [
        'sunan abu dawud',
        'sunan abi dawud',
        'abu dawud',
        'abu dawood',
        'abi dawud',
      ],
    ),
    HadithCollection(
      slug: 'tirmidhi',
      title: "Jami' at-Tirmidhi",
      titleArabic: 'جامع الترمذي',
      aliases: [
        "jami' at-tirmidhi",
        'jami at-tirmidhi',
        'sunan at-tirmidhi',
        'at-tirmidhi',
        'al-tirmidhi',
        'tirmidhi',
        'tirmidhee',
      ],
    ),
    HadithCollection(
      slug: 'nasai',
      title: "Sunan an-Nasa'i",
      titleArabic: 'سنن النسائي',
      aliases: [
        "sunan an-nasa'i",
        'sunan an-nasai',
        "an-nasa'i",
        'an-nasai',
        "nasa'i",
        'nasai',
      ],
    ),
    HadithCollection(
      slug: 'ibnmajah',
      title: 'Sunan Ibn Majah',
      titleArabic: 'سنن ابن ماجه',
      aliases: ['sunan ibn majah', 'ibn majah', 'ibn maajah'],
    ),
    HadithCollection(
      slug: 'malik',
      title: 'Muwatta Malik',
      titleArabic: 'موطأ مالك',
      aliases: ['muwatta malik', 'al-muwatta', 'muwatta', 'malik'],
    ),
    HadithCollection(
      slug: 'ahmad',
      title: 'Musnad Ahmad',
      titleArabic: 'مسند أحمد',
      aliases: ['musnad ahmad', 'musnad of ahmad', 'ahmad'],
    ),
    HadithCollection(
      slug: 'darimi',
      title: 'Sunan ad-Darimi',
      titleArabic: 'سنن الدارمي',
      aliases: ['sunan ad-darimi', 'ad-darimi', 'darimi'],
    ),
    HadithCollection(
      slug: 'nawawi',
      title: "Riyad as-Salihin",
      titleArabic: 'رياض الصالحين',
      aliases: ['riyad as-salihin', 'riyadh as-salihin', 'riyad us-saliheen'],
    ),
    HadithCollection(
      slug: 'bulugh',
      title: 'Bulugh al-Maram',
      titleArabic: 'بلوغ المرام',
      aliases: ['bulugh al-maram', 'bulugh al maram'],
    ),
  ];

  static HadithCollection? bySlug(String slug) {
    final needle = slug.toLowerCase();
    for (final c in all) {
      if (c.slug == needle) return c;
    }
    return null;
  }

  /// Every alias paired with its collection, longest first. The parser scans
  /// this in order so "sahih al-bukhari" wins over the bare "bukhari" that is
  /// contained inside it.
  static List<({String alias, HadithCollection collection})> get aliasIndex {
    final out = <({String alias, HadithCollection collection})>[];
    for (final c in all) {
      for (final a in c.aliases) {
        out.add((alias: a, collection: c));
      }
    }
    out.sort((a, b) => b.alias.length.compareTo(a.alias.length));
    return out;
  }

  /// The first collection named anywhere in [text], or null.
  ///
  /// Returns the *earliest* match in the string rather than the longest, once
  /// ties on length are resolved — a citation that reads "narrated by Jabir,
  /// Sahih al-Bukhari and Sahih Muslim" should resolve to Bukhari, the one the
  /// author put first.
  static HadithCollection? matchIn(String text) {
    final haystack = text.toLowerCase();
    HadithCollection? best;
    var bestAt = 1 << 30;
    var bestLen = 0;
    for (final entry in aliasIndex) {
      final at = haystack.indexOf(entry.alias);
      if (at < 0) continue;
      if (at < bestAt || (at == bestAt && entry.alias.length > bestLen)) {
        best = entry.collection;
        bestAt = at;
        bestLen = entry.alias.length;
      }
    }
    return best;
  }
}

/// A hadith identified well enough to fetch, cache and open.
class HadithRef implements Comparable<HadithRef> {
  const HadithRef({required this.collection, required this.number});

  /// A collection slug from [HadithCollections]. Lowercase.
  final String collection;

  /// Kept as a String deliberately: real hadith numbering includes `2612a`,
  /// `1234-1236` and `7b`, none of which survive an int parse.
  final String number;

  HadithCollection? get book => HadithCollections.bySlug(collection);

  /// "Sahih al-Bukhari 3326" — what a reader should see.
  String get display => '${book?.title ?? collection} $number';

  /// `hadith:bukhari:3326` — what the graph and the cache see.
  EntityRef get entityRef => EntityRef.hadith(collection, number);

  String get canonical => entityRef.canonical;

  /// Round-trips [canonical], accepting either `hadith:bukhari:3326` or the
  /// bare `bukhari:3326`.
  static HadithRef? parse(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.startsWith('${EntityType.hadith.slug}:')) {
      value = value.substring(EntityType.hadith.slug.length + 1);
    }
    final cut = value.indexOf(':');
    if (cut <= 0 || cut == value.length - 1) return null;
    return HadithRef(
      collection: value.substring(0, cut).toLowerCase(),
      number: value.substring(cut + 1),
    );
  }

  /// The shape the brief specifies: `{"collection": "bukhari", "number": "3326"}`.
  /// Used by `assets/data/knowledge/edges.json` and by the sqflite cache.
  factory HadithRef.fromJson(Map<String, dynamic> json) => HadithRef(
        collection: (json['collection'] as String? ?? '').toLowerCase(),
        number: '${json['number'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'collection': collection,
        'number': number,
      };

  @override
  String toString() => canonical;

  @override
  bool operator ==(Object other) =>
      other is HadithRef &&
      other.collection == collection &&
      other.number == number;

  @override
  int get hashCode => Object.hash(collection, number);

  /// Collection order as declared in [HadithCollections.all] — Bukhari before
  /// Muslim before the four Sunan — then numerically within a collection.
  @override
  int compareTo(HadithRef other) {
    final mine = HadithCollections.all.indexWhere((c) => c.slug == collection);
    final theirs =
        HadithCollections.all.indexWhere((c) => c.slug == other.collection);
    if (mine != theirs) return mine.compareTo(theirs);
    final a = int.tryParse(RegExp(r'\d+').stringMatch(number) ?? '');
    final b = int.tryParse(RegExp(r'\d+').stringMatch(other.number) ?? '');
    if (a != null && b != null && a != b) return a.compareTo(b);
    return number.compareTo(other.number);
  }
}
