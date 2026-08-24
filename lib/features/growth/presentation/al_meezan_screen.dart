/// Al-Mizan (الْمِيزَان) — "The Scale".
///
/// The days-lived screen. Reached from the hero card at the top of Home, which is
/// the only entry point: the Growth row that used to lead here was removed when
/// this became the first thing on Home.
///
/// ── Four rules govern every line of this file ─────────────────────────
///
/// **1. Nothing counts down.** There is no progress bar, no life expectancy, no
/// remaining-days estimate, and no "% of life used" — not hidden, not optional,
/// not behind a setting. The lived portion is drawn; the remainder is drawn as
/// seven marks that fade to nothing and is never quantified. *No one is told the
/// number of their days.* If that number is not knowable, a screen that implies
/// it is lying.
///
/// **2. Nothing is scored.** No grade, no rank, no total, no verdict, no streak
/// guilt, no "you missed 3 days", no percentage complete. The copy is descriptive
/// throughout.
///
/// **3. The app's record is not the user's record with Allah** — and the screen
/// says so, in those words, inside [_WhatYouHaveBuilt]. That sentence is not
/// polish. It is the thing that keeps a screen full of counted deeds honest.
///
/// **4. Every figure is real.** All of it derives from the stored birth date and
/// actual app history, through `mizan_figures.dart` (calendar) and
/// `growth_stats_repository.dart` (history). Nothing is estimated to fill a slot.
/// If the birth date is missing the screen *asks* for it — see
/// [_AskForBirthDate] — rather than guessing from the install date.
///
/// ── The order of the four blocks is load-bearing ──────────────────────
/// Ramadan field → facts row → what you have built → the hadith. The content is
/// taller than one viewport on purpose: the Ramadan field and the beginning of
/// what you have built are what a person sees, and the hadith is what they find.
///
/// Two other orders were built and both were wrong. Putting the hadith earlier
/// pushes the akhira card off the screen, and that card is the reason the feature
/// exists — people are not asking "how many days have I lived", they are asking
/// "what am I building". Putting the akhira card last makes the hadith clip on its
/// Arabic line, which reads as a finished thought and breaks the app-wide rule
/// that Arabic is never decoration. Keep this order.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../domain/growth_map_providers.dart';
import '../domain/mizan_birth_date.dart';
import '../domain/mizan_figures.dart';

