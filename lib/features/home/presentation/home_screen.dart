/// Home — rebuilt on the Mizan design system.
///
/// ── What this screen is ───────────────────────────────────────────────
/// The landing screen, laid out to `Mizan Light.pdf` / `Mizan Dark.pdf` page 2:
/// a header row, the greeting under an arch watermark, Today's Mizan, the
/// Today's Thread hero, two half-width cards, and the ayah card. It reads only
/// from [MizanPalette], [MizanType] and [MizanGeometry] — there is not one
/// `AppColors` reference in this file, which is the whole point of the rebuild.
///
/// ── What replaced the old Home ────────────────────────────────────────
/// The previous 1,655-line version detected five time-of-day "states" (Friday,
/// returning, muhasabah, morning wird, default) and rendered a different screen
/// for each. The new design has one Home, so that machinery is gone. Two things
/// were rescued out of it before it went, because they were content and content
/// is expensive: the seven-ayah rotation now lives in `data/daily_ayah.dart`, and
/// the seven morning adhkar now live in `data/todays_encounter.dart`.
///
/// The adhkar currently have nowhere to be shown — the eight screens in the
/// design do not include a dhikr screen. The data is kept and verified; it needs
/// a home in a later pass rather than a silent deletion now.
///
/// ── Where the content comes from ──────────────────────────────────────
/// Every card is bound to something already sourced. See
/// `domain/home_today_providers.dart` for the reasoning, including why the
/// mockup's "TODAY IN ISLAM" card reads "FROM THE SEERAH" here: the app has no
/// hijri-dated event list, and inventing anniversaries for sacred history is not
/// something this codebase does.
///
/// ── On the Mizan strip ────────────────────────────────────────────────
/// Rule #4: it records, it does not score. Three facets, filled diamond or empty
/// diamond, no count and no verdict. The state difference is carried by *shape*
/// (solid vs outline), not by colour alone.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../core/util/hijri_date.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../identity/domain/identity_providers.dart';
import '../../quran/presentation/ayah_detail_screen.dart' show SavedAyatStore;
import '../data/daily_ayah.dart';
import '../data/todays_encounter.dart';
import '../domain/home_today_providers.dart';
import '../domain/streak_provider.dart';
import '../domain/todays_mizan.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            _HeaderBlock(),
            SizedBox(height: 22),
            _TodaysMizanCard(),
            SizedBox(height: MizanGeometry.gap),
            _ThreadHero(),
            SizedBox(height: MizanGeometry.gap),
            _TwoUp(),
            SizedBox(height: MizanGeometry.gap),
            _AyahCard(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER + GREETING
// ══════════════════════════════════════════════════════════════════════

/// The header row and greeting, with the arch drawn behind both.
///
/// The arch is a [Positioned] child of a `Clip.none` [Stack], so it is free to
/// overhang the bottom of this block — the Mizan card that follows in the list
/// is opaque and paints over the overhang, which is exactly how the mockup
/// crops it. Keeping the arch *inside* the scrolling content (rather than
/// pinning it to the Scaffold) means it scrolls away with the greeting it
/// belongs to.
class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final w = MediaQuery.sizeOf(context).width;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -14,
          left: w * 0.10,
          right: -6,
          height: 296,
          child: MizanArch(
            // Gold reads as a warm hairline on cream; on navy the blue accent
            // is the quieter of the two and matches the dark mockup.
            color: p.isLight ? p.accent : p.link,
            opacity: p.isLight ? 0.32 : 0.26,
          ),
        ),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(),
            SizedBox(height: 26),
            _Greeting(),
          ],
        ),
      ],
    );
  }
}

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        MizanIconTile(
          icon: Icons.person_outline_rounded,
          semanticLabel: 'Your account',
          onTap: () => context.go('/settings'),
        ),
        const Spacer(),
        const _StreakPill(),
        const SizedBox(width: 10),
        MizanIconTile(
          icon: Icons.notifications_none_rounded,
          semanticLabel: 'Notifications',
          // The mockup draws a gold unread dot here. There is no unread count in
          // the app yet, and a dot that is always lit is a notification that
          // never existed — so it stays off until something can actually set it.
          badge: false,
          onTap: () => context.go('/settings/notifications'),
        ),
      ],
    );
  }
}

class _StreakPill extends ConsumerWidget {
  const _StreakPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final days = ref.watch(streakProvider);

