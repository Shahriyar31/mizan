/// Ayah Detail Screen — PageView reading experience with word tap
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/quran_providers.dart';
import '../domain/audio_providers.dart';
import '../../settings/domain/reading_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/ayah.dart';
import '../../../shared/models/surah.dart';
import '../../../shared/models/ayah_word.dart';
import '../../../shared/widgets/word_tap_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/ayah_share_mapper.dart';
import '../../sharing/share_target_sheet.dart';
import 'layer_screen.dart';
import '../../../shared/widgets/tactile.dart';

class AyahDetailScreen extends ConsumerStatefulWidget {
  const AyahDetailScreen({
    super.key,
    required this.surahNumber,
    this.initialAyahNumber,
  });

  final int surahNumber;

  /// Opens the reader straight to this ayah instead of the first one —
  /// used by "Continue reading" on the surah list.
  final int? initialAyahNumber;

  @override
  ConsumerState<AyahDetailScreen> createState() => _AyahDetailScreenState();
}

class _AyahDetailScreenState extends ConsumerState<AyahDetailScreen> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.initialAyahNumber ?? 1) - 1;
    _currentPage = initialIndex < 0 ? 0 : initialIndex;
    _pageController = PageController(initialPage: _currentPage);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    // No-op here — we save on page settle below
  }

  Future<void> _saveLastAyah({
    required int surahNumber,
    required int ayahNumber,
    required String surahName,
    required String arabic,
    required String translation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', surahNumber);
    await prefs.setInt('last_ayah', ayahNumber);
    await prefs.setString('last_surah_name', surahName);
    await prefs.setString('last_ayah_arabic', arabic);
    await prefs.setString('last_ayah_translation', translation);
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

    // Get surah name from loaded data, fallback to generic
    final surahName =
        surahAsync.valueOrNull?.englishName ?? 'Surah ${widget.surahNumber}';

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
          onPageChanged: (page) {
            setState(() => _currentPage = page);
            if (page < ayat.length) {
              final ayah = ayat[page];
              _saveLastAyah(
                surahNumber: widget.surahNumber,
                ayahNumber: ayah.ayahNumber,
                surahName: surahName,
                arabic: ayah.arabicText,
                translation: ayah.translation,
              );
            }
          },
          surahNumber: widget.surahNumber,
          surahName: surahName,
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
    required this.surahName,
  });

  final AsyncValue<Surah> surahAsync;
  final List<Ayah> ayat;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final int surahNumber;
  final String surahName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SurahHeader(
          surahAsync: surahAsync,
          currentPage: currentPage,
          totalAyat: ayat.length,
          surahNumber: surahNumber,
        ),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: ayat.length,
            reverse: true,
            itemBuilder: (context, index) {
              return _AyahPage(
                ayah: ayat[index],
                surah: surahAsync.valueOrNull,
                surahNumber: surahNumber,
                surahName: surahName,
                isFirst: index == 0,
              );
            },
          ),
        ),
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
class _SurahHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(quranAudioProvider);
    final showError =
        audio.status == QuranAudioStatus.error && audio.surahNumber == surahNumber;

    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child:  Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: surahAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (surah) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.englishName,
                    style: AppTypography.displaySmall(color: AppColors.textPrimary),
                  ),
                  Text(surah.translatedName, style: AppTypography.caption()),
                ],
              ),
            ),
          ),
          _ListenButton(surahNumber: surahNumber),
          const SizedBox(width: 10),
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
          if (showError) ...[
            const SizedBox(height: 8),
            Text(
              audio.errorMessage ?? 'Playback failed.',
              style: AppTypography.caption(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Listen/Play control ─────────────────────────────────────────
class _ListenButton extends ConsumerWidget {
  const _ListenButton({required this.surahNumber});
  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(quranAudioProvider);
    final pair = ref.watch(selectedMoshafProvider);
    final isThisSurah = audio.surahNumber == surahNumber;
    final loading = isThisSurah && audio.status == QuranAudioStatus.loading;
    final playing = isThisSurah && audio.status == QuranAudioStatus.playing;

    return TactileChip(
      baseColor: AppColors.slate,
      borderRadius: 99,
      strength: 0.7,
      padding: const EdgeInsets.all(6),
      onTap: () async {
        if (pair == null) {
          try {
            context.push('/settings/audio');
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open Audio settings: $e')),
              );
            }
          }
          return;
        }
        final (reciter, moshaf) = pair;
        final notifier = ref.read(quranAudioProvider.notifier);
        if (playing) {
          await notifier.pause();
        } else if (isThisSurah && audio.status == QuranAudioStatus.paused) {
          await notifier.resume();
        } else {
          await notifier.playSurah(surahNumber, reciter: reciter, moshaf: moshaf);
        }
      },
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            )
          : Icon(
              playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: pair == null ? AppColors.muted : AppColors.gold,
              size: 30,
            ),
    );
  }
}

