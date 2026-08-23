/// Quran audio — MP3Quran reciters/moshaf + a single shared player.
///
/// One [AudioPlayer] instance for the whole app (not per-screen), so
/// playback survives navigating away from the reader. Reciter list is
/// cached in SharedPreferences; audio itself always streams from the
/// MP3Quran server URL — nothing is downloaded or bundled.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';
import '../../../services/audio/mp3quran_service.dart';
import '../../../services/audio/playback_arbiter.dart';
import '../../../shared/models/reciter.dart';

const String _tag = 'QuranAudio';

// ── Reciters (cached locally) ────────────────────────────────────────

final mp3QuranServiceProvider = Provider((ref) => Mp3QuranService());

const _kRecitersCacheKey = 'mp3quran_reciters_cache_v1';

final recitersProvider = FutureProvider<List<Reciter>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_kRecitersCacheKey);
  if (cached != null) {
    try {
      final list = jsonDecode(cached) as List;
      return list.map((r) => Reciter.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      // Corrupt cache — fall through to a fresh fetch.
    }
  }

  final reciters = await ref.read(mp3QuranServiceProvider).getReciters();
  await prefs.setString(
    _kRecitersCacheKey,
    jsonEncode(reciters.map((r) => r.toJson()).toList()),
  );
  return reciters;
});

/// Clears the local reciter cache — call, then invalidate [recitersProvider]
/// from the caller's own Ref/WidgetRef to force a fresh fetch.
Future<void> clearRecitersCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kRecitersCacheKey);
}

// ── Selected reciter/moshaf (persisted) ───────────────────────────────

class SelectedReciter {
  const SelectedReciter({required this.reciterId, required this.moshafId});
  final int reciterId;
  final int moshafId;
}

class SelectedReciterNotifier extends StateNotifier<SelectedReciter?> {
  SelectedReciterNotifier() : super(null) {
    _load();
  }

  static const _kReciterId = 'selected_reciter_id';
  static const _kMoshafId = 'selected_moshaf_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getInt(_kReciterId);
    final m = prefs.getInt(_kMoshafId);
    if (r != null && m != null) {
      state = SelectedReciter(reciterId: r, moshafId: m);
    }
  }

  Future<void> select(int reciterId, int moshafId) async {
    state = SelectedReciter(reciterId: reciterId, moshafId: moshafId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReciterId, reciterId);
    await prefs.setInt(_kMoshafId, moshafId);
  }
}

final selectedReciterProvider =
    StateNotifierProvider<SelectedReciterNotifier, SelectedReciter?>(
  (ref) => SelectedReciterNotifier(),
);

/// The resolved (Reciter, Moshaf) pair for the current selection, once
/// reciters have loaded. Null while loading or if nothing is selected yet.
final selectedMoshafProvider = Provider<(Reciter, Moshaf)?>((ref) {
  final selected = ref.watch(selectedReciterProvider);
  final reciters = ref.watch(recitersProvider).value;
  if (selected == null || reciters == null) return null;
  for (final r in reciters) {
    for (final m in r.moshaf) {
      if (r.id == selected.reciterId && m.id == selected.moshafId) {
        return (r, m);
      }
    }
  }
  return null;
});

// ── Player ─────────────────────────────────────────────────────────

enum QuranAudioStatus { idle, loading, playing, paused, error }

class QuranAudioState {
  const QuranAudioState({
    this.status = QuranAudioStatus.idle,
    this.surahNumber,
    this.errorMessage,
  });

  final QuranAudioStatus status;
  final int? surahNumber;
  final String? errorMessage;

