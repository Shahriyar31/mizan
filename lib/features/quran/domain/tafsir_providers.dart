/// Providers for the Words, Scholars and Similar layers' remote content.
///
/// Kept apart from `layer_providers.dart` on purpose: that file resolves the
/// bundled [LayerData] for an ayah and is what every layer already watches.
/// These providers are additive — each layer watches its own one *in addition*
/// to the bundled content, and renders whichever is richer. Nothing that already
/// worked depends on any of them resolving.
///
/// The family keys are strings rather than records because Riverpod family
/// arguments must be value-equal for caching to work, and a plain string is the
/// cheapest thing that is.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mutashabihat_repository.dart';
import '../data/tafsir_repository.dart';
import '../data/word_analysis_repository.dart';

// ── Word-by-word ──────────────────────────────────────────────────────

/// The words of one ayah. Key is `'surah:ayah'`.
///
/// Resolves to an empty list rather than an error when nothing is available, so
/// the layer's `.value ?? const []` reads the same in every state.
final ayahWordsProvider =
    FutureProvider.family<List<QuranWord>, String>((ref, key) async {
  final parts = key.split(':');
  if (parts.length < 2) return const [];
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null || ayah == null) return const [];
  return WordAnalysisRepository.instance.forAyah(surah, ayah);
});

// ── Tafsir sources ────────────────────────────────────────────────────

/// Every tafsīr the reader can switch to. Always contains [kBundledTafsir].
final tafsirSourcesProvider = FutureProvider<List<TafsirSource>>(
  (ref) => TafsirRepository.instance.sources(),
);

/// The selected tafsīr's key, persisted so a reader who prefers al-Muyassar is
/// not handed Ibn Kathīr again at the next launch.
class TafsirSourceNotifier extends StateNotifier<String> {
  TafsirSourceNotifier() : super(bundledTafsirKey) {
    _load();
  }

  static const _key = 'tafsir_source_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return;
    // Not validated against the catalogue here: an unknown key simply resolves
    // to no passage, and the layer falls back to the bundled commentary — which
    // is a better outcome than blocking startup on a network round trip.
    state = saved;
  }

  Future<void> select(String key) async {
    if (key == state) return;
    state = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, key);
  }
}

final tafsirSourceProvider =
    StateNotifierProvider<TafsirSourceNotifier, String>(
  (ref) => TafsirSourceNotifier(),
);

/// The [TafsirSource] object for the current selection, once the catalogue has
/// loaded. Falls back to the bundled source while loading or if the saved key is
/// no longer in the catalogue.
final selectedTafsirProvider = Provider<TafsirSource>((ref) {
  final key = ref.watch(tafsirSourceProvider);
  final sources = ref.watch(tafsirSourcesProvider).value;
  if (sources == null) return kBundledTafsir;
  for (final source in sources) {
    if (source.key == key) return source;
  }
  return kBundledTafsir;
});

/// The commentary on one ayah from the selected source. Key is `'surah:ayah'`.
///
/// Watches [selectedTafsirProvider], so tapping a different source chip
/// re-resolves this automatically — that is the whole of "source switching".
final ayahTafsirProvider =
    FutureProvider.family<TafsirPassage?, String>((ref, key) async {
  final source = ref.watch(selectedTafsirProvider);
  if (source.isBundled) return null;

  final parts = key.split(':');
  if (parts.length < 2) return null;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null || ayah == null) return null;

  return TafsirRepository.instance.passage(source, surah, ayah);
});

// ── Mutashabihat ──────────────────────────────────────────────────────

/// Verses that resemble this one. Key is `'surah:ayah'`.
///
/// An empty list is the normal answer for most ayat, not a failure.
final similarVersesProvider =
    FutureProvider.family<List<SimilarVerse>, String>((ref, key) async {
  final parts = key.split(':');
  if (parts.length < 2) return const [];
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null || ayah == null) return const [];
  return MutashabihatRepository.instance.forAyah(surah, ayah);
});
