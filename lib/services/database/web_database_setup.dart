/// Choosing where the app's SQLite databases actually live.
///
/// On Android and iOS `sqflite` registers its own platform factory during plugin
/// registration, so nothing has to be chosen and this file's native branch does
/// nothing at all. In a browser there is no plugin to register: `sqflite` 2.4.3
/// declares `android`, `ios` and `macos` and no web, so the first call to
/// `getDatabasesPath()` throws `MissingPluginException`.
///
/// That was the single hard blocker on the web build, and worth being precise
/// about because the symptom hid the cause. `main()` awaits
/// `DatabaseService.instance.database` before `runApp`, unguarded, so the
/// exception escaped before any widget existed: no error screen, no first frame,
/// just a white page with a console line most people would never open. It looked
/// like a build problem and was a one-line platform problem.
///
/// ## Why a conditional import
///
/// The web implementation lives in `sqflite_common_ffi_web`, whose code is built
/// on `dart:js_interop` and cannot compile for Android or iOS. So it must not be
/// in the native compilation unit at all — a runtime `if (kIsWeb)` is too late,
/// because by then both branches have already had to compile.
///
/// `import 'a.dart' if (dart.library.js_interop) 'b.dart'` is resolved by the
/// compiler per target, which is exactly the right granularity. `dart:io`'s entry
/// in the SDK's `libraries.json` sets `"support_conditional_import": false` for
/// every web target, so `dart.library.js_interop` is reliably true only in a
/// browser build.
///
/// **This is the one file in `lib/` that will not analyze until
/// `flutter pub get` has run**, because the package it names is not yet in the
/// pub cache. That is deliberate containment: one unresolved URI in a leaf file
/// with no logic in it, rather than a package import spread across the two
/// database files. See `docs/PWA.md` for the two commands.
library;

import 'web_database_setup_native.dart'
    if (dart.library.js_interop) 'web_database_setup_web.dart' as impl;

/// Point `sqflite` at a factory that works on this platform.
///
/// Call once, before the first database is opened, and await it. A no-op on
/// Android and iOS.
Future<void> configureDatabaseFactory() => impl.configureDatabaseFactory();
