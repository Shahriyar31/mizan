/// Layer System Riverpod Providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/layer_repository.dart';
import '../models/layer_unlock.dart';

// ── Repository ────────────────────────────────────────────────
final layerRepositoryProvider = Provider<LayerRepository>((ref) {
  return LayerRepository();
});

// ── Ayah unlock state ─────────────────────────────────────────
// Holds all unlock records for a specific ayah
// Key = "surahNumber:ayahNumber"
final ayahUnlocksProvider =
    FutureProvider.family<List<LayerUnlock>, String>((ref, ayahKey) async {
  final parts = ayahKey.split(':');
  final surahNumber = int.parse(parts[0]);
  final ayahNumber = int.parse(parts[1]);
  final repo = ref.watch(layerRepositoryProvider);
  return repo.getUnlocksForAyah(surahNumber, ayahNumber);
});

// ── Layer availability provider ───────────────────────────────
// Computes which layers are available and which are locked
// Returns a list of 5 LayerState objects
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
      // Words layer — always unlocked
      return LayerState(
        index: index,
        isUnlocked: true,
        unlockedAt: unlocks.isNotEmpty
            ? unlocks.firstWhere(
                (u) => u.layerIndex == 0,
                orElse: () => LayerUnlock(
                  surahNumber: surahNumber,
                  ayahNumber: ayahNumber,
                  layerIndex: 0,
                  unlockedAt: now,
                ),
              ).unlockedAt
            : null,
        availableAt: null,
      );
    }

    // Find if previous layer was unlocked
    final previousUnlock = unlocks.where(
      (u) => u.layerIndex == index - 1,
    ).firstOrNull;

    if (previousUnlock == null) {
      // Previous layer not even opened
      return LayerState(
        index: index,
        isUnlocked: false,
        unlockedAt: null,
        availableAt: null, // unknown — depends on opening previous
      );
    }

    final availableAt = previousUnlock.unlockedAt
        .add(LayerMeta.unlockInterval);
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

// ── Reflection provider ───────────────────────────────────────
final reflectionProvider =
    FutureProvider.family<String?, String>((ref, ayahKey) async {
  final parts = ayahKey.split(':');
  final repo = ref.watch(layerRepositoryProvider);
  return repo.getReflection(int.parse(parts[0]), int.parse(parts[1]));
});

// ── State class ───────────────────────────────────────────────
class LayerState {
  const LayerState({
    required this.index,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.availableAt,
  });

  final int index;
  final bool isUnlocked;
  final DateTime? unlockedAt;   // when this layer was opened
  final DateTime? availableAt;  // when it will become available

  /// How long until this layer unlocks, formatted
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
