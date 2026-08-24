/// GROWTH — what you have learned, kept privately.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 8 (screen 07 of 08).
///
/// ── Rule #4 is the whole design of this screen ─────────────────────────
/// Nothing here totals, ranks, grades or congratulates. That is not a stylistic
/// preference; a screen that scores worship teaches the user to perform for the
/// score. So the five rows describe *where things live*, and the only figures on
/// the screen are:
///
///   • **the word count** — an inventory, not an achievement; it says how much is
///     in your bank, the way a library says how many books it holds, and
///     [vocabCountProvider] reads it straight from the table.
///   • **days, Fridays and Ramadans lived** — time *given to you*, which is the
///     premise of Al-Meezan. Nothing is claimed about what you did with it.
///
/// There is deliberately no streak, no percentage, no "6 of 7 days", and no
/// weekly chart, even though the data for a streak exists in `StreakStore`.
///
/// ── Scholar AI is drawn locked because it is locked ────────────────────
/// The mockup gives it a lock glyph, and that is accurate: `ScholarAiService` is
/// a stub and there is no `/growth/scholar` route to send anyone to. It is kept
/// visible with an honest explanation rather than hidden — the promise it makes
/// (every answer cites a verified source) is the reason it is not shipped yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/mizan_icons.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../domain/meezan_summary.dart';
import '../domain/vocab_providers.dart';

class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MizanGeometry.gutter,
            10,
            MizanGeometry.gutter,
            MizanGeometry.scrollBottomPadding,
          ),
          children: const [
            _Header(),
            SizedBox(height: 22),
            _VocabularyRow(),
            SizedBox(height: 12),
            _GrowthMapRow(),
            SizedBox(height: 12),
            _ScholarAiRow(),
            SizedBox(height: 12),
            _MuhasabahRow(),
            SizedBox(height: 12),
            _AlMeezanRow(),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bronze on cream, gold on navy — Rule #1, because this is text.
              // The transliterated English sits on the very next line, Rule #6.
              Text(
                'النُّمُوّ',
                textDirection: TextDirection.rtl,
                style: MizanType.arabic(color: p.accentText, fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text('Growth', style: MizanType.screenTitle(color: p.ink)),
              const SizedBox(height: 4),
              Text(
                'Your knowledge and practice, kept privately.',
                style: MizanType.body(color: p.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        MizanIconTile(
          // Artwork, not `Icons.settings_outlined` — Settings is one of the ten
          // things with a real mark. 24 rather than the tile's default 20: the
          // art has internal detail a gear glyph does not.
          artwork: MizanIcons.settings,
          iconSize: 24,
          circle: true,
          semanticLabel: 'Settings',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE FIVE ROWS
// ══════════════════════════════════════════════════════════════════════

class _VocabularyRow extends ConsumerWidget {
  const _VocabularyRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final count = ref.watch(vocabCountProvider).valueOrNull;

    return MizanRow(
      title: 'Vocabulary Bank',
      // Silent until the count arrives, and a different sentence when the bank is
      // empty — "0 words saved" invites a feeling about nothing having happened.
      subtitle: switch (count) {
        null => 'Words you saved while reading',
        0 => 'Save a word from any ayah and it starts here',
        1 => '1 word saved · spaced repetition active',
        final n => '${groupThousands(n)} words saved · spaced repetition active',
      },
      leading: const MizanIconTile(
        icon: Icons.translate_rounded,
        circle: false,
        semanticLabel: 'Vocabulary Bank',
      ),
      onTap: () => context.push('/growth/vocab'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The badge is an inventory figure, so it is stated plainly on navy and
          // never coloured as a reward.
          if (count != null && count > 0) ...[
            _CountBadge(count: count),
            const SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
        ],
      ),
    );
  }
}

class _GrowthMapRow extends StatelessWidget {
  const _GrowthMapRow();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanRow(
      title: 'Growth Map',
      subtitle: 'Your knowledge and practice, drawn as a night sky',
      leading: const MizanIconTile(
        icon: Icons.auto_awesome_outlined,
        circle: false,
        semanticLabel: 'Growth Map',
      ),
      onTap: () => context.push('/growth/map'),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
    );
  }
}

/// Locked, and says so. No route exists and the service behind it is a stub, so
/// tapping opens an explanation rather than a dead end.
class _ScholarAiRow extends StatelessWidget {
  const _ScholarAiRow();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanRow(
      title: 'Scholar AI',
      subtitle: 'Not open yet — every answer will cite a verified source',
      leading: const MizanIconTile(
        icon: Icons.school_outlined,
        circle: false,
        semanticLabel: 'Scholar AI',
      ),
      onTap: () => _showScholarLocked(context),
      trailing: Icon(Icons.lock_outline_rounded, size: 20, color: p.muted),
    );
  }
}

class _MuhasabahRow extends StatelessWidget {
  const _MuhasabahRow();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanRow(
      title: 'Muhasabah',
      subtitle: 'Nightly three-question self-reckoning — private forever',
      leading: const MizanIconTile(
        icon: Icons.nights_stay_outlined,
        circle: false,
        semanticLabel: 'Muhasabah',
      ),
      onTap: () => context.push('/growth/muhasabah'),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
    );
  }
}

class _AlMeezanRow extends ConsumerWidget {
  const _AlMeezanRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final summary = ref.watch(meezanSummaryProvider).valueOrNull;

    return MizanRow(
      title: 'Al-Meezan',
      subtitle: 'The weight of a life, counted honestly',
      // The one filled tile on the screen. Al-Meezan is the room this app is
      // named after, and `filled` is how the token system marks "the current one".
      // No iconColor override: filled resolves to navy-fill/cream-glyph on light
      // and gold-fill/navy-glyph on dark, and forcing gold would be gold on gold.
      leading: const MizanIconTile(
        icon: Icons.balance_rounded,
        circle: false,
        filled: true,
        semanticLabel: 'Al-Meezan',
      ),
      onTap: () => context.push('/growth/meezan'),
      // Absent until a birth date exists. Zeros would be a false statement about
      // a living person, and an invented figure here would be the worst possible
      // place to invent one.
      footer: summary == null ? null : _MeezanFooter(summary: summary),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SMALL PIECES
// ══════════════════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      ),
      child: Text(
        groupThousands(count),
        style: MizanType.bodyStrong(color: p.onFilled).copyWith(fontSize: 13.5),
      ),
    );
  }
}

class _MeezanFooter extends StatelessWidget {
  const _MeezanFooter({required this.summary});

  final MeezanSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MizanRule(color: p.hairline),
        const SizedBox(height: 10),
        Text(
          summary.line,
          style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
        ),
      ],
    );
  }
}

/// What "locked" means here, in plain words. The reason is the point: an answer
/// about the deen without a source attached is the one thing this app will not
/// ship, and a language model will produce one happily.
void _showScholarLocked(BuildContext context) {
  final p = MizanPalette.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(MizanGeometry.gutter),
      child: MizanSurface(
        tone: MizanTone.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MizanSectionLabel('Scholar AI'),
            const SizedBox(height: 10),
            Text(
              'Not open yet.',
              style: MizanType.cardHeadline(color: p.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'It will only answer with a verified source attached — an ayah, '
              'a hadith with its grade, or a named tafseer. Until it can do '
              'that every single time, it stays closed. An unsourced answer '
              'about the deen is worse than no answer.',
              style: MizanType.translation(color: p.muted),
            ),
            const SizedBox(height: 18),
            MizanButton(
              label: 'Close',
              kind: MizanButtonKind.secondary,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
