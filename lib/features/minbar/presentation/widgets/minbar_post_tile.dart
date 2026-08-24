/// MinbarPostTile — one public post on Al-Minbar.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 7 (screen 06 of 08).
/// The public API is unchanged (`view`, `onReact`, `onOpen`) so the feed screen
/// and any future embedder keep working; only the visuals moved onto Mizan tokens.
///
/// ── The comment bubble is gone, on purpose ────────────────────────────
/// The light mockup draws a footer of four items: a heart with 129, a comment
/// bubble with 18, a bookmark with 73, and a gold "Du'a". Three of those cannot
/// exist in this product:
///
///   • **Comments.** Al-Minbar has no text replies, ever — that is a product
///     rule, not a missing feature. The bubble is omitted entirely rather than
///     drawn and disabled, because a greyed-out affordance still promises a
///     thing that is never coming.
///   • **A bookmark count.** Nothing in the schema counts who saved a post.
///   • **A separate "like".** There is no generic like here. The three
///     [ReactionType]s *are* the footer: Du'a, Resonated, Moved.
///
/// So the footer is the three real reactions with their real counts, and a count
/// is only rendered once it is above zero — a row of confident "0"s is a worse
/// lie than a bare icon.
///
/// ── Every post carries a citation by construction ─────────────────────
/// You cannot type a post into Al-Minbar. A share is always a [SharedContent]
/// snapshot of something already in the app, which means it always arrives with
/// `citationSource` attached. That is why the citation line at the foot of the
/// card can be rendered unconditionally: there is no code path that produces an
/// uncited post.
///
/// ── Deleting is the author's own act, and only theirs ──────────────────
/// A post can be withdrawn by the person who published it and by nobody else.
/// The tile does not work that out: it is handed [onDelete] on the reader's own
/// posts and null on everyone else's, so there is no ownership rule in this file
/// to get out of step with the one in the feed and the two repositories. The
/// control is a single icon in the footer next to Open — see [_DeleteButton] for
/// why it is there and not in the author line's absent "..." menu.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/mizan_tokens.dart';
import '../../../../core/theme/mizan_typography.dart';
import '../../../../shared/models/reaction_type.dart';
import '../../../../shared/models/shared_content.dart';
import '../../../../shared/widgets/mizan/mizan_components.dart';
import '../../../../shared/widgets/mizan/mizan_pressable.dart';
import '../../models/minbar_models.dart';

class MinbarPostTile extends StatelessWidget {
  const MinbarPostTile({
    super.key,
    required this.view,
    required this.onReact,
    this.onOpen,
    this.onDelete,
    this.isMine = false,
  });

  final MinbarShareView view;
  final ValueChanged<ReactionType> onReact;

  /// Opens the source content. Null when the share predates route tracking, in
  /// which case the open affordance is hidden rather than dead.
  final VoidCallback? onOpen;

  /// Withdraws this post from the feed. Non-null **only** on posts the current
  /// user wrote: the feed resolves ownership once, where it already knows who is
  /// signed in, and passes null for everyone else's posts. So the tile never
  /// decides who may delete what — it only knows whether it was handed a way to,
  /// which is what keeps the author-only rule in one place instead of restated
  /// in every widget that draws a post.
  final VoidCallback? onDelete;

