/// GROWTH — what you have learned, kept privately.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 8 (screen 07 of 08),
/// then revised when Today's Mizan moved here from Home.
///
/// ── Why Today's Mizan lives here now ──────────────────────────────────
/// It is a private record of the day, and this is the private tab. The specific
/// thing that could not be on Home is the **seven-day strip**: a strip that shows
/// a missed day is only appropriate somewhere a person goes deliberately. On the
/// first screen of the app it becomes a small daily verdict delivered before
/// anything else, which is exactly what Rule #4 forbids. Al-Mizan went the other
/// way, to Home, because it says something about the reader's life rather than
/// about their performance.
///
/// ── Rule #4 is the whole design of this screen ─────────────────────────
/// Nothing here totals, ranks, grades or congratulates. That is not a stylistic
/// preference; a screen that scores worship teaches the user to perform for the
/// score. So the header records without scoring — solid diamond or hollow
/// diamond, never a count out of three — and the rows describe *where things
/// live*, each with its real inventory figure attached.
///
/// The one figure here that could become a score is `longestRun`, in the closing
/// strip. It is rendered under "Gaps are not failures. The record simply shows
/// where you were." That line is load-bearing: without it, a longest run turns
/// this tab into a streak app.
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
import '../../../core/util/hijri_date.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../halaqa/domain/halaqa_providers.dart';
import '../../home/domain/todays_mizan.dart';
import '../domain/growth_map_providers.dart';
import '../domain/mizan_figures.dart' show groupThousands;
import '../domain/mizan_record.dart';
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
            SizedBox(height: 18),
            _TodaysMizanHeaderCard(),
            SizedBox(height: 20),
            _VocabularyRow(),
            SizedBox(height: 12),
            _GrowthMapRow(),
            SizedBox(height: 12),
            _MuhasabahRow(),
            SizedBox(height: 12),
            _ScholarAiRow(),
            SizedBox(height: 12),
            _CirclesRow(),
            SizedBox(height: 20),
            _SinceYouBegan(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TODAY'S MIZAN — the tab header
// ══════════════════════════════════════════════════════════════════════

/// Three facets for today, then the week behind them.
///
/// Navy in both themes ([MizanTone.inverse]), which is what makes it read as the
/// tab's header rather than as the first of six equal rows.
///
/// Recorded and not-recorded are carried by **shape** — solid diamond against
/// hollow diamond — not by colour alone, so the distinction survives colour-blind
/// vision and a dimmed screen. Nothing counts the solid ones.
class _TodaysMizanHeaderCard extends ConsumerWidget {
  const _TodaysMizanHeaderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;
    final on = tone.onColor(p);
    final onMuted = tone.mutedOn(p);
    final hairline = tone.hairlineOn(p);

    final mizan = ref.watch(todaysMizanProvider);
    final now = DateTime.now();

    return MizanSurface(
      tone: tone,
      radius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MizanSectionLabel("Today's Mizan", onInverse: true),
              const Spacer(),
              Text(
                HijriDate.today(now: now).dayAndMonth,
                style: MizanType.body(color: onMuted).copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Facet(
                  icon: Icons.menu_book_outlined,
                  label: 'Learned',
                  done: mizan.learned,
                  on: on,
                  onMuted: onMuted,
                ),
              ),
              _FacetDivider(color: hairline),
              Expanded(
                child: _Facet(
                  icon: Icons.favorite_border_rounded,
                  label: 'Reflected',
                  done: mizan.reflected,
                  on: on,
                  onMuted: onMuted,
                ),
              ),
              _FacetDivider(color: hairline),
              Expanded(
                child: _Facet(
                  icon: Icons.directions_walk_rounded,
                  label: 'Acted',
                  done: mizan.acted,
                  on: on,
                  onMuted: onMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MizanRule(color: hairline),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _WeekStrip(),
              const Spacer(),
              Text(
                'A record, not a score.',
                style: MizanType.translation(color: onMuted)
                    .copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One facet. Icon, name, and a diamond that is solid or hollow.
class _Facet extends StatelessWidget {
  const _Facet({
    required this.icon,
    required this.label,
    required this.done,
    required this.on,
    required this.onMuted,
  });

  final IconData icon;
  final String label;
  final bool done;
  final Color on;
  final Color onMuted;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Semantics(
      label: '$label — ${done ? 'recorded today' : 'nothing recorded yet'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Icon(icon, size: 21, color: MizanTone.inverse.accentTextOn(p)),
          const SizedBox(height: 10),
          Text(
            label,
            style: MizanType.bodyStrong(color: on)
                .copyWith(fontSize: 13.5, height: 1.1),
          ),
          const SizedBox(height: 9),
          MizanDiamond(size: 9, filled: done, color: p.accent),
        ],
      ),
    );
  }
}

class _FacetDivider extends StatelessWidget {
  const _FacetDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: MizanGeometry.hairlineWidth,
        height: 62,
        color: color,
      );
}

/// The last seven days, oldest first, today last and slightly larger.
///
/// Undated and unlabelled on purpose: it shows the *shape* of a week, not a row
/// of days to account for. A missed day becomes visible without being named or
/// counted — which is only appropriate in a private tab, and is the reason this
/// card could not stay on Home.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final record = ref.watch(mizanRecordProvider).valueOrNull;
    if (record == null) return const SizedBox(height: 13);

    final marks = record.strip;

    return Semantics(
      label: 'The last ${marks.length} days. '
          '${marks.where((m) => m).length} of them recorded.',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < marks.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            MizanDiamond(
              // Today reads slightly larger, so the row has a near end without
              // needing a label under it.
              size: i == marks.length - 1 ? 9 : 7,
              filled: marks[i],
              color: p.accent,
            ),
          ],
        ],
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

class _GrowthMapRow extends ConsumerWidget {
  const _GrowthMapRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final m = ref.watch(growthMetricsProvider).valueOrNull;

    return MizanRow(
      title: 'Growth Map',
      // The real breadth of the reading, counted from `layer_unlocks`. Both halves
      // are queried; neither is derived from the other.
      subtitle: switch (m) {
        null => 'Your knowledge and practice, drawn as a night sky',
        final m when m.quranAyahs == 0 =>
          'Open a layer on any ayah and the sky starts filling',
        final m => '${groupThousands(m.quranAyahs)} '
            '${m.quranAyahs == 1 ? 'ayah' : 'ayat'} across '
            '${m.quranSurahs} ${m.quranSurahs == 1 ? 'surah' : 'surahs'}',
      },
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

class _MuhasabahRow extends ConsumerWidget {
  const _MuhasabahRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final m = ref.watch(growthMetricsProvider).valueOrNull;
    // Ayah reflections plus hadith reflections. Counted together because the row
    // is about the act of writing, not about which text prompted it.
    final written =
        m == null ? null : m.reflectionsWritten + m.hadithReflections;

    return MizanRow(
      title: 'Muhasabah',
      subtitle: switch (written) {
        null => 'Nightly three-question self-reckoning — private forever',
        0 => 'Nightly three-question self-reckoning — private forever',
        1 => '1 reflection written · private forever',
        final n => '${groupThousands(n)} reflections written · private forever',
      },
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

/// The circles the user sits in.
///
/// ── A deviation from the mockup, on purpose ───────────────────────────
/// The mockup reads "7 sessions across 2 halaqas". There is no session concept
/// anywhere in the halaqa feature — a circle has members, an invite code, and a
/// feed of notes; nothing counts or schedules sittings. So the number of sessions
/// cannot be stated, and Rule 4 forbids estimating one to fill the slot. The
/// subtitle states the figure that is real and countable: how many circles the
/// user belongs to, from [myHalaqasProvider]. If sessions ever exist, this line
/// gets the second half back.
class _CirclesRow extends ConsumerWidget {
  const _CirclesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final circles = ref.watch(myHalaqasProvider).valueOrNull;

    return MizanRow(
      title: 'Circles',
      subtitle: switch (circles?.length) {
        null => 'The halaqas you sit in',
        0 => 'Join or start a circle of two to eight',
        1 => '1 halaqa',
        final n => '$n halaqas',
      },
      leading: const MizanIconTile(
        icon: Icons.group_outlined,
        circle: false,
        semanticLabel: 'Circles',
      ),
      onTap: () => context.go('/halaqa'),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
    );
  }
}

/// The record since the first day anything was recorded.
///
/// Three figures and one guardrail. `longestRun` is here because it is a true
/// fact about the record, not because a longer one is better — and the line
/// beneath it says so, in those words. Remove that line and this becomes a
/// streak app, which Rule #4 forbids.
///
/// Absent entirely until the user has recorded something. A row of noughts under
/// "since you began" would be a report card handed to someone on day one.
class _SinceYouBegan extends ConsumerWidget {
  const _SinceYouBegan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final record = ref.watch(mizanRecordProvider).valueOrNull;
    if (record == null || !record.hasBegun) return const SizedBox.shrink();

    return MizanSurface(
      tone: MizanTone.sunk,
      radius: const BorderRadius.all(Radius.circular(18)),
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MizanSectionLabel('Since you began'),
          const SizedBox(height: 11),
          Text.rich(
            TextSpan(
              children: [
                _fig(p, record.daysWithMizan),
                _word(p, ' days with Mizan  ·  '),
                _fig(p, record.daysRecorded),
                _word(p, ' of them recorded  ·  '),
                _fig(p, record.longestRun),
                _word(p, ' longest run'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MizanRule(color: p.hairline),
          const SizedBox(height: 10),
          Text(
            'Gaps are not failures. The record simply shows where you were.',
            style: MizanType.translation(color: p.muted).copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  TextSpan _fig(MizanPalette p, int n) => TextSpan(
        text: groupThousands(n),
        style: MizanType.bodyStrong(color: p.ink).copyWith(fontSize: 14),
      );

  TextSpan _word(MizanPalette p, String s) => TextSpan(
        text: s,
        style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
      );
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
