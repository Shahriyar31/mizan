/// Vocabulary Bank Riverpod Providers
///
/// These connect the repository to the UI.
/// The UI watches these providers and rebuilds automatically
/// when the data changes — no manual refresh needed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/vocab_word.dart';
import '../data/vocab_repository.dart';

// ── Repository Provider ───────────────────────────────────────
// Single instance shared across the whole app
final vocabRepositoryProvider = Provider<VocabRepository>((ref) {
  return VocabRepository();
});

// ── All Words Provider ────────────────────────────────────────
// Fetches all saved words for the Vocabulary Bank screen
// AsyncNotifier allows us to refresh after save/delete
final vocabWordsProvider =
    AsyncNotifierProvider<VocabWordsNotifier, List<VocabWord>>(
  VocabWordsNotifier.new,
);

class VocabWordsNotifier extends AsyncNotifier<List<VocabWord>> {
  @override
  Future<List<VocabWord>> build() async {
    final repo = ref.watch(vocabRepositoryProvider);
    return repo.getAllWords();
  }

  /// Call this after saving or deleting a word to refresh the list
  Future<void> refresh() async {
    final repo = ref.read(vocabRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repo.getAllWords());
  }

  /// Saves a word and refreshes the list
  Future<bool> saveWord(VocabWord word) async {
    final repo = ref.read(vocabRepositoryProvider);
    final id = await repo.saveWord(word);
    if (id > 0) {
      await refresh();
      return true;
    }
    return false; // duplicate — already saved
  }

  /// Deletes a word and refreshes the list
  Future<void> deleteWord(int id) async {
    final repo = ref.read(vocabRepositoryProvider);
    await repo.deleteWord(id);
    await refresh();
  }
}

// ── Word Count Provider ───────────────────────────────────────
// Shows total saved words count in Growth tab badge
final vocabCountProvider = FutureProvider<int>((ref) async {
  // Re-runs whenever vocabWordsProvider changes
  ref.watch(vocabWordsProvider);
  final repo = ref.read(vocabRepositoryProvider);
  return repo.getWordCount();
});

// ── Is Word Saved Provider ────────────────────────────────────
// Used by word tap sheet to show correct button state
// family modifier = one provider per Arabic word string
final isWordSavedProvider =
    FutureProvider.family<bool, String>((ref, arabic) async {
  // Re-runs when vocab list changes (after save/delete)
  ref.watch(vocabWordsProvider);
  final repo = ref.read(vocabRepositoryProvider);
  return repo.isWordSaved(arabic);
});

// ── Review Words Provider ─────────────────────────────────────
// Words due for review — used in morning Wird (Phase 3 Home)
final reviewWordsProvider = FutureProvider<List<VocabWord>>((ref) async {
  ref.watch(vocabWordsProvider);
  final repo = ref.read(vocabRepositoryProvider);
  return repo.getWordsForReview(limit: 3);
});
