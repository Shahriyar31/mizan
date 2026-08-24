/// HalaqaCircleScreen — the inside of one circle.
///
/// Everything a member needs in one scroll: who's here (the member ring), how to
/// invite others (the invite code), a gentle nudge for anyone who's gone quiet,
/// and the feed of shared reflections — each answerable only with the three
/// reactions. It reads four providers (the circle, its members, its quiet
/// members, and its feed) and writes nothing directly; reactions, leaving and
/// both deletions go through the notifiers, which keeps this screen declarative.
///
/// ── Who may remove what ───────────────────────────────────────────────
/// Two destructive actions live here, and they are scoped differently on
/// purpose:
///
///   • **Deleting a share** is author-only, and it is self-deletion rather than
///     moderation — there is no way to take down somebody else's reflection. The
///     tile is handed a callback only for shares the viewer wrote.
///   • **Deleting the circle** is creator-only, and sits in the menu beside
///     Leave rather than replacing it.
///
/// Both rules are decided once in this file and enforced again in the
/// repository (and, online, a third time by row-level security). A hidden
/// control is a courtesy, not a permission.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/readable_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../identity/domain/identity_providers.dart';
import '../domain/halaqa_providers.dart';
import '../models/halaqa_models.dart';
import 'widgets/halaqa_share_tile.dart';
import 'widgets/member_ring.dart';
import 'widgets/nudge_card.dart';

class HalaqaCircleScreen extends ConsumerWidget {
  const HalaqaCircleScreen({super.key, required this.halaqaId});

  final String halaqaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final halaqaAsync = ref.watch(halaqaByIdProvider(halaqaId));

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: halaqaAsync.when(
          loading: () =>  Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, _) =>
              _MissingCircle(message: 'Something went wrong loading this circle.'),
          data: (halaqa) => halaqa == null
              ? _MissingCircle(message: 'This circle no longer exists.')
              : _CircleBody(halaqa: halaqa),
        ),
      ),
    );
  }
}

