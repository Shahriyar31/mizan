/// Where an [EntityRef] opens.
///
/// One function decides this for the whole platform, and every connected row,
/// evidence chip and journey step calls it. That is the reason navigation is
/// endless: a widget that has a ref never needs to know what kind of thing it is
/// holding, so a new entity type becomes reachable from everywhere the moment
/// this switch handles it.
///
/// Four of the ten types already had screens before the knowledge layer existed,
/// and those routes are used unchanged — tapping "Adam" from a hadith page lands
/// on the same five-layer story the Discover tab opens, not on a second, thinner
/// version of it. A verse opens the reader at that ayah, where the layers already
/// live. Only the types with no existing home (`theme`, `scholar`, `place`,
/// `journey`, `hadith`) route into `/knowledge/…`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/knowledge/entity_ref.dart';

class KnowledgeRoutes {
  KnowledgeRoutes._();

  static const String themesIndex = '/knowledge/themes';
  static const String journeysIndex = '/knowledge/journeys';
  static const String scholarsIndex = '/knowledge/scholars';
  static const String placesIndex = '/knowledge/places';

  /// The hadith learning section. Not in [indexFor] because it is not the index
  /// of an [EntityType] — `hadith` entities are reached by citation, and this is
  /// the topic-based way in rather than a list of every hadith in the graph.
  static const String hadithTopicsIndex = '/knowledge/hadith-topics';

  static String hadithTopic(String topicId) => '/knowledge/hadith-topic/$topicId';

  /// The index path for a type, where one exists.
  static String? indexFor(EntityType type) => switch (type) {
        EntityType.theme => themesIndex,
        EntityType.journey => journeysIndex,
        EntityType.scholar => scholarsIndex,
        EntityType.place => placesIndex,
        _ => null,
      };

  /// The route that opens [ref], or null when the ref cannot be opened.
  ///
  /// Null happens for exactly one case worth naming: a hadith ref whose id is
  /// missing a collection or a number. An unnumbered citation has nothing to
  /// fetch and nothing to show, so it must not be given a tappable row.
  static String? pathFor(EntityRef ref) {
    switch (ref.type) {
      case EntityType.prophet:
        return '/discover/prophet/${ref.id}';
      case EntityType.sahabi:
        return '/discover/sahabi/${ref.id}';
      case EntityType.seerah:
        return '/discover/seerah/${ref.id}';
      case EntityType.divineName:
        return '/discover/name/${ref.id}';
      case EntityType.verse:
        final surah = ref.verseSurah;
        final ayah = ref.verseAyah;
        if (surah == null) return null;
        return ayah == null ? '/quran/$surah' : '/quran/$surah?ayah=$ayah';
      case EntityType.hadith:
        final collection = ref.hadithCollection;
        final number = ref.hadithNumber;
        if (collection == null || number == null) return null;
        return '/knowledge/hadith/$collection/$number';
      case EntityType.theme:
        return '/knowledge/theme/${ref.id}';
      case EntityType.scholar:
        return '/knowledge/scholar/${ref.id}';
      case EntityType.place:
        return '/knowledge/place/${ref.id}';
      case EntityType.journey:
        return '/knowledge/journey/${ref.id}';
    }
  }

  static bool canOpen(EntityRef ref) => pathFor(ref) != null;

  /// Pushes [ref] onto the stack. `push`, not `go`, on purpose: following a
  /// connection is a step deeper into the graph, and the back button has to
  /// unwind it — Adam → Bukhari 3326 → Creation → Adam is a legitimate walk, and
  /// each hop must be reversible.
  static void open(BuildContext context, EntityRef ref) {
    final path = pathFor(ref);
    if (path == null) return;
    context.push(path);
  }
}
