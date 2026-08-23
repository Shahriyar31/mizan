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
/// share the process's single audio session. [AudioSessionConfiguration.speech]
/// is the right recipe: recitation is continuous human voice, `spokenAudio` mode
/// keeps it off the music-EQ path on iOS, and `androidWillPauseWhenDucked` means
/// a notification pauses the ayah rather than talking over it — which for Qur'an
/// is the respectful behaviour as well as the clearer one.
///
/// [attachInterruptionHandling] wires the events every media app owes the user:
/// a phone call pauses playback, unplugging headphones stops it instead of
/// blasting the speaker. Both are passed a plain stop/pause callback so this file
/// stays free of any dependency on the players themselves.
library;

import 'package:audio_session/audio_session.dart';

import '../../core/utils/logger.dart';

class AudioSessionSetup {
  AudioSessionSetup._();

  static const String _tag = 'AudioSession';

  static bool _configured = false;

  /// Whether configuration succeeded. Playback is attempted regardless — a
  /// session that will not configure is a degraded experience, not a dead one.
  static bool get isConfigured => _configured;

  /// Called once from `main()`. Never throws: on an unsupported platform, or a
  /// desktop build without the plugin, the app must still start.
  static Future<void> configure() async {
    if (_configured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _configured = true;
    } catch (e) {
      AppLogger.error('Audio session not configured', error: e, tag: _tag);
    }
  }

  /// Hooks interruptions and headphone removal to the app's own players.
  ///
  /// [onPause] is for a temporary interruption the listener will want to resume
  /// from — a call, another app taking focus. [onStop] is for the ones where
  /// resuming is wrong: the headphones are out of the ear.
  static Future<void> attachInterruptionHandling({
    required void Function() onPause,
    required void Function() onStop,
    required bool Function() isPlaying,
  }) async {
    try {
      final session = await AudioSession.instance;

      var interrupted = false;

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // The configuration asks Android to pause rather than duck, and
              // ducking is handled by the platform on iOS. Nothing to do.
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              interrupted = isPlaying();
              if (interrupted) onPause();
          }
        } else {
          // Deliberately not auto-resuming. Coming out of a phone call into
          // recitation the listener did not re-start is startling, and the
          // player is one tap away.
          interrupted = false;
        }
      });

      session.becomingNoisyEventStream.listen((_) => onStop());
    } catch (e) {
      AppLogger.error('Interruption handling not attached', error: e, tag: _tag);
    }
  }
}
