/// HalaqaScreen — the Halaqa tab.
///
/// Two top-level states, driven entirely by [myHalaqasProvider]:
///   • No circles yet  → an inviting empty state with Create / Join actions.
///   • One or more      → a list of circle cards that tap through to the circle.
///
/// The screen never touches the database — it only watches the provider and
/// opens the two bottom sheets, then navigates into whatever circle they return.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/halaqa_providers.dart';
import '../models/halaqa_models.dart';
import 'widgets/halaqa_sheets.dart';

class HalaqaScreen extends ConsumerWidget {
  const HalaqaScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showCreateHalaqaSheet(context);
    if (created != null && context.mounted) {
      context.push('/halaqa/circle/${created.id}');
    }
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final joined = await showJoinHalaqaSheet(context);
    if (joined != null && context.mounted) {
      context.push('/halaqa/circle/${joined.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myHalaqasProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: circles.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(myHalaqasProvider),
                ),
                data: (list) => list.isEmpty
                    ? _EmptyState(
                        onCreate: () => _create(context, ref),
                        onJoin: () => _join(context, ref),
                      )
                    : _CircleList(
                        circles: list,
                        onCreate: () => _create(context, ref),
                        onJoin: () => _join(context, ref),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حَلَقَة',
              style: AppTypography.arabicDisplay(color: AppColors.jade, size: 20)),
          Text('Halaqa',
              style: AppTypography.displayLarge(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Small circles for reading and reflecting together.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, required this.onJoin});
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.jade.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.jade.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.people_rounded,
                  color: AppColors.jade, size: 38),
            ),
            const SizedBox(height: 24),
            Text('Start your first circle',
                style: AppTypography.displaySmall(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Invite a few people you trust. Share an ayah, a name of Allah, '
              'or a story — and respond with du\'a, not chatter.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Create a circle',
                    style: AppTypography.buttonPrimary()),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onJoin,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Join with a code',
                    style: AppTypography.buttonSecondary(color: AppColors.gold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle list ───────────────────────────────────────────────────
class _CircleList extends StatelessWidget {
  const _CircleList({
    required this.circles,
    required this.onCreate,
    required this.onJoin,
  });

  final List<Halaqa> circles;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniAction(
                icon: Icons.add_rounded,
                label: 'New circle',
                onTap: onCreate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniAction(
                icon: Icons.login_rounded,
                label: 'Join',
                onTap: onJoin,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final h in circles) ...[
          _CircleCard(halaqa: h),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTypography.labelLarge(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleCard extends ConsumerWidget {
  const _CircleCard({required this.halaqa});
  final Halaqa halaqa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(halaqaMemberCountProvider(halaqa.id));

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/halaqa/circle/${halaqa.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_rounded,
                    color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(halaqa.name,
                        style: AppTypography.displaySmall(
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      count.maybeWhen(
                        data: (n) => '$n member${n == 1 ? '' : 's'}',
                        orElse: () => '…',
                      ),
                      style: AppTypography.bodySmall(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text('Could not load your circles',
              style: AppTypography.bodyLarge(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
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
