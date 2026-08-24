/// THE LAYERS SHEET — the one and only way into the six layers of an ayah.
///
/// Rebuilt from mockup 7a ("LAYER LIST OPEN") and 7b ("FIRST AYAH A NEW USER
/// OPENS").
///
/// ── Why a sheet and not a button per layer ────────────────────────────
/// The reader's job is the ayah. Six labelled destinations cannot sit on an ayah
/// card without competing with revelation for attention, and the previous single
/// "Layers" word said nothing about what was behind it. A sheet is the only
/// shape that can show all six *with their state* — read, here, unread, locked —
/// which is the information a reader actually needs to choose one.
///
/// ── One entry point, one name ─────────────────────────────────────────
/// The sheet is opened from exactly one control: the "Six layers" pill in the
/// reader's bottom bar. The per-card "Layers" link that used to sit beside share
/// was removed when this landed — two doors to one room made the action row look
/// like it offered two different things. The pill also says the same two words on
/// every ayah in the Quran, whether or not curated tafsir exists behind it: a
/// control that renames itself per item reads as a different feature, not the
/// same one.
///
/// ── Where the numbers come from ───────────────────────────────────────
/// Nothing on this sheet is invented.
///   • "N read" counts rows in `layer_unlocks` for this ayah, via
///     [layerStatesProvider] — a layer is "read" when it has actually been
///     opened, not when it is merely available.
///   • "N min left" sums [LayerMeta.readMinutes] over the layers not yet read.
///     That list is an honest *estimate* of reading time and is labelled as one;
///     it is the one number here that is not measured, and it is stated in whole
///     minutes so it never pretends to precision it does not have.
///   • Scholars' "N views" is the length of [tafsirSourcesProvider] — the real
///     count of tafāsīr the reader can switch to inside the layer. While that
///     catalogue is loading the clause is dropped rather than guessed.
///   • Similar's count is the length of [similarVersesProvider], the real
///     mutashabihat index, with singular/plural agreement — and when the index
///     has nothing for this ayah the row says so plainly instead of implying
///     there is something to go and look at.
///
/// ── "HERE" ────────────────────────────────────────────────────────────
/// The mockup marks the layer "currently open". Nothing is open while the reader
/// is looking at the reader, and the layer screen already has its own tab bar
/// for moving between layers — putting this sheet in there too would be a second
/// layer switcher. So HERE marks the layer opened **most recently** for this
/// ayah: where the reader stopped. That is the promise the intro card makes
/// ("the app remembers where you stopped"), and it is real data — the newest
/// `unlocked_at` timestamp.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../../shared/widgets/mizan/mizan_pressable.dart';
import '../domain/layer_providers.dart';
import '../domain/tafsir_providers.dart';
import '../models/layer_unlock.dart';
import 'layer_screen.dart';

/// The word "Six" is written out rather than interpolated from
/// [LayerMeta.count]: it is a name, not a running total, and it is the same name
/// on the pill, on this sheet's title and in the intro card. If a seventh layer
/// is ever added, all three change together and deliberately.
const String _kLayersName = 'Six layers';

/// One line per layer, keyed by **storage** index (so 4 is Reflection and 5 is
/// Similar — see [LayerMeta]). Scholars and Similar get a real count appended at
/// build time; these are the parts that never change.
const Map<int, String> _kSubtitles = {
  0: 'Root meanings, one word at a time',
  1: 'When it came down, and to whom',
  2: 'How the mufassirun read it',
  3: 'The chain behind each narration',
  4: 'A question to sit with, and space to write',
  5: 'Ayat elsewhere that resemble this one',
};

/// The intro card's six glosses, keyed by storage index. Shorter than the sheet
/// subtitles on purpose — the card is read once, at speed, before the reader
/// knows any of the words.
const Map<int, String> _kIntroGloss = {
  0: 'what each root means',
  1: 'when it came down',
  2: 'how they read it',
  3: 'who carried it to us',
  4: 'a question to sit with',
  5: 'ayat that echo it',
};

