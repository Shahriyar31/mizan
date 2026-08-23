/// READER — the ayah page.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 4 (screen 03 of 08).
///
/// ── The big change: a scroll, not a slideshow ──────────────────────────
/// The old reader was a horizontal [PageView], one ayah per screen, with
/// Prev/Next buttons at the bottom. The mockup is a **vertical scroll of ayah
/// cards**, which is how every Mushaf and every Quran app works, and how people
/// actually read: an ayah with the one before and after it in view. The
/// horizontal pager also fought the app shell's own left/right tab gestures.
///
/// So the reader is now a [CustomScrollView] with two slivers around a `center`
/// key. That is what makes "open Al-Baqarah at ayah 255" land *at* 255 with 254
/// scrollable above it, without measuring or animating anything — the ayat
/// before the target lay out upward from the centre, the rest downward. A
/// `jumpTo` on a list of variable-height cards cannot do that.
///
/// ── What each piece of the mockup is wired to ─────────────────────────
///   • **"Ayah 2 of 286"** — the live reading position, recomputed when the
///     scroll settles by asking which card sits under the upper third of the
///     screen. That same number is what gets written to `last_ayah`, so Home's
///     "Continue reading" resumes where the eye actually was, not where the
///     screen was opened.
///   • **"Juz 1"** is **not** shown. Juz boundaries are a fact about the Quran
///     and this app has no juz table — not in [Surah], not in [Ayah], not in the
///     API response we parse. Guessing them by arithmetic would put a wrong
///     number on a Mushaf. The surah's translated name takes that slot instead.
///   • **Tt** opens real reading settings, backed by
///     [readingPreferencesProvider] — Arabic font and size, translation size,
///     translation and transliteration toggles — the same store Settings →
///     Personalisation writes to.
///   • **•••** holds the things that have no room on a card: jump to an ayah
///     and copy it. Not the layers — the card already links to those.
///   • **The ▶ on a card plays that ayah**, through
///     [ayahAudioProvider] — one file per ayah, so when it ends the player
///     knows, and can move to the next ayah, scroll the list to it, or replay it
///     for memorisation. The surah-at-a-time player in `audio_providers.dart`
///     cannot do any of that, so it is stopped whenever this one starts.
///   • **Repeat** lives in the player bar: 1× · 3× · 5× · 10× · ∞. It repeats
///     the *current* ayah that many times and then carries on, which is how
///     memorising actually works.
///   • **"Layers"** opens the five-layer screen for that ayah. Exactly one way
///     in, one word, the same on every ayah: three controls that all landed on
///     the same screen made the row look like it offered three things. Where no
///     curated tafseer exists yet, [LayerScreen] says so itself — the label does
///     not change, because a control that renames itself per ayah reads as a
///     different feature rather than the same one.
///   • **The word-by-word strip** shows on the focused ayah only — it is real
///     data ([Ayah.tappableWords]) and tapping a word opens the existing word
///     sheet. On every card at once it would bury the ayah.
///
/// ── Deviations from the mockup, on purpose ────────────────────────────
///   • The player bar does not float *over* the text; it sits directly above the
///     app shell's tab bar. Overlapping content hides an ayah, and hiding
///     revelation to show a progress bar is the wrong trade.
///   • The mockup's note/pencil icon is not drawn. Per-ayah *notes* are stored by
///     the Layers screen's reflection step, so the "Layers" link is already the
///     way to write on an ayah; a pencil beside it would be a second door to one
///     room.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/models/ayah.dart';
import '../../../shared/models/ayah_word.dart';
import '../../../shared/models/surah.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../../shared/widgets/mizan/mizan_pressable.dart';
import '../../../shared/widgets/word_tap_sheet.dart';
import '../../settings/domain/reading_preferences_provider.dart';
import '../../sharing/share_target_sheet.dart';
import '../data/ayah_share_mapper.dart';
import '../domain/audio_providers.dart';
import '../domain/ayah_audio_provider.dart';
import '../domain/quran_providers.dart';
import 'layer_screen.dart';

