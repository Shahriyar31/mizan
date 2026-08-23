/// LayerUnlock — tracks when a user first opened each layer for each ayah
///
/// Stored in SQLite. One row per (surah, ayah, layer) combination.
/// When a user opens a layer for the first time, we record the timestamp.
/// The next layer becomes available exactly 24 hours later.
///
/// Layer indices — these are **storage** indices and are permanent:
/// 0 = Words (always unlocked — no wait needed for the first layer)
/// 1 = Context
/// 2 = Scholars (tafsir)
/// 3 = Isnad
/// 4 = Reflection
/// 5 = Similar (mutashabihat)
///
/// Similar was added last and therefore took the next free index, even though it
/// is *shown* before Reflection. The alternative — giving Similar index 4 and
/// pushing Reflection to 5 — would have silently reinterpreted every
/// `layer_unlocks` row already saved on every device: a row saying
/// "layer 4 opened" would change meaning from "Reflection" to "Similar".
/// So order-on-screen and order-in-storage are kept as separate concerns and
/// [LayerMeta.displayOrder] is the only place the difference lives.
library;

import 'package:flutter/material.dart' show IconData, Icons;

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
  final int layerIndex;        // 0–5, a storage index — see the library comment
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

/// The names shown in the layer tab bar.
///
/// Indexed by **storage** index throughout — see the library comment. Anything
/// that renders the tab bar walks [displayOrder] and uses each entry as the
/// index into these lists.
class LayerMeta {
  static const List<String> names = [
    'Words',
    'Context',
    'Scholars',
    'Isnad',
    'Reflection',
    'Similar',
  ];

  /// One glyph per layer, indexed by **storage** index.
  ///
  /// These were emoji until the layers sheet landed. Emoji are drawn by the
  /// platform's own font: they ignore the palette, so a locked or inverse row
  /// could not tint them, they change shape between Android and iOS, and beside
  /// the app's rounded Material icons they read as another product's UI. These
  /// are the same icon family the rest of the reader uses.
  static const List<IconData> icons = [
    Icons.translate_rounded,      // Words — roots and meanings
    Icons.place_rounded,          // Context — where and when it came down
    Icons.auto_stories_rounded,   // Scholars — the tafsir
    Icons.link_rounded,           // Isnad — the chain
    Icons.edit_note_rounded,      // Reflection — the reader writes
    Icons.compare_arrows_rounded, // Similar — mutashabihat
  ];

  /// Roughly how long one layer takes to read, in whole minutes, by **storage**
  /// index.
  ///
  /// An estimate, not a measurement — nothing in the app times a reader. It
  /// exists so the layers sheet can say "about 9 min left" instead of showing
  /// six destinations with no sense of the cost of any of them, and it is always
  /// spoken with a hedge ("about") for exactly that reason. Scholars is the
  /// longest because it is prose from a mufassir; Context and Similar are the
  /// shortest because they are a paragraph and a short list.
  static const List<int> readMinutes = [3, 2, 4, 2, 3, 2];

  /// How many layers exist.
  static int get count => names.length;

  /// Storage indices in the order they are shown, left to right.
  ///
  /// Reflection stays last on screen because it is the layer that gates moving
  /// on to the next ayah — putting a browsing layer after it would invite
  /// leaving the ayah without reflecting. Similar therefore sits between Isnad
  /// and Reflection, which is why this list is not simply `0..5`.
  static const List<int> displayOrder = [0, 1, 2, 3, 5, 4];

  /// Where a storage index appears on screen, or -1 if it is not shown.
  static int positionOf(int storageIndex) => displayOrder.indexOf(storageIndex);

  /// The storage index of the layer shown immediately before this one, or null
  /// for the first. This is what the unlock schedule follows: waiting is
  /// measured against the layer the reader actually saw last, not against
  /// whichever index happens to be one lower.
  static int? predecessorOf(int storageIndex) {
    final position = positionOf(storageIndex);
    if (position <= 0) return null;
    return displayOrder[position - 1];
  }

  /// How long to wait before next layer unlocks
  static const Duration unlockInterval = Duration(seconds: 1);

  /// For testing — use 1 minute instead of 24 hours
  /// Change back to Duration(hours: 24) before release
  // static const Duration unlockInterval = Duration(minutes: 1);
}
