/// Ayah Detail Screen — PageView reading experience
///
/// Design decision: PageView instead of ListView
/// Reasoning: Reading Quran is not like browsing a list.
/// Each ayah deserves full attention. Swiping page by page
/// forces the reader to sit with one ayah before moving to next.
/// This matches how physical Quran reading works.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/quran_providers.dart';
import '../../../shared/models/ayah.dart';
import '../../../shared/models/surah.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class AyahDetailScreen extends ConsumerStatefulWidget {
  const AyahDetailScreen({
    super.key,
    required this.surahNumber,
  });

  final int surahNumber;

  @override
  ConsumerState<AyahDetailScreen> createState() => _AyahDetailScreenState();
}

class _AyahDetailScreenState extends ConsumerState<AyahDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahAsync = ref.watch(surahsProvider).whenData(
          (surahs) => surahs.firstWhere(
            (s) => s.number == widget.surahNumber,
            orElse: () => throw Exception('Surah not found'),
          ),
        );
    final ayatAsync = ref.watch(ayatProvider(widget.surahNumber));

    return Scaffold(
      backgroundColor: AppColors.night,
      body: ayatAsync.when(
        loading: () => const _LoadingPage(),
        error: (e, _) => _ErrorPage(
          onRetry: () => ref.invalidate(ayatProvider(widget.surahNumber)),
        ),
        data: (ayat) => _PageViewReader(
          surahAsync: surahAsync,
          ayat: ayat,
          pageController: _pageController,
          currentPage: _currentPage,
          onPageChanged: (page) => setState(() => _currentPage = page),
          surahNumber: widget.surahNumber,
        ),
      ),
    );
  }
}

// ── PageView Reader ───────────────────────────────────────────
class _PageViewReader extends StatelessWidget {
  const _PageViewReader({
    required this.surahAsync,
    required this.ayat,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
    required this.surahNumber,
  });

  final AsyncValue<Surah> surahAsync;
  final List<Ayah> ayat;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Fixed Header ─────────────────────────────────────
        _SurahHeader(
          surahAsync: surahAsync,
          currentPage: currentPage,
          totalAyat: ayat.length,
          surahNumber: surahNumber,
        ),

        // ── PageView — one ayah per page ─────────────────────
        // reverse: true makes swipe direction match Arabic RTL reading
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: ayat.length,
            reverse: true,
            itemBuilder: (context, index) {
              return _AyahPage(
                ayah: ayat[index],
                surahNumber: surahNumber,
                isFirst: index == 0,
              );
            },
          ),
        ),

        // ── Page indicator + navigation ──────────────────────
        _PageControls(
          currentPage: currentPage,
          totalPages: ayat.length,
          pageController: pageController,
          surahNumber: surahNumber,
        ),
      ],
    );
  }
}

// ── Fixed Header ──────────────────────────────────────────────
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    required this.surahAsync,
    required this.currentPage,
    required this.totalAyat,
    required this.surahNumber,
  });

  final AsyncValue<Surah> surahAsync;
  final int currentPage;
  final int totalAyat;
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Surah name
          Expanded(
            child: surahAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (surah) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.englishName,
                    style: AppTypography.displaySmall(color: AppColors.white),
                  ),
                  Text(
                    surah.translatedName,
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ),
          ),

          // Ayah counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.slate,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${currentPage + 1} / $totalAyat',
              style: AppTypography.caption(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single Ayah Page ──────────────────────────────────────────
class _AyahPage extends StatelessWidget {
  const _AyahPage({
    required this.ayah,
    required this.surahNumber,
    required this.isFirst,
  });

  final Ayah ayah;
  final int surahNumber;
  final bool isFirst;

  static const Map<int, String> _scenes = {
    1: 'Recited in every rakah of every prayer — at minimum 17 times every day. These are the words you say to Allah more than any other.',
    18: 'Recommended to recite every Friday. Contains four stories: the People of the Cave, the two men with gardens, Musa and Al-Khidr, and Dhul-Qarnayn.',
    94: 'Revealed during the Year of Sorrow — after the Prophet ﷺ lost Khadijah (RA) and Abu Talib, and was stoned out of Ta\'if. These words came down in that exact moment.',
    112:
        'Worth one-third of the Quran in reward. A complete description of Allah\'s nature in four ayat.',
    114:
        'The final surah. Seeks refuge in Allah from the whispering of Shaytan.',
  };

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final hasScene = isFirst && _scenes.containsKey(surahNumber);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Scene setting — only on first ayah of key surahs
            if (hasScene) ...[
              const SizedBox(height: 16),
              _SceneSetting(text: _scenes[surahNumber]!),
            ],

            // Vertical spacing to center the ayah
            SizedBox(
              height: hasScene ? screenHeight * 0.1 : screenHeight * 0.2,
            ),

            // Ayah reference number
            Text(
              '${ayah.surahNumber}:${ayah.ayahNumber}',
              style: AppTypography.caption(color: AppColors.gold),
            ),
            const SizedBox(height: 24),

            // Arabic text — hero of the page
            Text(
              ayah.arabicText,
              style: AppTypography.arabicHero(
                color: AppColors.white,
                size: 30,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),

            const SizedBox(height: 32),

            // Gold divider line
            Container(
              height: 1,
              width: 60,
              color: AppColors.gold.withOpacity(0.3),
            ),

            const SizedBox(height: 24),

            // Translation
            if (ayah.translation.isNotEmpty)
              Text(
                ayah.translation,
                style: AppTypography.quoteItalic(
                  color: const Color(0xFF9CADB8),
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'Translation loading…',
                style: AppTypography.bodySmall(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Save',
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.layers_rounded,
                  label: 'Layers',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Scene Setting Card ────────────────────────────────────────
class _SceneSetting extends StatelessWidget {
  const _SceneSetting({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.gold, width: 3),
        ),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall(
          color: const Color(0xFFB0C4C0),
        ),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.slate,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.muted, size: 20),
          ),
          const SizedBox(height: 5),
          Text(label, style: AppTypography.caption()),
        ],
      ),
    );
  }
}

