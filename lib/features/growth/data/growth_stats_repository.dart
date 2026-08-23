/// GrowthStatsRepository — read-only roll-ups that feed the Growth Map.
///
/// Gathers the user's real progress from every local source: the main database
/// (tafseer layers opened, ayah reflections, hadith reflections, saved words),
/// the separate Discover database (entries whose quiz was passed), and shared
/// preferences (the daily streak + whether tonight's muhasabah is done).
///
/// Nothing here writes. The streak in particular is *owned* by the Home
/// screen's streak badge — we only read it, so the Home count and the Growth
/// Map can never disagree.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';
import '../../discover/data/discover_database.dart';
import '../../home/domain/streak_provider.dart';
import '../../knowledge/data/hadith_repository.dart';
import '../../quran/data/layer_repository.dart';
import '../domain/growth_map_models.dart';
import 'vocab_repository.dart';

class GrowthStatsRepository {
  GrowthStatsRepository({
    LayerRepository? layerRepository,
    VocabRepository? vocabRepository,
    HadithRepository? hadithRepository,
  })  : _layers = layerRepository ?? LayerRepository(),
        _vocab = vocabRepository ?? VocabRepository(),
        _hadith = hadithRepository ?? HadithRepository();

  final LayerRepository _layers;
  final VocabRepository _vocab;
  final HadithRepository _hadith;

  static const String _tag = 'GrowthStatsRepository';

  Future<GrowthMetrics> load() async {
    // Each source is read independently and guarded: one failure (e.g. a table
    // absent on a very fresh install) must never blank the whole map — it just
    // leaves that one area at zero.
    final quranLayers = await _safe(_layers.countUnlocks);
    final quranAyahs = await _safe(_layers.countAyahsTouched);
    final reflections = await _safe(_layers.countReflections);
    final hadithReflections = await _safe(_hadith.reflectionCount);
    final vocabCount = await _safe(_vocab.getWordCount);
    final discover = await _safe(_discoverCompleted);
    final signals = await _prefsSignals();

    return GrowthMetrics(
      quranLayers: quranLayers,
      quranAyahs: quranAyahs,
      vocabCount: vocabCount,
      streak: signals.streak,
      reflectionsWritten: reflections,
      hadithReflections: hadithReflections,
      reflectedToday: signals.reflectedToday,
      discoverCompleted: discover,
    );
  }

  Future<int> _discoverCompleted() async {
    // getCompletionStats() returns completed counts keyed by entry type
    // (prophet / sahabi / divine_name). We only need the total mastered.
    final stats = await DiscoverDatabase.getCompletionStats();
    var total = 0;
    for (final n in stats.values) {
      total += n;
    }
    return total;
  }

  Future<_PrefSignals> _prefsSignals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Read-only, and deliberately not `prefs.getInt('streak_count')` on its
      // own. That integer is only meaningful next to the date it was last moved:
      // a run that broke three days ago still has its old count sitting in
      // storage, because `StreakStore` never rewrites on a read. Going through
      // `evaluate()` applies the same today/yesterday test the Home pill uses, so
      // Growth and Home can never disagree about whether a streak is alive.
      final streak = (await StreakStore.evaluate()).days;
      final lastMuhasabah = prefs.getString('last_muhasabah_date');
      // Must match the padded date format the muhasabah screen writes and that
      // Home uses in muhasabahDoneProvider: 'yyyy-MM-dd'. Keep all three in sync.
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return _PrefSignals(streak, lastMuhasabah == todayStr);
    } catch (_) {
      return const _PrefSignals(0, false);
    }
  }

  Future<int> _safe(Future<int> Function() query) async {
    try {
      return await query();
    } catch (e) {
      AppLogger.warning('Growth stat query failed: $e', tag: _tag);
      return 0;
    }
  }
}

class _PrefSignals {
  const _PrefSignals(this.streak, this.reflectedToday);
  final int streak;
  final bool reflectedToday;
}