// ── Single Ayah Page ──────────────────────────────────────────
class _AyahPage extends ConsumerWidget {
  const _AyahPage({
    required this.ayah,
    required this.surah,
    required this.surahNumber,
    required this.surahName,
    required this.isFirst,
  });

  final Ayah ayah;
  final Surah? surah;
  final int surahNumber;
  final String surahName;
  final bool isFirst;

  static const Map<int, String> _scenes = {
    1: 'Recited in every rakah of every prayer — at minimum 17 times every day. These are the words you say to Allah more than any other.',
    18: 'Recommended to recite every Friday. Contains four stories: the People of the Cave, the two men with gardens, Musa and Al-Khidr, and Dhul-Qarnayn.',
    94: 'Revealed during the Year of Sorrow — after the Prophet ﷺ lost Khadijah (RA) and Abu Talib, and was stoned out of Ta\'if.',
    112:
        'Worth one-third of the Quran in reward. A complete description of Allah\'s nature in four ayat.',
    114:
        'The final surah. Seeks refuge in Allah from the whispering of Shaytan.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPreferencesProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final hasScene = isFirst && _scenes.containsKey(surahNumber);
    final tappableWords = ayah.tappableWords;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            if (hasScene) ...[
              const SizedBox(height: 16),
              _SceneSetting(text: _scenes[surahNumber]!),
            ],
            SizedBox(
              height: hasScene ? screenHeight * 0.08 : screenHeight * 0.18,
            ),
            Text(
              '${ayah.surahNumber}:${ayah.ayahNumber}',
              style: AppTypography.caption(color: AppColors.gold),
            ),
            const SizedBox(height: 24),
            if (tappableWords.isNotEmpty)
              _TappableArabicText(
                words: tappableWords,
                surahNumber: surahNumber,
                ayahNumber: ayah.ayahNumber,
                surahName: surahName,
                font: prefs.arabicFont,
                fontSize: prefs.arabicTextSize,
              )
            else
              Text(
                ayah.arabicText,
                style: prefs.arabicFont.style(
                  size: prefs.arabicTextSize + 2,
                  color: AppColors.textPrimary,
                  height: 1.9,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            const SizedBox(height: 32),
            Container(
              height: 1,
              width: 60,
              color: AppColors.gold.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            if (isFirst && tappableWords.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(
                    Icons.touch_app_rounded,
                    size: 12,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap any word to explore its meaning',
                    style: AppTypography.caption(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (prefs.showTransliteration &&
                (ayah.transliteration ?? '').isNotEmpty) ...[
              Text(
                ayah.transliteration!,
                style: AppTypography.quoteItalic(color: AppColors.gold)
                    .copyWith(fontSize: prefs.translationTextSize),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
            if (prefs.showTranslation && ayah.translation.isNotEmpty)
              Text(
                ayah.translation,
                style: AppTypography.quoteItalic(
                  color: AppColors.quranMuted,
                ).copyWith(fontSize: prefs.translationTextSize),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SaveAyahButton(
                  surahNumber: surahNumber,
                  ayahNumber: ayah.ayahNumber,
                ),
                const SizedBox(width: 16),
                _ShareToFeedButton(
                  ayah: ayah,
                  surah: surah,
                  surahName: surahName,
                ),
                const SizedBox(width: 16),
                _CopyAyahButton(
                  ayah: ayah,
                  surahNumber: surahNumber,
                  surahName: surahName,
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.layers_rounded,
                  label: 'Layers',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LayerScreen(
                          surahNumber: surahNumber,
                          ayahNumber: ayah.ayahNumber,
                          surahName: surahName,
                          arabicText: ayah.arabicText,
                          translation: ayah.translation,
                        ),
                      ),
                    );
                  },
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

// ── Tappable Arabic Text ──────────────────────────────────────
class _TappableArabicText extends StatelessWidget {
  const _TappableArabicText({
    required this.words,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    this.font = ArabicFont.amiri,
    this.fontSize = 28,
  });

  final List<AyahWord> words;
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final ArabicFont font;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 8,
        children: words
            .map((word) => _TappableWord(
                  word: word,
                  surahNumber: surahNumber,
                  ayahNumber: ayahNumber,
                  surahName: surahName,
                  font: font,
                  fontSize: fontSize,
                ))
            .toList(),
      ),
    );
  }
}

// ── Single Tappable Word ──────────────────────────────────────
class _TappableWord extends StatefulWidget {
  const _TappableWord({
    required this.word,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    this.font = ArabicFont.amiri,
    this.fontSize = 28,
  });

  final AyahWord word;
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final ArabicFont font;
  final double fontSize;

  @override
  State<_TappableWord> createState() => _TappableWordState();
}

class _TappableWordState extends State<_TappableWord> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        showWordSheet(
          context,
          widget.word,
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          surahName: widget.surahName,
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color:
              _pressed ? AppColors.jade.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _pressed ? AppColors.jade.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Text(
          widget.word.arabic,
          style: widget.font.style(
            size: widget.fontSize,
            color: _pressed ? AppColors.gold : AppColors.textPrimary,
            height: 1.9,
          ),
          textDirection: TextDirection.rtl,
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
        border:  Border(
          left:  BorderSide(color: AppColors.gold, width: 3),
        ),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall(color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
   _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    Color? iconColor,
    this.labelColor,
  })  : _iconColor = iconColor;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? _iconColor;

  Color get iconColor => _iconColor ?? AppColors.muted;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Tactile(
          onTap: onTap,
          baseColor: AppColors.slate,
          borderRadius: 12,
          strength: 0.8,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.slate,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: AppTypography.caption(color: labelColor ?? AppColors.muted)),
      ],
    );
  }
}

// ── Saved ayat — lightweight local bookmark list ────────────────
class SavedAyatStore {
  static const _key = 'saved_ayat';

  static Future<Set<String>> _load(SharedPreferences prefs) async =>
      (prefs.getStringList(_key) ?? const []).toSet();

  static Future<bool> isSaved(int surahNumber, int ayahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await _load(prefs);
    return saved.contains('$surahNumber:$ayahNumber');
  }

  /// Flips the saved state for this ayah and returns the new state.
  static Future<bool> toggle(int surahNumber, int ayahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await _load(prefs);
    final key = '$surahNumber:$ayahNumber';
    final nowSaved = !saved.contains(key);
    nowSaved ? saved.add(key) : saved.remove(key);
    await prefs.setStringList(_key, saved.toList());
    return nowSaved;
  }
}

// ── Save button — bookmarks the ayah locally ────────────────────
class _SaveAyahButton extends StatefulWidget {
  const _SaveAyahButton({required this.surahNumber, required this.ayahNumber});

  final int surahNumber;
  final int ayahNumber;

  @override
  State<_SaveAyahButton> createState() => _SaveAyahButtonState();
}

class _SaveAyahButtonState extends State<_SaveAyahButton> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    SavedAyatStore.isSaved(widget.surahNumber, widget.ayahNumber).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    final nowSaved =
        await SavedAyatStore.toggle(widget.surahNumber, widget.ayahNumber);
    if (!mounted) return;
    setState(() => _saved = nowSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowSaved ? 'Ayah saved' : 'Removed from saved ayat',
          style: AppTypography.bodySmall(color: AppColors.white),
        ),
        backgroundColor: nowSaved ? AppColors.jade : AppColors.muted,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      label: _saved ? 'Saved' : 'Save',
      iconColor: _saved ? AppColors.gold : AppColors.muted,
      labelColor: _saved ? AppColors.gold : null,
      onTap: _toggle,
    );
  }
}

