/// AYAH-BY-AYAH RECITATION — the reader's own player.
///
/// Separate from [quranAudioProvider] (`audio_providers.dart`) on purpose, and
/// the two are never allowed to run at once:
///
///   • **That** player streams one MP3 per *surah* from MP3Quran. It is what
///     Settings → Audio previews and what you want for listening to a whole
///     surah in the background.
///   • **This** player streams one MP3 per *ayah*. That is the only way to know
///     when an ayah ends, and knowing when an ayah ends is what makes
///     auto-advance, follow-along highlighting and repeat-for-memorisation
///     possible at all. A surah file has no ayah timings in it, so none of those
///     features can be built on top of it.
///
/// ── Repeat ────────────────────────────────────────────────────────────
/// [AyahAudioState.repeatTarget] is how many times the *current* ayah plays
/// before the player moves on: 1 is straight through, 3/5/10 are the
/// memorisation loops, and [kRepeatForever] stays on one ayah until you stop it.
/// Repeat is counted here rather than handed to just_audio's [LoopMode] because
/// `LoopMode.one` loops forever and never reports completion — so the player
/// could never count to five and then continue.
///
/// ── Where the audio comes from ────────────────────────────────────────
/// everyayah.com, whose file layout is completely deterministic:
///
///     https://everyayah.com/data/<folder>/<surah:3><ayah:3>.mp3
///     e.g.  .../data/Alafasy_128kbps/002255.mp3   → Al-Baqarah 255
///
/// No index request, no API key, no response parsing — which is why per-ayah
/// playback can start on the first tap. The one thing that can go wrong is a
/// wrong `folder` string in [kAyahReciters]: that produces a 404, which surfaces
/// as this player's error state naming the reciter, never as silence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';

const String _tag = 'AyahAudio';

/// Repeat the current ayah until the listener stops it.
const int kRepeatForever = -1;

/// The repeat choices offered in the player, in the order they cycle.
const List<int> kRepeatChoices = [1, 3, 5, 10, kRepeatForever];

// ── Reciters ──────────────────────────────────────────────────────────

/// A reciter with a complete ayah-by-ayah set on everyayah.com.
class AyahReciter {
  const AyahReciter({
    required this.id,
    required this.name,
    required this.folder,
  });

  /// Stable key used to persist the choice — never the list index, so the list
  /// can be reordered without silently changing someone's reciter.
  final String id;

  final String name;

  /// The everyayah.com directory. See the library comment.
  final String folder;

  String urlFor(int surahNumber, int ayahNumber) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$a.mp3';
  }
}

const List<AyahReciter> kAyahReciters = [
  AyahReciter(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    folder: 'Alafasy_128kbps',
  ),
  AyahReciter(
    id: 'husary',
    name: 'Mahmoud Khalil Al-Husary',
    folder: 'Husary_128kbps',
  ),
  AyahReciter(
    id: 'abdulbasit',
    name: 'Abdul Basit (Murattal)',
    folder: 'Abdul_Basit_Murattal_192kbps',
  ),
  AyahReciter(
    id: 'minshawy',
    name: 'Muhammad Siddiq Al-Minshawi',
    folder: 'Minshawy_Murattal_128kbps',
  ),
  AyahReciter(
    id: 'sudais',
    name: 'Abdurrahman As-Sudais',
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
  ),
];

class AyahReciterNotifier extends StateNotifier<AyahReciter> {
  AyahReciterNotifier() : super(kAyahReciters.first) {
    _load();
  }

  static const _key = 'ayah_reciter_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id == null) return;
    for (final r in kAyahReciters) {
      if (r.id == id) {
        state = r;
        return;
      }
    }
    // Unknown id (list changed between versions) — keep the default.
  }

  Future<void> select(AyahReciter reciter) async {
    state = reciter;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, reciter.id);
  }
}

final ayahReciterProvider =
    StateNotifierProvider<AyahReciterNotifier, AyahReciter>(
  (ref) => AyahReciterNotifier(),
);

// ── State ─────────────────────────────────────────────────────────────

enum AyahAudioStatus { idle, loading, playing, paused, error }

class AyahAudioState {
  const AyahAudioState({
    this.status = AyahAudioStatus.idle,
    this.surahNumber,
    this.ayahNumber,
    this.lastAyah = 0,
    this.repeatTarget = 1,
    this.repeatDone = 0,
    this.continuous = true,
    this.errorMessage,
  });

  final AyahAudioStatus status;
  final int? surahNumber;
  final int? ayahNumber;

  /// Ayah count of the surah being read, so the player knows where to stop
  /// advancing without reaching back into a provider mid-completion.
  final int lastAyah;

  /// How many times the current ayah should play. See the library comment.
  final int repeatTarget;

  /// How many times it already has, this visit.
  final int repeatDone;

  /// Whether finishing an ayah moves to the next one.
  final bool continuous;

  final String? errorMessage;

  bool get isActive =>
      status != AyahAudioStatus.idle && surahNumber != null && ayahNumber != null;

  bool get isPlaying => status == AyahAudioStatus.playing;

  bool get repeatsForever => repeatTarget == kRepeatForever;

  /// True while this exact ayah is the one loaded in the player.
  bool isOn(int surahNumber, int ayahNumber) =>
      this.surahNumber == surahNumber && this.ayahNumber == ayahNumber;

