/// Layer Providers — updated to use ScholarAIService
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/layer_repository.dart';
import '../data/layer_content.dart';
import '../models/layer_unlock.dart';
import '../../../services/scholar_ai/scholar_ai_service.dart';

// ── Repository ────────────────────────────────────────────────
final layerRepositoryProvider = Provider<LayerRepository>((ref) {
  return LayerRepository();
});

// ── Layer Content Provider ────────────────────────────────────
// Fetches content from ScholarAI (Groq or local fallback)
// Key format: "surahNumber:ayahNumber:arabicText:translation"
final layerContentProvider = FutureProvider.family<LayerData?, String>(
  (ref, key) async {
    final parts = key.split('|||');
    final ayahKey = parts[0]; // "1:1"
    final arabicText = parts.length > 1 ? parts[1] : '';
    final translation = parts.length > 2 ? parts[2] : '';

    final ayahParts = ayahKey.split(':');
    final surahNumber = int.parse(ayahParts[0]);
    final ayahNumber = int.parse(ayahParts[1]);

    return ScholarAIService.instance.getLayerContent(
      surahNumber,
      ayahNumber,
      arabicText,
      translation,
    );
  },
);

// ── Layer States Provider ─────────────────────────────────────
//
// Unlocking follows the order the layers are *shown*, not the order they are
// stored: the layer before Similar is Isnad, and the layer before Reflection is
// Similar. See [LayerMeta.displayOrder] for why those differ.
final layerStatesProvider =
    FutureProvider.family<List<LayerState>, String>((ref, ayahKey) async {
  final parts = ayahKey.split(':');
  final surahNumber = int.parse(parts[0]);
  final ayahNumber = int.parse(parts[1]);
  final repo = ref.watch(layerRepositoryProvider);
  final unlocks = await repo.getUnlocksForAyah(surahNumber, ayahNumber);
  final now = DateTime.now();

  DateTime? openedAt(int index) =>
      unlocks.where((u) => u.layerIndex == index).firstOrNull?.unlockedAt;

  // Indexed by storage index, so `states[4]` is Reflection whatever its
  // position on screen. The tab bar reorders; this list does not.
  return List.generate(LayerMeta.count, (index) {
    final ownUnlock = openedAt(index);

    // Already opened once — unlocked forever. Checked before anything else,
    // because a layer the reader has already read must never close again. Adding
    // Similar between Isnad and Reflection changed Reflection's predecessor, and
    // without this an already-unlocked Reflection would have re-locked on
    // upgrade purely because the layer in front of it had never been opened.
    if (ownUnlock != null) {
      return LayerState(
        index: index,
        isUnlocked: true,
        unlockedAt: ownUnlock,
        availableAt: null,
      );
    }

    final predecessor = LayerMeta.predecessorOf(index);
    if (predecessor == null) {
      // The first layer shown is always open — there is nothing to wait for.
      return LayerState(
        index: index,
        isUnlocked: true,
        unlockedAt: null,
        availableAt: null,
      );
    }

    final predecessorOpenedAt = openedAt(predecessor);
    if (predecessorOpenedAt == null) {
      return LayerState(
        index: index,
        isUnlocked: false,
        unlockedAt: null,
        availableAt: null,
      );
    }

    final availableAt = predecessorOpenedAt.add(LayerMeta.unlockInterval);
    final isUnlocked = now.isAfter(availableAt);

    return LayerState(
      index: index,
      isUnlocked: isUnlocked,
      unlockedAt: null,
      availableAt: isUnlocked ? null : availableAt,
    );
  });
});

// ── Reflection Provider ───────────────────────────────────────
final reflectionProvider =
    FutureProvider.family<String?, String>((ref, ayahKey) async {
  final parts = ayahKey.split(':');
  final repo = ref.watch(layerRepositoryProvider);
  return repo.getReflection(int.parse(parts[0]), int.parse(parts[1]));
});

// ── State Class ───────────────────────────────────────────────
class LayerState {
  const LayerState({
    required this.index,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.availableAt,
  });

  final int index;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime? availableAt;

  String get timeUntilUnlock {
    if (availableAt == null) return '';
    final diff = availableAt!.difference(DateTime.now());
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}