// ── Share to feed — opens the in-app share sheet (Al-Minbar / a circle) ──
// This is the app's core social action: pass the ayah on to your circle or
// the whole Ummah. The sheet itself handles picking a destination, the
// optional note for a circle, persistence, and the confirmation — so here we
// just build the verified content snapshot and hand it over.
class _ShareToFeedButton extends StatelessWidget {
  const _ShareToFeedButton({
    required this.ayah,
    required this.surah,
    required this.surahName,
  });

  final Ayah ayah;
  final Surah? surah;
  final String surahName;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      icon: Icons.share_rounded,
      label: 'Share',
      onTap: () {
        HapticFeedback.selectionClick();
        showShareTargetSheet(
          context,
          ayah.toSharedContent(surah: surah, fallbackName: surahName),
        );
      },
    );
  }
}

// ── Copy button — copies a shareable card to the clipboard ─────
// The "outward" counterpart to Share: for pasting into WhatsApp, notes, etc.
// No native OS share-sheet dependency in the project yet (share_plus), so a
// clipboard copy is the real, working action today.
class _CopyAyahButton extends StatelessWidget {
  const _CopyAyahButton({
    required this.ayah,
    required this.surahNumber,
    required this.surahName,
  });

  final Ayah ayah;
  final int surahNumber;
  final String surahName;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      icon: Icons.copy_rounded,
      label: 'Copy',
      onTap: () async {
        HapticFeedback.selectionClick();
        final text = '${ayah.arabicText}\n\n'
            '"${ayah.translation}"\n\n'
            '— Quran $surahName $surahNumber:${ayah.ayahNumber}';
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ayah copied — paste anywhere to share',
              style: AppTypography.bodySmall(color: AppColors.white),
            ),
            backgroundColor: AppColors.jade,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
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
          Tactile(
            baseColor: AppColors.slate,
            borderRadius: 99,
            strength: 0.7,
            enabled: !_isLastAyah || !_isLastSurah,
            onTap: !_isLastAyah
                ? () => pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : !_isLastSurah
                    ? () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => AyahDetailScreen(
                              surahNumber: surahNumber + 1,
                            ),
                          ),
                        );
                      }
                    : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: (!_isLastAyah || !_isLastSurah)
                    ? AppColors.slate
                    : AppColors.slate.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 14,
                    color: (!_isLastAyah || !_isLastSurah)
                        ? AppColors.textPrimary
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isLastAyah && !_isLastSurah ? 'Next Surah' : 'Next',
                    style: AppTypography.labelSmall(
                      color: (!_isLastAyah || !_isLastSurah)
                          ? AppColors.textPrimary
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _DotIndicator(
            currentPage: currentPage,
            totalPages: totalPages,
          ),
          Tactile(
            baseColor: AppColors.slate,
            borderRadius: 99,
            strength: 0.7,
            enabled: !_isFirstAyah,
            onTap: !_isFirstAyah
                ? () => pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: !_isFirstAyah
                    ? AppColors.slate
                    : AppColors.slate.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Prev',
                    style: AppTypography.labelSmall(
                      color: !_isFirstAyah ? AppColors.textPrimary : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: !_isFirstAyah ? AppColors.textPrimary : AppColors.muted,
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
    if (totalPages > 10) {
      return Text(
        '${currentPage + 1} of $totalPages',
        style: AppTypography.caption(color: AppColors.muted),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (index) {
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

// ── Loading / Error ───────────────────────────────────────────
class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.wifi_off_rounded, color: AppColors.muted, size: 48),
          const SizedBox(height: 16),
          Text(
            'Could not load ayat',
            style: AppTypography.labelLarge(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