    return Semantics(
      button: true,
      label: '$days day journey. Opens Growth.',
      excludeSemantics: true,
      child: MizanSurface(
        radius: const BorderRadius.all(
          Radius.circular(MizanGeometry.pillRadius),
        ),
        padding: const EdgeInsets.fromLTRB(14, 7, 18, 7),
        onTap: () => context.go('/growth'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 20,
              // Bronze on cream, gold on navy — gold is never a text/icon
              // colour on the light page.
              color: p.accentText,
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$days',
                  style: MizanType.bodyStrong(color: p.ink)
                      .copyWith(fontSize: 17, height: 1.05),
                ),
                const SizedBox(height: 3),
                Text(
                  'day journey',
                  style: MizanType.body(color: p.muted)
                      .copyWith(fontSize: 11, height: 1.0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  /// The name the local, signed-out profile is created with. Greeting somebody
  /// as "You" is worse than not naming them at all, so it is treated as "no
  /// name" here rather than printed.
  static const String _placeholderName = 'You';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    // effectiveUserProvider, not currentUserProvider: the latter is always the
    // on-device profile, so a signed-in user was greeted by whatever the local
    // row said — usually the placeholder — instead of by the name on their
    // account. This is the same provider Halaqa and Minbar attribute posts to,
    // so the name in the greeting and the name on a share can no longer differ.
    final name =
        ref.watch(effectiveUserProvider).valueOrNull?.displayName.trim();
    final hasName =
        name != null && name.isNotEmpty && name != _placeholderName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'السَّلَامُ عَلَيْكُمْ',
          textDirection: TextDirection.rtl,
          style: MizanType.arabic(color: p.ink, fontSize: 34),
        ),
        const SizedBox(height: 4),
        Text(
          hasName ? 'Assalamu Alaikum, $name' : 'Assalamu Alaikum',
          style: MizanType.body(color: p.muted).copyWith(fontSize: 16),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TODAY'S MIZAN
// ══════════════════════════════════════════════════════════════════════

class _TodaysMizanCard extends ConsumerWidget {
  const _TodaysMizanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final mizan = ref.watch(todaysMizanProvider);
    final now = DateTime.now();
    final date = '${weekdayShort(now)} · ${HijriDate.today(now: now).dayAndMonth}';

    return MizanSurface(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MizanSectionLabel("Today's Mizan"),
              const Spacer(),
              Text(
                date,
                style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Facet(
                  icon: Icons.menu_book_outlined,
                  label: 'Learned',
                  done: mizan.learned,
                ),
              ),
              _FacetDivider(color: p.hairline),
              Expanded(
                child: _Facet(
                  icon: Icons.favorite_border_rounded,
                  label: 'Reflected',
                  done: mizan.reflected,
                ),
              ),
              _FacetDivider(color: p.hairline),
              Expanded(
                child: _Facet(
                  icon: Icons.directions_walk_rounded,
                  label: 'Acted',
                  done: mizan.acted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const MizanRule(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'A record, not a score.',
                  style: MizanType.translation(color: p.muted)
                      .copyWith(fontSize: 14),
                ),
              ),
              _TextLink(
                label: 'Open Growth',
                onTap: () => context.go('/growth'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Facet extends StatelessWidget {
  const _Facet({required this.icon, required this.label, required this.done});

  final IconData icon;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Semantics(
      label: '$label — ${done ? 'recorded today' : 'nothing recorded yet'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Icon(icon, size: 21, color: p.ink),
          const SizedBox(height: 10),
          Text(
            label,
            style: MizanType.bodyStrong(color: p.ink)
                .copyWith(fontSize: 14, height: 1.1),
          ),
          const SizedBox(height: 9),
          MizanDiamond(
            size: 7,
            filled: done,
            // Solid sage when engaged, hollow when not. The shape carries the
            // meaning; the colour only reinforces it.
            color: done ? p.sage : p.muted.withValues(alpha: 0.42),
          ),
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

// ══════════════════════════════════════════════════════════════════════
//  TODAY'S THREAD
// ══════════════════════════════════════════════════════════════════════

/// The one dark panel on the light screen, and a raised panel on the dark one —
/// [MizanTone.inverse] handles both.
///
/// The copy is read synchronously from [encounterForToday] so the hero always
/// renders; only the progress rail waits on the database. A hero that blinks in
/// after a query is worse than a rail that appears a frame late.
class _ThreadHero extends ConsumerWidget {
  const _ThreadHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;
    final on = tone.onColor(p);
    final onMuted = tone.mutedOn(p);

    final encounter = encounterForToday();
    final thread = ref.watch(threadTodayProvider).valueOrNull;

    void open() {
      // Opening today's thread is engagement with knowledge, which is what the
      // "Learned" facet records. It is not a claim that anything was mastered —
      // see todays_mizan.dart on why there is no score here.
      ref.read(todaysMizanProvider.notifier).mark(MizanFacet.learned);
      context.go(encounter.routePath);
    }

    return ClipRRect(
      borderRadius: MizanGeometry.cardBorderRadius,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tone.resolve(p),
          shape: RoundedRectangleBorder(
            borderRadius: MizanGeometry.cardBorderRadius,
            side: BorderSide(
              color: tone.hairlineOn(p),
              width: MizanGeometry.hairlineWidth,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Two arches bleeding off the right edge, clipped by the card.
            Positioned(
              right: -38,
              bottom: -62,
              width: 196,
              height: 236,
              child: MizanArch(color: p.accent, opacity: 0.15, rings: 2),
            ),
            Padding(
              padding: const EdgeInsets.all(MizanGeometry.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MizanSectionLabel(
                        "Today's Thread",
                        onInverse: true,
                      ),
                      const Spacer(),
                      if (thread != null)
                        Text(
                          thread.counter,
                          style: MizanType.body(color: onMuted)
                              .copyWith(fontSize: 13, letterSpacing: 0.6),
                        ),
                    ],
                  ),
                  if (thread != null) ...[
                    const SizedBox(height: 18),
                    _ThreadRail(
                      stage: thread.stage,
                      total: thread.totalLayers,
                      accent: p.accent,
                      dim: onMuted.withValues(alpha: 0.42),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'THE QUESTION',
                    style: MizanType.sectionLabel(color: onMuted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    encounter.hook,
                    style: MizanType.cardHeadline(color: on)
                        .copyWith(fontSize: 26, height: 1.24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    encounter.question,
                    style: MizanType.translation(color: onMuted),
                  ),
                  const SizedBox(height: 20),
                  MizanButton(
                    label: (thread?.isStarted ?? false) ? 'Continue' : 'Begin',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onInverse: true,
                    onPressed: open,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The layer rail: completed layers are solid dots, the current layer is a ring,
/// layers still ahead are dim dots. Nothing here is decorative — [total] is the
/// entry's real layer count and [stage] is the user's real position in it.
class _ThreadRail extends StatelessWidget {
  const _ThreadRail({
    required this.stage,
    required this.total,
    required this.accent,
    required this.dim,
  });

  final int stage;
  final int total;
  final Color accent;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    final nodes = <Widget>[];
    for (var i = 1; i <= total; i++) {
      if (i > 1) {
        nodes.add(
          Expanded(
            child: Container(height: 1.4, color: i <= stage ? accent : dim),
          ),
        );
      }
      nodes.add(_RailNode(index: i, stage: stage, accent: accent, dim: dim));
    }

    return Semantics(
      label: 'Layer $stage of $total',
      excludeSemantics: true,
      child: SizedBox(height: 18, child: Row(children: nodes)),
    );
  }
}

class _RailNode extends StatelessWidget {
  const _RailNode({
    required this.index,
    required this.stage,
    required this.accent,
    required this.dim,
  });

  final int index;
  final int stage;
  final Color accent;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    if (index == stage) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 2),
        ),
      );
    }
    final done = index < stage;
    final d = done ? 10.0 : 7.0;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? accent : dim,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE TWO HALF-WIDTH CARDS
// ══════════════════════════════════════════════════════════════════════

/// [IntrinsicHeight] so the two cards share a height and their footers line up,
/// which is what lets each one push its rule and link to the bottom with a
/// [Spacer].
class _TwoUp extends StatelessWidget {
  const _TwoUp();

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _WordCard()),
            SizedBox(width: MizanGeometry.gap),
            Expanded(child: _SeerahCard()),
          ],
        ),
      );
}

/// Today's Word — one word from the user's OWN vocabulary bank.
///
/// This is the honest version of the mockup's card. There is no editorial
/// word-of-the-day list in the app, and writing one would mean authoring
/// meanings for Quranic vocabulary, which needs verified sources. A word the
/// user saved while reading already carries its surah and ayah, so the citation
/// comes for free.
class _WordCard extends ConsumerWidget {
  const _WordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final word = ref.watch(todaysWordProvider).valueOrNull;

    return MizanSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MizanSectionLabel("Today's Word"),
          const SizedBox(height: 8),
          if (word == null)
            ...[
              Text(
                'Nothing saved yet.',
                style: MizanType.bodyStrong(color: p.ink)
                    .copyWith(fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap a word while you read and it will wait for you here.',
                style: MizanType.body(color: p.muted)
                    .copyWith(fontSize: 14, height: 1.45),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              const MizanRule(),
              const SizedBox(height: 8),
              _TextLink(
                label: 'Open the Quran',
                onTap: () => context.go('/quran'),
              ),
            ]
          else
            ...[
              Center(
                child: Text(
                  word.arabic,
                  textDirection: TextDirection.rtl,
                  style: MizanType.arabic(color: p.ink, fontSize: 32),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      word.transliteration,
                      style: MizanType.bodyStrong(color: p.ink)
                          .copyWith(fontSize: 14),
                    ),
                    const SizedBox(width: 7),
                    MizanDiamond(size: 5, color: p.accentText),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        word.meaning,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MizanType.body(color: p.muted)
                            .copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                word.insight,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: MizanType.body(color: p.muted)
                    .copyWith(fontSize: 14, height: 1.45),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              const MizanRule(),
              const SizedBox(height: 8),
              _TextLink(
                label: 'Explore the word',
                onTap: () => context.go('/growth/vocab'),
              ),
            ],
        ],
      ),
    );
  }
}

/// From the Seerah — a real entry, with the entry's own date string.
///
/// The mockup calls this "TODAY IN ISLAM" over "17 Ramadan, 2 AH". That is an
/// anniversary claim, and the app has no verified hijri-dated event list to
/// stand behind it. The card keeps its shape and shows what is actually known.
class _SeerahCard extends ConsumerWidget {
  const _SeerahCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final entry = ref.watch(seerahTodayProvider).valueOrNull;

    return MizanSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MizanSectionLabel('From the Seerah'),
          const SizedBox(height: 10),
          if (entry == null)
            Text(
              'Loading…',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 14),
            )
          else
            ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: p.accentText,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      entry.year,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MizanType.body(color: p.muted)
                          .copyWith(fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MizanType.cardHeadline(color: p.ink)
                    .copyWith(fontSize: 20, height: 1.18),
              ),
              const SizedBox(height: 8),
              Text(
                entry.teaser,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: MizanType.body(color: p.muted)
                    .copyWith(fontSize: 14, height: 1.45),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              const MizanRule(),
              const SizedBox(height: 8),
              _TextLink(
                label: 'Read the day',
                onTap: () {
                  ref
                      .read(todaysMizanProvider.notifier)
                      .mark(MizanFacet.learned);
                  context.go('/discover/seerah/${entry.id}');
                },
              ),
            ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  AYAH TO SIT WITH
// ══════════════════════════════════════════════════════════════════════

class _AyahCard extends ConsumerWidget {
  const _AyahCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final ayah = ayahForToday();

    return MizanSurface(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MizanSectionLabel('Ayah to sit with'),
              const Spacer(),
              _BookmarkButton(
                surahNumber: ayah.surahNumber,
                ayahNumber: ayah.ayahNumber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rule #6: Arabic is always right-aligned and always paired with a
          // translation. Both hold here.
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              ayah.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: MizanType.arabic(color: p.ink, fontSize: 26),
            ),
          ),
          const SizedBox(height: 16),
          const MizanRule(),
          const SizedBox(height: 16),
          Text(
            ayah.translation,
            style: MizanType.translation(color: p.muted),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  ayah.reference,
                  style: MizanType.bodyStrong(color: p.ink)
                      .copyWith(fontSize: 14),
                ),
              ),
              MizanButton.quiet(
                label: 'Read in context',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {
                  ref
                      .read(todaysMizanProvider.notifier)
                      .mark(MizanFacet.learned);
                  context.go('/quran/${ayah.surahNumber}');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Toggles the ayah in [SavedAyatStore] — the same bookmark list the reader
/// writes to, so an ayah saved here shows as saved there.
class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({required this.surahNumber, required this.ayahNumber});

  final int surahNumber;
  final int ayahNumber;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    SavedAyatStore.isSaved(widget.surahNumber, widget.ayahNumber).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    final now = await SavedAyatStore.toggle(
      widget.surahNumber,
      widget.ayahNumber,
    );
    if (mounted) setState(() => _saved = now);
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Semantics(
      button: true,
      label: _saved ? 'Saved. Tap to remove.' : 'Save this ayah',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: SizedBox(
          width: MizanGeometry.tapTarget,
          height: MizanGeometry.tapTarget,
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 21,
              color: _saved ? p.accentText : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SHARED BITS
// ══════════════════════════════════════════════════════════════════════

/// The quiet inline link at the foot of a card: bronze on cream, gold on navy,
/// with a 44px-high tap area even though the text is 14px.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MizanType.button(color: p.accentText)
                    .copyWith(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 15, color: p.accentText),
            ],
          ),
        ),
      ),
    );
  }
}