  /// Renders the author as "You". Resolved by the feed, which already knows the
  /// current user, so the tile stays a plain [StatelessWidget].
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final share = view.share;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorLine(
            name: isMine ? 'You' : share.sharedByName,
            verb: share.content.contentType.shareVerb,
            when: _relativeTime(share.sharedAt),
          ),
          const SizedBox(height: 10),
          _ContentCard(content: share.content),
          const SizedBox(height: 10),
          _ReactionRow(
            view: view,
            onReact: onReact,
            onOpen: onOpen,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  AUTHOR
// ══════════════════════════════════════════════════════════════════════

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({
    required this.name,
    required this.verb,
    required this.when,
  });

  final String name;
  final String verb;
  final String when;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Two token-derived tints so adjacent avatars are distinguishable
            // without inventing a colour: the letter picks the tint, so the same
            // person always gets the same one.
            color: initial.codeUnitAt(0).isEven
                ? p.sunk
                : p.link.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: MizanType.cardHeadline(color: p.muted).copyWith(fontSize: 17),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MizanType.bodyStrong(color: p.ink).copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                '$verb · $when',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
        // The mockup puts a "..." overflow menu here. Nothing that belongs to
        // *other people's* posts sits behind it yet — there is no report
        // endpoint, no follow graph, and no way to delete a post you did not
        // write — so it is still left out. Withdrawing your own post is real,
        // but it lives in the footer with this card's other actions rather than
        // in a menu of one; see [_DeleteButton].
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE CARD
// ══════════════════════════════════════════════════════════════════════

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content});

  final SharedContent content;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      // Flat, hairline only. A feed post holds text, and the shadow rules
      // reserve depth for things you press. The one touchable lives in the
      // footer row beneath the card, not up here.
      tone: MizanTone.card,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeChip(type: content.contentType),
          const SizedBox(height: 14),

          // Rule #6: the Arabic name never stands alone — the English title sits
          // directly beneath it, and the excerpt carries the meaning.
          if ((content.titleArabic ?? '').trim().isNotEmpty) ...[
            Text(
              content.titleArabic!,
              textDirection: TextDirection.rtl,
              style: MizanType.arabic(color: p.accentText, fontSize: 24),
            ),
            const SizedBox(height: 2),
          ],

          if (content.title.trim().isNotEmpty)
            Text(
              content.title,
              style: MizanType.cardHeadline(color: p.ink),
            ),

          if (content.excerpt.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content.excerpt,
              // Quran excerpts are translations, and a translation is Playfair
              // italic per the type scale. Everything else is a plain teaser.
              style: content.contentType == ContentType.quran
                  ? MizanType.translation(color: p.ink)
                  : MizanType.body(color: p.ink).copyWith(fontSize: 15.5),
            ),
          ],

          const SizedBox(height: 16),
          MizanRule(color: p.hairline),
          const SizedBox(height: 12),
          _CitationLine(content: content),
        ],
      ),
    );
  }
}

/// The outlined kind-chip: an icon and the content type in tracked caps. Bronze
/// on cream, gold on navy — Rule #1, since this is text.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    // Quran keeps the calm link colour; everything else takes the gold family,
    // which is how the two mockup cards differ.
    final color = type == ContentType.quran ? p.link : p.accentText;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
          border: Border.all(
            color: color.withValues(alpha: 0.42),
            width: MizanGeometry.hairlineWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.chipIcon, size: 15, color: color),
            const SizedBox(width: 8),
            Text(
              type.chipLabel.toUpperCase(),
              style: MizanType.sectionLabel(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitationLine extends StatelessWidget {
  const _CitationLine({required this.content});

  final SharedContent content;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final detail = (content.citationDetail ?? '').trim();
    final text = detail.isEmpty
        ? content.citationSource
        : '${content.citationSource} · $detail';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sage, not gold: this badge means "sourced", and sage is the palette's
        // one success colour.
        Icon(Icons.verified_outlined, size: 16, color: p.sage),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  FOOTER — reactions left, delete then open far right
// ══════════════════════════════════════════════════════════════════════

/// One row under the card: the three reactions packed to the left, then all the
/// remaining width, then the author's own actions hard against the right edge.
///
/// ── Why the open action moved down here ───────────────────────────────
/// It used to be a bare ↗ arrow in the card's top-right corner, and a bare arrow
/// in a corner reads as "share" — which is the one thing it is not. Al-Minbar
/// posts are snapshots of content that already exists in the app, so there is no
/// re-share: sharing happens on the content's own screen, where the share sheet
/// lives. One entry point per action.
///
/// It now sits at the far right of the footer with the word **Open** next to it,
/// separated from the reactions by a [Spacer] rather than sitting in the same
/// cluster. Reactions and "go read this" are different kinds of act, and putting
/// them shoulder to shoulder made the fourth item look like a fourth reaction.
class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.view,
    required this.onReact,
    this.onOpen,
    this.onDelete,
  });

  final MinbarShareView view;
  final ValueChanged<ReactionType> onReact;

  /// Null when the share predates route tracking. The affordance is then hidden
  /// rather than drawn dead — a button that goes nowhere is worse than no button.
  final VoidCallback? onOpen;

  /// Null on posts that are not the reader's own, which is most of them.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          for (final r in ReactionTypeX.ordered)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ReactionButton(
                reaction: r,
                count: view.countFor(r),
                isMine: view.reactedWith(r),
                onTap: () => onReact(r),
              ),
            ),
          const Spacer(),
          // Delete sits inboard of Open, so the destructive control is never the
          // one closest to the screen edge where a thumb lands by default, and
          // Open keeps the corner it already had.
          if (onDelete != null) _DeleteButton(onTap: onDelete!),
          if (onOpen != null) _OpenButton(onTap: onOpen!),
        ],
      ),
    );
  }
}

