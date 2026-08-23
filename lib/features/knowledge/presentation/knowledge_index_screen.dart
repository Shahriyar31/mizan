/// The index screens — Themes, Journeys, Scholars, Places.
///
/// One screen, four configurations, because the four lists differ only in their
/// wording and their sort. Each row shows what the entity is and how much the
/// graph has on it, so a theme with fourteen entries reads differently from one
/// with two before you open either.
///
/// Counts come from the graph, never from a stored number, so they cannot drift
/// out of date when the corpus grows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/knowledge/entity_ref.dart';
import '../../../core/knowledge/knowledge_entity.dart';
import '../../../core/knowledge/knowledge_providers.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import 'knowledge_routes.dart';
import 'widgets/connected_sections.dart';
import 'widgets/knowledge_scaffold.dart';

class KnowledgeIndexScreen extends ConsumerWidget {
  const KnowledgeIndexScreen({super.key, required this.type});

  final EntityType type;

  /// The one line under each index title. Written once here rather than in four
  /// screens, and phrased to describe how the list is produced — a theme page is
  /// aggregated, not authored, and saying so is part of being honest about it.
  String get _blurb => switch (type) {
        EntityType.theme =>
          'Each theme gathers every prophet, companion, event and name whose '
              'sources speak to it.',
        EntityType.journey =>
          'A journey is an ordered path through entries that already exist. The '
              'sequence is curated; the words are each entry\'s own.',
        EntityType.scholar =>
          'The scholars whose commentary the app cites, and what they are cited '
              'on.',
        EntityType.place =>
          'The places the seerah and the stories name, with the events that '
              'happened at each.',
        _ => '',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final graph = ref.watch(knowledgeGraphProvider);

    return KnowledgeScaffold(
      hero: KnowledgeHero(
        title: type.pluralLabel,
        eyebrow: 'KNOWLEDGE',
        meta: graph.maybeWhen(
          data: (g) {
            final n = g.ofType(type).length;
            return '$n ${n == 1 ? type.label.toLowerCase() : type.pluralLabel.toLowerCase()}';
          },
          orElse: () => null,
        ),
      ),
      children: [
        Text(
          _blurb,
          style: MizanType.body(color: p.muted).copyWith(height: 1.55),
        ),
        const SizedBox(height: 22),
        graph.when(
          loading: () => const KnowledgePlaceholder(title: '', loading: true),
          error: (_, __) => const KnowledgePlaceholder(
            title: 'Not available',
            message: 'This list could not be loaded.',
          ),
          data: (g) {
            final items = g.ofType(type);
            if (items.isEmpty) {
              return KnowledgePlaceholder(
                title: 'Nothing here yet',
                message: 'No ${type.pluralLabel.toLowerCase()} have been added.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _IndexRow(
                    entity: items[i],
                    degree: g.connections(items[i].ref).length,
                    type: type,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IndexRow extends StatelessWidget {
  const _IndexRow({
    required this.entity,
    required this.degree,
    required this.type,
  });

  final KnowledgeEntity entity;
  final int degree;
  final EntityType type;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    // What the count means differs by type, and a bare number would be
    // meaningless: a journey has steps, a theme has entries.
    final countLabel = switch (type) {
      EntityType.journey => '$degree steps',
      EntityType.theme => '$degree entries',
      EntityType.scholar => '$degree citations',
      EntityType.place => '$degree connections',
      _ => '$degree',
    };

    return MizanRow(
      title: entity.title,
      subtitle: entity.teaser ?? entity.subtitle,
      leading: MizanIconTile(
        icon: knowledgeTypeIcon(entity.type),
        circle: false,
        size: 40,
        iconSize: 18,
      ),
      trailing: entity.titleArabic == null
          ? null
          : Text(
              entity.titleArabic!,
              textDirection: TextDirection.rtl,
              style: MizanType.arabic(color: p.accentText, fontSize: 17),
            ),
      onTap: () => KnowledgeRoutes.open(context, entity.ref),
      footer: degree == 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                countLabel,
                style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
              ),
            ),
    );
  }
}
