/// Growth Map — Riverpod providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/growth_stats_repository.dart';
import 'growth_map_models.dart';

/// The stats repository. A plain [Provider] so it can be overridden in tests.
final growthStatsRepositoryProvider = Provider<GrowthStatsRepository>((ref) {
  return GrowthStatsRepository();
});

/// The raw roll-ups, before they are arranged into constellations.
///
/// Split out of [growthMapProvider] so the Growth tab's rows can state their real
/// counts without building the map's geometry, and — more importantly — so both
/// read the *same* result. Two providers each calling `repo.load()` would issue
/// two sets of queries and could disagree by whatever was saved in between.
final growthMetricsProvider =
    FutureProvider.autoDispose<GrowthMetrics>((ref) async {
  final repo = ref.watch(growthStatsRepositoryProvider);
  return repo.load();
});

/// Builds the whole Growth Map from the user's real local data.
///
/// `autoDispose` so it recomputes every time the screen is opened — the numbers
/// should feel live (a word saved a minute ago shows up immediately), and we
/// don't want to hold the result once the user leaves the screen.
final growthMapProvider =
    FutureProvider.autoDispose<GrowthMapData>((ref) async {
  final metrics = await ref.watch(growthMetricsProvider.future);
  return buildGrowthMap(metrics);
});
