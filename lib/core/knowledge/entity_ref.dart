/// EntityRef — one canonical string for every thing the app knows about.
///
/// The knowledge layer never matches on names. "Adam" appears in a prophet file,
/// in three seerah layers and in two hadith, spelled differently in each; if
/// edges were keyed on text, those would be five different people. So every
/// entity gets a ref, and two entities are the same entity if and only if their
/// refs are equal.
///
/// The canonical form is `type:id`, with verses and hadith carrying their numbers
/// in the id because a verse has no name:
///
///   prophet:adam        sahabi:abu-bakr       seerah:hijrah
///   verse:2:30          hadith:bukhari:3326   theme:tawbah
///   name:ar-rahman      scholar:ibn-kathir    place:makkah
///
/// That string is the route parameter, the adjacency-map key, and — when
/// retrieval is added — the row id of an embedding. It is stable across rebuilds
/// because it is derived from the corpus id, not from an index.
library;

/// The kinds of thing that can be a node in the graph.
///
/// The first four already exist as JSON in `assets/data/discover/`. The rest are
/// either derived from citations (`verse`, `hadith`) or declared in
/// `assets/data/knowledge/` (`theme`, `scholar`, `place`, `journey`).
enum EntityType {
  prophet('prophet', 'Prophet'),
  sahabi('sahabi', 'Companion'),
  seerah('seerah', 'Event'),
  divineName('name', 'Divine Name'),
  verse('verse', 'Verse'),
  hadith('hadith', 'Hadith'),
  theme('theme', 'Theme'),
  scholar('scholar', 'Scholar'),
  place('place', 'Place'),
  journey('journey', 'Journey');

  const EntityType(this.slug, this.label);

  /// The prefix used in a canonical ref. Kept separate from [name] so renaming
  /// the Dart enum value can never invalidate saved refs on disk.
  final String slug;

  /// Human-readable, singular. Used as the section label and the type chip.
  final String label;

  /// Plural for section headings. Irregulars are spelled out rather than
  /// generated, because "Companions" and "Hadith" both break the +s rule.
  String get pluralLabel => switch (this) {
        EntityType.prophet => 'Prophets',
        EntityType.sahabi => 'Companions',
        EntityType.seerah => 'Events',
        EntityType.divineName => 'Divine Names',
        EntityType.verse => 'Verses',
        EntityType.hadith => 'Hadith',
        EntityType.theme => 'Themes',
        EntityType.scholar => 'Scholars',
        EntityType.place => 'Places',
        EntityType.journey => 'Journeys',
      };

  static EntityType? fromSlug(String slug) {
    for (final t in EntityType.values) {
      if (t.slug == slug) return t;
    }
    return null;
  }
}

/// A pointer to one entity. Immutable, comparable, and cheap to put in a Set.
class EntityRef implements Comparable<EntityRef> {
  const EntityRef(this.type, this.id);

  /// A verse ref. The id is `surah:ayah`, so `verse:2:30` — three colons total
  /// in the canonical string, which [parse] handles by splitting only once.
  factory EntityRef.verse(int surah, int ayah) =>
      EntityRef(EntityType.verse, '$surah:$ayah');

  /// A hadith ref. [collection] is already slugged by the parser
  /// (`sahih al-bukhari` → `bukhari`) so this stays a dumb constructor.
  factory EntityRef.hadith(String collection, String number) =>
      EntityRef(EntityType.hadith, '$collection:$number');

  final EntityType type;

  /// Lowercase, hyphenated, stable. For the four corpus types this is the `id`
  /// field straight out of the JSON.
  final String id;

  /// `type:id`. The one string form; nothing else is written to disk or to a
  /// route.
  String get canonical => '${type.slug}:$id';

  /// Parses a canonical string back into a ref, or null if it is malformed.
  ///
  /// Splits once on purpose: a verse id contains a colon and a hadith id
  /// contains a colon, so everything after the first separator is the id.
  static EntityRef? parse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    final cut = value.indexOf(':');
    if (cut <= 0 || cut == value.length - 1) return null;
    final type = EntityType.fromSlug(value.substring(0, cut));
    if (type == null) return null;
    return EntityRef(type, value.substring(cut + 1));
  }

  /// The surah number for a verse ref, else null. Saves every caller writing the
  /// same split.
  int? get verseSurah {
    if (type != EntityType.verse) return null;
    return int.tryParse(id.split(':').first);
  }

  /// The ayah number for a verse ref, else null.
  int? get verseAyah {
    if (type != EntityType.verse) return null;
    final parts = id.split(':');
    return parts.length < 2 ? null : int.tryParse(parts[1]);
  }

  /// The collection slug for a hadith ref, else null.
  String? get hadithCollection {
    if (type != EntityType.hadith) return null;
    return id.split(':').first;
  }

  /// The hadith number for a hadith ref, else null. Kept as a String: hadith
  /// numbering includes forms like `2612a` and ranges like `1234-1236`, so
  /// parsing it to an int would quietly lose information.
  String? get hadithNumber {
    if (type != EntityType.hadith) return null;
    final parts = id.split(':');
    return parts.length < 2 ? null : parts[1];
  }

  @override
  String toString() => canonical;

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  /// Sorts by type then id, so any list of refs has a deterministic order even
  /// when it came out of a Map. Verses sort numerically rather than
  /// lexically — otherwise 2:10 lands before 2:9 in every connected section.
  @override
  int compareTo(EntityRef other) {
    if (type != other.type) return type.index.compareTo(other.type.index);
    if (type == EntityType.verse) {
      final s = (verseSurah ?? 0).compareTo(other.verseSurah ?? 0);
      if (s != 0) return s;
      return (verseAyah ?? 0).compareTo(other.verseAyah ?? 0);
    }
    return id.compareTo(other.id);
  }
}
