/// The ten doors into the hadith corpus.
///
/// The brief is explicit that this is not a reader: "DO NOT create a generic
/// Hadith reader. DO NOT simply show collections. Use topic-based discovery."
/// A collection list answers "which book?", which is a question only somebody who
/// already knows the answer can ask. A topic list answers "what did the Prophet ﷺ
/// say about patience?", which is the question a learner actually has.
///
/// Each topic is a *query*, not a curated list of hadith numbers. That is a
/// deliberate constraint of the Citation Lock: hand-picking hadiths per topic
/// would mean this file asserting that a particular narration belongs under
/// "Character", which is a scholarly claim we are not sourced to make. Searching
/// the collections and showing what the collections return keeps the attribution
/// with the collection, where it belongs, and every result carries its own
/// citation.
///
/// [themeId] links a topic to the theme the knowledge graph already derives from
/// the corpus, so "Patience" in hadith and "Patience" (`sabr`) in the graph are
/// the same door seen from two sides. Five of the ten have a theme today; the
/// other five carry null rather than a theme invented to fill the column.
library;

import 'package:flutter/material.dart';

class HadithTopic {
  const HadithTopic({
    required this.id,
    required this.title,
    required this.titleArabic,
    required this.blurb,
    required this.queries,
    required this.icon,
    this.themeId,
  });

  final String id;
  final String title;
  final String titleArabic;

  /// What this door opens onto. Describes the search, never the ruling.
  final String blurb;

  /// Search terms, tried in order until one returns results. English, because
  /// the searchable field on these collections is the translation.
  final List<String> queries;

  final IconData icon;

  /// The graph theme this topic corresponds to, where one exists.
  final String? themeId;

  /// The term shown to the reader as the one that produced the results.
  String get primaryQuery => queries.first;
}

abstract final class HadithTopics {
  static const List<HadithTopic> all = [
    HadithTopic(
      id: 'faith',
      title: 'Faith & Tawheed',
      titleArabic: 'الإيمان والتوحيد',
      blurb:
          'Narrations on belief, the oneness of Allah, and what faith asks of '
          'the one who holds it.',
      queries: ['faith', 'belief', 'oneness', 'worship'],
      icon: Icons.light_mode_outlined,
      themeId: 'tawheed',
    ),
    HadithTopic(
      id: 'prayer',
      title: 'Prayer',
      titleArabic: 'الصلاة',
      blurb:
          'How the Prophet ﷺ prayed, and what the collections record about its '
          'place in a day.',
      queries: ['prayer', 'prostration', 'congregation'],
      icon: Icons.self_improvement,
    ),
    HadithTopic(
      id: 'patience',
      title: 'Patience',
      titleArabic: 'الصبر',
      blurb:
          'Narrations on endurance, hardship, and holding steady when a thing '
          'does not pass quickly.',
      queries: ['patience', 'patient', 'affliction'],
      icon: Icons.hourglass_empty,
      themeId: 'sabr',
    ),
    HadithTopic(
      id: 'knowledge',
      title: 'Knowledge',
      titleArabic: 'العلم',
      blurb:
          'Seeking it, carrying it, teaching it, and the warnings about speaking '
          'without it.',
      queries: ['knowledge', 'learn', 'teach'],
      icon: Icons.menu_book_outlined,
      themeId: 'ilm',
    ),
    HadithTopic(
      id: 'character',
      title: 'Character',
      titleArabic: 'الأخلاق',
      blurb:
          'Truthfulness, anger, modesty, the tongue — the narrations about how a '
          'believer behaves.',
      queries: ['character', 'manners', 'truthful', 'modesty'],
      icon: Icons.volunteer_activism_outlined,
    ),
    HadithTopic(
      id: 'repentance',
      title: 'Repentance',
      titleArabic: 'التوبة',
      blurb: 'Turning back, seeking forgiveness, and what the collections record '
          'about being met halfway.',
      queries: ['repentance', 'repent', 'forgiveness'],
      icon: Icons.autorenew,
      themeId: 'tawbah',
    ),
    HadithTopic(
      id: 'family',
      title: 'Family',
      titleArabic: 'الأسرة',
      blurb:
          'Parents, spouses, children and kin — the narrations on the people '
          'nearest to a person.',
      queries: ['parents', 'mother', 'children', 'kinship'],
      icon: Icons.family_restroom,
    ),
    HadithTopic(
      id: 'leadership',
      title: 'Leadership',
      titleArabic: 'الإمارة',
      blurb:
          'Authority as responsibility: the narrations on ruling, consulting, '
          'and being answerable.',
      queries: ['leader', 'ruler', 'authority', 'shepherd'],
      icon: Icons.flag_outlined,
      themeId: 'leadership',
    ),
    HadithTopic(
      id: 'companions',
      title: 'Companions',
      titleArabic: 'الصحابة',
      blurb:
          'What the collections record about the generation that heard the '
          'Prophet ﷺ directly.',
      queries: ['companions', 'ansar', 'muhajirun'],
      icon: Icons.people_outline,
    ),
    HadithTopic(
      id: 'signs',
      title: 'Signs of the Hour',
      titleArabic: 'أشراط الساعة',
      blurb:
          'The narrations on what precedes the Hour, reported as they were '
          'reported and no further.',
      queries: ['the hour', 'resurrection', 'signs'],
      icon: Icons.access_time,
    ),
  ];

  static HadithTopic? byId(String? id) {
    if (id == null) return null;
    final needle = id.toLowerCase();
    for (final t in all) {
      if (t.id == needle) return t;
    }
    return null;
  }

  /// The topic that carries [themeId], so a theme page can offer "hadith on
  /// this theme" without keeping its own mapping.
  static HadithTopic? forTheme(String themeId) {
    for (final t in all) {
      if (t.themeId == themeId) return t;
    }
    return null;
  }
}
