/// Loading one clip after another onto a *live* [AudioPlayer] — including in a
/// browser, where the obvious way does not work.
///
/// Both of Mizan's players work the same way: one clip is loaded, played, and
/// then replaced by the next one. On Android that is one line, `setAudioSource`.
/// On web that line is silently ignored and the first clip of the page session
/// plays for ever. This class holds the workaround, once, for both players.
///
/// ## Why `setAudioSource` cannot work twice in a browser
///
/// Two facts, each reasonable alone and lethal together:
///
///   • An [AudioPlayer] keeps **one** root playlist for its whole life
///     (`just_audio-0.10.6/lib/just_audio.dart:119`, built at `:264`), and that
///     playlist is constructed with `super(id: '')` — a hardcoded constant,
///     not the uuid every other audio source is given. `setAudioSource(x)` is
///     `setAudioSources([x])`, which swaps *that* playlist's children, so every
///     load message the platform ever receives carries the id `''`.
///   • `just_audio_web`'s `getAudioSource` caches decoded sources by message id
///     in `_audioSourcePlayers[id]` and returns the cached one whenever an id
///     repeats (`just_audio_web.dart:537-546`). The second load therefore gets
///     back the **first** clip and the new URL is dropped;
///     `ConcatenatingAudioSourcePlayer` takes its children at construction, so
///     nothing later refreshes them either.
///
/// Android and iOS rebuild their source tree from each message instead, which
/// is why only the browser breaks, and why an APK can be fine while the PWA
/// repeats one ayah in every surah.
///
/// ## Why the first attempt at this failed
///
/// Shipped 2026-08-25 as `1ba9807` and wrong: `stop()` before each load, on the
/// reasoning that deactivating the platform player disposes the
/// `Html5AudioPlayer` and so empties that cache. It does do that. It also
/// **destroys the one `<audio>` element the page has**, because the element is a
/// field of the platform player (`just_audio_web.dart:116`) and `release()`
/// strips its `src` (`:523-529`). A fresh element has never been touched by a
/// user gesture, and iOS Safari will not play one that hasn't — so on iPhone and
/// iPad it traded a wrong ayah for silence, and it stayed broken on desktop too.
///
/// ## What works: append and seek, never replace
///
/// The web plugin *does* implement playlist mutation, and those paths reach the
/// cached player rather than being swallowed by it:
///
///   1. [AudioPlayer.addAudioSource] sends `concatenatingInsertAll`, which the
///      plugin applies to the cached `ConcatenatingAudioSourcePlayer` via
///      `insertAll` — and the new child, unlike the playlist, has a fresh uuid,
///      so it really is decoded (`just_audio_web.dart:410-425`).
///   2. [AudioPlayer.seek] with a *different* `index` reaches
///      `Html5AudioPlayer._seek`, which pauses the old child, moves the index
///      and calls `load(position)` on the new one — putting the new URL on the
///      **same** `<audio>` element (`just_audio_web.dart:395-407`).
///
/// So the element created by the first user tap survives the whole session and
/// stays unlocked, which is exactly what iOS requires, and every later clip is
/// a real load. Appending at the end also keeps `onEnded` reporting
/// `completed` rather than auto-advancing, because the clip being played is
/// always the last item in the playlist (`just_audio_web.dart:203-238`) — the
/// app's own completion handler is what decides the next ayah.
///
/// **The playlist grows by one entry per clip and is deliberately never
/// trimmed.** An entry is a URI and a uuid; a long session costs kilobytes and
/// a page reload starts over. Removing the played entries would mean a second
/// platform round-trip during playback, on the one path this class exists to
/// keep working, and re-index arithmetic on both sides of it — a poor trade for
/// a list of strings.
///
/// On native none of this applies and [load] is a plain `setAudioSource`, so the
/// Android build compiles to what it did before — [AppPlatform.isWeb] is a
/// `static const`, so the web branch is not merely skipped but absent.
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../core/platform/app_platform.dart';

/// Loads one clip at a time onto [player], correctly on every platform.
///
/// Holds no state of its own: the clip in play is always the last entry of the
/// player's own playlist, so there is no index here to drift out of step with
/// the one inside the plugin.
class SingleClipLoader {
  SingleClipLoader(this._player);

  final AudioPlayer _player;

  /// Loads [source] onto the player and returns its duration if known.
  ///
  /// Leaves the clip loaded and **not** playing, so the caller decides when to
  /// start; that ordering is what stops the tail of one clip being emitted over
  /// the head of the next.
  ///
  /// The caller must have paused first, and on web that is not politeness.
  /// `just_audio_web`'s `play(PlayRequest)` opens `if (_playing) return;` and
  /// `pause(PauseRequest)` is the only thing that lowers that flag
  /// (`just_audio_web.dart:306-324`). A clip that reaches its end fires
  /// `onEnded` and never goes through `pause()`, so without a pause the flag is
  /// still raised and the next `play()` returns without touching the `<audio>`
  /// element — a playing button with silence behind it.
  Future<Duration?> load(AudioSource source) async {
    if (!AppPlatform.isWeb) {
      return _player.setAudioSource(source);
    }

    // Nothing in the playlist yet: the id cache is empty, so the ordinary path
    // is both correct and necessary — it is what attaches the playlist that
    // every later append mutates.
    if (_player.audioSources.isEmpty) {
      return _player.setAudioSource(source);
    }

    await _player.addAudioSource(source);
    final index = _player.audioSources.length - 1;

    // `AudioPlayer.seek` returns without doing anything while
    // `processingState` is `loading` (`just_audio.dart:1311-1313`), and a
    // dropped seek here is indistinguishable from the bug this class exists to
    // fix — the previous clip would simply keep playing. The append itself puts
    // the player through `loading` (`concatenatingInsertAll` reloads the current
    // item), so this is the normal case, not an edge one.
    await _settled();

    await _player.seek(Duration.zero, index: index);
    return _player.duration;
  }

  /// Stops playback the way the platform wants it stopped, ready for [load].
  ///
  /// Native releases the decoders, which is what `stop()` is for. Web only
  /// pauses: a browser has no decoders to hand back, and `stop()` there disposes
  /// the platform player and with it the `<audio>` element — see the library
  /// comment.
  Future<void> stop() async {
    if (AppPlatform.isWeb) {
      await _player.pause();
      return;
    }
    await _player.stop();
  }

  /// Whether a finished clip can be repeated by rewinding it, or has to be
  /// loaded again.
  ///
  /// False on web, and the reason is not performance. Nothing in the web
  /// plugin's `seek` or `play` transitions the processing state, so a clip
  /// rewound after `onEnded` leaves the platform reporting `completed` for ever
  /// (`just_audio_web.dart:388-407`, `:676-694`). The app's completion handler
  /// would then either re-fire immediately — counting one repeat as many — or,
  /// once the identical event is filtered as a duplicate, never fire again and
  /// hang the recitation. Loading the clip afresh runs `loadUri`, which
  /// transitions `loading` then `ready` even when the URL has not changed
  /// (`:277-303`), so the state machine is honest again.
  static bool get canRewindToRepeat => !AppPlatform.isWeb;

  /// Resolves once the player is out of its `loading` state, or after a few
  /// seconds regardless — a load that never settles is a failure the caller's
  /// own error handling should report, not a reason to hang here for ever.
  Future<void> _settled() async {
    if (_player.processingState != ProcessingState.loading) return;
    await _player.processingStateStream
        .firstWhere((s) => s != ProcessingState.loading)
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => ProcessingState.idle,
        );
  }
}
