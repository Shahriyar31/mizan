/// Quran Riverpod Providers
///
/// Providers explained simply:
/// A provider is like a data source that widgets can watch.
/// When the data changes, any widget watching it rebuilds automatically.
/// No setState, no StreamBuilder, no manual refresh needed.
///
/// Three types used here:
/// Provider        → synchronous, always available data
/// FutureProvider  → async data (API calls), has loading/error states
/// StateProvider   → mutable state (selected surah number)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/quran_repository.dart';
import '../../../shared/models/surah.dart';
import '../../../shared/models/ayah.dart';

// ── Repository Provider ───────────────────────────────────────
// Single instance of QuranRepository shared across the whole app
// Riverpod ensures this is created once and reused everywhere
final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepository();
});

// ── Surahs Provider ───────────────────────────────────────────
// Fetches all 114 surahs from the repository
// AsyncValue has three states: loading, data, error
// The UI handles all three states cleanly
final surahsProvider = FutureProvider<List<Surah>>((ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  return repository.getSurahs();
});

// ── Selected Surah Provider ───────────────────────────────────
// Tracks which surah the user tapped
// Starts at null — no surah selected
// When user taps a surah, we set this and navigate to detail screen
final selectedSurahNumberProvider = StateProvider<int?>((ref) => null);

// ── Ayat Provider ─────────────────────────────────────────────
// Only fetches when a surah is selected
// family modifier means: one provider instance per surah number
// ayatProvider(1) fetches Al-Fatihah
// ayatProvider(2) fetches Al-Baqarah
// Each is cached separately
final ayatProvider =
    FutureProvider.family<List<Ayah>, int>((ref, surahNumber) async {
  final repository = ref.watch(quranRepositoryProvider);
  return repository.getAyatForSurah(surahNumber);
});

// ── Search Query Provider ─────────────────────────────────────
// Tracks the search text the user types
// Empty string means no search active
final surahSearchQueryProvider = StateProvider<String>((ref) => '');

// ── Filtered Surahs Provider ──────────────────────────────────
// Combines surahs + search query to return filtered results
// This is a derived provider — it depends on two other providers
// When either changes, this automatically recomputes
final filteredSurahsProvider = Provider<AsyncValue<List<Surah>>>((ref) {
  final surahsAsync = ref.watch(surahsProvider);
  final query = ref.watch(surahSearchQueryProvider).toLowerCase().trim();

  // If surahs haven't loaded yet, return as-is (loading or error)
  if (!surahsAsync.hasValue) return surahsAsync;

  final surahs = surahsAsync.value!;

  // No search query — return all surahs
  if (query.isEmpty) return AsyncValue.data(surahs);

  // Filter by English name, Arabic name, or surah number
  final filtered = surahs.where((surah) {
    return surah.englishName.toLowerCase().contains(query) ||
        surah.translatedName.toLowerCase().contains(query) ||
        surah.arabicName.contains(query) ||
        surah.number.toString() == query;
  }).toList();

  return AsyncValue.data(filtered);
});
