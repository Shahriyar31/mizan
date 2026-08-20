/// SupabaseService — single connection point to Supabase
/// 
/// Used for:
/// - Auth (user login/signup)
/// - Halaqa groups and sharing
/// - Layer content cache (Scholar AI results)
/// - Minbar public feed
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

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
  Future<void> setLayerCache(
    int surahNumber,
    int ayahNumber,
    int layerIndex,
    Map<String, dynamic> content,
  ) async {
    await client.from('layer_cache').upsert({
      'surah_number': surahNumber,
      'ayah_number': ayahNumber,
      'layer_index': layerIndex,
      'content_json': content,
      'generated_at': DateTime.now().toIso8601String(),
    });
  }
}