/// The author's own withdraw control: one icon, in the footer, on their posts.
///
/// It joins the row the card already keeps its actions in rather than reviving
/// the mockup's "..." menu on the author line. A menu holding exactly one item
/// is a second place to look for something there is only one of, and the footer
/// is where a reader has already learned this card's verbs live.
///
/// Wordless where [_OpenButton] is labelled. Reading a post is the act this feed
/// exists for and deleting one is a rare correction, so the two should not have
/// equal weight; the icon plus its semantic label carries the meaning without
/// putting a standing invitation to delete beside every post. The label is fixed
/// — the same icon and the same words on every post — because a control that
/// renames itself per item has to be re-read each time.
///
/// [AppColors.error] is the codebase's single destructive colour and the only
/// theme-aware one: deep red on cream, soft red on navy (see
/// core/theme/app_colors.dart, which is itself a view onto the Mizan palette).
/// The Mizan spec has no red of its own, and that file says plainly that
/// inventing a "Mizan red" is a design decision to take deliberately — not one
/// to take here, in a feed tile, by hardcoding a hex that would read correctly
/// in only one of the two themes.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MizanPressable(
      onTap: onTap,
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      semanticLabel: 'Delete your post',
      child: Icon(
        Icons.delete_outline_rounded,
        size: 19,
        color: AppColors.error,
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanPressable(
      onTap: onTap,
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      semanticLabel: 'Open this in the app',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Open',
            style: MizanType.bodyStrong(color: p.link).copyWith(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Icon(Icons.north_east_rounded, size: 18, color: p.link),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.reaction,
    required this.count,
    required this.isMine,
    required this.onTap,
  });

  final ReactionType reaction;
  final int count;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    // Colour carries the state, not depth — a reaction you have left reads gold
    // family; one you haven't is the single muted grey.
    final color = isMine ? p.accentText : p.muted;

    return MizanPressable(
      onTap: onTap,
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      semanticLabel: isMine
          ? '${reaction.label} — remove yours'
          : '${reaction.label} — ${reaction.meaning}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMine ? reaction.filledIcon : reaction.outlineIcon,
            size: 20,
            color: color,
          ),
          // Zero is not displayed. An unreacted post shows three bare icons,
          // which is the truth rather than three zeros.
          if (count > 0) ...[
            const SizedBox(width: 7),
            Text(
              '$count',
              style: MizanType.bodyStrong(color: color).copyWith(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SMALL MAPPINGS
// ══════════════════════════════════════════════════════════════════════

extension on ReactionType {
  IconData get outlineIcon => switch (this) {
        ReactionType.dua => Icons.volunteer_activism_outlined,
        ReactionType.resonated => Icons.favorite_border_rounded,
        ReactionType.moved => Icons.auto_awesome_outlined,
      };

  IconData get filledIcon => switch (this) {
        ReactionType.dua => Icons.volunteer_activism_rounded,
        ReactionType.resonated => Icons.favorite_rounded,
        ReactionType.moved => Icons.auto_awesome_rounded,
      };
}

extension on ContentType {
  IconData get chipIcon => switch (this) {
        ContentType.quran => Icons.menu_book_outlined,
        ContentType.hadith => Icons.format_quote_rounded,
        ContentType.sahabi => Icons.person_outline_rounded,
        ContentType.name => Icons.diamond_outlined,
        ContentType.prophet => Icons.auto_stories_outlined,
        ContentType.seerah => Icons.history_edu_outlined,
      };

  /// The chip's wording. `label` alone reads oddly for Quran on a feed card —
  /// the mockup says "QURAN VERSE" — so that one case is spelled out.
  String get chipLabel => switch (this) {
        ContentType.quran => 'Quran verse',
        _ => label,
      };

  /// What the author did, shown under their name. Deliberately not "posted":
  /// the verb should describe an act of engagement, not of broadcasting.
  String get shareVerb => switch (this) {
        ContentType.quran => 'sat with an ayah',
        ContentType.hadith => 'shared a hadith',
        ContentType.sahabi => 'shared a companion’s story',
        ContentType.name => 'reflected on a name of Allah',
        ContentType.prophet => 'shared a prophet story',
        ContentType.seerah => 'shared from the seerah',
      };
}

/// Coarse and deliberately vague past a week — a feed does not need to tell you
/// something happened 37 days ago.
String _relativeTime(DateTime then) {
  final d = DateTime.now().difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  final weeks = d.inDays ~/ 7;
  if (weeks < 5) return '${weeks}w';
  return '${d.inDays ~/ 30}mo';
}
