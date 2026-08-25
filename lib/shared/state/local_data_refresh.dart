/// Re-reads everything that was computed from local storage.
///
/// ── Why this needs to exist ────────────────────────────────────────────
/// Riverpod caches. `FutureProvider`s that read SQLite or SharedPreferences hold
/// their first answer until something invalidates them, which is exactly right
/// while the only writer is the app itself — every save goes through a notifier
/// that refreshes its own provider.
///
/// It stops being right the moment something rewrites the stores *underneath*
/// those providers in bulk. Two things do:
///
///   * a restore, which can add hundreds of rows across six tables and twenty
///     preferences in one transaction, and
///   * [AccountDataBoundary.onSignedIn], which deletes the previous owner's rows
///     when a different account signs in on the same phone.
///
/// Without this, the screens keep showing the old numbers — a streak of 0 next
/// to a restored 40-day record, an empty vocabulary bank holding 120 words, or
/// (in the account-switch case) the previous person's counts under the new
/// person's name. Not stale data in the harmless sense: the reader concludes the
/// restore did not work, and presses it again.
///
/// ── What is here and what is not ───────────────────────────────────────
/// Only providers whose value comes from the *personal* stores. Content
/// providers — surahs, tafsir, the seerah list, today's Thread — read bundled
/// assets or the API cache, and neither a restore nor an account switch changes
/// what they would return.
///
/// Several providers are omitted on purpose because they already depend on one
/// that is listed: `vocabCountProvider`, `isWordSavedProvider`,
/// `reviewWordsProvider` and `todaysWordProvider` all watch a provider below, so
/// Riverpod recomputes them. Invalidating them again would be noise that reads
/// like completeness.
///
/// ── Known gap ──────────────────────────────────────────────────────────
/// The account-switch path does not call this yet. `AccountDataBoundary.onSignedIn`
/// returns true when it cleared another account's data specifically so its caller
/// can, but the caller — `AuthRepository` — is not a Riverpod consumer and
/// currently drops the flag. Threading it up to `AuthController` is the fix.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/providers/discover_providers.dart';
import '../../features/growth/domain/mizan_birth_date.dart';
import '../../features/growth/domain/mizan_record.dart';
import '../../features/growth/domain/growth_map_providers.dart';
import '../../features/growth/domain/vocab_providers.dart';
import '../../features/home/domain/home_providers.dart';
import '../../features/home/domain/streak_provider.dart';
import '../../features/home/domain/todays_mizan.dart';
import '../../features/quran/domain/layer_providers.dart';

/// Drops every cached value derived from this device's personal data.
///
/// Cheap to call: invalidation only marks providers dirty, and a provider with
/// no active listener is not recomputed at all. So invalidating the Discover and
/// Quran families from a Settings screen costs nothing until those screens are
/// next built, which is precisely when the fresh value is needed.
void refreshLocalDataProviders(WidgetRef ref) {
  // Home
  ref.invalidate(lastAyahProvider);
  ref.invalidate(vocabDueProvider);
  ref.invalidate(muhasabahDoneProvider);
  ref.invalidate(streakProvider);
  ref.invalidate(todaysMizanProvider);

  // Growth
  ref.invalidate(mizanRecordProvider);
  ref.invalidate(mizanFiguresProvider);
  ref.invalidate(growthMetricsProvider);
  ref.invalidate(growthMapProvider);
  ref.invalidate(vocabWordsProvider);

  // The reader's own words and which layers they have opened. Families, so this
  // clears every ayah at once rather than needing the list of ayat that changed.
  ref.invalidate(layerStatesProvider);
  ref.invalidate(reflectionProvider);

  // Discover progress — four sections, four independent notifiers.
  ref.invalidate(prophetProgressProvider);
  ref.invalidate(sahabiProgressProvider);
  ref.invalidate(nameProgressProvider);
  ref.invalidate(seerahProgressProvider);
}