// ── Page Controls ─────────────────────────────────────────────
class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.currentPage,
    required this.totalPages,
    required this.pageController,
    required this.surahNumber,
  });

  final int currentPage;
  final int totalPages;
  final PageController pageController;
  final int surahNumber;

  bool get _isLastAyah => currentPage == totalPages - 1;
  bool get _isLastSurah => surahNumber >= 114;
  bool get _isFirstAyah => currentPage == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 24,
        top: 12,
      ),
      color: AppColors.night,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── NEXT on LEFT (Arabic RTL direction) ──────────────
          GestureDetector(
            onTap: !_isLastAyah
                // Not last ayah — go to next ayah
                ? () => pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                // Last ayah + more surahs — go to next surah
                : !_isLastSurah
                    ? () {
                        // Replace current screen with next surah
                        // User can still tap back to return to surah list
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => AyahDetailScreen(
                              surahNumber: surahNumber + 1,
                            ),
                          ),
                        );
                      }
                    // Last ayah of An-Nas (114) — nothing more
                    : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                // Dim the button if it's the very end (An-Nas last ayah)
                color: (!_isLastAyah || !_isLastSurah)
                    ? AppColors.slate
                    : AppColors.slate.withOpacity(0.3),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 14,
                    color: (!_isLastAyah || !_isLastSurah)
                        ? AppColors.white
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    // Label changes at end of surah
                    _isLastAyah && !_isLastSurah ? 'Next Surah' : 'Next',
                    style: AppTypography.labelSmall(
                      color: (!_isLastAyah || !_isLastSurah)
                          ? AppColors.white
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Dot Indicator — RTL (active dot starts from right) ──
          _DotIndicator(
            currentPage: currentPage,
            totalPages: totalPages,
          ),

          // ── PREV on RIGHT (Arabic RTL direction) ─────────────
          GestureDetector(
            onTap: !_isFirstAyah
                ? () => pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: !_isFirstAyah
                    ? AppColors.slate
                    : AppColors.slate.withOpacity(0.3),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Prev',
                    style: AppTypography.labelSmall(
                      color: !_isFirstAyah ? AppColors.white : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: !_isFirstAyah ? AppColors.white : AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot Indicator — RTL ───────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    // For long surahs show text indicator instead of dots
    if (totalPages > 10) {
      return Text(
        '${currentPage + 1} of $totalPages',
        style: AppTypography.caption(color: AppColors.muted),
      );
    }

    // RTL dots — active dot is on the RIGHT for first ayah
    // List is reversed so dot 0 appears on the right
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (index) {
        // Reverse the index so first ayah = rightmost dot
        final reversedIndex = totalPages - 1 - index;
        final isActive = reversedIndex == currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold : AppColors.slate,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

// ── Loading Page ──────────────────────────────────────────────
class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.gold,
        strokeWidth: 2,
      ),
    );
  }
}

// ── Error Page ────────────────────────────────────────────────
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.muted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load ayat',
            style: AppTypography.labelLarge(color: AppColors.white),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
