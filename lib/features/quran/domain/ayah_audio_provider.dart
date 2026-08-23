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
/// [AudioRepository] resolves a URL — computed on the device for the bundled
/// everyayah reciters, looked up from UmmahAPI for catalogue ones — and
/// [RecitationCache] keeps the file. That ordering matters:
///
///   1. Already on disk → play the local file. No network at all, so a repeat
///      for memorisation is instant and an ayah heard once is heard again on a
///      train with no signal.
///   2. Not on disk → stream it *while writing it to disk* through just_audio's
///      caching source, so the first listen costs one download and the second
///      costs none.
///
/// The next ayah is fetched to disk while the current one plays, which is what
/// removes the stall at each boundary.
///
/// ── Why "it stops after two ayat" and "it distorts" were four bugs ─────
/// Caching was necessary but it was not the whole cause. Each of these is
/// documented at the code that fixes it; in short:
///
///   1. **The stop.** `await _player.play()` in [playAyah]. just_audio's `play()`
///      future does not complete until playback *ends*, so auto-advance held the
///      completion guard raised for the whole of the next ayah and then threw
///      that ayah's completion away as re-entrant. Exactly two ayat, always.
///      `play()` is started and not awaited now.
///   2. **A second interruption policy.** [AudioPlayer] defaults to
///      `handleInterruptions: true` and installs its own handler on the two
///      `AudioSession` streams `main()` already listens on. Two policies then ran
///      per interruption, one resuming and one deliberately not, against one
///      player. Both players are built with it off; `AudioSessionSetup` owns the
///      policy alone, and no longer treats a notification chime as a full loss of
///      focus.
///   3. **A live source swap.** [playAyah] loaded the next source onto a player
///      that was *still playing*. Resolving a URL is not instant, so the previous
///      ayah stayed audible across that window and then `setAudioSource` swapped
///      the source under a live audio track — the tail of one ayah emitted over
///      the head of the next. The player is paused first now.
///   4. **Two writers, one file.** The prefetch and just_audio's caching source
///      wrote the *same* path by different routes, so on a slow connection an
///      ayah was downloaded twice and renamed into place twice while the decoder
///      was reading it. [_sourceFor] now waits for a download already in flight
///      instead of opening a competing one.
///
/// Per-ayah `setAudioSource` remains the design — see the note on repeat above
/// for why a gapless playlist (`AudioPlayer.setAudioSources`) cannot replace it
/// — so a short gap at each boundary is expected and is not the artefact this
/// guards against.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';
import '../../../services/audio/playback_arbiter.dart';
import '../../../services/audio/recitation_cache.dart';
import '../data/audio_repository.dart';
import '../data/ayah_reciters.dart';

export '../data/ayah_reciters.dart';

const String _tag = 'AyahAudio';

/// Repeat the current ayah until the listener stops it.
const int kRepeatForever = -1;

/// The repeat choices offered in the player, in the order they cycle.
const List<int> kRepeatChoices = [1, 3, 5, 10, kRepeatForever];

// ── Reciters ──────────────────────────────────────────────────────────
//
// The model and the bundled list live in `../data/ayah_reciters.dart` and are
// re-exported above, so nothing that imports this file had to change.

/// Every reciter on offer: the bundled five, plus whatever UmmahAPI adds.
///
/// Never fails — [AudioRepository.reciters] falls back to the bundled list — so
/// callers can read `.value ?? kAyahReciters` and always have something to show.
final ayahRecitersProvider = FutureProvider<List<AyahReciter>>(
  (ref) => AudioRepository.instance.reciters(),
);

class AyahReciterNotifier extends StateNotifier<AyahReciter> {
  AyahReciterNotifier() : super(kAyahReciters.first) {
    _load();
  }

  static const _key = 'ayah_reciter_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id == null) return;

    // The bundled list first, so a saved bundled reciter is restored without
    // waiting on the network.
    for (final r in kAyahReciters) {
      if (r.id == id) {
        state = r;
        return;
      }
    }

    // Otherwise it was a catalogue reciter, which means resolving the catalogue.
    // A failure here leaves the default in place rather than a broken selection.
    final all = await AudioRepository.instance.reciters();
    for (final r in all) {
      if (r.id == id) {
        state = r;
        return;
      }
    }
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
    PlaybackArbiter.instance.register(
      this,
      stop: stop,
      pause: pause,
      isPlaying: () => state.status == AyahAudioStatus.playing,
    );
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

  /// `handleInterruptions: false` because [AudioSessionSetup] owns that policy
  /// for the whole app.
  ///
  /// Left at its default of `true`, just_audio subscribes to the same two
  /// `AudioSession` streams `main()` already listens on, and every interruption
  /// then ran two policies against one player: just_audio pauses and resumes
  /// afterwards, this app pauses and deliberately does not. The two arrive in
  /// either order, so a notification a couple of ayat in could end with the
  /// player stopped and this notifier's state reset — the recitation stopping on
  /// its own, with nothing in the app that looked responsible for it.
  ///
  /// This does not disable audio *attributes*: `androidApplyAudioAttributes`
  /// is a separate flag and stays on.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final RecitationCache _cache = RecitationCache.instance;
  final AudioRepository _repository = AudioRepository.instance;

