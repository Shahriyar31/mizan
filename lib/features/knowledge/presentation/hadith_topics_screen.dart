/// The hadith learning section — ten topics, not eleven books.
///
/// The brief is explicit: "DO NOT create a generic Hadith reader. DO NOT simply
/// show collections. Use topic-based discovery." So there is no collection
/// browser here and no chapter tree. A reader arrives with a question — patience,
/// prayer, character — picks the door that matches it, and every row they land on
/// is a full citation that opens the existing hadith page.
///
/// Two screens, both built from the components the rest of the knowledge platform
/// uses, so this section is visibly part of the app rather than a bolted-on
/// module:
///
///  - [HadithTopicsScreen], the index of ten.
///  - [HadithTopicScreen], one topic's results, with a way across into the
///    knowledge graph's theme page where the topic has a theme.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/knowledge/entity_ref.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../data/hadith_record.dart';
import '../data/hadith_search_repository.dart';
import '../data/hadith_topic.dart';
import '../domain/hadith_providers.dart';
import 'knowledge_routes.dart';
import 'widgets/connected_sections.dart';
import 'widgets/knowledge_scaffold.dart';

class HadithTopicsScreen extends ConsumerWidget {
  const HadithTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final saved = ref.watch(savedHadithCountProvider).valueOrNull ?? 0;

    return KnowledgeScaffold(
      hero: KnowledgeHero(
        title: 'Hadith',
        titleArabic: 'الحديث',
        eyebrow: 'LEARN',
        meta: saved == 0
            ? '${HadithTopics.all.length} topics'
            : '${HadithTopics.all.length} topics · $saved saved',
      ),
      children: [
        Text(
          'Start from what you are asking about. Each topic searches the '
          'collections themselves, so every result arrives with the citation '
          'you can check it by.',
          style: MizanType.body(color: p.muted).copyWith(height: 1.55),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < HadithTopics.all.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _TopicRow(topic: HadithTopics.all[i]),
        ],
      ],
    );
  }
}

class _TopicRow extends ConsumerWidget {
  const _TopicRow({required this.topic});

  final HadithTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    // Zero here is measured, never assumed: the map holds only topics that have
    // actually been searched this session. A topic the service has nothing for is
    // labelled rather than left looking like a broken link, and it is never
    // filled with narrations the app chose for itself.
    final known = ref.watch(hadithTopicCountsProvider)[topic.id];
    final empty = known == 0;

    return MizanRow(
      title: topic.title,
      subtitle: topic.titleArabic,
      leading: MizanIconTile(
        icon: topic.icon,
        circle: false,
        size: 42,
        iconSize: 19,
      ),
      trailing: empty
          ? Text(
              'none available',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 11.5),
            )
          : null,
      onTap: () => context.push(KnowledgeRoutes.hadithTopic(topic.id)),
    );
  }
}

/// One topic's results.
class HadithTopicScreen extends ConsumerWidget {
  const HadithTopicScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final topic = HadithTopics.byId(topicId);

    if (topic == null) {
      return const KnowledgeScaffold(
        hero: KnowledgeHero(title: 'Topic', eyebrow: 'HADITH'),
        children: [
          KnowledgePlaceholder(
            title: 'Unknown topic',
            message: 'This topic is not one of the ten.',
          ),
        ],
      );
    }

    final results = ref.watch(hadithTopicOutcomeProvider(topic.id));

    return KnowledgeScaffold(
      hero: KnowledgeHero(
        title: topic.title,
        titleArabic: topic.titleArabic,
        eyebrow: 'HADITH',
        meta: results.valueOrNull == null
            ? null
            : '${results.valueOrNull!.records.length} narrations',
      ),
      children: [
        Text(
          topic.blurb,
          style: MizanType.body(color: p.ink).copyWith(height: 1.6),
        ),

        // The way across into the graph. Present only where the corpus already
        // derives a theme of the same name, so the two never disagree about
        // whether a theme exists.
        if (topic.themeId != null) ...[
          const SizedBox(height: 14),
          MizanRow(
            title: 'This theme across the app',
            subtitle: 'Verses, stories and people on ${topic.title.toLowerCase()}',
            leading: const MizanIconTile(
              icon: Icons.hub_outlined,
              circle: false,
              size: 42,
              iconSize: 19,
            ),
            onTap: () => KnowledgeRoutes.open(
              context,
              EntityRef(EntityType.theme, topic.themeId!),
            ),
          ),
        ],

        const SizedBox(height: 26),
        const KnowledgeSectionHeader('NARRATIONS'),
        const SizedBox(height: 12),
        results.when(
          loading: () => const KnowledgePlaceholder(title: '', loading: true),
          error: (_, __) => const KnowledgePlaceholder(
            title: 'Search unavailable',
            message:
                'The hadith service could not be reached. Anything already '
                'saved on this device is still readable from the saved list.',
          ),
          data: (outcome) => outcome.isEmpty
              ? _NoResults(topic: topic, outcome: outcome)
              : _Results(items: outcome.records),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.items});

  final List<HadithRecord> items;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          MizanRow(
            title: items[i].display,
            subtitle: _snippet(items[i]),
            leading: MizanIconTile(
              icon: knowledgeTypeIcon(EntityType.hadith),
              circle: false,
              size: 40,
              iconSize: 18,
            ),
            onTap: () =>
                KnowledgeRoutes.open(context, items[i].ref.entityRef),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'These are the collections\' own results for this term, in their own '
          'order. Nothing here is ranked or selected by the app.',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
        ),
      ],
    );
  }

  /// A first line, not a paragraph. [MizanRow] does not clamp its subtitle, and a
  /// full narration in a list row would bury the citation above it.
  static String? _snippet(HadithRecord record) {
    final text = record.english?.trim();
    if (text == null || text.isEmpty) return null;
    final flat = text.replaceAll(RegExp(r'\s+'), ' ');
    if (flat.length <= 110) return flat;
    return '${flat.substring(0, 109).trimRight()}…';
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.topic, required this.outcome});

  final HadithTopic topic;
  final HadithTopicOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    // Three different situations, three different sentences. "Nothing returned"
    // over all of them was the state that hid a real defect for a day: the
    // service was answering with narrations the app was silently discarding.
    final String headline;
    final String body;
    if (outcome.unreachable) {
      headline = 'Search unavailable';
      body = 'The hadith service could not be reached for this topic. Anything '
          'already saved on this device is still readable from the saved list.';
    } else if (outcome.droppedEverything) {
      headline = 'Nothing citable returned';
      body = 'The service answered for "${topic.primaryQuery}", but none of what '
          'it sent carried both a collection and a hadith number. A narration '
          'this app cannot let you check is one it does not show, and it will '
          'not invent the reference to make the list look full.';
    } else {
      headline = 'Nothing returned';
      body = 'The service returned no narrations for "${topic.primaryQuery}". '
          'The app does not fill a gap like this with text of its own — a '
          'hadith it cannot fetch is a hadith it does not show.';
    }

    return MizanSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_off_outlined, size: 17, color: p.muted),
              const SizedBox(width: 9),
              Text(headline, style: MizanType.bodyStrong(color: p.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: MizanType.body(color: p.muted).copyWith(height: 1.55),
          ),

          // Debug only, and worth its space: this is the line that says whether
          // the fault is upstream or ours.
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Text(
              [
                for (final a in outcome.attempts) '${a.term} → ${a.summary}',
              ].join('\n'),
              style: MizanType.body(color: p.muted).copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
