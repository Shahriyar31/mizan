/// What this build of Mizan is actually able to do.
///
/// Before the web port there was no platform gate anywhere in `lib/` — one
/// cosmetic `defaultTargetPlatform` check in `mizan_pressable.dart` and nothing
/// else. This file is the convention, so please add to it rather than reaching
/// for `kIsWeb` at a call site.
///
/// ## Why capabilities and not `kIsWeb`
///
/// `if (kIsWeb)` at a call site records *where* the code is running. What every
/// caller actually needs to know is *what it may do*. Those are different
/// questions and they come apart quickly: a desktop build has a filesystem but
/// no `zonedSchedule`; an Android build below API 33 can schedule but cannot ask
/// for notification permission. Naming the capability means the day one of those
/// changes, this file changes and no screen does.
///
/// It also keeps the reason for a gate next to the gate. `if (kIsWeb) return;`
/// three files deep is unreadable a month later — [canCacheAudio] says what is
/// being protected and its comment says which package throws.
///
/// ## The thing to be careful about
///
/// `dart:io` is **not** the boundary, which is worth stating because it is the
/// obvious guess and it is wrong. `dart:io` is a supported library on all three
/// web targets (see `libraries.json` in the Dart SDK), so `import 'dart:io'`
/// compiles for web and `File(path)` / `Directory(path)` constructors are inert
/// and do not throw. Only the *syscalls* throw `UnsupportedError`, and only when
/// reached. So an `import 'dart:io'` audit finds the wrong six files; what
/// matters is which lines perform I/O. Gate the operation, not the import.
library;

import 'package:flutter/foundation.dart';

/// Capability flags for the current build.
///
/// Every member is a `const` on web-vs-not, so the compiler can tree-shake a
/// gated branch out of the build entirely rather than carrying dead code.
abstract final class AppPlatform {
  /// True when the app is running in a browser, native included via WASM.
  ///
  /// Prefer a named capability below. This exists for the two places that
  /// genuinely mean "browser" — the install prompt and the storage-eviction
  /// warning — because those are facts about browsers, not about capabilities.
  static const bool isWeb = kIsWeb;

  /// Whether `dart:io` filesystem *operations* will succeed.
  ///
  /// False on web: `File.exists`, `Directory.list`, `File.rename` and friends
  /// are patched to throw `UnsupportedError` there. Note the constructors do
  /// not throw, so a null check on a `File` object proves nothing — the failure
  /// arrives on first use.
  ///
  /// Also false-adjacent: `path_provider` has no web implementation at all
  /// (`getTemporaryDirectory`, `getApplicationCacheDirectory`), so those throw
  /// `MissingPluginException` rather than `UnsupportedError`. Both are gated by
  /// this one flag because a caller cannot do anything useful with either.
  static const bool hasFileSystem = !kIsWeb;

  /// Whether a daily reminder can actually be scheduled.
  ///
  /// `flutter_local_notifications` *does* have a web implementation, which makes
  /// this the easiest gate in the file to get wrong: `init()`, `cancel()` and
  /// `requestPermission()` all work in a browser, so a smoke test looks fine.
  /// `zonedSchedule()` — the one call a reminder is made of — throws
  /// `UnsupportedError` on web, and there is no polyfill for it: a browser can
  /// only fire a notification while a page or service worker is alive, which is
  /// not what "every morning at Fajr" means.
  ///
  /// Reminders are therefore hidden rather than shown-and-broken. A switch that
  /// throws when touched is worse than a switch that is not there.
  static const bool canScheduleNotifications = !kIsWeb;

  /// Whether recitation audio can be kept for offline listening.
  ///
  /// False on web for two independent reasons, either of which alone would be
  /// enough: `RecitationCache` writes files through `dart:io`, and `just_audio`'s
  /// `LockCachingAudioSource` is itself built on `dart:io` + `path_provider`.
  ///
  /// Audio still *plays* on web — it streams from the network every time. This
  /// flag is about keeping a copy, not about playback, and the distinction is
  /// load-bearing: conflating them silently broke every ayah rather than just
  /// the offline case.
  static const bool canCacheAudio = !kIsWeb;

  /// Whether local data survives independently of the browser's whim.
  ///
  /// On web the databases live in IndexedDB, which Safari will evict under
  /// storage pressure and when a PWA goes unopened for long enough. Reflections,
  /// muhasabah, saved words and unlocked layers are local-only by design, so on
  /// web the export in Settings → "Your data" stops being a convenience and
  /// becomes the only copy that exists.
  ///
  /// Read by the backup screen to promote that message from a footnote to the
  /// thing it leads with.
  static const bool hasDurableStorage = !kIsWeb;

  /// One line naming the build target, for the debug log next to
  /// `BuildConfig.describe()`. Names capabilities, never values.
  static String describe() {
    final on = <String>[
      if (hasFileSystem) 'fs',
      if (canScheduleNotifications) 'reminders',
      if (canCacheAudio) 'audio-cache',
      if (hasDurableStorage) 'durable-storage',
    ];
    return '${isWeb ? 'web' : 'native'} '
        '(${on.isEmpty ? 'no optional capabilities' : on.join(', ')})';
  }
}
