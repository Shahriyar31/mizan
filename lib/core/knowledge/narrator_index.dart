/// NarratorIndex — the one place in the app that turns a person's *name* into a
/// companion's entity ref.
///
/// It exists because two callers need the same answer and must not disagree:
///
///  - the graph builder, which reads "narrated by Jabir" out of a corpus citation
///    and wants a `narratedBy` edge;
///  - the hadith screen, which has a `narrator` string that came from the hadith
///    service and wants to make it tappable so it opens the companion's existing
///    biography rather than a second, thinner profile of him.
///
/// Matching people by name is the kind of thing that goes quietly wrong, so the
/// rules are written down and the index errs towards *nothing*:
///
///  1. An exact normalised match wins.
///  2. Narration lead-ins ("narrated by", "on the authority of", "it was
///     narrated from") and honorifics are stripped, then rule 1 is retried.
///  3. A shorter form is accepted only when it prefixes exactly one companion id.
///     "Asma" prefixes both Asma bint Abi Bakr and Asma bint Umays, so it
///     resolves to neither.
///
/// Rule 3 is why "better nothing than wrong" is not a slogan here: a hadith
/// attributed to the wrong companion is a false statement about a person, and a
/// missing link is merely a missing link.
library;

import 'entity_ref.dart';

class NarratorIndex {
  NarratorIndex();

  final Map<String, EntityRef> _byKey = {};
  final List<({String key, EntityRef ref})> _ids = [];

  bool get isEmpty => _ids.isEmpty;

  /// Registers one companion under [ref] plus every [names] spelling that should
  /// resolve to him.
  ///
  /// The id always wins; the other spellings are only added where they are not
  /// already taken, so two companions who share a kunyah keep the first
  /// registration rather than overwriting each other.
  void add(EntityRef ref, Iterable<String?> names) {
    final id = normalise(ref.id);
    if (id.isEmpty) return;
    _byKey[id] = ref;
    for (final name in names) {
      if (name == null) continue;
      final key = normalise(name);
      if (key.isEmpty) continue;
      _byKey.putIfAbsent(key, () => ref);
    }
    _ids.add((key: id, ref: ref));
  }

  /// The companion [narrator] names, or null.
  EntityRef? match(String? narrator) {
    if (narrator == null) return null;

    final direct = _lookup(normalise(narrator));
    if (direct != null) return direct;

    // A hadith service says "Narrated Abu Hurairah:" where the corpus says
    // "Abu Hurayrah". Strip the framing and try again.
    return _lookup(normalise(strip(narrator)));
  }

  EntityRef? _lookup(String key) {
    if (key.length < 3) return null;

    final exact = _byKey[key];
    if (exact != null) return exact;

    EntityRef? only;
    for (final candidate in _ids) {
      if (!candidate.key.startsWith('${key}_')) continue;
      if (only != null) return null; // Ambiguous — better nothing than wrong.
      only = candidate.ref;
    }
    return only;
  }

  /// Removes the words around a name: the narration verb, the honorific, and any
  /// trailing punctuation. Public so a screen can show the bare name it matched
  /// on rather than the whole sentence.
  static String strip(String raw) {
    var value = raw.trim();

    // Honorifics, in the spellings that actually appear in hadith translations.
    value = value.replaceAll(
      RegExp(
        r'\((?:may allah be pleased with (?:him|her|them)[^)]*|ra|radiy?allahu[^)]*)\)',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(
      RegExp(
        r'\b(?:may allah be pleased with (?:him|her|them)|peace be upon him|'
        r'radiyallahu anhu|radiallahu anhu)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Lead-ins. Anchored at the start so a name containing "from" survives.
    value = value.replaceFirst(
      RegExp(
        r'^\s*(?:it was )?(?:narrated|reported|related|transmitted)'
        r'(?:\s+(?:by|from|that|to us))?\s*[:\-–]?\s*',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceFirst(
      RegExp(r'^\s*on the authority of\s+', caseSensitive: false),
      '',
    );

    // Whatever the narrator went on to say.
    final cut = value.indexOf(RegExp(r'[:;,]'));
    if (cut > 2) value = value.substring(0, cut);

    return value.trim();
  }

  /// Lowercases, drops the transliteration marks, and folds the two spelling
  /// differences that separate the same name in two sources: `ay`/`ai`
  /// (Hurayrah / Hurairah) and doubled letters (Abdullaah / Abdullah).
  ///
  /// Folding can only merge keys, never split them, so it can introduce a
  /// collision — which [add] resolves by keeping the first registration and
  /// [_lookup] resolves by refusing an ambiguous prefix.
  static String normalise(String raw) {
    final base = raw
        .toLowerCase()
        .replaceAll(RegExp(r"['’`ʿʾ]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .replaceAll('ay', 'ai');

    // Collapse runs of the same character: "abdullaah" → "abdullah".
    final out = StringBuffer();
    for (var i = 0; i < base.length; i++) {
      if (i > 0 && base[i] == base[i - 1]) continue;
      out.write(base[i]);
    }
    return out.toString();
  }
}
