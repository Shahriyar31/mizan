/// Share target sheet — the one place a piece of content becomes a share.
///
/// Given a [SharedContent] (built by a Qur'an or Discover mapper), this modal
/// lets the user choose where it goes:
///   • Al-Minbar  — the public feed (no note; a public post is the content).
///   • A circle    — one of their Halaqas, with an optional ≤100-char note.
///
/// It's a tiny two-step wizard in a single sheet: choose destination, then (for
/// a circle) add a note and confirm. All writes go through the repositories and
/// the relevant feed provider is invalidated so an open feed refreshes. The
/// sheet shows its own confirmation, so callers just do:
///
///   onShare: () => showShareTargetSheet(context, content)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/shared_content.dart';
import '../../shared/widgets/content_visuals.dart';
import '../halaqa/domain/halaqa_providers.dart';
import '../halaqa/models/halaqa_models.dart';
import '../identity/domain/identity_providers.dart';
import '../minbar/domain/minbar_providers.dart';

Future<void> showShareTargetSheet(BuildContext context, SharedContent content) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(content: content),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.content});
  final SharedContent content;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _note = TextEditingController();
  Halaqa? _selected; // null = choosing destination; set = note step
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _confirm(String destinationLabel) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          content: Text('Shared to $destinationLabel',
              style: AppTypography.bodyMedium(color: AppColors.textPrimary)),
        ),
      );
    Navigator.of(context).pop();
  }

  Future<void> _shareToMinbar() async {
    setState(() => _busy = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      await ref
          .read(minbarRepositoryProvider)
          .shareToMinbar(user: user, content: widget.content);
      ref.invalidate(minbarFeedProvider);
      _confirm('Al-Minbar');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _error();
      }
    }
  }

  Future<void> _shareToCircle(Halaqa circle) async {
    setState(() => _busy = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      final note = _note.text.trim();
      await ref.read(halaqaRepositoryProvider).shareToHalaqa(
            halaqaId: circle.id,
            user: user,
            content: widget.content,
            personalNote: note.isEmpty ? null : note,
          );
      ref.invalidate(halaqaFeedProvider(circle.id));
      _confirm(circle.name);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _error();
      }
    }
  }

  void _error() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          content: Text('Could not share. Please try again.',
              style: AppTypography.bodyMedium(color: AppColors.error)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        // Scrollable so a long list of circles — or the keyboard on the note
        // step — never overflows the sheet on small screens.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _selected == null ? _chooser() : _noteStep(_selected!),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: choose destination ──────────────────────────────────
  Widget _chooser() {
    final circles = ref.watch(myHalaqasProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Share',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _ContentPreview(content: widget.content),
        const SizedBox(height: 20),
        _DestinationTile(
          icon: Icons.campaign_rounded,
          title: 'Al-Minbar',
          subtitle: 'Public — visible to the whole Ummah',
          onTap: _busy ? null : _shareToMinbar,
        ),
        const SizedBox(height: 20),
        Text('YOUR CIRCLES',
            style: AppTypography.labelSmall(color: AppColors.muted)),
        const SizedBox(height: 10),
        circles.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold))),
          ),
          error: (_, __) => Text('Could not load your circles.',
              style: AppTypography.bodySmall(color: AppColors.muted)),
          data: (list) => list.isEmpty
              ? Text(
                  'You\'re not in any circle yet — create one from the Halaqa tab.',
                  style: AppTypography.bodySmall(color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (final h in list) ...[
                      _DestinationTile(
                        icon: Icons.groups_rounded,
                        title: h.name,
                        subtitle: 'Private circle',
                        onTap: _busy ? null : () => setState(() => _selected = h),
                        showChevron: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ── Step 2: optional note for a circle ──────────────────────────
  Widget _noteStep(Halaqa circle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _busy ? null : () => setState(() => _selected = null),
              borderRadius: BorderRadius.circular(99),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Share to ${circle.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.displaySmall(color: AppColors.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ContentPreview(content: widget.content),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          autofocus: true,
          maxLength: AppConstants.personalNoteMaxLength,
          maxLines: 2,
          minLines: 1,
          style: AppTypography.bodyLarge(color: AppColors.textPrimary),
          cursorColor: AppColors.gold,
          decoration: InputDecoration(
            hintText: 'Add a short note (optional)…',
            hintStyle: AppTypography.bodyLarge(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surface,
            counterStyle: AppTypography.caption(color: AppColors.muted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : () => _shareToCircle(circle),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.night))
                : Text('Share to circle',
                    style: AppTypography.buttonPrimary()),
          ),
        ),
      ],
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────────
class _ContentPreview extends StatelessWidget {
  const _ContentPreview({required this.content});
  final SharedContent content;

  @override
  Widget build(BuildContext context) {
    final v = ContentVisuals.of(content.contentType);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: v.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: v.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(v.icon, size: 18, color: v.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.contentType.label.toUpperCase(),
                    style: AppTypography.labelSmall(color: v.accent)),
                const SizedBox(height: 2),
                Text(content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.labelLarge(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge(
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.bodySmall(color: AppColors.muted)),
                  ],
                ),
              ),
              if (showChevron)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
