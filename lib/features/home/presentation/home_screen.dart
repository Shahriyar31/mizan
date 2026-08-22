// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart — Redesigned home with proper UX
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/home_providers.dart';
import '../../growth/domain/vocab_providers.dart';
import '../data/todays_encounter.dart';
import '../../identity/domain/identity_providers.dart';
import 'thread_detail_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/tactile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeStateAsync = ref.watch(homeStateProvider);
    return homeStateAsync.when(
      loading: () => const _HomeLoading(),
      error: (_, __) => const _DefaultState(),
      data: (state) => switch (state) {
        HomeState.friday => const _FridayState(),
        HomeState.returning => const _ReturningState(),
        HomeState.muhasabah => const _MuhasabahState(),
        HomeState.wird => const _WirdState(),
        HomeState.defaultState => const _DefaultState(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading
// ─────────────────────────────────────────────────────────────────────────────

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();
  @override
  Widget build(BuildContext context) =>  Scaffold(
        backgroundColor: AppColors.night,
        body: Center(
          child:
              CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MORNING WIRD — The main engagement state
// ─────────────────────────────────────────────────────────────────────────────

class _WirdState extends ConsumerWidget {
  const _WirdState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Greeting ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Greeting()),
                    _StreakBadge(),
                    const SizedBox(width: 10),
                    _HeaderIconButton(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Today's Thread — signature feature ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: _TodaysThreadCard(),
              ),
            ),

            // ── Ayah to Sit With ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _AyahOfDayCard(),
              ),
            ),

            // ── Daily Dua ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _DailyDuaCard(),
              ),
            ),

            // ── Your Growth ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _GrowthGatewayCard(),
              ),
            ),

            // ── A Moment to Weigh (Al-Meezan) ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _MeezanGatewayCard(),
              ),
            ),

            // ── Bottom spacer ────────────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header icon button — used for the Growth/Settings shortcuts (not tabs).
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tactile(
        onTap: onTap,
        baseColor: AppColors.slate,
        borderRadius: 99,
        strength: 0.7,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.slate,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting — replaces the old "Morning Wird" heading. Time-independent.
// ─────────────────────────────────────────────────────────────────────────────

class _Greeting extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(effectiveUserProvider).valueOrNull;
    final name = user?.displayName.trim();
    final showName = name != null && name.isNotEmpty && name != 'You';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'السلام عليكم',
          style: AppTypography.arabicDisplay(color: AppColors.gold, size: 24),
        ),
        const SizedBox(height: 2),
        Text(
          showName ? 'Assalamu Alaikum, $name' : 'Assalamu Alaikum',
          style: AppTypography.labelSmall(color: AppColors.muted),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Thread — the signature feature. A curated, verified Discover
// entry, deterministic by day. Strongest visual treatment on the screen.
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysThreadCard extends StatefulWidget {
  @override
  State<_TodaysThreadCard> createState() => _TodaysThreadCardState();
}

class _TodaysThreadCardState extends State<_TodaysThreadCard> {
  int _stage = 0; // 0: question, 1: reveal, 2: source, 3: sit with this

  late final Encounter _encounter = encounterForToday();

  void _advance() {
    if (_stage < 3) {
      setState(() => _stage++);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ThreadDetailScreen(encounter: _encounter),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageLabels = const ['THE QUESTION', 'THE REVEAL', 'THE SOURCE', 'SIT WITH THIS'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.night,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("TODAY'S THREAD",
                    style: AppTypography.labelSmall(color: AppColors.gold)
                        .copyWith(letterSpacing: 3)),
                Text(encounterIndexForToday().toString().padLeft(2, '0'),
                    style: AppTypography.labelSmall(
                        color: AppColors.gold.withValues(alpha: 0.5))),
              ],
            ),
            const SizedBox(height: 8),
            // Progress: 01 → 02 → 03 → 04
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 1,
                        color: i <= _stage
                            ? AppColors.gold.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= _stage
                          ? AppColors.gold
                          : AppColors.gold.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _StageContent(
                key: ValueKey(_stage),
                stageLabel: stageLabels[_stage],
                encounter: _encounter,
                stage: _stage,
              ),
            ),
            const SizedBox(height: 24),
            TactilePill(
              onTap: _advance,
              baseColor: AppColors.surfaceElevated,
              strength: 1.1,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _stage < 3 ? 'CONTINUE' : 'FOLLOW THE THREAD',
                    style: AppTypography.labelMedium(color: AppColors.gold)
                        .copyWith(letterSpacing: 1),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.gold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageContent extends StatelessWidget {
  const _StageContent({
    super.key,
    required this.stageLabel,
    required this.encounter,
    required this.stage,
  });

  final String stageLabel;
  final Encounter encounter;
  final int stage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stageLabel,
            style: AppTypography.labelSmall(color: AppColors.muted)
                .copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 10),
        if (stage == 0) ...[
          Text(
            encounter.hook,
            style: AppTypography.displayLarge(color: AppColors.textPrimary)
                .copyWith(height: 1.25, fontSize: 24),
          ),
          const SizedBox(height: 12),
          Text(
            encounter.question,
            style: AppTypography.quoteItalic(color: AppColors.textSecondary),
          ),
        ] else if (stage == 1) ...[
          // The "aha" moment — the name, given weight.
          Text(
            encounter.subject,
            style: AppTypography.displayLarge(color: AppColors.gold)
                .copyWith(height: 1.2, fontSize: 28),
          ),
        ] else if (stage == 2) ...[
          Text(
            encounter.context,
            style: AppTypography.bodyLarge(color: AppColors.textPrimary)
                .copyWith(height: 1.6),
          ),
          const SizedBox(height: 14),
          Text(encounter.reference,
              style: AppTypography.labelSmall(color: AppColors.gold)),
        ] else ...[
          Text(
            'Let this settle for a moment.',
            style: AppTypography.displayMedium(color: AppColors.textPrimary)
                .copyWith(height: 1.3, fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            encounter.question,
            style: AppTypography.quoteItalic(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Dua — one dua, deterministic by day. Full Dua tab is a future task.
// ─────────────────────────────────────────────────────────────────────────────

class _DailyDuaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dua = duaForToday();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: AppColors.jade, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAILY DUA',
              style: AppTypography.labelSmall(color: AppColors.jade)),
          const SizedBox(height: 14),
          Text(
            dua['arabic']!,
            style: AppTypography.arabicBody(color: AppColors.textPrimary),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(dua['translit']!,
              style: AppTypography.quoteItalic(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(dua['meaning']!,
              style: AppTypography.bodySmall(color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(dua['source']!,
              style: AppTypography.labelSmall(color: AppColors.jade)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Your Growth — gateway to the existing Growth screen; no second dashboard.
// ─────────────────────────────────────────────────────────────────────────────

class _GrowthGatewayCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabCount = ref.watch(vocabCountProvider).valueOrNull;
    final subtitle = (vocabCount != null && vocabCount > 0)
        ? '$vocabCount ${vocabCount == 1 ? 'word' : 'words'} saved — your knowledge is growing'
        : 'Continue your learning and reflection journey.';

    return Semantics(
      button: true,
      label: 'Open Growth',
      child: Tactile(
        onTap: () => context.push('/growth'),
        baseColor: AppColors.surface,
        borderRadius: 20,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text('YOUR GROWTH',
                      style: AppTypography.labelSmall(color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: 10),
              Text(subtitle,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text('OPEN GROWTH →',
                    style: AppTypography.labelSmall(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A Moment to Weigh — gateway to the existing Al-Meezan screen.
// ─────────────────────────────────────────────────────────────────────────────

class _MeezanGatewayCard extends StatefulWidget {
  @override
  State<_MeezanGatewayCard> createState() => _MeezanGatewayCardState();
}

class _MeezanGatewayCardState extends State<_MeezanGatewayCard> {
  int? _daysLived;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('meezan_birth_date');
    final birthDate = stored == null ? null : DateTime.tryParse(stored);
    if (birthDate != null && mounted) {
      setState(() => _daysLived = DateTime.now().difference(birthDate).inDays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _daysLived != null
        ? '$_daysLived days lived, and counting.'
        : null;

    return Tactile(
      onTap: () => context.push('/growth/meezan'),
      baseColor: AppColors.surface,
      borderRadius: 20,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A MOMENT TO WEIGH',
                style: AppTypography.labelSmall(color: AppColors.violet)),
            const SizedBox(height: 10),
            Text(
              'If today were placed on the scale,\nwhat would you want to see?',
              style: AppTypography.quoteItalic(color: AppColors.textSecondary),
            ),
            if (preview != null) ...[
              const SizedBox(height: 10),
              Text(preview,
                  style: AppTypography.bodySmall(color: AppColors.muted)),
            ],
            const SizedBox(height: 12),
            Text('Reflect →',
                style: AppTypography.labelSmall(color: AppColors.violet)),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Streak Badge — the identity anchor
// ─────────────────────────────────────────────────────────────────────────────

class _StreakBadge extends StatefulWidget {
  @override
  State<_StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<_StreakBadge> {
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_opened_at');
    int streak = prefs.getInt('streak_count') ?? 1;
    if (last != null) {
      final lastDate = DateTime.tryParse(last);
      if (lastDate != null) {
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff == 1) {
          streak += 1;
          await prefs.setInt('streak_count', streak);
        } else if (diff > 1) {
          streak = 1;
          await prefs.setInt('streak_count', 1);
        }
      }
    }
    if (mounted) setState(() => _streak = streak);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_streak',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                  height: 1,
                ),
              ),
              Text(
                _streak == 1 ? 'day' : 'days',
                style: AppTypography.labelSmall(color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah of the Day — the hero card
// ─────────────────────────────────────────────────────────────────────────────

class _AyahOfDayCard extends StatelessWidget {
  // Rotates daily — one ayah per day. `surah` is the numeric surah number
  // named in `reference`, added only to link "Read in context →" to the
  // real Quran screen — not a new claim.
  static const _ayahs = [
    {
      'arabic': 'أَفَلَا يَتَدَبَّرُونَ الْقُرْآنَ',
      'translation': 'Will they not then ponder over the Quran?',
      'reference': 'Muhammad 47:24',
      'context': 'The ayah from which this app takes its name.',
      'surah': 47,
      'ayah': 24,
    },
    {
      'arabic': 'وَبِالْأَسْحَارِ هُمْ يَسْتَغْفِرُونَ',
      'translation':
          'And in the hours before dawn, they would seek forgiveness.',
      'reference': 'Adh-Dhariyat 51:18',
      'context':
          'Of those whom Allah praises — they sought forgiveness at Fajr.',
      'surah': 51,
      'ayah': 18,
    },
    {
      'arabic': 'إِنَّ فِي ذَٰلِكَ لَذِكْرَىٰ لِمَن كَانَ لَهُ قَلْبٌ',
      'translation': 'Indeed in that is a reminder for whoever has a heart.',
      'reference': 'Qaf 50:37',
      'context':
          'The heart that receives. The Quran speaks to those who listen.',
      'surah': 50,
      'ayah': 37,
    },
    {
      'arabic': 'وَاذْكُر رَّبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً',
      'translation': 'Remember your Lord within yourself in humility and fear.',
      'reference': 'Al-A\'raf 7:205',
      'context': 'Remembrance that is real — felt inside, not only spoken.',
      'surah': 7,
      'ayah': 205,
    },
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'translation': 'Remember Me, and I will remember you.',
      'reference': 'Al-Baqarah 2:152',
      'context': 'The greatest exchange — your remembrance for His.',
      'surah': 2,
      'ayah': 152,
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'translation': 'Indeed, Allah is with the patient.',
      'reference': 'Al-Baqarah 2:153',
      'context': 'Not a promise of ease. A promise of company.',
      'surah': 2,
      'ayah': 153,
    },
    {
      'arabic':
          'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
      'translation':
          'Our Lord, give us good in this world and good in the Hereafter.',
      'reference': 'Al-Baqarah 2:201',
      'context': 'The du\'a the Prophet ﷺ made most often — Sahih Bukhari.',
      'surah': 2,
      'ayah': 201,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final ayah = _ayahs[dayOfYear % _ayahs.length];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label
            Text(
              'AYAH TO SIT WITH',
              style: AppTypography.labelSmall(color: AppColors.gold),
            ),
            const SizedBox(height: 20),

            // Arabic text — the centrepiece
            Text(
              ayah['arabic'] as String,
              style: AppTypography.arabicHero(color: AppColors.textPrimary),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),

            // Divider
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Translation
            Text(
              ayah['translation'] as String,
              style: AppTypography.quoteItalic(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),

            // Reference
            Text(
              ayah['reference'] as String,
              style: AppTypography.labelSmall(color: AppColors.gold),
            ),
            const SizedBox(height: 16),

            // Quiet action — opens the real surah
            TactileChip(
              baseColor: AppColors.surfaceElevated,
              strength: 0.6,
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () => context
                  .push('/quran/${ayah['surah']}?ayah=${ayah['ayah']}'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Read in context',
                    style: AppTypography.labelMedium(color: AppColors.muted),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7 Dhikr Cards — each tapped once to mark complete
// ─────────────────────────────────────────────────────────────────────────────

class _DhikrList extends StatefulWidget {
  @override
  State<_DhikrList> createState() => _DhikrListState();
}

class _DhikrListState extends State<_DhikrList> {
  final List<bool> _done = List.filled(7, false);

  static const _dhikr = kMorningAdhkar;

  @override
  Widget build(BuildContext context) {
    final completedCount = _done.where((d) => d).length;
    final allDone = completedCount == 7;

    return SliverList(
      delegate: SliverChildListDelegate([
        // Ring progress indicator at top
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _WirdRingCompact(
            completed: completedCount,
            total: 7,
          ),
        ),
        // Each dhikr card
        ..._dhikr.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          return _SingleDhikrCard(
            arabic: d['arabic']!,
            translit: d['translit']!,
            meaning: d['meaning']!,
            source: d['source']!,
            isDone: _done[i],
            onTap: () {
              if (!_done[i]) {
                setState(() => _done[i] = true);
              }
            },
          );
        }),
        if (allDone) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.jade.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.jade.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                 Text('✓',
                    style: TextStyle(
                        fontSize: 20,
                        color: AppColors.jade,
                        fontWeight: FontWeight.w300)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wird complete.',
                          style:
                              AppTypography.labelLarge(color: AppColors.jade)),
                      Text('May Allah accept it from you.',
                          style:
                              AppTypography.bodySmall(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }
}

// Compact ring showing wird progress
class _WirdRingCompact extends StatelessWidget {
  final int completed;
  final int total;
  const _WirdRingCompact({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _RingPainter(
                progress: completed / total,
                ringColor: AppColors.gold,
                bgColor: AppColors.gold.withAlpha(25)),
            child: Center(
              child: Text(
                '$completed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                completed == 0
                    ? 'Start your morning dhikr'
                    : completed == total
                        ? 'All dhikr complete'
                        : '$completed of $total dhikr done',
                style: AppTypography.labelLarge(color: AppColors.parchment),
              ),
              const SizedBox(height: 4),
              // 7 segment dots
              Row(
                children: List.generate(total, (i) {
                  return Container(
                    margin: const EdgeInsets.only(right: 5),
                    width: i < completed ? 18 : 8,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < completed
                          ? AppColors.gold
                          : AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color bgColor;
  _RingPainter(
      {required this.progress, required this.ringColor, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// Individual tappable dhikr card
class _SingleDhikrCard extends StatelessWidget {
  final String arabic;
  final String translit;
  final String meaning;
  final String source;
  final bool isDone;
  final VoidCallback onTap;

  const _SingleDhikrCard({
    required this.arabic,
    required this.translit,
    required this.meaning,
    required this.source,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isDone ? AppColors.jade.withValues(alpha: 0.08) : AppColors.slate,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? AppColors.jade.withValues(alpha: 0.35)
                : AppColors.gold.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Check circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppColors.jade : Colors.transparent,
                border: Border.all(
                  color: isDone
                      ? AppColors.jade
                      : AppColors.gold.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabic,
                    style: AppTypography.arabicBody(
                      color: isDone
                          ? AppColors.jade.withValues(alpha: 0.7)
                          : AppColors.parchment,
                      size: 18,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translit,
                    style: AppTypography.labelSmall(
                        color: AppColors.gold.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meaning,
                    style: AppTypography.bodySmall(color: AppColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────────────────────────────────────
// FRIDAY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _FridayState extends ConsumerWidget {
  const _FridayState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(fridayQuestionProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('يَوْمُ الْجُمُعَةِ',
                          style: AppTypography.arabicDisplay(
                              color: AppColors.jade, size: 18)),
                      Text('Friday — the best of days',
                          style:
                              AppTypography.labelSmall(color: AppColors.muted)),
                    ],
                  ),
                  const Spacer(),
                  _StreakBadge(),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This week\'s question',
                        style: AppTypography.labelSmall(color: AppColors.jade)),
                    const SizedBox(height: 14),

                    // The question — full width, commanding
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.jade.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.jade.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        question['question'] ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.5,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Context
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.jade, width: 3),
                        ),
                      ),
                      child: Text(
                        question['context'] ?? '',
                        style:
                            AppTypography.quoteItalic(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Jumu'ah ayah
                    _QuranCard(
                      arabic:
                          'يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا نُودِيَ لِلصَّلَاةِ مِن يَوْمِ الْجُمُعَةِ فَاسْعَوْا إِلَىٰ ذِكْرِ اللَّهِ',
                      translation:
                          'O you who believe, when the call to prayer is made on Friday, proceed to the remembrance of Allah.',
                      reference: 'Al-Jumu\'ah 62:9',
                    ),
                  ],
                ),
              ),
            ),

            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _ActionCard(
                icon: Icons.menu_book_rounded,
                label: 'Open the Quran',
                color: AppColors.jade,
                onTap: () => context.go('/quran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RETURNING STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ReturningState extends ConsumerWidget {
  const _ReturningState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastAyahAsync = ref.watch(lastAyahProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مَرْحَباً',
                          style: AppTypography.arabicDisplay(
                              color: AppColors.goldSoft, size: 20)),
                      Text('Welcome back',
                          style:
                              AppTypography.labelSmall(color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Quran was here\nwaiting for you.',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('It always will be.',
                        style:
                            AppTypography.bodyMedium(color: AppColors.muted)),
                    const SizedBox(height: 36),
                    lastAyahAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (ayah) {
                        if (ayah == null) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You left with this',
                                style: AppTypography.labelSmall(
                                    color: AppColors.gold)),
                            const SizedBox(height: 12),
                            _QuranCard(
                              arabic: ayah['arabic'] ?? '',
                              translation: ayah['translation'] ?? '',
                              reference:
                                  '${ayah['surahName']} ${ayah['surah']}:${ayah['ayah']}',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _ActionCard(
                icon: Icons.menu_book_rounded,
                label: 'Continue reading',
                color: AppColors.jade,
                onTap: () => context.go('/quran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MUHASABAH STATE (Evening)
// ─────────────────────────────────────────────────────────────────────────────

class _MuhasabahState extends ConsumerWidget {
  const _MuhasabahState();

  static const _purple = Color(0xFF7C6EAF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneAsync = ref.watch(muhasabahDoneProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الْمُحَاسَبَةُ',
                      style: AppTypography.arabicDisplay(
                          color: _purple, size: 20)),
                  Text('Evening reckoning',
                      style: AppTypography.labelSmall(color: AppColors.muted)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: _purple, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '"Take account of yourselves before you are taken to account."',
                            style: AppTypography.quoteItalic(
                                color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '— Umar ibn al-Khattab رضي الله عنه',
                            style: AppTypography.labelSmall(color: _purple),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    doneAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => _MuhasabahPrompt(purple: _purple),
                      data: (done) => done
                          ? _MuhasabahDone()
                          : _MuhasabahPrompt(purple: _purple),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _ActionCard(
                icon: Icons.menu_book_rounded,
                label: 'Open the Quran',
                color: AppColors.slate,
                labelColor: AppColors.parchment,
                onTap: () => context.go('/quran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuhasabahPrompt extends StatelessWidget {
  final Color purple;
  const _MuhasabahPrompt({required this.purple});

  static const _questions = [
    ('١', 'What did I do today for the sake of Allah alone?'),
    ('٢', 'What did my nafs pull me toward that I should not have followed?'),
    ('٣', 'What is my intention for tomorrow?'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Three questions.\nAnswer honestly.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            )),
        const SizedBox(height: 24),
        ..._questions.map((q) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: purple.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.$1,
                      style:
                          AppTypography.arabicDisplay(color: purple, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(q.$2,
                        style: AppTypography.bodyMedium(
                            color: AppColors.parchment)),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => context.go('/growth/muhasabah'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Begin Muhasabah',
                    style: AppTypography.labelLarge(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MuhasabahDone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.jade.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.jade.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
           Text('✓',
              style: TextStyle(
                  fontSize: 36,
                  color: AppColors.jade,
                  fontWeight: FontWeight.w300)),
          const SizedBox(height: 12),
          Text('Muhasabah complete.',
              style: AppTypography.displaySmall(color: AppColors.parchment)),
          const SizedBox(height: 8),
          Text('May Allah accept it from you.',
              style: AppTypography.bodySmall(color: AppColors.muted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT STATE
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultState extends StatelessWidget {
  const _DefaultState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تَدَبُّر',
                  style: AppTypography.arabicDisplay(
                      color: AppColors.gold, size: 22)),
              const SizedBox(height: 2),
              Text('Reflect upon the Quran',
                  style: AppTypography.labelSmall(color: AppColors.muted)),
              const SizedBox(height: 32),
              _AyahOfDayCard(),
              const SizedBox(height: 24),
              _ActionCard(
                icon: Icons.menu_book_rounded,
                label: 'Open the Quran',
                color: AppColors.jade,
                onTap: () => context.go('/quran'),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.explore_rounded,
                label: 'Discover',
                color: AppColors.slate,
                labelColor: AppColors.parchment,
                onTap: () => context.go('/discover'),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.trending_up_rounded,
                label: 'Growth',
                color: AppColors.slate,
                labelColor: AppColors.parchment,
                onTap: () => context.go('/growth'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _QuranCard extends StatelessWidget {
  final String arabic;
  final String translation;
  final String reference;

  const _QuranCard({
    required this.arabic,
    required this.translation,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (arabic.isNotEmpty) ...[
            Text(arabic,
                style: AppTypography.arabicBody(color: AppColors.parchment),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl),
            const SizedBox(height: 14),
            Divider(color: AppColors.gold.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: 14),
          ],
          Text(translation,
              style: AppTypography.quoteItalic(color: AppColors.muted),
              textAlign: TextAlign.left),
          const SizedBox(height: 6),
          Text(reference,
              style: AppTypography.labelSmall(color: AppColors.gold),
              textAlign: TextAlign.left),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? labelColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = labelColor ?? AppColors.night;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
              border: labelColor != null
                  ? Border.all(color: AppColors.gold.withValues(alpha: 0.1))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 12),
                Text(label, style: AppTypography.labelLarge(color: textColor)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: textColor, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
