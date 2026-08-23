/// Corpus audit — what the knowledge layer will actually have to show.
///
/// Runs the real [ReferenceParser] over the real JSON in `assets/data/discover/`
/// and reports what comes out. This is not a test of the parser against fixtures;
/// it is a census of the corpus, which is the number that decides what Evidence
/// Mode can and cannot display.
///
/// It exists because the honest answer to "does tapping a hadith citation show
/// the hadith?" depends entirely on how many citations carry a number, and that
/// is a property of the data, not of the code. Guessing was not acceptable.
///
/// Runs without Flutter: every file under `lib/core/knowledge/` is pure Dart, so
/// the graph's reasoning can be audited from the command line.
///
///     dart run tools/audit_corpus.dart
// Relative imports into lib/ are the only way a script outside lib/ can reach
// the real parser, and reaching the *real* parser is the entire point — a copy
// would agree with itself while both were wrong.
// ignore_for_file: avoid_relative_lib_imports
library;

import 'dart:convert';
import 'dart:io';

import '../lib/core/knowledge/evidence.dart';
import '../lib/core/knowledge/hadith_ref.dart';
import '../lib/core/knowledge/reference_parser.dart';

void main() {
  final dirs = {
    'prophets': 'assets/data/discover/prophets',
    'sahabah': 'assets/data/discover/sahabah',
    'names': 'assets/data/discover/names',
    'seerah': 'assets/data/discover/seerah',
  };

  var entries = 0;
  var layers = 0;
  var quranRefs = 0;
  var hadithRefs = 0;
  var sources = 0;

  final quran = <String>{};
  final hadithNumbered = <HadithRef>{};
  final hadithUnnumbered = <String>{};
  final hadithLocated = <String>{};
  final tafsir = <String>{};
  final scholars = <String>{};
  var citationOnly = 0;

  for (final entry in dirs.entries) {
    final dir = Directory(entry.value);
    if (!dir.existsSync()) {
      stdout.writeln('missing: ${entry.value}');
      continue;
    }
    var dirEntries = 0;
    var dirLayers = 0;

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final doc = jsonDecode(file.readAsStringSync());
      if (doc is! Map) continue;
      dirEntries++;
      entries++;

      final raw = doc['layers'];
      if (raw is! List) continue;

      for (final l in raw) {
        if (l is! Map) continue;
        dirLayers++;
        layers++;

        final quranRef = l['quran_ref'] as String?;
        final hadithRef = l['hadith_ref'] as String?;
        final source = l['source'] as String?;
        if (quranRef != null && quranRef.trim().isNotEmpty) quranRefs++;
        if (hadithRef != null && hadithRef.trim().isNotEmpty) hadithRefs++;
        if (source != null && source.trim().isNotEmpty) sources++;

        final evidence = ReferenceParser.parseLayer(
          quranRef: quranRef,
          hadithRef: hadithRef,
          source: source,
        );

        for (final e in evidence) {
          switch (e) {
            case QuranEvidence():
              quran.add('${e.surah}:${e.ayah}');
            case HadithEvidence():
              final ref = e.ref;
              if (ref == null) {
                hadithUnnumbered.add(e.collection);
                if (e.locator != null) {
                  hadithLocated.add('${e.collectionTitle} ${e.locator}');
                }
              } else {
                hadithNumbered.add(ref);
              }
            case TafsirEvidence():
              tafsir.add(e.scholarId ?? e.scholarName);
            case ScholarEvidence():
              scholars.add(e.scholarId ?? e.scholarName);
            case CitationEvidence():
              citationOnly++;
          }
        }
      }
    }
    stdout.writeln('${entry.key.padRight(9)} $dirEntries entries, '
        '$dirLayers layers');
  }

  stdout
    ..writeln('')
    ..writeln('── corpus ────────────────────────────────')
    ..writeln('entries              $entries')
    ..writeln('layers               $layers')
    ..writeln('layers w/ quran_ref  $quranRefs')
    ..writeln('layers w/ hadith_ref $hadithRefs')
    ..writeln('layers w/ source     $sources')
    ..writeln('')
    ..writeln('── what Evidence Mode can open ───────────')
    ..writeln('distinct ayat cited          ${quran.length}')
    ..writeln('hadith w/ collection+number  ${hadithNumbered.length}'
        '   ← fetchable, become entities')
    ..writeln('hadith collection only       ${hadithUnnumbered.length}'
        ' collections named without a number')
    ..writeln('  of those, w/ volume/page   ${hadithLocated.length}'
        '   ← shown as written, never fetched')
    ..writeln('tafsir passages addressable  ${tafsir.length} scholars')
    ..writeln('scholars named in sources    ${scholars.length}')
    ..writeln('prose-only citations         $citationOnly')
    ..writeln('');

  if (hadithNumbered.isNotEmpty) {
    final sorted = hadithNumbered.toList()..sort();
    stdout.writeln('numbered hadith:');
    for (final ref in sorted) {
      stdout.writeln('  ${ref.display}');
    }
    stdout.writeln('');
  }
  if (hadithLocated.isNotEmpty) {
    stdout.writeln('print-located hadith (volume/page, not fetchable):');
    for (final l in hadithLocated.toList()..sort()) {
      stdout.writeln('  $l');
    }
    stdout.writeln('');
  }
  if (scholars.isNotEmpty) {
    stdout.writeln('scholars: ${(scholars.toList()..sort()).join(', ')}');
  }

  _themeCensus();
}