class AlMeezanScreen extends ConsumerWidget {
  const AlMeezanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final state = ref.watch(mizanFiguresProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _MizanHeader(),
            Expanded(
              child: switch (state) {
                AsyncLoading() => const SizedBox.shrink(),
                AsyncError() => _AskForBirthDate(
                    onSet: () => _pickDate(context, ref, null),
                  ),
                AsyncValue(value: final figures) => figures == null
                    ? _AskForBirthDate(
                        onSet: () => _pickDate(context, ref, null),
                      )
                    : _MizanBody(
                        figures: figures,
                        onEditDate: () =>
                            _pickDate(context, ref, figures.birthDate),
                      ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The one place the birth date is written.
///
/// Goes through [MizanFiguresController.set] rather than touching
/// `SharedPreferences` directly, so Home's hero and this screen recompute off the
/// same notifier and cannot show two different day numbers.
Future<void> _pickDate(
  BuildContext context,
  WidgetRef ref,
  DateTime? current,
) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: current ?? DateTime(2000),
    firstDate: DateTime(1900),
    // Not a day later. A birth date in the future is not a birth date, and the
    // figures downstream would go negative.
    lastDate: now,
    helpText: 'Your date of birth',
  );
  if (picked == null) return;
  await ref.read(mizanFiguresProvider.notifier).set(picked);
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════

class _MizanHeader extends StatelessWidget {
  const _MizanHeader();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(MizanGeometry.gutter, 6, 12, 10),
      child: Row(
        children: [
          MizanIconTile(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 17,
            semanticLabel: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الْمِيزَان',
                  textDirection: TextDirection.rtl,
                  // height 1.35 rather than the 1.9 MizanType.arabic carries. That
                  // multiplier is sized for running Quranic text, where the
                  // leading has to clear two rows of diacritics; on a single
                  // right-aligned word it just puts 12pt of empty page above the
                  // title. The word still clears its own harakat at 1.35.
                  style: MizanType.arabic(color: p.accentText, fontSize: 21)
                      .copyWith(height: 1.35),
                ),
                const SizedBox(height: 2),
                Text(
                  'The Scale',
                  style: MizanType.screenTitle(color: p.ink)
                      .copyWith(fontSize: 21),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE BODY, IN ITS ORDER
// ══════════════════════════════════════════════════════════════════════

class _MizanBody extends StatelessWidget {
  const _MizanBody({required this.figures, required this.onEditDate});

  final MizanFigures figures;
  final VoidCallback onEditDate;

  @override
  Widget build(BuildContext context) {
    // One continuous list, deliberately.
    //
    // An earlier build put a `SliverFillRemaining` between the akhira card and
    // the hadith to guarantee the hadith began at or below the fold — a scroll
    // view clips at a pixel rather than at a widget boundary, so nothing inside
    // the hadith card can stop the viewport cutting between the Arabic line and
    // its English translation, and an Arabic line stranded on the bottom edge
    // with nothing under it reads as a finished thought. It worked, and it looked
    // broken: on a phone it opened a viewport-sized hole in the middle of the
    // page, and once scrolled past, that hole was the most prominent thing on the
    // screen.
    //
    // The Growth row does the same job honestly. It is worth roughly eighty
    // points of real content in exactly the place the hole used to be, which is
    // enough to keep the hadith's top edge below the fold at the Ramadan counts
    // that matter, and at the counts where the card does peek into view it peeks
    // by less than the Arabic line is tall — so what a reader sees is an
    // obviously-cut line that says "scroll", never a complete Arabic sentence
    // sitting alone. Swept across 0..100 witnessed Ramadans and three chrome
    // models in tools/verify_mizan_layout.dart.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MizanGeometry.gutter,
        6,
        MizanGeometry.gutter,
        // Not MizanGeometry.scrollBottomPadding. That token exists for screens
        // whose content scrolls *under* a floating bar; here the shell puts the
        // tab bar below the body in a Column, so the body already ends where the
        // bar begins and 96pt of it would be plain empty page.
        24,
      ),
      children: [
        _RamadanField(figures: figures),
        const SizedBox(height: 18),
        _FactsRow(figures: figures),
        const SizedBox(height: 18),
        const _WhatYouHaveBuilt(),
        const SizedBox(height: 18),
        const _GrowthDoor(),
        const SizedBox(height: 18),
        const _FiveBeforeFive(),
        const SizedBox(height: 16),
        _BornFooter(birthDate: figures.birthDate, onEdit: onEditDate),
      ],
    );
  }
}

/// The way into Growth, sitting where Al-Mizan used to leave a hole.
///
/// Al-Mizan is a child of Growth in the route tree, but nothing on screen said
/// so, and Growth is not one of the five tabs — so until this row existed the
/// only door to the entire tab was a pill on Home that reads like a status
/// badge. Two people could not find it.
///
/// The subtitle names what is behind the row instead of describing it, and names
/// Today's Mizan first because that card just moved off Home and into Growth:
/// anyone who misses it from where it used to be is told here where it went.
class _GrowthDoor extends StatelessWidget {
  const _GrowthDoor();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanRow(
      title: 'Growth',
      subtitle: "Today's Mizan, your vocabulary, the map and muhasabah",
      leading: const MizanIconTile(
        icon: Icons.eco_outlined,
        circle: false,
        semanticLabel: 'Growth',
      ),
      // `go`, not `push`. Growth is this screen's parent route, so this is
      // upward navigation, not a deeper push onto the stack.
      onTap: () => context.go('/growth'),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
    );
  }
}

// ── 1. The Ramadan field ─────────────────────────────────────────────

/// Ramadans witnessed, drawn as diamonds, then seven more that dissolve.
///
/// **Nine per row, always.** A [Wrap] reflows to seventeen marks per row at this
/// width, which destroys the entire point — twenty-seven has to be countable at a
/// glance, and it is only countable in rows of nine. So the marks are chunked into
/// literal [Row]s of [columns] before they are laid out: how many marks share a
/// row is a property of the widget tree, not of the space available, and no width
/// can change it. The last row is padded with invisible cells so its marks keep
/// the same column positions as the rows above.
///
/// A `GridView.count` would also give nine columns, but its cells are square by
/// default, which makes the vertical pitch track the device width instead of the
/// 13px the design asks for. Explicit rows fix the pitch.
///
/// The seven trailing outlines at descending alpha are how rule 1 is honoured
/// visually: the sequence *dissolves* instead of stopping at a wall. A hard edge
/// after the last witnessed Ramadan would read as an end date. The line underneath
/// says out loud what the fade means.
class _RamadanField extends StatelessWidget {
  const _RamadanField({required this.figures});

  final MizanFigures figures;

  /// Locked to nine. See the class doc — this is not a tuning knob.
  static const int columns = 9;

  /// How far the remainder fades. Seven marks, never a number the user could
  /// count as "years left" — they are drawn at these alphas precisely so that
  /// counting them is unnatural.
  static const List<double> _fade = [.5, .3, .22, .16, .11, .07, .04];

  static const double _maxMark = 17;
  static const double _rowGap = 13;
  static const double _colGap = 10;

  /// A rotated square needs its *diagonal* worth of width, and [MizanDiamond]
  /// reserves `size * 1.42` for exactly that. Nine of those plus eight 10px gaps
  /// do not fit inside a 360pt phone, so the mark scales down to the column
  /// rather than overflowing it: nine per row is the invariant, seventeen points
  /// is only a preference. Measured — see tools/verify_mizan_layout.dart, which
  /// checks every supported width from 320 up.
  static double _markFor(double width) {
    final cell = (width - (columns - 1) * _colGap) / columns;
    final fit = cell / 1.42;
    return fit < _maxMark ? fit : _maxMark;
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final witnessed = figures.ramadansWitnessed;

    return MizanSurface(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MizanSectionLabel('Ramadans witnessed'),
          const SizedBox(height: 8),
          Text(
            groupThousands(witnessed),
            // height 1.0 rather than the 37/32 the style carries: a display
            // numeral standing alone does not need leading above and below it,
            // and the 6pt saved is 6pt the akhira card needs to stay above the
            // fold. Verified in tools/verify_mizan_layout.dart.
            style: MizanType.screenTitle(color: p.ink)
                .copyWith(fontSize: 40, height: 1.0),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: '$witnessed Ramadans witnessed, drawn in rows of nine. '
                'The remainder is not counted.',
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, box) {
                final mark = _markFor(box.maxWidth);
                final marks = <Widget>[
                  for (var i = 0; i < witnessed; i++)
                    MizanDiamond(size: mark, color: p.accent),
                  for (final alpha in _fade)
                    MizanDiamond(
                      size: mark,
                      filled: false,
                      color: p.accent.withValues(alpha: alpha),
                    ),
                ];

                final rows = <Widget>[];
                for (var start = 0; start < marks.length; start += columns) {
                  final end = start + columns <= marks.length
                      ? start + columns
                      : marks.length;
                  final row = marks.sublist(start, end);
                  if (rows.isNotEmpty) {
                    rows.add(const SizedBox(height: _rowGap));
                  }
                  rows.add(
                    // Height is the mark, not the mark's rotated bounding box.
                    // The corners paint into the 13pt gap, which is what the
                    // design intends — a CSS `transform: rotate(45deg)` does not
                    // change the element's box either, so reserving the diagonal
                    // vertically would make every row 7pt taller than drawn.
                    SizedBox(
                      height: mark,
                      child: Row(
                        children: [
                          for (var c = 0; c < columns; c++) ...[
                            if (c > 0) const SizedBox(width: _colGap),
                            // Every column is an equal share of the width, in
                            // every row, so a short final row lines up under the
                            // full rows above it.
                            Expanded(
                              child: Center(
                                child: c < row.length
                                    ? row[c]
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'The next one is not drawn. ',
                  style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
                ),
                TextSpan(
                  text: 'No one is told the number of their days.',
                  style: MizanType.bodyStrong(color: p.ink)
                      .copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. The facts row ────────────────────────────────────────────────

/// Four supporting facts in one card, divided by hairlines.
///
/// Deliberately not a 2×2 of large cards. These are context for the Ramadan field
/// above them, not four heroes — promoting them would give the screen four
/// competing focal points and no subject.
///
/// **"To Ramadan" is the only label in gold**, because it is the only figure here
/// that can be acted on. The rest describe what has already happened.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.figures});

  final MizanFigures figures;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final prayers = figures.prayerTimesPassed;

    return MizanSurface(
      // vertical 13, not 15. The spec calls this row supporting facts rather than
      // heroes, and the tighter row both says so and buys back the last few
      // points the akhira card needs to clear the fold on the tightest chrome.
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _Fact(
              figure: groupThousands(figures.dayNumber),
              label: 'Days',
            ),
          ),
          _FactDivider(color: p.hairline),
          Expanded(
            child: _Fact(
              figure: groupThousands(figures.jumuahs),
              label: 'Jumu’ahs',
            ),
          ),
          _FactDivider(color: p.hairline),
          Expanded(
            // "Prayer times", never "prayers". This is the number of times the
            // adhan has been called since the user reached the age of
            // responsibility — it says nothing whatsoever about how many were
            // prayed, and phrasing it as "prayers" would turn a fact about the
            // calendar into a claim about a person's worship.
            //
            // Zero means the user has not yet had a fifteenth Hijri birthday, so
            // there is genuinely nothing to count. An em dash rather than "0",
            // which would read as a shortfall rather than as "not yet".
            child: _Fact(
              figure: prayers == 0 ? '—' : groupThousands(prayers),
              label: 'Prayer times',
            ),
          ),
          _FactDivider(color: p.hairline),
          Expanded(
            child: _Fact(
              figure: groupThousands(figures.daysToRamadan),
              label: 'To Ramadan',
              accent: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.figure,
    required this.label,
    this.accent = false,
  });

  final String figure;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Semantics(
      label: '$label: $figure',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            figure,
            maxLines: 1,
            style: MizanType.screenTitle(color: p.ink)
                .copyWith(fontSize: 20, height: 1.1),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MizanType.body(color: accent ? p.accentText : p.muted)
                .copyWith(
              fontSize: 10.5,
              fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  const _FactDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: MizanGeometry.hairlineWidth,
        height: 40,
        color: color,
      );
}

// ── 3. What you have built here ─────────────────────────────────────

/// The reason the feature exists.
///
/// People do not open this screen asking how many days they have lived. They open
/// it asking what they are building. So this card sits third — high enough to be
/// fully visible on a 390×844 viewport without scrolling, which was measured, not
/// estimated.
///
/// The last line is the one that must never be edited out: *the app's record is
/// not the user's record with Allah.* Every figure above it is a count of taps in
/// a piece of software. Saying so is what stops a screen of counted deeds from
/// quietly implying it is weighing them.
class _WhatYouHaveBuilt extends ConsumerWidget {
  const _WhatYouHaveBuilt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final m = ref.watch(growthMetricsProvider).valueOrNull;

    return MizanSurface(
      tone: MizanTone.sunk,
      radius: const BorderRadius.all(Radius.circular(18)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MizanSectionLabel('What you have built here'),
          const SizedBox(height: 14),
          _Built(
            figure: m?.quranAyahs,
            description: 'ayat read with their meaning',
          ),
          const SizedBox(height: 11),
          _Built(
            figure: m?.vocabCount,
            description: 'roots learned',
          ),
          const SizedBox(height: 11),
          _Built(
            figure:
                m == null ? null : m.reflectionsWritten + m.hadithReflections,
            description: 'reflections written',
          ),
          const SizedBox(height: 15),
          MizanRule(color: p.hairline),
          const SizedBox(height: 11),
          Text(
            'This is what the app has seen — not your record with Allah. '
            'That one is not ours to show.',
            style: MizanType.translation(color: p.muted).copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Built extends StatelessWidget {
  const _Built({required this.figure, required this.description});

  /// Null while the query is in flight. Renders an em dash rather than a nought,
  /// because a nought is a statement and "not yet known" is not one.
  final int? figure;
  final String description;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            figure == null ? '—' : groupThousands(figure!),
            style: MizanType.screenTitle(color: p.ink).copyWith(fontSize: 22),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            description,
            style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

// ── 4. The hadith ──────────────────────────────────────────────────

/// «Take advantage of five before five.»
///
/// ── Why this block is built as one unit ──────────────────────────────
/// The Arabic line is **never** rendered alone. If a viewport clips this block it
/// must clip below the English line, never between the Arabic and the English: an
/// Arabic line sitting at the bottom edge with nothing beneath it reads as a
/// finished thought, and the app-wide rule is that Arabic is never decoration —
/// it always has its meaning attached on the very next line.
///
/// That is also why this sits last rather than earlier. Last, it can run past the
/// fold and the clip lands after the five clauses. Earlier, the akhira card above
/// disappears entirely.
class _FiveBeforeFive extends StatelessWidget {
  const _FiveBeforeFive();

  static const List<String> _clauses = [
    'your youth before your old age',
    'your health before your illness',
    'your wealth before your poverty',
    'your free time before your preoccupation',
    'your life before your death',
  ];

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;
    final on = tone.onColor(p);
    final onMuted = tone.mutedOn(p);
    final gold = tone.accentTextOn(p);

    return MizanSurface(
      tone: tone,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'اغْتَنِمْ خَمْسًا قَبْلَ خَمْسٍ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: MizanType.arabic(color: gold, fontSize: 24),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Take advantage of five before five:',
            style: MizanType.translation(color: on).copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          for (final clause in _clauses) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: MizanDiamond(size: 6, color: gold),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      clause,
                      style: MizanType.body(color: onMuted)
                          .copyWith(fontSize: 13.5, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          // Citation Lock: the narrator and the collection, on the page, next to
          // the words. Not in a tooltip and not a tap away.
          Text(
            'Narrated by Ibn ‘Abbas — al-Hakim, al-Mustadrak',
            style: MizanType.body(color: onMuted).copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────

class _BornFooter extends StatelessWidget {
  const _BornFooter({required this.birthDate, required this.onEdit});

  final DateTime birthDate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Born ${_formatDate(birthDate)} · ',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 12),
        ),
        GestureDetector(
          onTap: onEdit,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            // The text is small; the tap area is not.
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Text(
              'change',
              style: MizanType.body(color: p.link).copyWith(
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: p.link,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

// ══════════════════════════════════════════════════════════════════════
//  NO BIRTH DATE YET
// ══════════════════════════════════════════════════════════════════════

/// Asks. Never guesses.
///
/// Rule 4 in its plainest form: with no birth date there is no honest figure to
/// show, so the screen shows none. It does not fall back to the install date, an
/// average lifespan, or a zero — a "Day 1" for someone who has been alive for
/// decades is a false statement about their life, and this is the last screen in
/// the app that should make one.
class _AskForBirthDate extends StatelessWidget {
  const _AskForBirthDate({required this.onSet});

  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MizanGeometry.gutter,
        6,
        MizanGeometry.gutter,
        MizanGeometry.scrollBottomPadding,
      ),
      children: [
        MizanSurface(
          tone: MizanTone.inverse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Count your days',
                style: MizanType.cardHeadline(
                  color: MizanTone.inverse.onColor(p),
                ).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 10),
              Text(
                'Al-Mizan needs your date of birth, and nothing else. Every '
                'figure on this screen is counted from it — none is estimated, '
                'and none of it leaves this device.',
                style: MizanType.translation(
                  color: MizanTone.inverse.mutedOn(p),
                ).copyWith(fontSize: 14),
              ),
              const SizedBox(height: 18),
              MizanButton(
                label: 'Set date of birth',
                expand: true,
                onPressed: onSet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _FiveBeforeFive(),
      ],
    );
  }
}
