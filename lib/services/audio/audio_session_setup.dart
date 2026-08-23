/// AudioSessionSetup — tells the operating system what kind of audio this is.
///
/// just_audio documents this as a requirement, and it was missing entirely.
/// Without it the platform is left to guess, and the guesses are all wrong for a
/// recitation app:
///
///  • **iOS** defaults to the `soloAmbient` category, which routes to the
///    *ambient* stream, obeys the ringer switch and stops at screen lock. That
///    is why playback could sound thin or vanish; it was never on the playback
///    stream.
///  • **Android** never requests audio focus, so a recitation and whatever else
///    is playing — a podcast, a maps voice, a video — are mixed together by the
///    system with no ducking and no pause. Two mixed streams through one output
///    is heard as distortion, not as two sources.
///
/// Configured once, before the first frame, because both players in the app
/// share the process's single audio session.
///
/// ── Why not AudioSessionConfiguration.speech() ─────────────────────────
/// It was `.speech()`, and two of the four things that preset decides were wrong
/// for recitation. Both are now spelled out in [_recitation] instead of being
/// inherited from a name that sounded right.
///
///   • `androidWillPauseWhenDucked: true` was the reason recitation died a few
///     ayat in. It tells the platform "do not lower my volume for a notification
///     — take my focus away instead", which arrives here as a full
///     [AudioInterruptionType.pause]. One WhatsApp chime was therefore
///     indistinguishable from an incoming phone call, and since nothing
///     auto-resumes from a pause, the recitation was over. It is `false` now: a
///     chime ducks the ayah for its half-second and the recitation carries on
///     underneath it, while a real focus loss still arrives as `pause` and still
///     stops playback.
///
///   • `AndroidAudioContentType.speech` describes text-to-speech and podcasts.
///     Recitation is melodic and is served at 128–192 kbps, and `speech` invites
///     the device's voice post-processing — band-limiting, levelling — onto a
///     signal that has real high-frequency content in it. `music` is simply the
///     more honest description of the bytes. Lower confidence than the ducking
///     fix above, and listed second for that reason.
///
/// What is kept from `.speech()`: the `playback` category, which is what gets
/// recitation off iOS's ambient stream so it survives the ringer switch and the
/// lock screen, and `AndroidAudioFocusGainType.gain`, so starting an ayah stops
/// whatever else was playing rather than mixing with it. `spokenAudio` mode is
/// dropped along with the speech content type, for the same reason.
///
/// ── One interruption handler, not two ─────────────────────────────────
/// [attachInterruptionHandling] wires the events every media app owes the user:
/// a phone call pauses playback, unplugging the headphones pauses it too. Both
/// are passed a plain pause callback so this file stays free of any dependency
/// on the players themselves.
///
/// It is the *only* handler, and that had to be made true. `AudioPlayer` defaults
/// to `handleInterruptions: true`, which registers its own listener on these same
/// two streams — so every interruption ran two policies at once, one of which
/// (just_audio's) resumes afterwards and one of which (this one) deliberately
/// does not. They fought over the same player: this handler would stop it and
/// reset the reader's position, then just_audio would call `play()` on the
/// stopped player and nothing would happen. Both players are now constructed
/// with `handleInterruptions: false`, which leaves this file holding the policy
/// alone.
library;

import 'package:audio_session/audio_session.dart';

import '../../core/utils/logger.dart';

class AudioSessionSetup {
  AudioSessionSetup._();

  static const String _tag = 'AudioSession';

  static bool _configured = false;

  /// What the operating system is told this app plays. See the header for why
  /// each field is here rather than taking [AudioSessionConfiguration.speech].
  static const AudioSessionConfiguration _recitation = AudioSessionConfiguration(
    // iOS: the playback stream, so recitation is not silenced by the ringer
    // switch and does not stop at screen lock.
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.media,
    ),
    // Full focus: starting an ayah stops the podcast, rather than the two being
    // mixed into one output — which is what listeners hear as distortion.
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    // Duck for a notification instead of surrendering focus. See the header.
    androidWillPauseWhenDucked: false,
  );

  /// Whether configuration succeeded. Playback is attempted regardless — a
  /// session that will not configure is a degraded experience, not a dead one.
  static bool get isConfigured => _configured;

  /// Called once from `main()`. Never throws: on an unsupported platform, or a
  /// desktop build without the plugin, the app must still start.
  static Future<void> configure() async {
    if (_configured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(_recitation);
      _configured = true;
    } catch (e) {
      AppLogger.error('Audio session not configured', error: e, tag: _tag);
    }
  }

  /// Hooks interruptions and headphone removal to the app's own players.
  ///
  /// [onPause] is the only policy there is: every event handled here is one the
  /// listener will want to resume from — a call, another app taking focus, the
  /// headphones coming out — and none of them is a reason to discard the ayah
  /// they had reached. There was an `onStop` alongside this, wired to the
  /// arbiter's `stopAll`; it reset the reader's position on a headphone unplug,
  /// which is a harsher answer than the question deserved.
  static Future<void> attachInterruptionHandling({
    required void Function() onPause,
    required bool Function() isPlaying,
  }) async {
    try {
      final session = await AudioSession.instance;

      var interrupted = false;

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // A notification chime, a maps prompt. The platform lowers the
              // volume for its duration and raises it again afterwards; the ayah
              // keeps playing underneath. Pausing here — which is what the old
              // `androidWillPauseWhenDucked: true` configuration forced — is how
              // a chime used to end a recitation for good.
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // A real loss of focus: an incoming call, another media app
              // starting. Pause, and deliberately do not resume afterwards —
              // coming out of a phone call into recitation nobody re-started is
              // startling, and the player is one tap away.
              interrupted = isPlaying();
              if (interrupted) onPause();
          }
        } else {
          interrupted = false;
        }
      });

      // Headphones out. Pause rather than stop: both silence the speaker
      // immediately, which is the whole requirement, but pausing keeps the ayah
      // loaded so putting the headphones back in is one tap rather than finding
      // your place again.
      session.becomingNoisyEventStream.listen((_) => onPause());
    } catch (e) {
      AppLogger.error('Interruption handling not attached', error: e, tag: _tag);
    }
  }
}
