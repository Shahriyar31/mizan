/// Growth Map — domain models.
///
/// The Growth Map shows the user's practice as a night sky. Each *area* of the
/// deen they're building is a small constellation; each *star* in it is a
/// milestone that lights up only when the user has genuinely reached it. No
/// star is ever lit by decoration — every threshold maps to a real, locally
/// stored number (tafseer layers opened, words saved, streak days, Discover
/// entries mastered). That honesty is deliberate: the map should mirror who the
/// user is becoming, not flatter them.
///
/// This file is pure description + light view-model logic:
///   • [ConstellationSpec] — the fixed shape, copy, colour and milestone
///     thresholds of one area (const data, no user state).
///   • [GrowthConstellation] — a spec bound to the user's real [value], with
///     helpers for "which stars are lit" and "what's the next one".
///   • [GrowthMetrics] — the raw numbers read from the databases / prefs.
///   • [buildGrowthMap] — turns metrics into a fully-populated [GrowthMapData].
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The four areas of practice the map tracks.
enum GrowthArea { quran, vocabulary, reflection, discover }

/// One star in a constellation. It lights when the area's metric reaches
/// [threshold]. [dx]/[dy] are normalized (0..1) coordinates inside the
/// constellation's own square; the painter maps them onto the real canvas.
class GrowthStar {
  const GrowthStar({
    required this.threshold,
    required this.dx,
    required this.dy,
  });

  final int threshold;
  final double dx;
  final double dy;
}

/// The fixed shape + copy of one area. Holds no user state — bound to a real
/// value later to produce a [GrowthConstellation].
class ConstellationSpec {
  const ConstellationSpec({
    required this.area,
    required this.arabicName,
    required this.name,
    required this.color,
    required this.stars,
    required this.links,
  });

  final GrowthArea area;
  final String arabicName;
  final String name;
  final Color color;

  /// Stars in ascending [GrowthStar.threshold] order.
  final List<GrowthStar> stars;

  /// Pairs of star indices to connect with a faint line (the figure).
  final List<List<int>> links;
}

/// A spec bound to the user's real progress [value].
class GrowthConstellation {
  const GrowthConstellation({
    required this.spec,
    required this.value,
    required this.headline,
    required this.detail,
  });

  final ConstellationSpec spec;

  /// The user's current metric for this area (layers, words, streak days…).
  final int value;

  /// Primary stat-card line, e.g. "42 tafseer layers".
  final String headline;

  /// Secondary stat-card line, e.g. "across 15 ayahs".
  final String detail;

  GrowthArea get area => spec.area;
  String get arabicName => spec.arabicName;
  String get name => spec.name;
  Color get color => spec.color;
  List<GrowthStar> get stars => spec.stars;
  List<List<int>> get links => spec.links;

  bool isLit(int index) => value >= spec.stars[index].threshold;
  int get litCount => spec.stars.where((s) => value >= s.threshold).length;
  int get total => spec.stars.length;
  bool get isComplete => litCount == total;

  /// The next star still to earn, or null if the constellation is complete.
  GrowthStar? get nextStar {
    for (final s in spec.stars) {
      if (value < s.threshold) return s;
    }
    return null;
  }

  /// How many more units until the next star lights (0 if complete).
  int get toNextStar {
    final n = nextStar;
    return n == null ? 0 : (n.threshold - value).clamp(0, n.threshold);
  }
}

/// The whole map: four constellations plus a couple of headline signals.
class GrowthMapData {
  const GrowthMapData({
    required this.constellations,
    required this.streak,
    required this.reflectedToday,
  });

  final List<GrowthConstellation> constellations;
  final int streak;
  final bool reflectedToday;

  int get starsLit =>
      constellations.fold(0, (sum, c) => sum + c.litCount);
  int get starsTotal =>
      constellations.fold(0, (sum, c) => sum + c.total);

  /// True when nothing has been earned yet — the sky is still dark.
  bool get isEmpty => starsLit == 0;
}

/// Raw numbers gathered from the databases and shared preferences.
class GrowthMetrics {
  const GrowthMetrics({
    required this.quranLayers,
    required this.quranAyahs,
    required this.vocabCount,
    required this.streak,
    required this.reflectionsWritten,
    required this.hadithReflections,
    required this.reflectedToday,
    required this.discoverCompleted,
  });

  final int quranLayers;
  final int quranAyahs;
  final int vocabCount;
  final int streak;
  final int reflectionsWritten;

  /// Reflections written on a hadith rather than an ayah. Counted separately so
  /// the detail line can say which is which — "12 ayah reflections" when four of
  /// them were hadith would be wrong.
  final int hadithReflections;
  final bool reflectedToday;
  final int discoverCompleted;

  static const empty = GrowthMetrics(
    quranLayers: 0,
    quranAyahs: 0,
    vocabCount: 0,
    streak: 0,
    reflectionsWritten: 0,
    hadithReflections: 0,
    reflectedToday: false,
    discoverCompleted: 0,
  );
}

// ── Constellation specs (fixed shapes + milestone thresholds) ───────────────
//
// Positions are normalized (0..1) inside each area's own square. Thresholds
// ascend with the star index so lighting "grows" along the connecting lines.