class _CircleBody extends ConsumerWidget {
  const _CircleBody({required this.halaqa});
  final Halaqa halaqa;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Leave “${halaqa.name}”?',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        content: Text(
          'You\'ll stop seeing this circle. If you\'re the last member, the '
          'circle and everything shared in it will be removed.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Stay',
                style: AppTypography.buttonSecondary(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Leave',
                style: AppTypography.buttonSecondary(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(myHalaqasProvider.notifier).leave(halaqa.id);
    if (context.mounted) context.pop();
  }

  /// End the circle for everyone. Offered to the creator only — see [_showMenu].
  ///
  /// Separate from [_leave] rather than a mode of it, because they are different
  /// acts with different consequences and a single control that changed meaning
  /// depending on who tapped it would be the worst version of this.
  Future<void> _deleteCircle(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        // Named, like the leave dialog, because a member of several circles must
        // be able to see *which* one is about to end.
        title: Text('Delete “${halaqa.name}”?',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        // The three facts that make this different from leaving: it is not just
        // you, it takes the contents with it, and there is no undo.
        content: Text(
          'This removes the circle for everyone in it, along with every '
          'reflection shared here and every reaction to them. This cannot be '
          'undone.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep circle',
                style: AppTypography.buttonSecondary(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTypography.buttonSecondary(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(myHalaqasProvider.notifier).deleteCircle(halaqa.id);
    } catch (e) {
      // The likeliest failure is the database missing one of the cascades the
      // delete depends on, which arrives as a raw Postgres foreign-key string.
      // `readableError` logs the real cause and returns a sentence. The screen
      // stays where it is on purpose — the circle is still there, so popping out
      // of it would say the opposite of what happened.
      if (context.mounted) {
        _toast(context, readableError(e, tag: 'HalaqaCircleScreen'));
      }
      return;
    }

    // The circle this screen is built on is gone, so remaining here would render
    // `_MissingCircle` behind a back button. Leave the way [_leave] does.
    if (context.mounted) context.pop();
  }

  /// Remove one of the viewer's own shares. Reached only from a tile the viewer
  /// wrote — the ownership check is in [build], and the repository re-checks
  /// `shared_by` regardless.
  ///
  /// The copy names no ayah, surah or story: it is the same question on every
  /// share, because the control that opened it is the same control on every
  /// share.
  Future<void> _deleteShare(
      BuildContext context, WidgetRef ref, String shareId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Delete this share?',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        content: Text(
          'It will be removed from the circle for everyone, along with any '
          'reactions it has. This cannot be undone.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it',
                style: AppTypography.buttonSecondary(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTypography.buttonSecondary(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // The notifier handles this optimistically and restores the true feed if the
    // write fails, so there is nothing to catch here.
    await ref.read(halaqaFeedProvider(halaqa.id).notifier).deleteShare(shareId);
  }

  /// Copies the whole invite, not just the code — see [Halaqa.inviteMessage] for
  /// why. The toast names what landed on the clipboard, because "copied" after
  /// tapping something labelled with a code would imply it was the code.
  void _copyInvite(BuildContext context) {
    Clipboard.setData(ClipboardData(text: halaqa.inviteMessage));
    _toast(context, 'Invite copied — paste it into any chat.');
  }

  void _nudge(BuildContext context, HalaqaMember member) {
    // Symbolic for now (local-first, no push yet). See NudgeCard docs.
    _toast(context, '${member.displayName} will know they\'re missed. 🤍');
  }

  /// One floating snackbar for every message this screen has to show, so a
  /// confirmation and a failure are told in the same voice and the same place.
  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          content: Text(message,
              style: AppTypography.bodyMedium(color: AppColors.textPrimary)),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(halaqaMembersProvider(halaqa.id));
    final quietAsync = ref.watch(quietMembersProvider(halaqa.id));
    final feedAsync = ref.watch(halaqaFeedProvider(halaqa.id));
    final myId = ref.watch(effectiveUserProvider).value?.id ?? '';

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () => ref.read(halaqaFeedProvider(halaqa.id).notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          // ── Top bar ────────────────────────────────────────
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  halaqa.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.displayMedium(color: AppColors.textPrimary),
                ),
              ),
              _CircleIconButton(
                icon: Icons.more_horiz_rounded,
                onTap: () =>
                    _showMenu(context, ref, isCreator: halaqa.createdBy == myId),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Members ────────────────────────────────────────
          membersAsync.when(
            loading: () => const SizedBox(height: 74),
            error: (e, _) => _MembersError(
              message: readableError(e, tag: 'HalaqaCircleScreen'),
              // The same provider the loading and data paths watch, so the
              // retry reloads exactly what failed.
              onRetry: () => ref.invalidate(halaqaMembersProvider(halaqa.id)),
            ),
            data: (members) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MEMBERS · ${members.length}',
                    style: AppTypography.labelSmall(color: AppColors.muted)),
                const SizedBox(height: 12),
                MemberRing(
                  members: members,
                  createdBy: halaqa.createdBy,
                  currentUserId: myId,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Invite code ────────────────────────────────────
          _InviteCard(code: halaqa.inviteCode, onCopy: () => _copyInvite(context)),

          // ── Nudge (only if someone is quiet) ───────────────
          quietAsync.maybeWhen(
            data: (quiet) => quiet.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: NudgeCard(
                      quiet: quiet,
                      onNudge: (m) => _nudge(context, m),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          Text('SHARED',
              style: AppTypography.labelSmall(color: AppColors.muted)),
          const SizedBox(height: 12),

          // ── Feed ───────────────────────────────────────────
          feedAsync.when(
            loading: () =>  Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
            ),
            error: (e, _) => _FeedError(
              onRetry: () =>
                  ref.read(halaqaFeedProvider(halaqa.id).notifier).refresh(),
            ),
            data: (feed) => feed.isEmpty
                ? const _EmptyFeed()
                : Column(
                    children: [
                      for (final view in feed) ...[
                        HalaqaShareTile(
                          view: view,
                          onReact: (r) => ref
                              .read(halaqaFeedProvider(halaqa.id).notifier)
                              .react(view.share.id, r),
                          onOpen: (view.share.content.routePath?.isNotEmpty ??
                                  false)
                              ? () =>
                                  context.push(view.share.content.routePath!)
                              : null,
                          // The one ownership check in this screen. The tile
                          // stays dumb — it is handed a callback or null and
                          // never learns whose share it is drawing. `myId` is ''
                          // until the user resolves, and no real `sharedBy` can
                          // be empty, so an unresolved viewer offers no delete
                          // rather than offering it on everything.
                          onDelete: view.share.sharedBy == myId
                              ? () => _deleteShare(context, ref, view.share.id)
                              : null,
                        ),
                        const SizedBox(height: 22),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// The circle's menu.
  ///
  /// [isCreator] is passed in rather than re-derived here. `build` already
  /// resolves the current user for the member ring, so deriving it a second time
  /// would mean two comparisons of `createdBy` against two separately-read ids —
  /// which is exactly the shape of bug where a menu offers an action the rest of
  /// the screen believes you cannot take.
  void _showMenu(
    BuildContext context,
    WidgetRef ref, {
    required bool isCreator,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration:  BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading:  Icon(Icons.logout_rounded, color: AppColors.error),
              title: Text('Leave circle',
                  style: AppTypography.labelLarge(color: AppColors.error)),
              onTap: () {
                Navigator.of(context).pop();
                _leave(context, ref);
              },
            ),
            // Creator only, and *in addition* to Leave rather than instead of
            // it: a creator who simply wants out of a circle other people are
            // still using must not have "end it for everybody" as their only
            // exit. Everyone else sees the single row they saw before.
            if (isCreator)
              ListTile(
                leading:
                    Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text('Delete circle',
                    style: AppTypography.labelLarge(color: AppColors.error)),
                // Says who it affects up front, so the difference from the row
                // above it is legible before the confirm dialog, not only in it.
                subtitle: Text('Removes it for everyone',
                    style: AppTypography.caption(color: AppColors.muted)),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteCircle(context, ref);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Invite code card ──────────────────────────────────────────────
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INVITE CODE',
                      style: AppTypography.labelSmall(color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: AppTypography.displaySmall(color: AppColors.gold)
                        .copyWith(letterSpacing: 4),
                  ),
                ],
              ),
              const Spacer(),
               Icon(Icons.copy_rounded, size: 18, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────────
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child:  Icon(Icons.auto_stories_rounded,
                color: AppColors.gold, size: 28),
          ),
          const SizedBox(height: 16),
          Text('Nothing shared yet',
              style: AppTypography.displaySmall(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Open the Qur\'an or Discover, find something that moves you, and '
            'tap Share to post the first reflection here.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// The member strip's failure state, at the height of its loading box.
///
/// This used to be `SizedBox.shrink()`. On any failure the whole strip — label,
/// count and ring — disappeared, and the 74pt box the loading state had been
/// holding collapsed with it, so the screen jumped and the circle read as empty.
/// That is the one conclusion which can never be true here: you have to be a
/// member to be on this screen at all.
///
/// `minHeight` rather than a fixed height on purpose. 74 is what the loaded
/// strip measures, so at a normal text size this renders at exactly 74 and
/// nothing moves; a longer sentence or a large system font grows the box instead
/// of clipping the half of the message that says what to do about it.
class _MembersError extends StatelessWidget {
  const _MembersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 74),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // No count — the label stays so the section is still
                // identifiable, but claiming a number would be inventing one.
                Text('MEMBERS',
                    style: AppTypography.labelSmall(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(message,
                    style:
                        AppTypography.bodyMedium(color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Try again',
                style: AppTypography.buttonSecondary(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          children: [
            Text('Could not load the feed',
                style: AppTypography.bodyLarge(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text('Try again',
                  style: AppTypography.buttonSecondary(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingCircle extends StatelessWidget {
  const _MissingCircle({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
          ),
          const Spacer(),
           Icon(Icons.search_off_rounded,
              color: AppColors.muted, size: 40),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge(color: AppColors.textSecondary)),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
