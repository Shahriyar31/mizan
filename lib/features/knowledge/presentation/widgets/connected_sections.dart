/// Connected sections — Phase 2, and the reason the app stops being a set of
/// separate pages.
///
/// Every entity page ends with the same block: Connected People, Verses, Hadith,
/// Themes, Events, Places. None of it is authored. The graph is asked what is
/// adjacent to this entity and the sections render whatever comes back, in
/// [EntityType] order, each row carrying the *reason* for the connection rather
/// than a generic subtitle. Tapping a row opens that entity, whose page ends with
/// the same block — which is what makes the navigation endless.
///
/// A type with no neighbours renders nothing. An entity with no neighbours at all
/// renders nothing at all, so appending this to an existing screen cannot leave an
/// empty heading behind.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/knowledge/entity_ref.dart';
import '../../../../core/knowledge/knowledge_graph.dart';
import '../../../../core/knowledge/knowledge_providers.dart';
import '../../../../core/branding/mizan_icons.dart';
import '../../../../core/theme/mizan_tokens.dart';
import '../../../../core/theme/mizan_typography.dart';
import '../../../../shared/widgets/mizan/mizan_components.dart';
import '../knowledge_routes.dart';
import 'knowledge_scaffold.dart';

/// How many rows a section shows before it collapses behind "Show all".
const int _kCollapsedRows = 4;

/// Every connected section for one entity.
///
/// Drop this at the bottom of any page that knows its own [EntityRef] — the four
/// existing Discover detail screens do exactly that, and gain the whole graph
/// without changing a line of their own layout above it.
class ConnectedSections extends ConsumerWidget {
  const ConnectedSections({
    super.key,
    required this.entityRef,
    this.exclude = const <EntityType>{},
    this.heading = 'CONNECTED',
  });

  final EntityRef entityRef;

  /// Types to leave out — a verse page suppresses its own "Verses" section
  /// because a run of neighbouring ayat is the reader's job, not the graph's.
  final Set<EntityType> exclude;

  /// The label above the whole block. Null hides it.
  final String? heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(connectionsByTypeProvider(entityRef));
    if (grouped.isEmpty) return const SizedBox.shrink();

    final types = grouped.keys
        .where((t) => !exclude.contains(t) && grouped[t]!.isNotEmpty)
        .toList();
    if (types.isEmpty) return const SizedBox.shrink();

    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null) ...[
          const SizedBox(height: 30),
          Row(
            children: [
              MizanSectionLabel(heading!),
              const SizedBox(width: 12),
              Expanded(child: MizanRule(color: p.hairline)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Drawn from the sources these pages cite.',
            style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
          ),
        ],
        for (final type in types)
          ConnectedSection(
            type: type,
            connections: grouped[type]!,
          ),
      ],
    );
  }
}

/// One section: "CONNECTED COMPANIONS", then its rows.
class ConnectedSection extends StatefulWidget {
  const ConnectedSection({
    super.key,
    required this.type,
    required this.connections,
    this.label,
  });

  final EntityType type;
  final List<Connection> connections;

  /// Overrides "CONNECTED {PLURAL}" where a page words it better.
  final String? label;

  @override
  State<ConnectedSection> createState() => _ConnectedSectionState();
}

