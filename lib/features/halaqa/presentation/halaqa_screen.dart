/// HALAQA — your private circles.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 6 (screen 05 of 08).
///
/// ── Three things the mockup shows that this product cannot ─────────────
///
///   • **"EXPLORE CIRCLES · Join"** — a public directory of circles you can
///     browse and join. That contradicts the product rule directly: a halaqa is
///     2–8 people joined by invite code, and it is private. A browsable list
///     would make every circle discoverable by strangers. The section is gone,
///     and the navy panel at the foot of the screen now says plainly that
///     circles are invite-only, so its absence reads as a decision rather than
///     an oversight.
///
///   • **"Next session today, 8:30 PM · 3 going"** — there is no session model
///     and no RSVP anywhere in the schema. [Halaqa] carries id, name, creator,
///     invite code, member cap and creation date; that is all. The row's footer
///     slot instead shows the **invite code**, which is real, is the one thing
///     you actually need from this screen, and is what a member would otherwise
///     have to open the circle to find.
///
///   • **"5 members · Fajr reading"** — the member count is real
///     ([halaqaMemberCountProvider]); a per-circle topic or focus is not a field
///     that exists. The subtitle shows the count against the cap instead —
///     "5 of 8 members" — because the cap is the constraint people actually run
///     into when inviting.
///
/// ── The hadith card is deliberately empty-handed ──────────────────────
/// The mockup ends on a navy card quoting "A people do not gather to remember
/// Allah without mercy enveloping them. — Muslim 2699". That hadith is not in
/// `assets/data`, and mockup copy is not a source, so rendering it would mean
/// publishing a hadith and a grade this app cannot verify. The slot is kept and
/// filled with something true instead — how a halaqa works. Supply the verified
/// text and grade and it swaps in with a single edit.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/readable_error.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../../shared/widgets/mizan/mizan_pressable.dart';
import '../domain/halaqa_providers.dart';
import '../models/halaqa_models.dart';
import 'widgets/halaqa_sheets.dart';