  /// Playback speed, held here rather than read off the player so it survives
  /// loading a new ayah — `setAudioSource` resets the rate to 1.0.
  double _speed = 1.0;

  /// Guards the completion handler: seeking back to zero and playing again
  /// re-enters `playerStateStream`, and without this a repeat would fire twice.
  bool _handlingCompletion = false;

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  double get speed => _speed;

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
      // Not awaited, for the reason spelled out in [playAyah]: this future does
      // not complete until the repetition ends, and this method is what holds
      // `_handlingCompletion` raised.
      unawaited(_player.play().catchError((Object e) {
        AppLogger.error('repeat play() rejected', error: e, tag: _tag);
      }));
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

    // The two players share one output and one audio session, so exactly one of
    // them may be running. Enforced by the arbiter rather than at the call sites
    // — that is what let a Settings preview and a reader recitation overlap.
    await PlaybackArbiter.instance.claim(this);

    // Silence *this* player before loading anything, and do it before the awaits
    // below rather than after them.
    //
    // The arbiter deliberately skips the player that called `claim`, so nothing
    // else stops this one. Resolving the next ayah is not instant — a cache
    // lookup at best, and for a catalogue reciter up to two HTTP round-trips in
    // `AudioRepository.urlFor` — and for that whole window the *previous* ayah
    // was still audible while the app already showed the new one as loading.
    // Then `setAudioSource` arrived on a player whose `playing` was still true,
    // so ExoPlayer swapped the source under a live audio track: the tail of the
    // old ayah's buffer is emitted over the head of the new one. That is the
    // click-and-garble at every boundary and every tap that reads as distortion,
    // and it is why it survived the caching fix — caching made the window
    // shorter, not empty.
    //
    // Pausing first both stops the sound immediately and drops `playing` to
    // false, so the new source cannot auto-start before `play()` is called
    // deliberately below.
    try {
      await _player.pause();
    } catch (_) {
      // Nothing loaded yet on the very first ayah. Not a failure.
    }

    state = state.copyWith(
      status: AyahAudioStatus.loading,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      lastAyah: lastAyah,
      repeatDone: 0,
      clearError: true,
    );

