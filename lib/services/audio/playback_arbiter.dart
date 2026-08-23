/// PlaybackArbiter — exactly one recitation at a time, without either player
/// having to know about the other.
///
/// The app has two players by design (see `ayah_audio_provider.dart` for why one
/// file per ayah and one file per surah are both needed), they share a single
/// audio session and a single output, and so at most one of them may ever be
/// running. That rule used to live in the widget that started playback, which is
/// the wrong place for it twice over: the reader remembered to stop the surah
/// player and Settings did not, and any third player added later would have had
/// to remember as well.
///
/// Here it is a property of starting playback instead. A player registers a stop
/// callback once, calls [claim] before it starts, and everything else stops. The
/// same registry gives the interruption handling in [AudioSessionSetup] something
/// to pause or stop without importing any provider — which is what keeps a phone
/// call and a yanked headphone cable from being wired per player.
///
/// Registration is keyed by the owner object rather than a name, so a hot reload
/// that rebuilds a controller replaces its entry instead of accumulating stale
/// callbacks.
library;

typedef PlaybackAction = Future<void> Function();
typedef PlaybackQuery = bool Function();

class _Registration {
  _Registration({required this.stop, required this.pause, required this.isPlaying});

  final PlaybackAction stop;
  final PlaybackAction pause;
  final PlaybackQuery isPlaying;
}

class PlaybackArbiter {
  PlaybackArbiter._();

  static final PlaybackArbiter instance = PlaybackArbiter._();

  final Map<Object, _Registration> _players = {};

  void register(
    Object owner, {
    required PlaybackAction stop,
    required PlaybackAction pause,
    required PlaybackQuery isPlaying,
  }) {
    _players[owner] = _Registration(stop: stop, pause: pause, isPlaying: isPlaying);
  }

  void unregister(Object owner) => _players.remove(owner);

  /// Called by a player about to start. Stops every other registered player.
  ///
  /// Deliberately unconditional: it does *not* first ask whether the other player
  /// is playing. `isPlaying` reports the notifier's state, and a player that has
  /// begun `setUrl`/`setAudioSource` but not yet reached `play()` reports
  /// `loading`, not `playing` — so gating on it let a player that was about to
  /// start slip through, resolve its source, and begin on top of the recitation
  /// the listener had just asked for. Two live outputs is what listeners report as
  /// distortion. `stop()` on a player that is idle is a no-op, so there is nothing
  /// to save by asking.
  ///
  /// Failures are swallowed per player: one player that will not stop must not
  /// prevent the one the listener just asked for from starting.
  Future<void> claim(Object owner) async {
    for (final entry in _players.entries.toList()) {
      if (entry.key == owner) continue;
      try {
        await entry.value.stop();
      } catch (_) {
        // Nothing useful to do — carry on and start the new one.
      }
    }
  }

  bool get anyPlaying => _players.values.any((p) => p.isPlaying());

  Future<void> pauseAll() async {
    for (final player in _players.values.toList()) {
      if (!player.isPlaying()) continue;
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  Future<void> stopAll() async {
    for (final player in _players.values.toList()) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }
}