class HalaqaScreen extends ConsumerWidget {
  const HalaqaScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final created = await showCreateHalaqaSheet(context);
    if (created != null && context.mounted) {
      context.push('/halaqa/circle/${created.id}');
    }
  }

  Future<void> _join(BuildContext context) async {
    final joined = await showJoinHalaqaSheet(context);
    if (joined != null && context.mounted) {
      context.push('/halaqa/circle/${joined.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final circles = ref.watch(myHalaqasProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        // Stack clips to its own bounds, so the oversized arch bleeding off the
        // right edge is trimmed rather than causing an overflow.
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -70,
              child: SizedBox(
                width: 260,
                height: 340,
                // Rule #2: the arch outline is how a screen gets texture without
                // spending its one image.
                child: MizanArch(color: p.accent, rings: 2, opacity: 0.22),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(
                MizanGeometry.gutter,
                10,
                MizanGeometry.gutter,
                MizanGeometry.scrollBottomPadding,
              ),
              children: [
                const _Header(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: MizanButton(
                        label: 'New circle',
                        icon: Icons.add_rounded,
                        kind: MizanButtonKind.primary,
                        expand: true,
                        onPressed: () => _create(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MizanButton(
                        label: 'Join',
                        icon: Icons.login_rounded,
                        kind: MizanButtonKind.secondary,
                        expand: true,
                        onPressed: () => _join(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const MizanSectionLabel('Your circles'),
                const SizedBox(height: 10),
                ...switch (circles) {
                  AsyncData(:final value) when value.isEmpty => const [
                      _NoCirclesYet(),
                    ],
                  AsyncData(:final value) => [
                      for (final halaqa in value) ...[
                        _CircleCard(halaqa: halaqa),
                        const SizedBox(height: 12),
                      ],
                    ],
                  // The sentence, not the exception. `readableError` logs the
                  // real cause on its way past — see
                  // core/errors/readable_error.dart.
                  AsyncError(:final error) => [
                      _CirclesError(
                        message: readableError(error, tag: 'HalaqaScreen'),
                        onRetry: () => ref.invalidate(myHalaqasProvider),
                      ),
                    ],
                  _ => const [_CirclesLoading()],
                },
                const SizedBox(height: 22),
                const _HowItWorks(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bronze on cream, gold on navy (Rule #1), and the transliteration sits
        // on the very next line (Rule #6).
        Text(
          'حَلْقَة',
          textDirection: TextDirection.rtl,
          style: MizanType.arabic(color: p.accentText, fontSize: 22),
        ),
        const SizedBox(height: 2),
        Text('Halaqa', style: MizanType.screenTitle(color: p.ink)),
        const SizedBox(height: 4),
        Text(
          'Small circles for reading and reflecting together.',
          style: MizanType.body(color: p.muted),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ONE CIRCLE
// ══════════════════════════════════════════════════════════════════════

class _CircleCard extends ConsumerWidget {
  const _CircleCard({required this.halaqa});

  final Halaqa halaqa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final count = ref.watch(halaqaMemberCountProvider(halaqa.id)).valueOrNull;

    return MizanRow(
      title: halaqa.name,
      // Until the count lands, say nothing about it rather than guessing at one.
      subtitle: count == null
          ? 'Opening…'
          : '$count of ${halaqa.maxMembers} members',
      leading: MizanIconTile(
        icon: Icons.people_outline_rounded,
        circle: false,
        semanticLabel: halaqa.name,
      ),
      onTap: () => context.push('/halaqa/circle/${halaqa.id}'),
      footer: _InviteCodeLine(code: halaqa.inviteCode),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
    );
  }
}

/// The invite code, tappable to copy. This is the honest occupant of the slot
/// the mockup gave to "Next session today, 8:30 PM".
class _InviteCodeLine extends StatelessWidget {
  const _InviteCodeLine({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanPressable(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: p.ink,
            content: Text(
              'Invite code copied',
              style: MizanType.body(color: p.page),
            ),
          ),
        );
      },
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.rowRadius),
      padding: EdgeInsets.zero,
      semanticLabel: 'Invite code $code, tap to copy',
      child: Row(
        children: [
          Icon(Icons.key_outlined, size: 17, color: p.sage),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Invite code · $code',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
            ),
          ),
          Icon(Icons.copy_rounded, size: 16, color: p.muted),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HOW IT WORKS — the navy panel
// ══════════════════════════════════════════════════════════════════════

/// Occupies the slot the mockup reserved for a hadith. Everything stated here is
/// a product rule, so it needs no citation — and the "no replies" line is the one
/// thing about this feature a new user will not expect.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;

    return MizanSurface(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MizanSectionLabel('How a halaqa works', onInverse: true),
          const SizedBox(height: 12),
          const _Point(
            tone: tone,
            text: 'Two to eight people, and only by invite code. '
                'Circles are never listed publicly.',
          ),
          const SizedBox(height: 10),
          const _Point(
            tone: tone,
            text: 'Share an ayah or a story with one short note, '
                'a hundred characters at most.',
          ),
          const SizedBox(height: 10),
          const _Point(
            tone: tone,
            text: 'Answer with Du’a, Resonated or Moved. '
                'There are no replies here — that is on purpose.',
          ),
          const SizedBox(height: 14),
          MizanRule(color: tone.hairlineOn(p)),
          const SizedBox(height: 12),
          Text(
            'Al-Minbar is the public one. This is not.',
            style: MizanType.translation(color: tone.mutedOn(p)),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.tone, required this.text});

  final MizanTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The diamond is gold on navy, which is exactly what Rule #1 permits.
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: MizanDiamond(size: 6, color: p.accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: MizanType.body(color: tone.onColor(p)),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  NON-CONTENT STATES
// ══════════════════════════════════════════════════════════════════════

class _NoCirclesYet extends StatelessWidget {
  const _NoCirclesYet();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return MizanSurface(
      tone: MizanTone.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are not in a circle yet.',
            style: MizanType.cardHeadline(color: p.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Start one and send the invite code to a few people you '
            'already read with, or enter a code someone sent you.',
            style: MizanType.translation(color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _CirclesLoading extends StatelessWidget {
  const _CirclesLoading();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
        ),
      ),
    );
  }
}

class _CirclesError extends StatelessWidget {
  const _CirclesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return MizanSurface(
      tone: MizanTone.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your circles could not be loaded.',
            style: MizanType.bodyStrong(color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(message, style: MizanType.body(color: p.muted)),
          const SizedBox(height: 14),
          MizanButton(
            label: 'Try again',
            kind: MizanButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