    try {
      final source = await _sourceFor(r, surahNumber, ayahNumber);
      if (source == null) {
        state = state.copyWith(
          status: AyahAudioStatus.error,
          errorMessage: 'No recitation available for this ayah in ${r.name}.',
        );
        return;
      }

      // A tap while this was resolving already moved the player on; finishing
      // this one would play the wrong ayah over the new one.
      if (!state.isOn(surahNumber, ayahNumber)) return;

      await _player.setAudioSource(source);
      await _player.setSpeed(_speed);

      // Started, not awaited — and this one line is why recitation stopped after
      // exactly two ayat.
      //
      // just_audio's `play()` does not complete when playback *begins*. Its own
      // documentation says the future "completes when the playback completes or
      // is paused or stopped", and both platform implementations bear that out:
      // each parks on a completer that is only fired at the end of the clip. So
      // `await _player.play()` here sat still for the entire ayah.
      //
      // That turned auto-advance into a one-shot. Ayah N ends, [_onPlayerState]
      // raises `_handlingCompletion` and calls [_onAyahFinished], which awaited
      // `playAyah` for ayah N+1, which awaited `play()` — which does not return
      // until N+1 has itself finished. The guard was therefore still raised when
      // N+1's completion arrived, that completion was discarded as re-entrant,
      // and the recitation was over. Two ayat, every time, with nothing logged
      // and nothing thrown.
      //
      // It also left [_warmNext] below unreachable until the ayah was over, so
      // the next ayah was never on disk in time and every boundary paid for a
      // cold fetch — audible as the gap and click at each transition.
      //
      // Not awaiting costs nothing: `playerStateStream` already drives
      // [AyahAudioStatus] through [_onPlayerState], so the button follows the
      // player rather than this method's optimism, and an error raised inside
      // `play()` surfaces on `playbackEventStream`, which the constructor
      // listens to.
      unawaited(_player.play().catchError((Object e) {
        AppLogger.error('play() rejected for $surahNumber:$ayahNumber',
            error: e, tag: _tag);
      }));

      _warmNext(r, surahNumber, ayahNumber, lastAyah);
    } catch (e) {
      AppLogger.error('Ayah playback failed for $surahNumber:$ayahNumber',
          error: e, tag: _tag);
      state = state.copyWith(
        status: AyahAudioStatus.error,
        // Names the reciter, because a missing set is reciter-specific and
        // trying another one is the fix.
        errorMessage: 'Could not play this ayah in ${r.name}. '
            'Check your connection, or try another reciter.',
      );
    }
  }

  /// A local file when this ayah has been heard before, otherwise a caching
  /// stream that writes it to that same file as it plays. Null when no URL for
  /// this ayah exists at all.
  Future<AudioSource?> _sourceFor(
    AyahReciter r,
    int surahNumber,
    int ayahNumber,
  ) async {
    final cached = await _cache.cached(r.id, surahNumber, ayahNumber);
    if (cached != null) return AudioSource.file(cached.path);

    final url = await _repository.urlFor(r, surahNumber, ayahNumber);
    if (url == null) return null;

    try {
      final file = await _cache.fileFor(r.id, surahNumber, ayahNumber);

      // Only one writer per path, ever.
      //
      // This is the collision the caching fix introduced. `_warmNext` prefetches
      // ayah N+1 through [RecitationCache], which downloads to `<name>.mp3.dl`
      // and renames into place. `LockCachingAudioSource` streams the *same* ayah
      // to `<name>.mp3.part` and renames into the *same* final path. On a slow
      // connection the prefetch of N+1 has not finished by the time auto-advance
      // arrives at N+1 — which is the normal case precisely when the connection
      // is bad — so `cached()` found nothing (only the `.dl` exists), a second
      // download started, and two writers raced onto one file while the player
      // was reading it: `LockCachingAudioSource.request()` re-stats the cache
      // file on every range request, so a rename landing mid-ayah changes the
      // bytes under the decoder. Frames read at the wrong offset are decoded as
      // noise. Waiting for the download that is *already running* costs nothing
      // — it is the same bytes from the same server — and leaves exactly one
      // writer on the path.
      final pending = _cache.pendingFor(file);
      if (pending != null) {
        final done = await pending;
        if (done != null) return AudioSource.file(done.path);
        // The prefetch failed, so the path is free again and streaming is the
        // right fallback rather than giving up on the ayah.
      }

      // LockCachingAudioSource streams and writes at once, so the first listen
      // pays for the download and every later one is a disk read. It writes a
      // `.part` file and renames on completion, so an interrupted listen cannot
      // leave a truncated file behind to be played as if it were whole.
      //
      // Experimental in just_audio 0.10.x, and used deliberately: it is the only
      // way to stream and cache in one download. If it is ever removed, the
      // fallback is the line below — stream without keeping the file — which
      // costs a re-download per repeat but never breaks playback.
      // ignore: experimental_member_use
      return LockCachingAudioSource(Uri.parse(url), cacheFile: file);
    } catch (_) {
      // No writable cache directory — stream without keeping it.
      return AudioSource.uri(Uri.parse(url));
    }
  }

  /// Pulls the next ayah onto disk while this one plays. This is the fix for the
  /// stall at every ayah boundary: by the time the current ayah ends, the next
  /// one is a local file.
  ///
  /// Only for pattern reciters, because a lookup reciter would need a request to
  /// learn the URL and a speculative request for an ayah that may never be
  /// reached is not worth it.
  void _warmNext(AyahReciter r, int surahNumber, int ayahNumber, int lastAyah) {
    if (!state.continuous) return;
    if (ayahNumber >= lastAyah) return;
    final next = ayahNumber + 1;
    final url = r.urlFor(surahNumber, next);
    if (url == null) return;
    _cache.prefetch(r.id, surahNumber, next, url);
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(status: AyahAudioStatus.paused);
  }

  /// Resumes the loaded ayah.
  ///
  /// `play()` is not awaited here either. Awaiting it meant this method did not
  /// return until the ayah had *finished*, and the `status: playing` line that
  /// used to follow then landed after playback was already over — writing
  /// "playing" onto a player that had stopped. [_onPlayerState] reports the real
  /// thing a frame later, so there is nothing to write here.
  Future<void> resume() async {
    unawaited(_player.play().catchError((Object e) {
      AppLogger.error('resume() rejected', error: e, tag: _tag);
      state = state.copyWith(
        status: AyahAudioStatus.error,
        errorMessage: 'Playback failed.',
      );
    }));
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

  /// Playback speed, applied now and re-applied to every ayah after this one.
  ///
  /// Kept in the controller because `setAudioSource` resets the player's rate,
  /// so a speed set once would otherwise silently revert at the next ayah.
  Future<void> setSpeed(double value) async {
    _speed = value.clamp(0.5, 2.0);
    try {
      await _player.setSpeed(_speed);
    } catch (_) {
      // Nothing loaded yet — it is applied when the next ayah starts.
    }
  }

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
    PlaybackArbiter.instance.unregister(this);
    _player.dispose();
    super.dispose();
  }
}

final ayahAudioProvider =
    StateNotifierProvider<AyahAudioController, AyahAudioState>(
  (ref) => AyahAudioController(ref),
);