// ══════════════════════════════════════════════════════════════════════
//  THE SHEET
// ══════════════════════════════════════════════════════════════════════

/// Opens the layers sheet for one ayah.
///
/// `isScrollControlled` because six rows plus a header and a footer are taller
/// than the default half-screen ceiling on a small phone, and a layer the reader
/// cannot reach is worse than a sheet that scrolls.
void showLayersSheet(
  BuildContext context, {
  required int surahNumber,
  required int ayahNumber,
  required String surahName,
  required String arabicText,
  required String translation,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(MizanGeometry.gutter),
      child: _LayersSheetBody(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        surahName: surahName,
        arabicText: arabicText,
        translation: translation,
      ),
    ),
  );
}

class _LayersSheetBody extends ConsumerWidget {
  const _LayersSheetBody({
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.arabicText,
    required this.translation,
  });

  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final String arabicText;
  final String translation;

  String get _ayahKey => '$surahNumber:$ayahNumber';

  void _open(BuildContext context, int storageIndex) {
    HapticFeedback.selectionClick();
    // The navigator is captured before the pop: after it, this sheet's element is
    // on its way out and `Navigator.of` on it is no longer safe.
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => LayerScreen(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          surahName: surahName,
          arabicText: arabicText,
          translation: translation,
          initialLayer: storageIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final states = ref.watch(layerStatesProvider(_ayahKey)).valueOrNull;
    final tafsirCount = ref.watch(tafsirSourcesProvider).valueOrNull?.length;
    final similar = ref.watch(similarVersesProvider(_ayahKey)).valueOrNull;

    LayerState? stateOf(int index) =>
        (states != null && index < states.length) ? states[index] : null;

    final read = states == null
        ? 0
        : states.where((s) => s.unlockedAt != null).length;

    // Sum the estimate over what is left, so the number falls as layers are
    // read instead of being a fixed advertisement.
    final minutesLeft = [
      for (final index in LayerMeta.displayOrder)
        if (stateOf(index)?.unlockedAt == null) LayerMeta.readMinutes[index],
    ].fold<int>(0, (a, b) => a + b);

    // Where the reader stopped: the newest unlock. See the library comment on
    // why that, and not "the route on top of the navigator", is HERE.
    int? here;
    DateTime? newest;
    for (final index in LayerMeta.displayOrder) {
      final at = stateOf(index)?.unlockedAt;
      if (at == null) continue;
      if (newest == null || at.isAfter(newest)) {
        newest = at;
        here = index;
      }
    }

    // "Read all six in order" lands on the first layer that is open and unread;
    // if every layer has been read it goes back to the first one, because
    // re-reading in order is the whole point of the phrase.
    final resume = LayerMeta.displayOrder.firstWhere(
      (index) {
        final s = stateOf(index);
        return s != null && s.isUnlocked && s.unlockedAt == null;
      },
      orElse: () => LayerMeta.displayOrder.first,
    );

    return MizanSurface(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _kLayersName,
                          style: MizanType.cardHeadline(color: p.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          read >= LayerMeta.count
                              ? 'All six read'
                              : '$read read · about $minutesLeft min left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MizanType.body(color: p.muted)
                              .copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  MizanIconTile(
                    icon: Icons.close_rounded,
                    iconSize: 18,
                    semanticLabel: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            MizanRule(color: p.hairline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final index in LayerMeta.displayOrder)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LayerRow(
                          storageIndex: index,
                          state: stateOf(index),
                          isHere: index == here,
                          subtitle: _subtitleFor(
                            index,
                            tafsirCount: tafsirCount,
                            similarCount: similar?.length,
                          ),
                          onTap: () => _open(context, index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            MizanRule(color: p.hairline),
            _ReadInOrderRow(onTap: () => _open(context, resume)),
          ],
        ),
      ),
    );
  }

  /// The one place the counts are spoken. Both clauses are dropped when their
  /// source has not resolved: an ayah's layers must never announce a number the
  /// app cannot stand behind.
  String _subtitleFor(
    int storageIndex, {
    required int? tafsirCount,
    required int? similarCount,
  }) {
    final base = _kSubtitles[storageIndex] ?? '';
    if (storageIndex == 2) {
      if (tafsirCount == null || tafsirCount < 1) return base;
      return '$base — $tafsirCount ${tafsirCount == 1 ? 'view' : 'views'}';
    }
    if (storageIndex == 5) {
      if (similarCount == null) return base;
      if (similarCount == 0) return 'No other ayah in the index resembles this';
      if (similarCount == 1) return 'One other ayah resembles this one';
      return '$similarCount other ayat resemble this one';
    }
    return base;
  }
}

/// One layer. Four states, four different right-hand markers, because "not read
/// yet" and "not open yet" are different facts and a reader who cannot tell them
/// apart will keep tapping a row that has nothing to give.
class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.storageIndex,
    required this.state,
    required this.isHere,
    required this.subtitle,
    required this.onTap,
  });

  final int storageIndex;
  final LayerState? state;
  final bool isHere;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final isRead = state?.unlockedAt != null;
    // Null state means the unlock table has not answered yet. Treated as open
    // rather than locked: a brief moment of an available layer is recoverable,
    // a layer wrongly shown as locked is not.
    final isLocked = state != null && !state!.isUnlocked;

    // The one filled row. On light this is the navy panel the mockup draws; on
    // dark [MizanTone.inverse] resolves to the card colour, which is the same
    // fill as the sheet behind it — so the gold hairline and the gold word carry
    // the state there. Both themes checked.
    final tone = isHere ? MizanTone.inverse : MizanTone.sunk;
    final ink = isLocked ? tone.mutedOn(p) : tone.onColor(p);

    // Locked rows say what they are waiting for by name. The remaining time is
    // deliberately not printed: [LayerMeta.unlockInterval] is currently set for
    // device testing, and a countdown that reads "0m" teaches the reader to
    // distrust the number.
    final predecessor = LayerMeta.predecessorOf(storageIndex);
    final line = isLocked && predecessor != null
        ? 'Opens after ${LayerMeta.names[predecessor]}'
        : subtitle;

    return MizanPressable(
      onTap: isLocked ? null : onTap,
      borderRadius: MizanGeometry.rowBorderRadius,
      fill: tone.resolve(p),
      border: BorderSide(
        color: isHere
            ? tone.accentTextOn(p).withValues(alpha: 0.55)
            : tone.hairlineOn(p),
        width: MizanGeometry.hairlineWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shadowsEnabled: false,
      semanticLabel: '${LayerMeta.names[storageIndex]}. $line'
          '${isRead ? '. Read' : ''}${isLocked ? '. Locked' : ''}',
      child: Row(
        children: [
          Icon(
            LayerMeta.icons[storageIndex],
            size: 20,
            color: isLocked ? tone.mutedOn(p) : tone.accentTextOn(p),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LayerMeta.names[storageIndex],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MizanType.bodyStrong(color: ink),
                ),
                const SizedBox(height: 2),
                // One line, ellipsized. A wrapped subtitle makes six rows six
                // different heights and the list stops reading as a list.
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MizanType.body(color: tone.mutedOn(p))
                      .copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StateMarker(
            isHere: isHere,
            isRead: isRead,
            isLocked: isLocked,
            tone: tone,
          ),
        ],
      ),
    );
  }
}

