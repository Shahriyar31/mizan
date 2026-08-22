/// HalaqaCircleScreen — the inside of one circle.
///
/// Everything a member needs in one scroll: who's here (the member ring), how to
/// invite others (the invite code), a gentle nudge for anyone who's gone quiet,
/// and the feed of shared reflections — each answerable only with the three
/// reactions. It reads four providers (the circle, its members, its quiet
/// members, and its feed) and writes nothing directly; reactions and leaving go
/// through the notifiers, which keeps this screen declarative.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  void _copyInvite(BuildContext context) {
    Clipboard.setData(ClipboardData(text: halaqa.inviteCode));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          content: Text('Invite code copied — share it with a friend.',
              style: AppTypography.bodyMedium(color: AppColors.textPrimary)),
        ),
      );
  }

  void _nudge(BuildContext context, HalaqaMember member) {
    // Symbolic for now (local-first, no push yet). See NudgeCard docs.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          content: Text('${member.displayName} will know they\'re missed. 🤍',
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
                onTap: () => _showMenu(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Members ────────────────────────────────────────
          membersAsync.when(
            loading: () => const SizedBox(height: 74),
            error: (_, __) => const SizedBox.shrink(),
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

  void _showMenu(BuildContext context, WidgetRef ref) {
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
