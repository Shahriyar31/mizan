/// SupabaseService — single connection point to Supabase
/// 
/// Used for:
/// - Auth (user login/signup)
/// - Halaqa groups and sharing
/// - Layer content cache (Scholar AI results)
/// - Minbar public feed
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const String _tag = 'SupabaseService';

  // The Supabase client — use this everywhere
  SupabaseClient get client => Supabase.instance.client;

  // Current logged-in user, null if not logged in
  User? get currentUser => client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ── Layer Cache ─────────────────────────────────────────────
  // Check if layer content exists in Supabase cache
  // If yes → return it (free, instant)
  // If no → Scholar AI generates it, we store it, return it
  Future<Map<String, dynamic>?> getLayerCache(
    int surahNumber,
    int ayahNumber,
    int layerIndex,
  ) async {
    final response = await client
        .from('layer_cache')
        .select('content_json')
        .eq('surah_number', surahNumber)
        .eq('ayah_number', ayahNumber)
        .eq('layer_index', layerIndex)
        .maybeSingle();

    if (response == null) return null;
    return response['content_json'] as Map<String, dynamic>?;
  }

  // Store Scholar AI generated content in cache
  //
  // ── Why `onConflict` is spelled out ──────────────────────────────
  // `layer_cache`'s primary key is `id BIGSERIAL`
  // (supabase/migrations/002_auth_rls.sql:46-54) and this payload never carries
  // an `id` — the server generates it. With no explicit conflict target
  // PostgREST infers the primary key, so it looks for a row with a matching
  // `id`, finds nothing to merge with, and the upsert degrades into a plain
  // INSERT that trips `UNIQUE (surah_number, ayah_number, layer_index)` with
  // SQLSTATE 23505 every single time the same ayah/layer is cached again.
  // Naming the unique triple makes the second write the UPDATE it was always
  // meant to be.
  //
  // The write is deliberately not allowed to fail the caller: by the time we
  // get here the content already exists and can be shown, so a cache miss on
  // the way *in* must never break the reader. It is logged instead — silence
  // is how a cache that never actually caches stays invisible.
  Future<void> setLayerCache(
    int surahNumber,
    int ayahNumber,
    int layerIndex,
    Map<String, dynamic> content,
  ) async {
    try {
      await client.from('layer_cache').upsert(
        {
          'surah_number': surahNumber,
          'ayah_number': ayahNumber,
          'layer_index': layerIndex,
          'content_json': content,
          'generated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'surah_number,ayah_number,layer_index',
      );
    } catch (e) {
      AppLogger.error(
        'layer_cache write failed for $surahNumber:$ayahNumber '
        'layer $layerIndex — content was served but not cached: $e',
        tag: _tag,
      );
    }
  }
}
