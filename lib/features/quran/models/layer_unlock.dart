/// LayerUnlock — tracks when a user first opened each layer for each ayah
///
/// Stored in SQLite. One row per (surah, ayah, layer) combination.
/// When a user opens a layer for the first time, we record the timestamp.
/// The next layer becomes available exactly 24 hours later.
///
/// Layer indices:
/// 0 = Words (always unlocked — no wait needed for the first layer)
/// 1 = Context (unlocks 24h after Words was first opened)
/// 2 = Scholars (unlocks 24h after Context was first opened)
/// 3 = Isnad (unlocks 24h after Scholars was first opened)
/// 4 = Reflection (unlocks 24h after Isnad was first opened)
library;

class LayerUnlock {
  const LayerUnlock({
    this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.layerIndex,
    required this.unlockedAt,
  });

  final int? id;
  final int surahNumber;
  final int ayahNumber;
  final int layerIndex;        // 0–4
  final DateTime unlockedAt;   // when this layer was first opened

  /// Key for looking up a specific unlock record
  String get key => '$surahNumber:$ayahNumber:$layerIndex';

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'surah_number': surahNumber,
    'ayah_number': ayahNumber,
    'layer_index': layerIndex,
    'unlocked_at': unlockedAt.toIso8601String(),
  };

  factory LayerUnlock.fromMap(Map<String, dynamic> map) => LayerUnlock(
    id: map['id'] as int?,
    surahNumber: map['surah_number'] as int,
    ayahNumber: map['ayah_number'] as int,
    layerIndex: map['layer_index'] as int,
    unlockedAt: DateTime.parse(map['unlocked_at'] as String),
  );
}

/// The names shown in the layer tab bar
class LayerMeta {
  static const List<String> names = [
    'Words',
    'Context',
    'Scholars',
    'Isnad',
    'Reflection',
  ];

  static const List<String> icons = [
    '🔤', '📍', '📚', '🔗', '✍️',
  ];

  /// How long to wait before next layer unlocks
  static const Duration unlockInterval = Duration(seconds: 1);

  /// For testing — use 1 minute instead of 24 hours
  /// Change back to Duration(hours: 24) before release
  // static const Duration unlockInterval = Duration(minutes: 1);
}
