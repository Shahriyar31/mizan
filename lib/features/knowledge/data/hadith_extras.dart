/// The two bundled drop-ins that fill the hadith page's Vocabulary and Scholar
/// Commentary layers.
///
/// Both are empty today, and that is a sourcing fact rather than an unfinished
/// feature:
///
///  - **Vocabulary.** UmmahAPI exposes no dictionary, lemma or root endpoint.
///    `/api/quran/words` covers the Qur'an only, and matching hadith Arabic to
///    Qur'anic word forms would need morphological analysis the app does not have.
///    Glossing a word ourselves would be exactly the machine-generated Islamic
///    content the brief forbids, so the layer ships as a real slot with an honest
///    empty state.
///
///  - **Scholar commentary.** There is no sharh endpoint either. Commentary
///    requires a named scholar and a named work or it is not commentary, so an
///    entry missing either is dropped rather than shown as anonymous opinion.
///
/// Drop `assets/data/hadith/vocabulary/{collection}.json` or
/// `assets/data/hadith/commentary/{collection}.json` into the bundle and both
/// layers light up with no code change — the same pattern
/// [BundledHadithSource] already uses for hadith texts.
///
/// Two lines in `pubspec.yaml` are the whole wiring:
///
/// ```yaml
///     - assets/data/hadith/vocabulary/
///     - assets/data/hadith/commentary/
/// ```
///
/// They are deliberately **not** declared today. Flutter fails the build on an
/// asset directory that does not exist, and git does not track empty
/// directories, so declaring them before any file ships would break `flutter
/// build` for everyone. Add the directory, the file and the pubspec line
/// together.
///
/// Expected shapes, keyed by hadith number:
///
/// ```json
/// { "3326": [ { "arabic": "…", "transliteration": "…", "meaning": "…" } ] }
/// { "3326": [ { "scholar": "…", "work": "…", "text": "…", "reference": "…" } ] }
/// ```
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/knowledge/hadith_ref.dart';

class HadithGloss {
  const HadithGloss({
    required this.arabic,
    required this.meaning,
    this.transliteration,
    this.note,
  });

  final String arabic;
  final String meaning;
  final String? transliteration;
  final String? note;

  static HadithGloss? fromJson(Map<String, dynamic> json) {
    final arabic = _str(json, const ['arabic', 'word', 'term', 'ar']);
    final meaning = _str(json, const ['meaning', 'gloss', 'english', 'en']);
    if (arabic == null || meaning == null) return null;
    return HadithGloss(
      arabic: arabic,
      meaning: meaning,
      transliteration: _str(json, const ['transliteration', 'translit', 'roman']),
      note: _str(json, const ['note', 'detail', 'comment']),
    );
  }
}

/// One scholar's remark on one hadith. Never anonymous.
class HadithCommentary {
  const HadithCommentary({
    required this.scholar,
    required this.work,
    required this.text,
    this.reference,
  });

  final String scholar;
  final String work;
  final String text;

  /// Volume and page, where the source file gives one.
  final String? reference;

  static HadithCommentary? fromJson(Map<String, dynamic> json) {
    final scholar = _str(json, const ['scholar', 'author', 'name']);
    final work = _str(json, const ['work', 'book', 'source', 'title']);
    final text = _str(json, const ['text', 'commentary', 'body', 'english']);
    // All three or nothing: commentary without an attributed source is opinion,
    // and opinion presented as scholarship is the thing we refuse to ship.
    if (scholar == null || work == null || text == null) return null;
    return HadithCommentary(
      scholar: scholar,
      work: work,
      text: text,
      reference: _str(json, const ['reference', 'citation', 'page', 'volume']),
    );
  }
}

/// Everything bundled for one hadith beyond its text.
class HadithExtras {
  const HadithExtras({
    this.vocabulary = const [],
    this.commentary = const [],
  });

  final List<HadithGloss> vocabulary;
  final List<HadithCommentary> commentary;

  bool get isEmpty => vocabulary.isEmpty && commentary.isEmpty;

  static const HadithExtras none = HadithExtras();
}

abstract final class HadithExtrasSource {
  static const String _vocabularyDir = 'assets/data/hadith/vocabulary';
  static const String _commentaryDir = 'assets/data/hadith/commentary';

  /// `dir/collection` → number → raw entries. Loaded once per run.
  static final Map<String, Map<String, List<Map<String, dynamic>>>> _cache = {};

  /// Files already looked for and not found, so an absent collection is asked
  /// for once rather than on every hadith page.
  static final Set<String> _absent = {};

  static Future<HadithExtras> load(HadithRef ref) async {
    final vocab = await _entries(_vocabularyDir, ref);
    final comm = await _entries(_commentaryDir, ref);

    return HadithExtras(
      vocabulary: [
        for (final e in vocab)
          if (HadithGloss.fromJson(e) case final g?) g,
      ],
      commentary: [
        for (final e in comm)
          if (HadithCommentary.fromJson(e) case final c?) c,
      ],
    );
  }

  static Future<List<Map<String, dynamic>>> _entries(
    String dir,
    HadithRef ref,
  ) async {
    final byNumber = await _file(dir, ref.collection);
    return byNumber?[ref.number] ?? const [];
  }

  static Future<Map<String, List<Map<String, dynamic>>>?> _file(
    String dir,
    String collection,
  ) async {
    final key = '$dir/$collection';
    if (_absent.contains(key)) return null;
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString('$key.json');
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        _absent.add(key);
        return null;
      }

      final out = <String, List<Map<String, dynamic>>>{};
      for (final entry in decoded.entries) {
        if (entry.key.startsWith('_')) continue;
        final value = entry.value;
        if (value is List) {
          out[entry.key] = [
            for (final item in value)
              if (item is Map) item.cast<String, dynamic>(),
          ];
        } else if (value is Map) {
          out[entry.key] = [value.cast<String, dynamic>()];
        }
      }

      _cache[key] = out;
      return out;
    } catch (_) {
      // Absent is the normal state. Nothing to warn about.
      _absent.add(key);
      return null;
    }
  }
}

String? _str(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