class _StateMarker extends StatelessWidget {
  const _StateMarker({
    required this.isHere,
    required this.isRead,
    required this.isLocked,
    required this.tone,
  });

  final bool isHere;
  final bool isRead;
  final bool isLocked;
  final MizanTone tone;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    if (isHere) {
      // Gold *as text*, which is illegal on cream and legal on the navy panel —
      // the whole reason this row is filled (Rule #1).
      return Text('HERE', style: MizanType.sectionLabel(color: p.accent));
    }
    if (isLocked) {
      return Icon(Icons.lock_outline_rounded, size: 17, color: tone.mutedOn(p));
    }
    if (isRead) {
      return Icon(Icons.check_rounded, size: 18, color: tone.accentTextOn(p));
    }
    return MizanDiamond(size: 7, color: tone.accentTextOn(p));
  }
}

/// The footer. A rule between the words and the chevron, so the row reads as one
/// long invitation rather than a label with a button stuck on the end.
class _ReadInOrderRow extends StatelessWidget {
  const _ReadInOrderRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanPressable(
      onTap: onTap,
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: MizanGeometry.rowBorderRadius,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      semanticLabel: 'Read all six layers in order',
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 19, color: p.accentText),
          const SizedBox(width: 12),
          Text(
            'Read all six in order',
            style: MizanType.bodyStrong(color: p.ink),
          ),
          const SizedBox(width: 12),
          Expanded(child: MizanRule(color: p.hairline)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  FIRST RUN  —  mockup 7b
// ══════════════════════════════════════════════════════════════════════

/// The card a new reader meets on the first ayah they open, and never again.
///
/// It exists because the "Six layers" pill cannot explain itself in two words.
/// Without this, the six layers — the thing that makes this app not another
/// mushaf — are behind a control whose name gives no reason to press it.
///
/// Shown once, on one ayah, and dismissed by *either* button: a card that has to
/// be refused on every ayah is an advert. The flag lives in [OnboardingFlags]
/// with the welcome flag, because that is already restored before the first
/// frame — so the card either renders or does not, and never appears late.
///
/// ── Why this no longer says "HOW MIZAN READS" ──────────────────────────
/// Because the welcome flow's second screen does, under that exact eyebrow, and
/// it makes the same claim — one ayah, six ways in — a few minutes earlier. Two
/// screens introducing the same idea with the same label reads as the app having
/// forgotten it already said this. So the introducing is left where it happens
/// first, and this card keeps the half the flow cannot do: naming the six on the
/// ayah actually in front of the person, and opening the first one. The list
/// stays — it is a legend for this screen now, not a pitch.
class LayersIntroCard extends StatelessWidget {
  const LayersIntroCard({
    super.key,
    required this.onStartWithWords,
    required this.onDismiss,
  });

  /// Opens the Words layer. Also dismisses — starting *is* an answer.
  final VoidCallback onStartWithWords;

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MizanSectionLabel('WHERE TO START', color: p.accentText),
          const SizedBox(height: 10),
          Text(
            'The six layers of this ayah',
            style: MizanType.cardHeadline(color: p.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Take them in order or pick one. You can always come back — the '
            'app remembers where you stopped.',
            style: MizanType.body(color: p.muted),
          ),
          const SizedBox(height: 16),
          // Numbered in display order, so the numeral beside a name is the same
          // position that name holds in the sheet and in the layer screen's tab
          // bar. Reflection is 6 on all three.
          for (var position = 0;
              position < LayerMeta.displayOrder.length;
              position++)
            _IntroLine(
              number: position + 1,
              storageIndex: LayerMeta.displayOrder[position],
            ),
          const SizedBox(height: 18),
          MizanButton(
            label: 'Start with Words',
            trailingIcon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: onStartWithWords,
          ),
          const SizedBox(height: 4),
          MizanPressable(
            fill: Colors.transparent,
            shadowsEnabled: false,
            borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
            padding: const EdgeInsets.symmetric(vertical: 12),
            semanticLabel: 'Dismiss this card',
            onTap: onDismiss,
            child: Text(
              "I'll find my own way",
              textAlign: TextAlign.center,
              style: MizanType.body(color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine({required this.number, required this.storageIndex});

  final int number;
  final int storageIndex;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            // The mockup's gold numerals. Gold is illegal *as text* on cream
            // (Rule #1), so these are bronze — the text-legal member of the gold
            // family — which is what every other gold numeral in the app uses.
            child: Text(
              '$number',
              style: MizanType.bodyStrong(color: p.accentText),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: LayerMeta.names[storageIndex],
                    style: MizanType.bodyStrong(color: p.ink),
                  ),
                  TextSpan(
                    text: ' — ${_kIntroGloss[storageIndex] ?? ''}',
                    style: MizanType.body(color: p.muted),
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