  QuranAudioState copyWith({
    QuranAudioStatus? status,
    int? surahNumber,
    String? errorMessage,
    bool clearError = false,
  }) =>
      QuranAudioState(
        status: status ?? this.status,
        surahNumber: surahNumber ?? this.surahNumber,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class QuranAudioController extends StateNotifier<QuranAudioState> {
  QuranAudioController() : super(const QuranAudioState()) {
    PlaybackArbiter.instance.register(
      this,
      stop: stop,
      pause: pause,
      isPlaying: () => state.status == QuranAudioStatus.playing,
    );
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        state = state.copyWith(status: QuranAudioStatus.idle);
      } else if (s.playing) {
        state = state.copyWith(status: QuranAudioStatus.playing);
      } else if (state.status == QuranAudioStatus.playing) {
        state = state.copyWith(status: QuranAudioStatus.paused);
      }
    });
    // Mid-stream failures (network drop after setUrl succeeded) surface
    // here, not as a thrown exception from play()/setUrl().
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        AppLogger.error('Playback stream error', error: e, tag: _tag);
        state = state.copyWith(
          status: QuranAudioStatus.error,
          errorMessage: 'Playback stopped unexpectedly.',
        );
      },
    );
  }

  /// `handleInterruptions: false` for the same reason as the ayah player:
  /// `AudioSessionSetup` holds the app's one interruption policy, and leaving
  /// this at its default put a second, conflicting policy on the same streams.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> playSurah(
    int surahNumber, {
    required Reciter reciter,
    required Moshaf moshaf,
  }) async {
    if (!moshaf.hasSurah(surahNumber)) {
      state = QuranAudioState(
        status: QuranAudioStatus.error,
        surahNumber: surahNumber,
        errorMessage: '${reciter.name} does not have this Surah.',
      );
      return;
    }

    // Same surah already loaded — just resume.
    if (state.surahNumber == surahNumber &&
        (state.status == QuranAudioStatus.paused)) {
      await resume();
      return;
    }

    // One output, one audio session, so exactly one player may run. Stopping the
    // other one is the arbiter's job rather than this method's or a widget's —
    // which is the half of the rule that was missing: a Settings preview used to
    // start on top of a recitation already playing in the reader.
    await PlaybackArbiter.instance.claim(this);

    state = QuranAudioState(
        status: QuranAudioStatus.loading, surahNumber: surahNumber);
    final url = moshaf.audioUrlFor(surahNumber);
    AppLogger.info(
      'playSurah: reciter=${reciter.name} moshaf=${moshaf.name} '
      'surah=$surahNumber url=$url',
      tag: _tag,
    );
    try {
      final duration = await _player.setUrl(url);
      AppLogger.info('setUrl ok, duration=$duration', tag: _tag);
      // Not awaited: just_audio's `play()` future completes when the surah
      // *ends*, not when it starts. Awaiting it here meant the status line that
      // used to follow ran an hour later and wrote "playing" over the `idle` the
      // completion listener had already set. The listener above is the only thing
      // that should be reporting playback state.
      unawaited(_player.play().catchError((Object e) {
        AppLogger.error('play() rejected for $url', error: e, tag: _tag);
      }));
    } catch (e) {
      AppLogger.error('Playback failed for $url', error: e, tag: _tag);
      state = QuranAudioState(
        status: QuranAudioStatus.error,
        surahNumber: surahNumber,
        errorMessage: 'Could not play this Surah. Check your connection.',
      );
    }
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(status: QuranAudioStatus.paused);
  }

  Future<void> resume() async {
    unawaited(_player.play().catchError((Object e) {
      AppLogger.error('resume() rejected', error: e, tag: _tag);
      state = state.copyWith(
          status: QuranAudioStatus.error, errorMessage: 'Playback failed.');
    }));
  }

  Future<void> stop() async {
    await _player.stop();
    state = const QuranAudioState();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> playAdjacent(
    int delta, {
    required Reciter reciter,
    required Moshaf moshaf,
  }) async {
    final current = state.surahNumber;
    if (current == null) return;
    final next = current + delta;
    if (next < 1 || next > 114) return;
    await playSurah(next, reciter: reciter, moshaf: moshaf);
  }

  @override
  void dispose() {
    PlaybackArbiter.instance.unregister(this);
    _player.dispose();
    super.dispose();
  }
}

final quranAudioProvider =
    StateNotifierProvider<QuranAudioController, QuranAudioState>(
  (ref) => QuranAudioController(),
);