  AyahAudioState copyWith({
    AyahAudioStatus? status,
    int? surahNumber,
    int? ayahNumber,
    int? lastAyah,
    int? repeatTarget,
    int? repeatDone,
    bool? continuous,
    String? errorMessage,
    bool clearError = false,
  }) =>
      AyahAudioState(
        status: status ?? this.status,
        surahNumber: surahNumber ?? this.surahNumber,
        ayahNumber: ayahNumber ?? this.ayahNumber,
        lastAyah: lastAyah ?? this.lastAyah,
        repeatTarget: repeatTarget ?? this.repeatTarget,
        repeatDone: repeatDone ?? this.repeatDone,
        continuous: continuous ?? this.continuous,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ── Controller ────────────────────────────────────────────────────────

class AyahAudioController extends StateNotifier<AyahAudioState> {
  AyahAudioController(this._ref) : super(const AyahAudioState()) {
    _player.playerStateStream.listen(_onPlayerState);
    // A network drop after setUrl succeeded arrives here, not as a throw.
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        AppLogger.error('Ayah playback stream error', error: e, tag: _tag);
        state = state.copyWith(
          status: AyahAudioStatus.error,
          errorMessage: 'Playback stopped unexpectedly.',
        );
      },
    );
  }

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();

  /// Guards the completion handler: seeking back to zero and playing again
  /// re-enters `playerStateStream`, and without this a repeat would fire twice.
  bool _handlingCompletion = false;

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  AyahReciter get reciter => _ref.read(ayahReciterProvider);

  void _onPlayerState(PlayerState s) {
    if (s.processingState == ProcessingState.completed) {
      if (_handlingCompletion) return;
      _handlingCompletion = true;
      _onAyahFinished().whenComplete(() => _handlingCompletion = false);
      return;
    }
    if (s.playing) {
      if (state.status != AyahAudioStatus.playing) {
        state = state.copyWith(status: AyahAudioStatus.playing);
      }
    } else if (state.status == AyahAudioStatus.playing) {
      state = state.copyWith(status: AyahAudioStatus.paused);
    }
  }

  /// Repeat if there are repeats left, otherwise move to the next ayah,
  /// otherwise stop. This is the whole listening model in one method.
  Future<void> _onAyahFinished() async {
    final s = state;
    final surah = s.surahNumber;
    final ayah = s.ayahNumber;
    if (surah == null || ayah == null) return;

    final done = s.repeatDone + 1;
    final wantsMore = s.repeatsForever || done < s.repeatTarget;

    if (wantsMore) {
      state = s.copyWith(repeatDone: done);
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (s.continuous && ayah < s.lastAyah) {
      await playAyah(surah, ayah + 1, lastAyah: s.lastAyah);
      return;
    }

    await stop();
  }

  /// Loads and plays one ayah. Tapping the ayah that is already playing pauses
  /// it; tapping a paused one resumes — so a single control does the obvious
  /// thing in all three states.
  Future<void> playAyah(
    int surahNumber,
    int ayahNumber, {
    required int lastAyah,
  }) async {
    if (state.isOn(surahNumber, ayahNumber)) {
      if (state.status == AyahAudioStatus.playing) return pause();
      if (state.status == AyahAudioStatus.paused) return resume();
    }

    final r = reciter;
    final url = r.urlFor(surahNumber, ayahNumber);

    state = state.copyWith(
      status: AyahAudioStatus.loading,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      lastAyah: lastAyah,
      repeatDone: 0,
      clearError: true,
    );

    try {
      await _player.setUrl(url);
      await _player.play();
      state = state.copyWith(status: AyahAudioStatus.playing);
    } catch (e) {
      AppLogger.error('Ayah playback failed for $url', error: e, tag: _tag);
      state = state.copyWith(
        status: AyahAudioStatus.error,
        // Names the reciter, because a missing set is reciter-specific and
        // trying another one is the fix.
        errorMessage: 'Could not play this ayah in ${r.name}. '
            'Check your connection, or try another reciter.',
      );
    }
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(status: AyahAudioStatus.paused);
  }

  Future<void> resume() async {
    try {
      await _player.play();
      state = state.copyWith(status: AyahAudioStatus.playing);
    } catch (e) {
      state = state.copyWith(
        status: AyahAudioStatus.error,
        errorMessage: 'Playback failed.',
      );
    }
  }

  Future<void> stop() async {
    await _player.stop();
    // Repeat and continuous are settings, not playback state — they survive.
    state = AyahAudioState(
      repeatTarget: state.repeatTarget,
      continuous: state.continuous,
    );
  }

  Future<void> seek(Duration position) => _player.seek(position);

  /// Step by whole ayat. Clamped to the surah, so the end is the end.
  Future<void> step(int delta) async {
    final surah = state.surahNumber;
    final ayah = state.ayahNumber;
    if (surah == null || ayah == null) return;
    final next = ayah + delta;
    if (next < 1 || next > state.lastAyah) return;
    await playAyah(surah, next, lastAyah: state.lastAyah);
  }

  /// Advances the repeat count to the next choice, wrapping round.
  void cycleRepeat() {
    final i = kRepeatChoices.indexOf(state.repeatTarget);
    final next = kRepeatChoices[(i + 1) % kRepeatChoices.length];
    // Restart the count so "5×" from here means five more, not five including
    // however many already played.
    state = state.copyWith(repeatTarget: next, repeatDone: 0);
  }

  void setRepeat(int target) =>
      state = state.copyWith(repeatTarget: target, repeatDone: 0);

  void setContinuous(bool value) =>
      state = state.copyWith(continuous: value);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final ayahAudioProvider =
    StateNotifierProvider<AyahAudioController, AyahAudioState>(
  (ref) => AyahAudioController(ref),
);
