/// One screen for every kind of entity the graph holds.
///
/// Themes, scholars, places and journeys all open here. The four Discover types
/// keep their own bespoke screens — a prophet's five-layer reader is a better page
/// than any generic one could be — so this screen exists for the types the
/// platform adds, and looks like the rest of the app because it is built from the
/// same hero, the same rows and the same evidence language.
///
/// Nothing on this page is written by hand at runtime. The title, the prose and
/// the citations come from the entity; everything below the fold comes from the
/// relationship engine. A theme page with fourteen entries and a theme page with
/// two are the same code.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/knowledge/entity_ref.dart';
import '../../../core/knowledge/evidence.dart';
import '../../../core/knowledge/hadith_ref.dart';
import '../../../core/knowledge/knowledge_entity.dart';
import '../../../core/knowledge/knowledge_providers.dart';
import '../../../core/knowledge/relation.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../domain/hadith_providers.dart';
import 'knowledge_routes.dart';
import 'widgets/connected_sections.dart';
import 'widgets/evidence_view.dart';
import 'widgets/knowledge_scaffold.dart';

class KnowledgeEntityScreen extends ConsumerWidget {
  const KnowledgeEntityScreen({super.key, required this.entityRef});

  final EntityRef entityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(knowledgeGraphProvider);

    return graph.when(
      loading: () => KnowledgeScaffold(
        hero: KnowledgeHero(
          title: entityRef.type.label,
          eyebrow: entityRef.type.label.toUpperCase(),
        ),
        children: const [KnowledgePlaceholder(title: '', loading: true)],
      ),
      error: (_, __) => KnowledgeScaffold(
        hero: KnowledgeHero(title: entityRef.type.label),
        children: const [
          KnowledgePlaceholder(
            title: 'Not available',
            message: 'This page could not be loaded.',
          ),
        ],
      ),
      data: (g) {
        final entity = g[entityRef];
        if (entity == null) {
          return KnowledgeScaffold(
            hero: KnowledgeHero(
              title: entityRef.type.label,
              eyebrow: entityRef.type.label.toUpperCase(),
            ),
            children: const [
              KnowledgePlaceholder(
                title: 'Nothing here yet',
                message:
                    'This entry has not been written. It is referenced from '
                    'elsewhere in the app, which is why the link exists.',
              ),
            ],
          );
        }

        // Warm the hadith cache for every numbered citation on the page, so
        // tapping one a moment later is instant rather than a wait.
        final hadithRefs = <HadithRef>[
          for (final e in [
            ...entity.evidence,
            for (final s in entity.sections) ...s.evidence,
          ])
            if (e is HadithEvidence && e.ref != null) e.ref!,
        ];
        if (hadithRefs.isNotEmpty) {
          ref.read(hadithRepositoryProvider).prefetch(hadithRefs);
        }

        return KnowledgeScaffold(
          hero: KnowledgeHero(
            title: entity.title,
            titleArabic: entity.titleArabic,
            eyebrow: entity.type.label.toUpperCase(),
            meta: _meta(entity, g.connections(entity.ref).length),
          ),
          children: [
            if (entity.teaser != null && entity.teaser!.trim().isNotEmpty)
              _Teaser(text: entity.teaser!),
            if (entity.metadata.isNotEmpty) _MetadataBlock(entity: entity),
            for (final section in entity.sections) _Section(section: section),
            if (entity.evidence.isNotEmpty) ...[
              const SizedBox(height: 26),
              EvidenceRows(evidence: entity.evidence, label: 'SOURCES'),
            ],
            if (entity.type == EntityType.journey)
              _JourneySteps(entityRef: entity.ref)
            else
              ConnectedSections(entityRef: entity.ref),
          ],
        );
      },
    );
  }

  static String? _meta(KnowledgeEntity entity, int degree) {
    final bits = <String>[];
    if (entity.subtitle != null && entity.subtitle!.trim().isNotEmpty) {
      bits.add(entity.subtitle!.trim());
    }
    if (degree > 0) {
      bits.add('$degree connection${degree == 1 ? '' : 's'}');
    }
    return bits.isEmpty ? null : bits.join(' · ');
  }
}

/// The corpus's own one-liner, set as a lead paragraph.
class _Teaser extends StatelessWidget {
  const _Teaser({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Text(
      text.trim(),
      style: MizanType.body(color: p.ink).copyWith(fontSize: 16.5, height: 1.6),
    );
  }
}

/// Era, school, year, tribe — whatever the type carries, as label/value rows.
///
/// A flat surface with hairline dividers rather than a stack of cards: this is
/// reference detail, not content, and it should not compete with the prose.
class _MetadataBlock extends StatelessWidget {
  const _MetadataBlock({required this.entity});

  final KnowledgeEntity entity;

