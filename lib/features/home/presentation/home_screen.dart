/// Home Screen — 4 smart states detected automatically
///
/// States:
/// 1. Friday Jumu'ah   — One honest question, replaces everything
/// 2. Returning        — 3+ days away, no guilt, ayah they left with
/// 3. Morning Wird     — Daily dhikr + 3 vocab words due for review
/// 4. Muhasabah        — Evening 3-question private self-reckoning
/// 5. Default          — Afternoon state with Quran entry points
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/home_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/vocab_word.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeStateAsync = ref.watch(homeStateProvider);

    return homeStateAsync.when(
      loading: () => const _HomeLoading(),
      error: (_, __) => const _HomeDefault(),
      data: (state) {
        return switch (state) {
          HomeState.friday    => const _FridayState(),
          HomeState.returning => const _ReturningState(),
          HomeState.muhasabah => const _MuhasabahState(),
          HomeState.wird      => const _WirdState(),
          HomeState.defaultState => const _HomeDefault(),
        };
      },
    );
  }
}

// ── Loading ───────────────────────────────────────────────────
class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATE 1 — FRIDAY JUMU'AH
// ══════════════════════════════════════════════════════════════
class _FridayState extends ConsumerWidget {
  const _FridayState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(fridayQuestionProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Friday header
              Text('يَوْمُ الْجُمُعَةِ',
                  style: AppTypography.arabicBody()
                      .copyWith(fontSize: 28, color: AppColors.gold)),
              const SizedBox(height: 4),
              Text('Friday',
                  style: AppTypography.labelLarge(color: AppColors.muted)),

              const SizedBox(height: 48),

              // The question
              Text('This week\'s question',
                  style: AppTypography.caption(color: AppColors.gold)
                      .copyWith(letterSpacing: 1)),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Text(
                  question['question'] ?? '',
                  style: AppTypography.displaySmall(color: AppColors.white)
                      .copyWith(height: 1.5, fontSize: 20),
                ),
              ),

              const SizedBox(height: 20),