class _ConnectedSectionState extends State<ConnectedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final all = widget.connections;
    final showAll = _expanded || all.length <= _kCollapsedRows;
    final shown = showAll ? all : all.take(_kCollapsedRows).toList();
    final indexPath = KnowledgeRoutes.indexFor(widget.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        KnowledgeSectionHeader(
          widget.label ?? 'CONNECTED ${widget.type.pluralLabel.toUpperCase()}',
          trailingText: '${all.length}',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ConnectedRow(connection: shown[i]),
        ],
        if (!showAll) ...[
          const SizedBox(height: 12),
          MizanButton.quiet(
            label: 'Show all ${all.length}',
            onPressed: () => setState(() => _expanded = true),
            expand: true,
          ),
        ],
        // Only offered where the type has an index worth browsing; a verse or a
        // hadith has no index page, so no dead control is drawn.
        if (showAll && indexPath != null && all.length > _kCollapsedRows) ...[
          const SizedBox(height: 10),
          Text(
            'All ${widget.type.pluralLabel.toLowerCase()} are listed under '
            '${widget.type.pluralLabel}.',
            style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

/// One neighbour.
///
/// Title, then the reason for the connection — the edge's own note where it has
/// one ("both cited at Qur'an 2:30"), else the entity's teaser. The relation kind
/// rides on the left as a small label, so a reader can tell a father from a
/// co-citation without opening anything.
class ConnectedRow extends StatelessWidget {
  const ConnectedRow({super.key, required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final entity = connection.entity;
    final reason = connection.reason;
    final canOpen = KnowledgeRoutes.canOpen(entity.ref);

    return MizanRow(
      title: entity.title,
      subtitle: reason == null || reason.trim().isEmpty ? null : reason.trim(),
      leading: knowledgeTypeTile(entity.type),
      showChevron: canOpen,
      onTap: canOpen ? () => KnowledgeRoutes.open(context, entity.ref) : null,
      footer: _RelationNote(connection: connection),
      trailing: entity.titleArabic == null
          ? null
          : Text(
              entity.titleArabic!,
              textDirection: TextDirection.rtl,
              style: MizanType.arabic(color: p.accentText, fontSize: 17),
            ),
    );
  }
}

/// The edge, in words. "Father of · from Qur'an 14:39" — a derived edge says so,
/// because a co-citation is a weaker claim than a stated relationship and the
/// reader is entitled to know which they are looking at.
class _RelationNote extends StatelessWidget {
  const _RelationNote({required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final relation = connection.relation;
    final provenance = relation.provenance;

    final parts = <String>[relation.kind.label];
    if (relation.derived && provenance?.layerTitle != null) {
      parts.add('from “${provenance!.layerTitle}”');
    } else if (!relation.derived && relation.evidence.isNotEmpty) {
      parts.add(relation.evidence.first.label);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            relation.derived
                ? Icons.hub_outlined
                : Icons.check_circle_outline_rounded,
            size: 13,
            color: relation.derived ? p.muted : p.sage,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MizanType.body(color: p.muted).copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 40px leading tile every knowledge row uses — connected sections, the
/// index, hadith topics, hadith detail. It existed as the same six-line
/// `MizanIconTile` copied into four files; now that artwork has to be chosen per
/// type, one copy is the only version that can stay correct.
///
/// A glyph type gets the bordered tile. An artwork type gets the art bare, in a
/// box of the same 40px footprint so rows stay aligned either way. Two reasons
/// not to put the art inside the tile: four of the five marks are *drawn inside a
/// mihrab arch already*, so the tile's hairline becomes a second frame around a
/// frame; and the art needs 28px to resolve (below that `names99` is a faint ring
/// and `prophet` is a smudge — measured on both card colours), which inside a
/// 40px tile leaves 6px of clearance and reads as bursting out of it.
///
/// This cannot produce a visually mixed list, because every list that calls it is
/// single-type: `KnowledgeIndexScreen` takes `required this.type` and lists
/// `g.ofType(type)`, `ConnectedSection` renders exactly one `type`, and the two
/// hadith screens are all hadith.
Widget knowledgeTypeTile(EntityType type) {
  final art = knowledgeTypeArtwork(type);
  if (art != null) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(child: MizanIcon(art, size: 28)),
    );
  }
  return MizanIconTile(
    icon: knowledgeTypeIcon(type),
    circle: false,
    size: 40,
    iconSize: 18,
  );
}

/// One glyph per entity type, used by every connected row, index and search
/// result so the types stay recognisable across the app.
///
/// Four of the ten types also have real brand artwork — see
/// [knowledgeTypeArtwork]. This function stays the fallback for the other six,
/// and stays total so a new [EntityType] is a compile error rather than a blank
/// row.
IconData knowledgeTypeIcon(EntityType type) => switch (type) {
      EntityType.prophet => Icons.brightness_low_outlined,
      EntityType.sahabi => Icons.person_outline_rounded,
      EntityType.seerah => Icons.timeline_outlined,
      EntityType.divineName => Icons.auto_awesome_outlined,
      EntityType.verse => Icons.menu_book_outlined,
      EntityType.hadith => Icons.format_quote_rounded,
      EntityType.theme => Icons.category_outlined,
      EntityType.scholar => Icons.account_balance_outlined,
      EntityType.place => Icons.place_outlined,
      EntityType.journey => Icons.route_outlined,
    };

/// The brand artwork for an entity type, where one of the ten marks in
/// `assets/README.md` actually names it — otherwise null, and the caller falls
/// back to [knowledgeTypeIcon].
///
/// `prophet` the *mark* is the calligraphic محمد in a mihrab arch, so it names
/// the Prophet ﷺ and belongs to [EntityType.seerah] — his life. It is
/// deliberately **not** given to [EntityType.prophet], which is the twenty-five
/// prophets from Adam onward; putting his name beside Nuh or Musa would be a
/// quiet inaccuracy, and inaccuracy about who is being depicted is not the kind
/// of thing this app trades for a nicer-looking row.
///
/// `verse` returns null because a single ayah is not the Quran section, and the
/// `quran` mark says Quran.
MizanIcons? knowledgeTypeArtwork(EntityType type) => switch (type) {
      EntityType.seerah => MizanIcons.prophet,
      EntityType.sahabi => MizanIcons.sahaba,
      EntityType.divineName => MizanIcons.names99,
      EntityType.hadith => MizanIcons.hadith,
      EntityType.prophet => null,
      EntityType.verse => null,
      EntityType.theme => null,
      EntityType.scholar => null,
      EntityType.place => null,
      EntityType.journey => null,
    };
