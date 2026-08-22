/// Quran Tab — Surah List Screen
///
/// Shows all 114 surahs from Al-Fatihah to An-Nas.
/// Features:
/// - Search by name or number
/// - Salah badge on surahs recited in prayer
/// - Friday badge on Al-Kahf
/// - Tap to open surah detail
///
/// Uses ConsumerWidget (Riverpod) instead of StatelessWidget
/// ConsumerWidget can watch providers — StatelessWidget cannot
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/quran_providers.dart';
import '../../../shared/models/surah.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'ayah_detail_screen.dart';

class QuranScreen extends ConsumerWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _QuranHeader(ref: ref),

          // ── Continue reading ─────────────────────────────────
          const _ResumeReadingCard(),

          // ── Surah List ──────────────────────────────────────
          Expanded(
            child: _SurahList(),
          ),
        ],
      ),
    );
  }
}

// ── Header with search ────────────────────────────────────────
class _QuranHeader extends StatelessWidget {
  const _QuranHeader({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text('Quran',
              style: AppTypography.displayLarge(
                color: AppColors.textPrimary,
              )),
          Text(
            'Al-Fatihah to An-Nas · Every ayah interactive',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
          const SizedBox(height: 14),

          // Search field
          _SearchField(ref: ref),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (value) {
        // Update search query provider when user types
        ref.read(surahSearchQueryProvider.notifier).state = value;
      },
      style: AppTypography.bodyMedium(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search surah name or number…',
        hintStyle: AppTypography.bodyMedium(
          color: AppColors.muted,
        ),
        prefixIcon:  Icon(
          Icons.search_rounded,
          color: AppColors.muted,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.slate,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide:  BorderSide(
            color: AppColors.jade,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

// ── Continue Reading — resumes from the last ayah viewed ───────
class _ResumeReadingCard extends StatefulWidget {
  const _ResumeReadingCard();

  @override
  State<_ResumeReadingCard> createState() => _ResumeReadingCardState();
}

class _LastRead {
  const _LastRead({
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.arabic,
  });

  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final String arabic;
}

class _ResumeReadingCardState extends State<_ResumeReadingCard> {
  _LastRead? _lastRead;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final surahNumber = prefs.getInt('last_surah');
    final ayahNumber = prefs.getInt('last_ayah');
    if (surahNumber == null || ayahNumber == null) return;
    if (!mounted) return;
    setState(() {
      _lastRead = _LastRead(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        surahName: prefs.getString('last_surah_name') ?? 'Surah $surahNumber',
        arabic: prefs.getString('last_ayah_arabic') ?? '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastRead = _lastRead;
    if (lastRead == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AyahDetailScreen(
                surahNumber: lastRead.surahNumber,
                initialAyahNumber: lastRead.ayahNumber,
              ),
            ),
          ),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.gold.withValues(alpha: 0.14),
                  AppColors.jade.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child:  Icon(Icons.auto_stories_rounded,
                      color: AppColors.gold, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTINUE READING',
                          style: AppTypography.labelSmall(color: AppColors.gold)),
                      const SizedBox(height: 2),
                      Text(
                        '${lastRead.surahName} — ${lastRead.surahNumber}:${lastRead.ayahNumber}',
                        style: AppTypography.bodyMedium(color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                 Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.gold, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Surah List ────────────────────────────────────────────────
class _SurahList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the filtered surahs provider
    // This automatically includes search filtering
    final surahsAsync = ref.watch(filteredSurahsProvider);

    return surahsAsync.when(
      // Loading state — show shimmer-style loading
      loading: () => const _LoadingState(),

      // Error state — show error with retry button
      error: (error, _) => _ErrorState(
        error: error.toString(),
        onRetry: () => ref.invalidate(surahsProvider),
      ),

      // Data state — show the list
      data: (surahs) {
        if (surahs.isEmpty) {
          return _EmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 24,
          ),
          itemCount: surahs.length,
          itemBuilder: (context, index) {
            return _SurahItem(
              surah: surahs[index],
              onTap: () {
                // Navigate to ayah detail screen
                // We'll create this route next
                context.push(
                  '/quran/${surahs[index].number}',
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Individual Surah Item ─────────────────────────────────────
class _SurahItem extends StatelessWidget {
  const _SurahItem({
    required this.surah,
    required this.onTap,
  });

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: '${surah.englishName}, ${surah.translatedName}',
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Surah number badge
                  _SurahNumber(number: surah.number),
                  const SizedBox(width: 14),

                  // Surah info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // English name + salah/friday badge
                        Row(
                          children: [
                            Text(
                              surah.englishName,
                              style: AppTypography.labelLarge(
                                  color: AppColors.textPrimary),
                            ),
                            if (surah.isFridaySurah) ...[
                              const SizedBox(width: 6),
                               _Badge(
                                label: '📅 Friday',
                                color: AppColors.jade,
                              ),
                            ] else if (surah.isRecitedInSalah) ...[
                              const SizedBox(width: 6),
                               _Badge(
                                label: '🕌 Salah',
                                color: AppColors.gold,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Translated name + meta
                        Text(
                          surah.translatedName,
                          style: AppTypography.bodySmall(
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          surah.metaDisplay,
                          style: AppTypography.caption(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),

                  // Arabic name
                  Text(
                    surah.arabicName,
                    style: AppTypography.arabicSmall(
                      color: AppColors.muted,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahNumber extends StatelessWidget {
  const _SurahNumber({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.night,
        borderRadius: BorderRadius.circular(99),
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: AppTypography.labelMedium(
          color: AppColors.gold,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ── Loading State ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

// ── Error State ───────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(
              Icons.wifi_off_rounded,
              color: AppColors.muted,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load surahs',
              style: AppTypography.labelLarge(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: AppTypography.bodySmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(
            Icons.search_off_rounded,
            color: AppColors.muted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No surahs found',
            style: AppTypography.labelLarge(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: AppTypography.bodySmall(),
          ),
        ],
      ),
    );
  }
}