              // Hadith context
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                      left: BorderSide(color: AppColors.gold, width: 3)),
                ),
                child: Text(
                  question['context'] ?? '',
                  style: AppTypography.bodySmall(color: AppColors.muted)
                      .copyWith(height: 1.6, fontStyle: FontStyle.italic),
                ),
              ),

              const SizedBox(height: 48),

              // Enter Quran
              _PrimaryButton(
                label: 'Open the Quran',
                onTap: () => context.go('/quran'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATE 2 — RETURNING (3+ days away)
// ══════════════════════════════════════════════════════════════
class _ReturningState extends ConsumerWidget {
  const _ReturningState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastAyahAsync = ref.watch(lastAyahProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Welcome back — no guilt
              Text('مَرْحَباً بِعَوْدَتِكَ',
                  style: AppTypography.arabicBody()
                      .copyWith(fontSize: 24, color: AppColors.gold)),
              const SizedBox(height: 8),
              Text('Welcome back.',
                  style: AppTypography.displaySmall(color: AppColors.white)),
              const SizedBox(height: 8),
              Text(
                'The Quran was here waiting. It always will be.',
                style: AppTypography.bodyMedium(color: AppColors.muted)
                    .copyWith(height: 1.5),
              ),

              const SizedBox(height: 40),

              // The ayah they left with
              lastAyahAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (ayah) {
                  if (ayah == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You left with this ayah',
                          style: AppTypography.caption(color: AppColors.gold)
                              .copyWith(letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2535),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.jade.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ayah['arabic'] ?? '',
                              style: AppTypography.arabicBody()
                                  .copyWith(fontSize: 22, height: 1.8),
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFF2A3545)),
                            const SizedBox(height: 12),
                            Text(
                              ayah['translation'] ?? '',
                              style: AppTypography.bodySmall(
                                      color: AppColors.muted)
                                  .copyWith(
                                      height: 1.6,
                                      fontStyle: FontStyle.italic),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${ayah['surahName']} ${ayah['surah']}:${ayah['ayah']}',
                              style:
                                  AppTypography.caption(color: AppColors.gold),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PrimaryButton(
                        label: 'Continue from here',
                        onTap: () => context.go('/quran'),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Secondary — go to beginning
              _SecondaryButton(
                label: 'Start from Al-Fatihah',
                onTap: () => context.go('/quran'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATE 3 — MORNING WIRD
// ══════════════════════════════════════════════════════════════
class _WirdState extends ConsumerWidget {
  const _WirdState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabDueProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Morning greeting
              Text('الوِرْدُ الصَّبَاحِيّ',
                  style: AppTypography.arabicBody()
                      .copyWith(fontSize: 22, color: AppColors.gold)),
              const SizedBox(height: 4),
              Text('Morning Wird',
                  style: AppTypography.labelLarge(color: AppColors.muted)),

              const SizedBox(height: 32),

              // Vocab review section
              vocabAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (words) {
                  if (words.isEmpty) {
                    return _EmptyVocabCard();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Words due for review',
                          style: AppTypography.caption(color: AppColors.gold)
                              .copyWith(letterSpacing: 1)),
                      const SizedBox(height: 12),
                      ...words.map((w) => _VocabReviewCard(word: w)),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Morning dhikr reminder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                      left: BorderSide(color: AppColors.gold, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Morning Dhikr',
                        style: AppTypography.caption(color: AppColors.gold)
                            .copyWith(letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Text(
                      'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
                      style: AppTypography.arabicBody()
                          .copyWith(fontSize: 20, height: 1.8),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"We have reached the morning and at this very time all sovereignty belongs to Allah."',
                      style: AppTypography.bodySmall(color: AppColors.muted)
                          .copyWith(height: 1.6, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 4),
                    Text('— Morning Athkar',
                        style: AppTypography.caption(color: AppColors.muted)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Open Quran
              _PrimaryButton(
                label: 'Open the Quran',
                onTap: () => context.go('/quran'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATE 4 — MUHASABAH (Evening)
// ══════════════════════════════════════════════════════════════
class _MuhasabahState extends ConsumerWidget {
  const _MuhasabahState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneAsync = ref.watch(muhasabahDoneProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Text('الْمُحَاسَبَةُ',
                  style: AppTypography.arabicBody()
                      .copyWith(fontSize: 28, color: AppColors.gold)),
              const SizedBox(height: 4),
              Text('Evening Reckoning',
                  style: AppTypography.labelLarge(color: AppColors.muted)),

              const SizedBox(height: 16),

              Text(
                '"Take account of yourselves before you are taken to account."',
                style: AppTypography.bodyMedium(color: AppColors.muted)
                    .copyWith(height: 1.6, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 4),
              Text('— Umar ibn al-Khattab رضي الله عنه',
                  style: AppTypography.caption(color: AppColors.muted)),

              const SizedBox(height: 40),

              doneAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => _MuhasabahEntry(),
                data: (done) {
                  if (done) return _MuhasabahDone();
                  return _MuhasabahEntry();
                },
              ),

              const SizedBox(height: 24),

              _SecondaryButton(
                label: 'Open the Quran',
                onTap: () => context.go('/quran'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuhasabahEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Three questions. Answer honestly.',
            style: AppTypography.bodyMedium(color: AppColors.white)),
        const SizedBox(height: 20),

        _QuestionCard(
          number: '١',
          question: 'What did I do today for the sake of Allah?',
        ),
        const SizedBox(height: 12),
        _QuestionCard(
          number: '٢',
          question: 'What did my nafs pull me toward that I should not have followed?',
        ),
        const SizedBox(height: 12),
        _QuestionCard(
          number: '٣',
          question: 'What is my intention for tomorrow?',
        ),

        const SizedBox(height: 24),

        _PrimaryButton(
          label: 'Begin Muhasabah',
          onTap: () => context.go('/growth/muhasabah'),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.jade.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text('Muhasabah done for today.',
              style: AppTypography.labelLarge(color: AppColors.white)),
          const SizedBox(height: 8),
          Text(
            'May Allah accept it from you.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATE 5 — DEFAULT
// ══════════════════════════════════════════════════════════════
class _HomeDefault extends StatelessWidget {
  const _HomeDefault();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              Text('تَدَبُّر',
                  style: AppTypography.arabicBody()
                      .copyWith(fontSize: 36, color: AppColors.gold)),
              const SizedBox(height: 4),
              Text(
                '"Will they not reflect upon the Quran?"',
                style: AppTypography.bodyMedium(color: AppColors.muted)
                    .copyWith(fontStyle: FontStyle.italic),
              ),
              Text('— Muhammad 47:24',
                  style: AppTypography.caption(color: AppColors.muted)),

              const SizedBox(height: 48),

              _PrimaryButton(
                label: 'Open the Quran',
                onTap: () => context.go('/quran'),
              ),

              const SizedBox(height: 16),

              _SecondaryButton(
                label: 'Growth & Vocabulary',
                onTap: () => context.go('/growth'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.jade,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.labelLarge(color: AppColors.white)),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2535),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3545)),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.labelLarge(color: AppColors.muted)),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.number, required this.question});
  final String number;
  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number,
              style: AppTypography.arabicBody()
                  .copyWith(fontSize: 20, color: AppColors.gold)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(question,
                style: AppTypography.bodyMedium(color: AppColors.white)
                    .copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _VocabReviewCard extends StatelessWidget {
  const _VocabReviewCard({required this.word});
  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.arabic,
                    style: AppTypography.arabicBody()
                        .copyWith(fontSize: 22, color: AppColors.gold)),
                const SizedBox(height: 4),
                Text(word.meaning,
                    style: AppTypography.bodySmall(color: AppColors.white)),
                if (word.root.isNotEmpty)
                  Text('Root: ${word.root}',
                      style: AppTypography.caption(color: AppColors.muted)),
              ],
            ),
          ),
          Text(word.surahName,
              style: AppTypography.caption(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _EmptyVocabCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('📖', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text('No words saved yet.',
              style: AppTypography.labelLarge(color: AppColors.white)),
          const SizedBox(height: 4),
          Text('Tap words while reading to save them here.',
              style: AppTypography.bodySmall(color: AppColors.muted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