/// Theme membership, measured the way the builder measures it.
///
/// Themes are the one part of the graph whose size is decided by a number a
/// human picked — `min_hits` in themes.json. Pick it too high and the theme page
/// opens empty; too low and it fills with entries that mention the word in
/// passing. So the threshold has to be set against the actual distribution, and
/// this prints that distribution.
///
/// The counting rule below is deliberately a copy of `KnowledgeBuilder
/// ._deriveThemeMembers` rather than a call to it: that method needs the whole
/// graph, which needs `rootBundle`, which needs a running engine. The rule is one
/// regex and one comparison, and it is documented in both places — if either
/// changes, this output goes visibly wrong, which is the point of running it.
void _themeCensus() {
  final file = File('assets/data/knowledge/themes.json');
  if (!file.existsSync()) return;
  final doc = jsonDecode(file.readAsStringSync());
  if (doc is! Map) return;
  final themes = doc['themes'];
  if (themes is! List) return;

  // Every entry's layer bodies, which is all the rule looks at.
  final bodies = <String, List<String>>{};
  for (final dir in const {
    'prophets': 'prophet',
    'sahabah': 'sahabi',
    'names': 'name',
    'seerah': 'seerah',
  }.entries) {
    final d = Directory('assets/data/discover/${dir.key}');
    if (!d.existsSync()) continue;
    for (final f in d.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json') || f.path.endsWith('index.json')) continue;
      final e = jsonDecode(f.readAsStringSync());
      if (e is! Map) continue;
      final layers = e['layers'];
      if (layers is! List) continue;
      bodies['${dir.value}:${e['id']}'] = [
        for (final l in layers)
          if (l is Map) (l['content'] as String?) ?? '',
      ];
    }
  }

  stdout
    ..writeln('')
    ..writeln('── theme membership (derived, not listed) ──');
  for (final t in themes) {
    if (t is! Map) continue;
    final keywords = (t['keywords'] as List?)?.cast<String>() ?? const [];
    final minHits = (t['min_hits'] as int?) ?? 4;
    final patterns = [
      for (final k in keywords)
        RegExp('\\b${RegExp.escape(k)}', caseSensitive: false),
    ];

    final scored = <(int, String)>[];
    for (final entry in bodies.entries) {
      var hits = 0;
      for (final body in entry.value) {
        for (final p in patterns) {
          hits += p.allMatches(body).length;
        }
      }
      if (hits > 0) scored.add((hits, entry.key));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final members = scored.where((s) => s.$1 >= minHits).toList();

    final flag = members.isEmpty
        ? '  ⚠ EMPTY PAGE'
        : members.length < 3
            ? '  ⚠ thin'
            : '';
    stdout.writeln('${(t['id'] as String).padRight(12)} min_hits=$minHits  '
        '${members.length} members$flag');
    stdout.writeln('             ${members.take(6).map((m) => m.$2).join(', ')}');
  }
}

