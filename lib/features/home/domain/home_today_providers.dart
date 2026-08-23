/// The four data bindings behind the Home screen's cards.
///
/// ── Why this file is careful ───────────────────────────────────────────
/// The Home mockup shows four content cards, and only two of them had data
/// behind them when it was drawn. Rather than author new Islamic content to fill
/// the gaps — which is forbidden here; content comes from verified sources the
/// user supplies — each card is bound to something the app already knows to be
/// sourced:
///
///   • Today's Thread  → [encounterForToday], whose copy is lifted verbatim from
///     `assets/data/discover/**`, plus that entry's real layer count and the
///     user's real unlock progress. The "02 / 04" in the mockup is therefore a
///     measured position in a real entry, not decoration.
///
///   • Today's Word    → the user's OWN saved vocabulary. Every saved word
///     carries the surah and ayah it was saved from, so the citation is real by
///     construction. If the bank is empty the card says so instead of inventing
///     a word of the day.
///
///   • From the Seerah → a real seerah entry, showing the entry's own `year`
///     string (e.g. "Rajab, the fifth year of prophethood — c. 615 CE").
///
///     NOTE: the mockup labels this card "TODAY IN ISLAM" over a hijri date
///     ("17 Ramadan, 2 AH"). That claim is an anniversary — "this happened on
///     this day" — and the app has no hijri-dated event list to support it.
///     Writing one would mean inventing dates for sacred history. So the card
///     keeps the mockup's shape and shows what is true: a moment from the seerah
///     with its own sourced date. Swap it back to "Today in Islam" the day a
///     verified hijri-dated list exists.
///
///   • Ayah to sit with → [ayahForToday], the existing verified rotation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/vocab_word.dart';
import '../../discover/data/discover_repository.dart';
import '../../discover/models/discover_models.dart';
import '../../discover/providers/discover_providers.dart';
import '../data/todays_encounter.dart';
import 'home_providers.dart';
import 'streak_math.dart' show dayOfYear;

// ══════════════════════════════════════════════════════════════════════
//  TODAY'S THREAD
// ══════════════════════════════════════════════════════════════════════

/// Today's encounter, resolved against the entry it points at.
class ThreadToday {
  const ThreadToday({
    required this.encounter,
    required this.totalLayers,
    required this.stage,
  });

  final Encounter encounter;

  /// How many layers the entry actually has. Read off the entry, never assumed —
  /// the models say "always 5" but the JSON is the truth.
  final int totalLayers;

  /// 1-based position on the rail: the layer the user is on. Equals
  /// `layersUnlocked`, floored at 1, because unlocking a layer *is* arriving at
  /// it.
  final int stage;

  /// `02 / 04`.
  String get counter =>
      '${stage.toString().padLeft(2, '0')} / ${totalLayers.toString().padLeft(2, '0')}';

  bool get isStarted => stage > 1;
}

/// `/discover/sahabi/abu_bakr` → `sahabi`, `abu_bakr`.
({String type, String id})? _parseRoute(String routePath) {
  final seg = routePath.split('/').where((s) => s.isNotEmpty).toList();
  // ['discover', <type>, <id>]
  if (seg.length < 3 || seg.first != 'discover') return null;
  return (type: seg[1], id: seg[2]);
}

final threadTodayProvider = FutureProvider<ThreadToday>((ref) async {
  final encounter = encounterForToday();
  final parsed = _parseRoute(encounter.routePath);

  // Fallbacks exist only for a malformed routePath, which would be a bug in the
  // encounter table rather than a state the user can reach. A one-stage rail is
  // honest about knowing nothing rather than guessing five.
  if (parsed == null) {
    return ThreadToday(encounter: encounter, totalLayers: 1, stage: 1);
  }

  final (:type, :id) = parsed;

  final layers = switch (type) {
    'prophet' => (await DiscoverRepository.getProphetById(id))?.layers,
    'sahabi' => (await DiscoverRepository.getSahabiById(id))?.layers,
    'seerah' => (await DiscoverRepository.getSeerahById(id))?.layers,
    'name' => (await DiscoverRepository.getNameById(id))?.layers,
    _ => null,
  };

  final progressProvider = switch (type) {
    'prophet' => prophetProgressProvider,
    'sahabi' => sahabiProgressProvider,
    'seerah' => seerahProgressProvider,
    'name' => nameProgressProvider,
    _ => null,
  };

  final unlocked = progressProvider == null
      ? 0
      : ref.watch(progressProvider).valueOrNull?[id]?.layersUnlocked ?? 0;

  final total = layers?.length ?? 1;
  return ThreadToday(
    encounter: encounter,
    totalLayers: total,
    stage: unlocked < 1 ? 1 : (unlocked > total ? total : unlocked),
  );
});

// ══════════════════════════════════════════════════════════════════════
//  TODAY'S WORD
// ══════════════════════════════════════════════════════════════════════

/// One word from the user's own bank, or `null` when the bank is empty.
///
/// Deliberately reuses [vocabDueProvider] — the same list the Wird review uses —
/// so the word on Home is a word actually due, not a second unrelated pick.
final todaysWordProvider = FutureProvider<VocabWord?>((ref) async {
  final due = await ref.watch(vocabDueProvider.future);
  return due.isEmpty ? null : due.first;
});

// ══════════════════════════════════════════════════════════════════════
//  FROM THE SEERAH
// ══════════════════════════════════════════════════════════════════════

/// A seerah moment for today, rotating on day-of-year.
///
/// Skips today's Thread entry when they collide, so Home never shows the same
/// subject twice on one screen.
final seerahTodayProvider = FutureProvider<SeerahEntry?>((ref) async {
  final all = await ref.watch(seerahProvider.future);
  if (all.isEmpty) return null;

  final now = DateTime.now();
  var index = dayOfYear(now) % all.length;

  final threadId = _parseRoute(encounterForToday().routePath)?.id;
  if (all.length > 1 && all[index].id == threadId) {
    index = (index + 1) % all.length;
  }
  return all[index];
});
