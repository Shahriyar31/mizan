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
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

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
  Widget build(BuildContext context) => const Scaffold(
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
            // ── Top bar with streak ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الوِرْدُ الصَّبَاحِيّ',
                          style: AppTypography.arabicDisplay(
                              color: AppColors.gold, size: 18),
                        ),
                        Text(
                          'Morning Wird',
                          style:
                              AppTypography.labelSmall(color: AppColors.muted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Streak counter — THE identity element
                    _StreakBadge(),
                  ],
                ),
              ),
            ),

            // ── Ayah of the Day — the hero ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _AyahOfDayCard(),
              ),
            ),

            // ── Section label ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Row(
                  children: [
                    Text(
                      'Morning Dhikr',
                      style:
                          AppTypography.labelLarge(color: AppColors.parchment),
                    ),
                    const Spacer(),
                    Text(
                      'Tap each to count',
                      style: AppTypography.labelSmall(
                          color: AppColors.muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),

            // ── 7 Dhikr cards ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _DhikrList(),
            ),

            // ── Bottom spacer ────────────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Quick actions ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    _ActionCard(
                      icon: Icons.menu_book_rounded,
                      label: 'Open the Quran',
                      color: AppColors.jade,
                      onTap: () => context.go('/quran'),
                    ),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.explore_rounded,
                      label: 'Continue in Discover',
                      color: AppColors.slate,
                      labelColor: AppColors.parchment,
                      onTap: () => context.go('/discover'),
                    ),
                  ],
                ),
              ),
            ),
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
  // Rotates daily — one ayah per day
  static const _ayahs = [
    {
      'arabic': 'أَفَلَا يَتَدَبَّرُونَ الْقُرْآنَ',
      'translation': 'Will they not then ponder over the Quran?',
      'reference': 'Muhammad 47:24',
      'context': 'The ayah from which this app takes its name.',
    },
    {
      'arabic': 'وَبِالْأَسْحَارِ هُمْ يَسْتَغْفِرُونَ',
      'translation':
          'And in the hours before dawn, they would seek forgiveness.',
      'reference': 'Adh-Dhariyat 51:18',
      'context':
          'Of those whom Allah praises — they sought forgiveness at Fajr.',
    },
    {
      'arabic': 'إِنَّ فِي ذَٰلِكَ لَذِكْرَىٰ لِمَن كَانَ لَهُ قَلْبٌ',
      'translation': 'Indeed in that is a reminder for whoever has a heart.',
      'reference': 'Qaf 50:37',
      'context':
          'The heart that receives. The Quran speaks to those who listen.',
    },
    {
      'arabic': 'وَاذْكُر رَّبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً',
      'translation': 'Remember your Lord within yourself in humility and fear.',
      'reference': 'Al-A\'raf 7:205',
      'context': 'Remembrance that is real — felt inside, not only spoken.',
    },
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
      'translation': 'Remember Me, and I will remember you.',
      'reference': 'Al-Baqarah 2:152',
      'context': 'The greatest exchange — your remembrance for His.',
    },
    {
      'arabic': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      'translation': 'Indeed, Allah is with the patient.',
      'reference': 'Al-Baqarah 2:153',
      'context': 'Not a promise of ease. A promise of company.',
    },
    {
      'arabic':
          'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
      'translation':
          'Our Lord, give us good in this world and good in the Hereafter.',
      'reference': 'Al-Baqarah 2:201',
      'context': 'The du\'a the Prophet ﷺ made most often — Sahih Bukhari.',
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.12),
            AppColors.gold.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ayah of the Day',
                  style: AppTypography.labelSmall(color: AppColors.gold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Arabic text — the centrepiece
            Text(
              ayah['arabic']!,
              style: AppTypography.arabicHero(color: AppColors.parchment),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              color: AppColors.gold.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),

            // Translation
            Text(
              ayah['translation']!,
              style: AppTypography.quoteItalic(color: AppColors.parchment2),
            ),
            const SizedBox(height: 8),

            // Reference
            Text(
              ayah['reference']!,
              style: AppTypography.labelSmall(color: AppColors.gold),
            ),
            const SizedBox(height: 12),

            // Context note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.night.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ayah['context']!,
                style: AppTypography.bodySmall(
                    color: AppColors.muted.withValues(alpha: 0.8)),
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

  static const _dhikr = [
    {
      'arabic': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
      'translit': 'Asbahna wa asbahal mulku lillah',
      'meaning': 'We enter the morning, and all dominion belongs to Allah.',
      'source': 'Abu Dawud',
    },
    {
      'arabic': 'اللَّهُمَّ بِكَ أَصْبَحْنَا',
      'translit': 'Allahumma bika asbahna',
      'meaning': 'O Allah, by Your grace we have entered the morning.',
      'source': 'Abu Dawud',
    },
    {
      'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      'translit': 'Subhan Allah wa bihamdihi',
      'meaning': 'Glory be to Allah and all praise is His.',
      'source': 'Sahih Muslim — 100 times in the morning',
    },
    {
      'arabic': 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
      'translit': 'La ilaha illallah wahdahu la sharika lah',
      'meaning': 'There is no god but Allah, alone with no partner.',
      'source': 'Sahih Bukhari — 10 times in the morning',
    },
    {
      'arabic': 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      'translit': 'A\'udhu billahi minash-shaytanir-rajim',
      'meaning': 'I seek refuge in Allah from the accursed Satan.',
      'source': 'Morning Athkar',
    },
    {
      'arabic': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ',
      'translit': 'Bismillahil-ladhi la yadurru ma\'as mihi shay\'',
      'meaning': 'In the name of Allah with whose name nothing can cause harm.',
      'source': 'Abu Dawud, Tirmidhi — 3 times in morning',
    },
    {
      'arabic': 'رَضِيتُ بِاللَّهِ رَبًّا وَبِالْإِسْلَامِ دِينًا',
      'translit': 'Raditu billahi rabban wa bil-islami dinan',
      'meaning': 'I am pleased with Allah as my Lord and Islam as my religion.',
      'source': 'Abu Dawud — 3 times in morning',
    },
  ];

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
                const Text('✓',
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
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5F0E8),
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
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF5F0E8),
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF5F0E8),
              height: 1.35,
            )),
        const SizedBox(height: 24),
        ..._questions.map((q) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF120F1E),
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
        color: const Color(0xFF0D2A24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.jade.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text('✓',
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