  static const Map<String, String> _labels = {
    'era': 'Era',
    'years': 'Years',
    'year': 'Year',
    'school': 'School',
    'method': 'Method',
    'region': 'Region',
    'tribe': 'Tribe',
    'group': 'Group',
    'kunyah': 'Kunyah',
    'modern_name': 'Known today as',
    'works': 'Works',
    'entries': 'Entries',
    'steps': 'Steps',
  };

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final entries = entity.metadata.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: MizanSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) MizanRule(color: p.hairline, indent: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(
                        (_labels[entries[i].key] ?? _humanise(entries[i].key))
                            .toUpperCase(),
                        style: MizanType.sectionLabel(color: p.muted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entries[i].value,
                        style: MizanType.body(color: p.ink)
                            .copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _humanise(String key) =>
      key.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');
}

/// One titled block of prose with its citations under it.
class _Section extends StatelessWidget {
  const _Section({required this.section});

  final KnowledgeSection section;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final paragraphs = section.body
        .split(RegExp(r'\n\s*\n|\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        KnowledgeSectionHeader(
          section.title.toUpperCase(),
          trailingText:
              section.layerNumber == null ? null : 'LAYER ${section.layerNumber}',
        ),
        if (section.subtitle != null && section.subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            section.subtitle!.trim(),
            style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
          ),
        ],
        const SizedBox(height: 14),
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Text(
            paragraphs[i],
            style: MizanType.body(color: p.ink).copyWith(height: 1.65),
          ),
        ],
        if (section.evidence.isNotEmpty) ...[
          const SizedBox(height: 18),
          EvidenceRows(evidence: section.evidence),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  JOURNEY MODE
// ══════════════════════════════════════════════════════════════════════

/// A journey's steps, in the curator's order.
///
/// Read from `relationsFor` rather than `connections`, because `connections`
/// sorts for relevance and a journey's whole meaning is its sequence. Each step
/// shows its own entity's teaser — no journey prose was written, which is exactly
/// why these five journeys could ship.
class _JourneySteps extends ConsumerWidget {
  const _JourneySteps({required this.entityRef});

  final EntityRef entityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(knowledgeGraphOrNullProvider);
    if (graph == null) return const SizedBox.shrink();

    final steps = graph
        .relationsFor(entityRef)
        .where((r) => r.kind == RelationKind.journeyIncludes)
        .toList();
    if (steps.isEmpty) return const SizedBox.shrink();

    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        KnowledgeSectionHeader('THE PATH', trailingText: '${steps.length} steps'),
        const SizedBox(height: 12),
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _JourneyStepRow(
            index: i + 1,
            total: steps.length,
            target: steps[i].to,
            note: steps[i].note,
            title: graph[steps[i].to]?.title ?? steps[i].to.id,
            teaser: graph[steps[i].to]?.teaser,
            titleArabic: graph[steps[i].to]?.titleArabic,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Each step opens the entry it points at. The order is the journey; the '
          'words are each entry\'s own.',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
        ),
        // A journey is also connected to its themes, which is worth showing —
        // but its steps are shown above, so the People/Events sections would
        // repeat them. Themes only.
        ConnectedSections(
          entityRef: entityRef,
          heading: null,
          exclude: const {
            EntityType.prophet,
            EntityType.sahabi,
            EntityType.seerah,
            EntityType.divineName,
            EntityType.verse,
            EntityType.hadith,
            EntityType.scholar,
            EntityType.place,
            EntityType.journey,
          },
        ),
      ],
    );
  }
}

class _JourneyStepRow extends StatelessWidget {
  const _JourneyStepRow({
    required this.index,
    required this.total,
    required this.target,
    required this.title,
    this.note,
    this.teaser,
    this.titleArabic,
  });

  final int index;
  final int total;
  final EntityRef target;
  final String title;
  final String? note;
  final String? teaser;
  final String? titleArabic;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final canOpen = KnowledgeRoutes.canOpen(target);

    return MizanRow(
      title: title,
      subtitle: teaser ?? note,
      leading: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.sunk,
            borderRadius: MizanGeometry.rowBorderRadius,
          ),
          child: Center(
            child: Text(
              '$index',
              style: MizanType.bodyStrong(color: p.accentText)
                  .copyWith(fontSize: 15),
            ),
          ),
        ),
      ),
      trailing: titleArabic == null
          ? null
          : Text(
              titleArabic!,
              textDirection: TextDirection.rtl,
              style: MizanType.arabic(color: p.accentText, fontSize: 17),
            ),
      showChevron: canOpen,
      onTap: canOpen ? () => KnowledgeRoutes.open(context, target) : null,
      footer: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Step $index of $total · ${target.type.label}',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
        ),
      ),
    );
  }
}
