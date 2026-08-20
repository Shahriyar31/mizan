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
final layerStatesProvider =
    FutureProvider.family<List<LayerState>, String>((ref, ayahKey) async {
  final parts = ayahKey.split(':');
  final surahNumber = int.parse(parts[0]);
  final ayahNumber = int.parse(parts[1]);
  final repo = ref.watch(layerRepositoryProvider);
  final unlocks = await repo.getUnlocksForAyah(surahNumber, ayahNumber);
  final now = DateTime.now();

  return List.generate(5, (index) {
    if (index == 0) {
      return LayerState(
        index: index,
        isUnlocked: true,
        unlockedAt: unlocks
            .where((u) => u.layerIndex == 0)
            .firstOrNull
            ?.unlockedAt,
        availableAt: null,
      );
    }

    final previousUnlock = unlocks
        .where((u) => u.layerIndex == index - 1)
        .firstOrNull;

    if (previousUnlock == null) {
      return LayerState(
        index: index,
        isUnlocked: false,
        unlockedAt: null,
        availableAt: null,
      );
    }

    final availableAt =
        previousUnlock.unlockedAt.add(LayerMeta.unlockInterval);
    final isUnlocked = now.isAfter(availableAt) ||
        unlocks.any((u) => u.layerIndex == index);

    return LayerState(
      index: index,
      isUnlocked: isUnlocked,
      unlockedAt: unlocks
          .where((u) => u.layerIndex == index)
          .firstOrNull
          ?.unlockedAt,
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

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