/// Qur'an depth — a gentle upward arc, like an ayah rising off the page.
/// Metric: total tafseer layers opened.
ConstellationSpec get specQuran => ConstellationSpec(
  area: GrowthArea.quran,
  arabicName: 'تَدَبُّر',
  name: 'Qur\'an Depth',
  color: AppColors.gold,
  stars: [
    GrowthStar(threshold: 1, dx: 0.12, dy: 0.78),
    GrowthStar(threshold: 5, dx: 0.30, dy: 0.58),
    GrowthStar(threshold: 15, dx: 0.46, dy: 0.66),
    GrowthStar(threshold: 30, dx: 0.62, dy: 0.42),
    GrowthStar(threshold: 60, dx: 0.78, dy: 0.50),
    GrowthStar(threshold: 120, dx: 0.90, dy: 0.24),
  ],
  links: [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [4, 5],
  ],
);

/// Vocabulary — a small gathered cluster, words drawing together.
/// Metric: Arabic words saved to the Vocab Bank.
ConstellationSpec get specVocab => ConstellationSpec(
  area: GrowthArea.vocabulary,
  arabicName: 'كَلِمَات',
  name: 'Vocabulary',
  color: AppColors.jade,
  stars: [
    GrowthStar(threshold: 1, dx: 0.30, dy: 0.72),
    GrowthStar(threshold: 5, dx: 0.20, dy: 0.48),
    GrowthStar(threshold: 12, dx: 0.40, dy: 0.38),
    GrowthStar(threshold: 25, dx: 0.58, dy: 0.52),
    GrowthStar(threshold: 50, dx: 0.50, dy: 0.74),
    GrowthStar(threshold: 100, dx: 0.76, dy: 0.34),
  ],
  links: [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [2, 5],
  ],
);

/// Reflection & streak — a crescent curve, fitting the nightly muhasabah.
/// Metric: current daily streak (days).
ConstellationSpec get specReflection => ConstellationSpec(
  area: GrowthArea.reflection,
  arabicName: 'مُحَاسَبَة',
  name: 'Reflection',
  color: AppColors.violet,
  stars: [
    GrowthStar(threshold: 1, dx: 0.30, dy: 0.24),
    GrowthStar(threshold: 3, dx: 0.18, dy: 0.44),
    GrowthStar(threshold: 7, dx: 0.20, dy: 0.66),
    GrowthStar(threshold: 14, dx: 0.38, dy: 0.80),
    GrowthStar(threshold: 30, dx: 0.60, dy: 0.78),
    GrowthStar(threshold: 100, dx: 0.78, dy: 0.62),
  ],
  links: [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [4, 5],
  ],
);

/// Discover mastery — a compass/star-burst radiating from a centre, for
/// guidance through the stories. Metric: entries with a passed quiz.
ConstellationSpec get specDiscover => ConstellationSpec(
  area: GrowthArea.discover,
  arabicName: 'قَصَص',
  name: 'Discover',
  color: AppColors.amber,
  stars: [
    GrowthStar(threshold: 1, dx: 0.50, dy: 0.50),
    GrowthStar(threshold: 2, dx: 0.50, dy: 0.20),
    GrowthStar(threshold: 4, dx: 0.28, dy: 0.40),
    GrowthStar(threshold: 7, dx: 0.72, dy: 0.40),
    GrowthStar(threshold: 12, dx: 0.34, dy: 0.76),
    GrowthStar(threshold: 20, dx: 0.70, dy: 0.76),
  ],
  links: [
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4],
    [0, 5],
  ],
);

/// All four specs, in display order.
List<ConstellationSpec> get kConstellationSpecs => [
  specQuran,
  specVocab,
  specReflection,
  specDiscover,
];

/// Turn raw [GrowthMetrics] into a fully-populated [GrowthMapData].
GrowthMapData buildGrowthMap(GrowthMetrics m) {
  String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  final quran = GrowthConstellation(
    spec: specQuran,
    value: m.quranLayers,
    headline: m.quranLayers == 0
        ? 'No tafseer opened yet'
        : plural(m.quranLayers, 'tafseer layer'),
    detail: m.quranAyahs == 0
        ? 'Open a layer while reading to begin'
        : 'across ${plural(m.quranAyahs, 'ayah')}',
  );

  final vocab = GrowthConstellation(
    spec: specVocab,
    value: m.vocabCount,
    headline: m.vocabCount == 0
        ? 'No words saved yet'
        : plural(m.vocabCount, 'word'),
    detail: m.vocabCount == 0
        ? 'Tap a word while reading to save it'
        : 'in your Vocabulary Bank',
  );

  final reflection = GrowthConstellation(
    spec: specReflection,
    value: m.streak,
    headline: m.streak == 0 ? 'No streak yet' : '${m.streak}-day streak',
    detail: [
      if (m.reflectionsWritten > 0)
        '${plural(m.reflectionsWritten, 'ayah reflection')} written'
      else if (m.hadithReflections == 0)
        'Reflect nightly to keep it alive',
      if (m.hadithReflections > 0)
        plural(m.hadithReflections, 'hadith reflection'),
      if (m.reflectedToday) 'reflected today',
    ].join(' · '),
  );

  final discover = GrowthConstellation(
    spec: specDiscover,
    value: m.discoverCompleted,
    headline: m.discoverCompleted == 0
        ? 'None mastered yet'
        : '${m.discoverCompleted} mastered',
    detail: 'prophets · companions · names',
  );

  return GrowthMapData(
    constellations: [quran, vocab, reflection, discover],
    streak: m.streak,
    reflectedToday: m.reflectedToday,
  );
}