/// The basmala, shown above the first ayah of every surah except Al-Fatihah
/// (where it *is* ayah 1) and At-Tawbah (which has none).
const String _kBasmala = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

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
  /// Anchors the second sliver. Everything before the opening ayah lays out
  /// upward from here, everything after it downward — see the library comment.
  final _centerKey = const ValueKey<String>('reader-center');

  /// One key per built card, so the scroll handler can ask the framework where
  /// each card actually ended up. Cards that scrolled out have a null context
  /// and are skipped, so this stays cheap.
  final Map<int, GlobalKey> _cardKeys = {};

  late final int _openAt = ((widget.initialAyahNumber ?? 1) - 1).clamp(0, 9999);

  /// The ayah under the reading line. Drives the header count and what is saved
  /// as the resume point.
  late int _readingIndex = _openAt;

  /// The ayah whose word-by-word strip is open. Starts on the one you arrived
  /// at, so the feature is discoverable without a hint telling you to tap.
  late int _focusedIndex = _openAt;

  GlobalKey _keyFor(int index) =>
      _cardKeys.putIfAbsent(index, () => GlobalKey());

  Future<void> _saveResumePoint(Ayah ayah, String surahName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', widget.surahNumber);
    await prefs.setInt('last_ayah', ayah.ayahNumber);
    await prefs.setString('last_surah_name', surahName);
    await prefs.setString('last_ayah_arabic', ayah.arabicText);
    await prefs.setString('last_ayah_translation', ayah.translation);
  }

  /// Which card is being read: the one crossing a line a third of the way down
  /// the screen. One rule, no history, no guessing at scroll direction.
  int? _indexUnderReadingLine() {
    final probe = MediaQuery.sizeOf(context).height / 3;
    int? containing;
    int? nearest;
    var nearestGap = double.infinity;

    for (final entry in _cardKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;

      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      if (top <= probe && bottom > probe) containing = entry.key;

      final gap = (top - probe).abs();
      if (gap < nearestGap) {
        nearestGap = gap;
        nearest = entry.key;
      }
    }
    // `nearest` covers the gap above the first card and below the last one,
    // where no card crosses the line at all.
    return containing ?? nearest;
  }

  void _onScrollSettled(List<Ayah> ayat, String surahName) {
    final index = _indexUnderReadingLine();
    if (index == null || index == _readingIndex) return;
    if (index < 0 || index >= ayat.length) return;
    setState(() => _readingIndex = index);
    _saveResumePoint(ayat[index], surahName);
  }

  /// Brings an ayah to just under the header. Used when the recitation moves on
  /// by itself — the card should follow the voice, not the other way round.
  ///
  /// [Scrollable.ensureVisible] rather than an offset, because the cards have
  /// variable height and there is no offset to compute. If the card is too far
  /// off-screen to have been built its context is null; that only happens on a
  /// deliberate jump, never on the one-step advance this exists for.
  void _scrollToAyah(int ayahNumber) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[ayahNumber - 1]?.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.08,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final surahAsync = ref.watch(surahsProvider).whenData(
          (surahs) => surahs.firstWhere(
            (s) => s.number == widget.surahNumber,
            orElse: () => throw Exception('Surah not found'),
          ),
        );
    final ayatAsync = ref.watch(ayatProvider(widget.surahNumber));
    final surah = surahAsync.valueOrNull;
    final surahName = surah?.englishName ?? 'Surah ${widget.surahNumber}';

    final audio = ref.watch(ayahAudioProvider);
    final playingIndex =
        (audio.isActive && audio.surahNumber == widget.surahNumber)
            ? audio.ayahNumber! - 1
            : -1;

    // Follow the recitation. Kept here rather than inside the audio controller
    // so the player knows nothing about lists, keys or scroll positions.
    ref.listen<AyahAudioState>(ayahAudioProvider, (previous, next) {
      if (!next.isActive || next.surahNumber != widget.surahNumber) return;
      if (previous?.ayahNumber == next.ayahNumber) return;
      _scrollToAyah(next.ayahNumber!);
    });

    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          _ReaderHeader(
            surah: surah,
            surahNumber: widget.surahNumber,
            readingAyah: ayatAsync.valueOrNull != null &&
                    _readingIndex < ayatAsync.value!.length
                ? ayatAsync.value![_readingIndex].ayahNumber
                : null,
            totalAyat: ayatAsync.valueOrNull?.length,
            onJump: (ayat) => _showJumpSheet(context, ayat),
            ayat: ayatAsync.valueOrNull,
            surahName: surahName,
          ),
          Expanded(
            child: switch (ayatAsync) {
              AsyncLoading() => const _LoadingBody(),
              AsyncError() => _ErrorBody(
                  onRetry: () =>
                      ref.invalidate(ayatProvider(widget.surahNumber)),
                ),
              AsyncValue(:final value?) => _ReaderScroll(
                  ayat: value,
                  surah: surah,
                  surahNumber: widget.surahNumber,
                  surahName: surahName,
                  centerKey: _centerKey,
                  openAt: _openAt.clamp(0, value.length - 1),
                  focusedIndex: _focusedIndex,
                  playingIndex: playingIndex,
                  keyFor: _keyFor,
                  onFocus: (i) => setState(
                    () => _focusedIndex = _focusedIndex == i ? -1 : i,
                  ),
                  onSettled: () => _onScrollSettled(value, surahName),
                ),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
      // Not `Positioned` over the text: see the library comment. Null while
      // nothing from this surah is loaded, so the reading area keeps its height.
      bottomNavigationBar: _PlayerBar(surahNumber: widget.surahNumber),
    );
  }

  /// Jump straight to an ayah. Pushed as a route replacement so the reader
  /// rebuilds with a new centre — the same mechanism as arriving from Home.
  void _showJumpSheet(BuildContext context, List<Ayah>? ayat) {
    if (ayat == null || ayat.isEmpty) return;
    final p = MizanPalette.of(context);
    final controller = TextEditingController();

    void go() {
      final n = int.tryParse(controller.text.trim());
      if (n == null || n < 1 || n > ayat.length) return;
      Navigator.of(context).pop();
      context.pushReplacement('/quran/${widget.surahNumber}?ayah=$n');
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: MizanGeometry.gutter,
          right: MizanGeometry.gutter,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
              MizanGeometry.gutter,
        ),
        child: MizanSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MizanSectionLabel('GO TO AYAH'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: MizanType.cardHeadline(color: p.ink),
                cursorColor: p.accentText,
                decoration: InputDecoration(
                  hintText: '1 – ${ayat.length}',
                  hintStyle: MizanType.body(color: p.muted),
                  filled: true,
                  fillColor: p.sunk,
                  border: OutlineInputBorder(
                    borderRadius: MizanGeometry.rowBorderRadius,
                    borderSide: BorderSide(color: p.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: MizanGeometry.rowBorderRadius,
                    borderSide: BorderSide(color: p.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: MizanGeometry.rowBorderRadius,
                    borderSide: BorderSide(color: p.accentText),
                  ),
                ),
                onSubmitted: (_) => go(),
              ),
              const SizedBox(height: 16),
              MizanButton(label: 'Go', expand: true, onPressed: go),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════

class _ReaderHeader extends ConsumerWidget {
  const _ReaderHeader({
    required this.surah,
    required this.surahNumber,
    required this.readingAyah,
    required this.totalAyat,
    required this.onJump,
    required this.ayat,
    required this.surahName,
  });

  final Surah? surah;
  final int surahNumber;
  final int? readingAyah;
  final int? totalAyat;
  final void Function(List<Ayah>?) onJump;
  final List<Ayah>? ayat;
  final String surahName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    // "Ayah 2 of 286 · The Cow" — the position, then what the surah is called.
    // No juz: the data has none, and see the library comment.
    final meta = [
      if (readingAyah != null && totalAyat != null)
        'Ayah $readingAyah of $totalAyat',
      if (surah != null && surah!.translatedName.isNotEmpty)
        surah!.translatedName,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: p.page,
        border: Border(
          bottom: BorderSide(
            color: p.hairline,
            width: MizanGeometry.hairlineWidth,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            children: [
              MizanIconTile(
                icon: Icons.arrow_back_ios_new_rounded,
                iconSize: 18,
                semanticLabel: 'Back',
                onTap: () => context.pop(),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      surah?.englishName ?? 'Surah $surahNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MizanType.cardHeadline(color: p.ink),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MizanType.body(color: p.muted)
                            .copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              MizanIconTile(
                icon: Icons.text_fields_rounded,
                semanticLabel: 'Reading settings',
                onTap: () => _showReadingSettings(context),
              ),
              const SizedBox(width: 8),
              MizanIconTile(
                icon: Icons.more_horiz_rounded,
                semanticLabel: 'More',
                onTap: () => _showMoreSheet(
                  context,
                  ref,
                  ayat: ayat,
                  surah: surah,
                  surahNumber: surahNumber,
                  surahName: surahName,
                  readingAyah: readingAyah,
                  onJump: () => onJump(ayat),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE SCROLL
// ══════════════════════════════════════════════════════════════════════

class _ReaderScroll extends StatelessWidget {
  const _ReaderScroll({
    required this.ayat,
    required this.surah,
    required this.surahNumber,
    required this.surahName,
    required this.centerKey,
    required this.openAt,
    required this.focusedIndex,
    required this.playingIndex,
    required this.keyFor,
    required this.onFocus,
    required this.onSettled,
  });

  final List<Ayah> ayat;
  final Surah? surah;
  final int surahNumber;
  final String surahName;
  final Key centerKey;
  final int openAt;
  final int focusedIndex;

  /// Index of the ayah currently loaded in the per-ayah player, or -1.
  final int playingIndex;

  final GlobalKey Function(int) keyFor;
  final ValueChanged<int> onFocus;
  final VoidCallback onSettled;

  Widget _card(int index) => Padding(
        key: keyFor(index),
        padding: const EdgeInsets.only(bottom: MizanGeometry.gap),
        child: _AyahCard(
          ayah: ayat[index],
          surah: surah,
          surahNumber: surahNumber,
          surahName: surahName,
          ayahCount: ayat.length,
          focused: index == focusedIndex,
          playing: index == playingIndex,
          onTap: () => onFocus(index),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        onSettled();
        return false;
      },
      child: CustomScrollView(
        center: centerKey,
        slivers: [
          // Laid out upward from the centre: child 0 is the ayah directly above
          // the opening one, and the last child is the surah preamble.
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MizanGeometry.gutter,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final index = openAt - 1 - i;
                  if (index >= 0) return _card(index);
                  return _SurahPreamble(
                    surah: surah,
                    surahNumber: surahNumber,
                  );
                },
                childCount: openAt + 1,
              ),
            ),
          ),
          SliverPadding(
            key: centerKey,
            padding: const EdgeInsets.symmetric(
              horizontal: MizanGeometry.gutter,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final index = openAt + i;
                  if (index < ayat.length) return _card(index);
                  return _SurahEnd(
                    surahNumber: surahNumber,
                    ayahCount: ayat.length,
                  );
                },
                childCount: ayat.length - openAt + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Above the first ayah: the basmala, and the one curated line about why this
/// surah matters, where such a line exists.
class _SurahPreamble extends StatelessWidget {
  const _SurahPreamble({required this.surah, required this.surahNumber});

  final Surah? surah;
  final int surahNumber;

  /// Curated, and deliberately short. Every line here is a statement of fact
  /// about the surah that can be pointed at a source; nothing is generated.
  static const Map<int, String> _notes = {
    1: 'Recited in every rakah of every prayer — at minimum 17 times every day. '
        'These are the words you say to Allah more than any other.',
    18: 'Recommended to recite every Friday. Contains four stories: the People '
        'of the Cave, the two men with gardens, Musa and Al-Khidr, and '
        'Dhul-Qarnayn.',
    94: 'Revealed during the Year of Sorrow — after the Prophet ﷺ lost Khadijah '
        '(RA) and Abu Talib, and was stoned out of Ta\'if.',
    112: 'Worth one-third of the Quran in reward. A complete description of '
        'Allah\'s nature in four ayat.',
    114: 'The final surah. Seeks refuge in Allah from the whispering of Shaytan.',
  };

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    // Al-Fatihah opens *with* the basmala as its first ayah, and At-Tawbah is
    // the one surah that has none. Printing it there would be an error.
    final showBasmala = surahNumber != 1 && surahNumber != 9;
    final note = _notes[surahNumber];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        if (surah != null) ...[
          Center(
            child: Text(
              surah!.arabicName,
              textDirection: TextDirection.rtl,
              style: MizanType.arabic(color: p.ink, fontSize: 26),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '${surah!.verseCount} ayat · '
              '${surah!.revelationPlace == RevelationPlace.makkah ? 'Makkah' : 'Madinah'}',
              style: MizanType.sectionLabel(color: p.muted),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (showBasmala) ...[
          Center(
            child: Text(
              _kBasmala,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              // Gold as text on cream is barred, so the basmala takes bronze —
              // the text-legal member of the gold family (Rule #1).
              style: MizanType.arabic(color: p.accentText, fontSize: 30),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 150,
              child: MizanRule(color: p.accentText.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 22),
        ],
        if (note != null) ...[
          MizanSurface(
            tone: MizanTone.sunk,
            padding: const EdgeInsets.all(MizanGeometry.cardPaddingTight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MizanSectionLabel('ABOUT THIS SURAH', color: p.accentText),
                const SizedBox(height: 8),
                Text(note, style: MizanType.body(color: p.ink)),
              ],
            ),
          ),
          const SizedBox(height: MizanGeometry.gap),
        ],
      ],
    );
  }
}

/// After the last ayah. No congratulation and no total — Rule #4. It states
/// what happened and offers the next surah.
class _SurahEnd extends ConsumerWidget {
  const _SurahEnd({required this.surahNumber, required this.ayahCount});

  final int surahNumber;
  final int ayahCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final isLast = surahNumber >= 114;
    final next = ref.watch(surahsProvider).valueOrNull?.firstWhere(
          (s) => s.number == surahNumber + 1,
          orElse: () => throw Exception('no next surah'),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(child: MizanDiamond(size: 8, color: p.accentText)),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'End of the surah · $ayahCount ayat',
            style: MizanType.sectionLabel(color: p.muted),
          ),
        ),
        if (!isLast) ...[
          const SizedBox(height: 20),
          MizanButton(
            label: next == null
                ? 'Continue to surah ${surahNumber + 1}'
                : 'Continue to ${next.englishName}',
            trailingIcon: Icons.arrow_forward_rounded,
            kind: MizanButtonKind.secondary,
            expand: true,
            onPressed: () {
              HapticFeedback.selectionClick();
              context.pushReplacement('/quran/${surahNumber + 1}');
            },
          ),
        ],
        const SizedBox(height: MizanGeometry.scrollBottomPadding),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ONE AYAH
// ══════════════════════════════════════════════════════════════════════

class _AyahCard extends ConsumerWidget {
  const _AyahCard({
    required this.ayah,
    required this.surah,
    required this.surahNumber,
    required this.surahName,
    required this.ayahCount,
    required this.focused,
    required this.playing,
    required this.onTap,
  });

  final Ayah ayah;
  final Surah? surah;
  final int surahNumber;
  final String surahName;

  /// Ayat in this surah — the recitation needs to know where to stop advancing.
  final int ayahCount;

  /// Tapped open by the reader: shows the word-by-word strip.
  final bool focused;

  /// Loaded in the per-ayah player: takes the gold border wherever the scroll is.
  final bool playing;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final prefs = ref.watch(readingPreferencesProvider);
    final words = ayah.tappableWords;
    final lit = focused || playing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      // Deliberately not a MizanSurface: an ayah is content, so it stays flat
      // with a hairline (never a press shadow), and the focused state needs to
      // change the border colour, which the shared surface does not expose.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(MizanGeometry.cardPadding),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: MizanGeometry.cardBorderRadius,
          border: Border.all(
            color: lit ? p.accent : p.hairline,
            width: MizanGeometry.hairlineWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AyahBadge(
                  number: ayah.ayahNumber,
                  filled: lit,
                  playing: playing,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: words.isEmpty
                      ? Text(
                          ayah.arabicText,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: prefs.arabicFont.style(
                            size: prefs.arabicTextSize,
                            color: p.ink,
                            height: 1.9,
                          ),
                        )
                      : _TappableArabic(
                          words: words,
                          surahNumber: surahNumber,
                          ayahNumber: ayah.ayahNumber,
                          surahName: surahName,
                          font: prefs.arabicFont,
                          fontSize: prefs.arabicTextSize,
                        ),
                ),
              ],
            ),
            if (prefs.showTransliteration &&
                (ayah.transliteration ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                ayah.transliteration!,
                style: MizanType.body(color: p.muted)
                    .copyWith(fontSize: prefs.translationTextSize),
              ),
            ],
            if (prefs.showTranslation && ayah.translation.isNotEmpty) ...[
              const SizedBox(height: 14),
              // The one italic serif on the card — the translation is a
              // rendering of the meaning, not the words themselves.
              Text(
                ayah.translation,
                style: MizanType.translation(color: p.ink)
                    .copyWith(fontSize: prefs.translationTextSize + 2),
              ),
            ],
            if (focused && words.isNotEmpty) ...[
              const SizedBox(height: 18),
              _WordByWord(
                words: words,
                surahNumber: surahNumber,
                ayahNumber: ayah.ayahNumber,
                surahName: surahName,
                font: prefs.arabicFont,
              ),
            ],
            const SizedBox(height: 16),
            MizanRule(color: p.hairline),
            const SizedBox(height: 14),
            _AyahActions(
              ayah: ayah,
              surah: surah,
              surahNumber: surahNumber,
              surahName: surahName,
              ayahCount: ayahCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _AyahBadge extends StatelessWidget {
  const _AyahBadge({
    required this.number,
    required this.filled,
    required this.playing,
  });

  final int number;
  final bool filled;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Gold fill is free of Rule #1 — the rule is about gold *text*.
            color: filled ? p.accent : Colors.transparent,
            border: Border.all(
              color: filled ? p.accent : p.accentText.withValues(alpha: 0.5),
              width: MizanGeometry.hairlineWidth,
            ),
          ),
          child: Text(
            '$number',
            style: MizanType.sectionLabel(
              color: filled ? MizanTone.inverse.onColor(p) : p.accentText,
            ),
          ),
        ),
        // The border alone cannot say *why* a card is lit — a tapped card and a
        // reciting card would look identical. This glyph is the difference.
        if (playing) ...[
          const SizedBox(height: 7),
          Icon(Icons.graphic_eq_rounded, size: 15, color: p.accentText),
        ],
      ],
    );
  }
}

/// The action row. Every icon here does something today; nothing is drawn dead.
class _AyahActions extends ConsumerWidget {
  const _AyahActions({
    required this.ayah,
    required this.surah,
    required this.surahNumber,
    required this.surahName,
    required this.ayahCount,
  });

  final Ayah ayah;
  final Surah? surah;
  final int surahNumber;
  final String surahName;
  final int ayahCount;

  void _openLayers(BuildContext context) {
    HapticFeedback.selectionClick();
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);

    return Row(
      children: [
        _ListenTile(
          surahNumber: surahNumber,
          ayahNumber: ayah.ayahNumber,
          ayahCount: ayahCount,
        ),
        const SizedBox(width: 10),
        _SaveTile(surahNumber: surahNumber, ayahNumber: ayah.ayahNumber),
        const SizedBox(width: 10),
        MizanIconTile(
          icon: Icons.ios_share_rounded,
          iconSize: 18,
          semanticLabel: 'Share this ayah',
          onTap: () {
            HapticFeedback.selectionClick();
            showShareTargetSheet(
              context,
              ayah.toSharedContent(surah: surah, fallbackName: surahName),
            );
          },
        ),
        const Spacer(),
        // The one and only way into the layers from a card. It is a word rather
        // than a glyph because "Layers" needs explaining and a stack icon does
        // not explain it — and it says the same word on every ayah, whether or
        // not curated tafsir exists behind it, so the row never looks like it
        // is offering different things on different ayat.
        MizanPressable(
          fill: Colors.transparent,
          shadowsEnabled: false,
          borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          semanticLabel: 'Open the five layers for this ayah',
          onTap: () => _openLayers(context),
          child: Text(
            'Layers',
            style: MizanType.bodyStrong(color: p.accentText),
          ),
        ),
      ],
    );
  }
}

/// Plays *this ayah*. Gold while it is the one reciting.
class _ListenTile extends ConsumerWidget {
  const _ListenTile({
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahCount,
  });

  final int surahNumber;
  final int ayahNumber;
  final int ayahCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final audio = ref.watch(ayahAudioProvider);
    final isThis = audio.isOn(surahNumber, ayahNumber);
    final playing = isThis && audio.status == AyahAudioStatus.playing;
    final loading = isThis && audio.status == AyahAudioStatus.loading;

    return MizanIconTile(
      icon: loading
          ? Icons.hourglass_empty_rounded
          : playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
      iconSize: 20,
      iconColor: isThis ? p.accentText : null,
      semanticLabel: playing ? 'Pause recitation' : 'Recite this ayah',
      onTap: () {
        HapticFeedback.selectionClick();
        // Two players, never both: the surah-at-a-time one stops here so a tap
        // can never leave two recitations overlapping.
        ref.read(quranAudioProvider.notifier).stop();
        ref.read(ayahAudioProvider.notifier).playAyah(
              surahNumber,
              ayahNumber,
              lastAyah: ayahCount,
            );
      },
    );
  }
}

class _SaveTile extends StatefulWidget {
  const _SaveTile({required this.surahNumber, required this.ayahNumber});

  final int surahNumber;
  final int ayahNumber;

  @override
  State<_SaveTile> createState() => _SaveTileState();
}

class _SaveTileState extends State<_SaveTile> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    SavedAyatStore.isSaved(widget.surahNumber, widget.ayahNumber).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanIconTile(
      icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      iconSize: 18,
      iconColor: _saved ? p.accentText : null,
      semanticLabel: _saved ? 'Remove from saved ayat' : 'Save this ayah',
      onTap: () async {
        HapticFeedback.mediumImpact();
        final nowSaved = await SavedAyatStore.toggle(
          widget.surahNumber,
          widget.ayahNumber,
        );
        if (!mounted) return;
        setState(() => _saved = nowSaved);
      },
    );
  }
}

// ── Tappable Arabic ─────────────────────────────────────────────────────

class _TappableArabic extends StatelessWidget {
  const _TappableArabic({
    required this.words,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.font,
    required this.fontSize,
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
        alignment: WrapAlignment.start,
        spacing: 2,
        runSpacing: 6,
        children: [
          for (final word in words)
            _TappableWord(
              word: word,
              surahNumber: surahNumber,
              ayahNumber: ayahNumber,
              surahName: surahName,
              font: font,
              fontSize: fontSize,
            ),
        ],
      ),
    );
  }
}

class _TappableWord extends StatefulWidget {
  const _TappableWord({
    required this.word,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.font,
    required this.fontSize,
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
    final p = MizanPalette.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          // The word lifts on press by warming its ground, not by changing the
          // letterform — the script is the one thing on this screen that never
          // moves.
          color: _pressed ? p.sunk : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.word.arabic,
          textDirection: TextDirection.rtl,
          style: widget.font.style(
            size: widget.fontSize,
            color: _pressed ? p.accentText : p.ink,
            height: 1.9,
          ),
        ),
      ),
    );
  }
}

/// The word-by-word strip. Each chip is the Arabic with its own gloss beneath,
/// which is the whole content of the word sheet in miniature.
class _WordByWord extends StatelessWidget {
  const _WordByWord({
    required this.words,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.font,
  });

  final List<AyahWord> words;
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final ArabicFont font;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      tone: MizanTone.sunk,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MizanSectionLabel('WORD BY WORD', color: p.accentText),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: [
                for (final word in words)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: MizanPressable(
                      borderRadius: BorderRadius.circular(10),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      semanticLabel: 'Explore ${word.transliteration}',
                      onTap: () => showWordSheet(
                        context,
                        word,
                        surahNumber: surahNumber,
                        ayahNumber: ayahNumber,
                        surahName: surahName,
                      ),
                      child: Column(
                        children: [
                          Text(
                            word.arabic,
                            textDirection: TextDirection.rtl,
                            style: font.style(size: 20, color: p.ink),
                          ),
                          if (word.translation.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              word.translation,
                              style: MizanType.body(color: p.muted)
                                  .copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
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
//  PLAYER BAR
// ══════════════════════════════════════════════════════════════════════

/// Sits above the app shell's tab bar while an ayah is loaded. It reports what
/// is reciting, how far through it is, and how many more times it will repeat.
///
/// Every [Column] in here is `MainAxisSize.min`. That is not tidiness: a Column
/// inside a Row's [Expanded] is measured against the *incoming* height, which
/// from `Scaffold.bottomNavigationBar` is the whole screen — so a default
/// `MainAxisSize.max` makes this bar swallow the entire reader.
class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({required this.surahNumber});

  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final audio = ref.watch(ayahAudioProvider);
    final reciter = ref.watch(ayahReciterProvider);

    if (!audio.isActive || audio.surahNumber != surahNumber) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(ayahAudioProvider.notifier);
    final failed = audio.status == AyahAudioStatus.error;
    final loading = audio.status == AyahAudioStatus.loading;
    final playing = audio.status == AyahAudioStatus.playing;
    final onNavy = MizanTone.inverse.onColor(p);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MizanGeometry.gutter,
          0,
          MizanGeometry.gutter,
          8,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The one navy panel on the reader, in both themes: the player is a
            // device sitting on the page, not part of the page.
            color: MizanTone.inverse.resolve(p),
            borderRadius: MizanGeometry.cardBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BarIcon(
                  icon: failed
                      ? Icons.refresh_rounded
                      : loading
                          ? Icons.hourglass_empty_rounded
                          : playing
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                  size: 30,
                  semanticLabel: playing ? 'Pause' : 'Play',
                  onTap: () {
                    if (failed) {
                      controller.playAyah(
                        surahNumber,
                        audio.ayahNumber!,
                        lastAyah: audio.lastAyah,
                      );
                      return;
                    }
                    playing ? controller.pause() : controller.resume();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: failed
                      ? Text(
                          audio.errorMessage ?? 'Playback stopped.',
                          maxLines: 3,
                          style: MizanType.body(color: onNavy)
                              .copyWith(fontSize: 12.5),
                        )
                      : _PlayerProgress(
                          reciterName: reciter.name,
                          ayahNumber: audio.ayahNumber!,
                          repeatTarget: audio.repeatTarget,
                          repeatDone: audio.repeatDone,
                          controller: controller,
                          onPickReciter: () => _showReciterSheet(context),
                        ),
                ),
                const SizedBox(width: 6),
                // Repeat. The label is the count, because an icon alone cannot
                // say "five times" — and five times is the whole point.
                _RepeatButton(
                  target: audio.repeatTarget,
                  onTap: controller.cycleRepeat,
                ),
                _BarIcon(
                  icon: Icons.close_rounded,
                  size: 20,
                  semanticLabel: 'Stop recitation',
                  onTap: controller.stop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanPressable(
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.all(7),
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Icon(icon, size: size, color: p.accent),
    );
  }
}

/// 1× shows nothing but the outline; 3/5/10 show the number; ∞ shows the glyph.
class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.target, required this.onTap});

  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final on = target != 1;
    final onNavy = MizanTone.inverse.onColor(p);

    return MizanPressable(
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      semanticLabel: target == kRepeatForever
          ? 'Repeat: always. Tap to change.'
          : target == 1
              ? 'Repeat: off. Tap to repeat this ayah.'
              : 'Repeat: $target times. Tap to change.',
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat_rounded,
            size: 19,
            color: on ? p.accent : onNavy.withValues(alpha: 0.55),
          ),
          if (on) ...[
            const SizedBox(width: 4),
            Text(
              target == kRepeatForever ? '∞' : '$target',
              style: MizanType.sectionLabel(color: p.accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerProgress extends StatelessWidget {
  const _PlayerProgress({
    required this.reciterName,
    required this.ayahNumber,
    required this.repeatTarget,
    required this.repeatDone,
    required this.controller,
    required this.onPickReciter,
  });

  final String reciterName;
  final int ayahNumber;
  final int repeatTarget;
  final int repeatDone;
  final AyahAudioController controller;
  final VoidCallback onPickReciter;

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final onNavy = MizanTone.inverse.onColor(p);
    final muted = MizanTone.inverse.mutedOn(p);

    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      builder: (context, positionSnap) {
        final position = positionSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: controller.durationStream,
          builder: (context, durationSnap) {
            final total = durationSnap.data;
            final fraction = (total == null || total.inMilliseconds == 0)
                ? 0.0
                : (position.inMilliseconds / total.inMilliseconds)
                    .clamp(0.0, 1.0);

            return Column(
              // See the note on [_PlayerBar]: without this the bar fills the
              // screen.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onPickReciter,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                reciterName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MizanType.body(color: onNavy)
                                    .copyWith(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 15,
                              color: muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      total == null
                          ? 'Ayah $ayahNumber'
                          : 'Ayah $ayahNumber · ${_clock(position)} / '
                              '${_clock(total)}',
                      style: MizanType.body(color: muted).copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    // Tap anywhere on the line to move there. A 3px-tall bar is
                    // too thin to drag, so the whole strip is the target.
                    onTapDown: (details) {
                      if (total == null) return;
                      final ratio = (details.localPosition.dx /
                              constraints.maxWidth)
                          .clamp(0.0, 1.0);
                      controller.seek(total * ratio);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(MizanGeometry.pillRadius),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 3,
                          backgroundColor: onNavy.withValues(alpha: 0.18),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(p.accent),
                        ),
                      ),
                    ),
                  ),
                ),
                if (repeatTarget != 1)
                  Text(
                    repeatTarget == kRepeatForever
                        ? 'Repeating this ayah'
                        : 'Repeat ${repeatDone + 1} of $repeatTarget',
                    style:
                        MizanType.sectionLabel(color: p.accent).copyWith(
                      fontSize: 9.5,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Ayah-by-ayah reciters. A separate list from Settings → Audio because those
/// are whole-surah recordings; see `ayah_audio_provider.dart`.
void _showReciterSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final p = MizanPalette.of(context);
        final current = ref.watch(ayahReciterProvider);
        final audio = ref.watch(ayahAudioProvider);

        return Padding(
          padding: const EdgeInsets.all(MizanGeometry.gutter),
          child: MizanSurface(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: MizanSectionLabel('RECITER'),
                ),
                MizanRule(color: p.hairline),
                for (final r in kAyahReciters) ...[
                  MizanPressable(
                    fill: Colors.transparent,
                    shadowsEnabled: false,
                    borderRadius: BorderRadius.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    semanticLabel: r.name,
                    onTap: () async {
                      await ref.read(ayahReciterProvider.notifier).select(r);
                      // Re-load the same ayah in the new voice so the change is
                      // audible immediately rather than at the next ayah.
                      if (audio.isActive) {
                        await ref.read(ayahAudioProvider.notifier).playAyah(
                              audio.surahNumber!,
                              audio.ayahNumber!,
                              lastAyah: audio.lastAyah,
                            );
                      }
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: r.id == current.id
                                ? MizanType.bodyStrong(color: p.ink)
                                : MizanType.body(color: p.ink),
                          ),
                        ),
                        if (r.id == current.id)
                          Icon(Icons.check_rounded,
                              size: 19, color: p.accentText),
                      ],
                    ),
                  ),
                  if (r != kAyahReciters.last)
                    MizanRule(color: p.hairline, indent: 20),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════
//  SHEETS
// ══════════════════════════════════════════════════════════════════════

/// The Tt sheet. Every control writes through [readingPreferencesProvider], so
/// a change here is the same change Settings → Personalisation makes.
void _showReadingSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final p = MizanPalette.of(context);
        final prefs = ref.watch(readingPreferencesProvider);
        final controller = ref.read(readingPreferencesProvider.notifier);

        return Padding(
          padding: const EdgeInsets.all(MizanGeometry.gutter),
          child: MizanSurface(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MizanSectionLabel('READING'),
                  const SizedBox(height: 14),

                  Text('Arabic', style: MizanType.bodyStrong(color: p.ink)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final font in ArabicFont.values)
                        MizanButton(
                          label: font.label,
                          kind: MizanButtonKind.chip,
                          selected: prefs.arabicFont == font,
                          onPressed: () => controller.setFont(font),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _SizeSlider(
                    label: 'Arabic size',
                    value: prefs.arabicTextSize,
                    min: 20,
                    max: 46,
                    onChanged: controller.setArabicTextSize,
                  ),
                  const SizedBox(height: 6),
                  MizanRule(color: p.hairline),
                  const SizedBox(height: 12),

                  Text('Translation', style: MizanType.bodyStrong(color: p.ink)),
                  const SizedBox(height: 4),
                  _PrefSwitch(
                    label: 'Show translation',
                    value: prefs.showTranslation,
                    onChanged: controller.setShowTranslation,
                  ),
                  _PrefSwitch(
                    label: 'Show transliteration',
                    value: prefs.showTransliteration,
                    onChanged: controller.setShowTransliteration,
                  ),
                  _SizeSlider(
                    label: 'Translation size',
                    value: prefs.translationTextSize,
                    min: 12,
                    max: 24,
                    onChanged: controller.setTranslationTextSize,
                  ),
                  const SizedBox(height: 16),
                  MizanButton(
                    label: 'Done',
                    kind: MizanButtonKind.secondary,
                    expand: true,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _SizeSlider extends StatelessWidget {
  const _SizeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(label, style: MizanType.body(color: p.muted)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: p.accentText,
            inactiveColor: p.sunk,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
            style: MizanType.bodyStrong(color: p.ink),
          ),
        ),
      ],
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Row(
      children: [
        Expanded(child: Text(label, style: MizanType.body(color: p.ink))),
        Switch(
          value: value,
          activeThumbColor: p.onFilled,
          activeTrackColor: p.accentText,
          inactiveThumbColor: p.muted,
          inactiveTrackColor: p.sunk,
          trackOutlineColor: WidgetStatePropertyAll(p.hairline),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The ••• sheet: the actions that belong to the ayah you are on but have no
/// room on the card.
void _showMoreSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Ayah>? ayat,
  required Surah? surah,
  required int surahNumber,
  required String surahName,
  required int? readingAyah,
  required VoidCallback onJump,
}) {
  final p = MizanPalette.of(context);
  final ayah = (ayat == null || readingAyah == null)
      ? null
      : ayat.firstWhere(
          (a) => a.ayahNumber == readingAyah,
          orElse: () => ayat.first,
        );

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(MizanGeometry.gutter),
      child: MizanSurface(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: MizanSectionLabel(
                ayah == null
                    ? surahName.toUpperCase()
                    : '$surahName $surahNumber:${ayah.ayahNumber}'.toUpperCase(),
              ),
            ),
            MizanRule(color: p.hairline),
            _MoreAction(
              icon: Icons.numbers_rounded,
              label: 'Go to ayah',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onJump();
              },
            ),
            if (ayah != null) ...[
              MizanRule(color: p.hairline, indent: 20),
              _MoreAction(
                icon: Icons.copy_rounded,
                label: 'Copy this ayah',
                onTap: () async {
                  final text = '${ayah.arabicText}\n\n'
                      '"${ayah.translation}"\n\n'
                      '— Quran $surahName $surahNumber:${ayah.ayahNumber}';
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                },
              ),
              // No "Open the layers" here. Every ayah card already has a
              // Layers link, and a second route to the same screen two taps
              // deeper only makes the menu look like it does more than it does.
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _MoreAction extends StatelessWidget {
  const _MoreAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanPressable(
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      semanticLabel: label,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.muted),
          const SizedBox(width: 14),
          Text(label, style: MizanType.body(color: p.ink)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SAVED AYAT  —  public API, read by Home
// ══════════════════════════════════════════════════════════════════════

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

// ══════════════════════════════════════════════════════════════════════
//  LOADING / ERROR
// ══════════════════════════════════════════════════════════════════════

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return Center(
      child: CircularProgressIndicator(color: p.accentText, strokeWidth: 2),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MizanGeometry.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: p.muted),
            const SizedBox(height: 16),
            Text(
              'Could not load these ayat',
              style: MizanType.cardHeadline(color: p.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'The text comes from the network the first time you open a '
              'surah. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: MizanType.body(color: p.muted),
            ),
            const SizedBox(height: 20),
            MizanButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
