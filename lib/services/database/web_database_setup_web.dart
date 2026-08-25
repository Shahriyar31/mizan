/// The browser branch of [configureDatabaseFactory].
///
/// **Only compiled for web**, selected by the conditional import in
/// `web_database_setup.dart`. Nothing else in `lib/` may import this file: it
/// names a package whose implementation is `dart:js_interop`, so pulling it into
/// a mobile compilation unit breaks the Android and iOS builds.
///
/// ## What this actually gives the app
///
/// `databaseFactoryFfiWeb` runs a real SQLite — the genuine C library compiled to
/// WebAssembly — inside a web worker, and persists its pages to IndexedDB. So the
/// app's schema, its migrations and every query in `DatabaseService` and
/// `DiscoverDatabase` run unchanged. This is the reason the web port did not need
/// a second storage layer: it is the same SQLite, on a different disk.
///
/// Two consequences that are not obvious and do matter:
///
///  - **It needs two files served next to `index.html`.** `sqlite3.wasm` and
///    `sqflite_sw.js` are not part of the Dart bundle; they are fetched at
///    runtime. `dart run sqflite_common_ffi_web:setup` downloads them into
///    `web/`. Without them every database call fails at runtime while the build
///    itself succeeds, which is a nasty failure mode — hence the explicit,
///    catchable error below rather than a silent hang.
///  - **IndexedDB is evictable.** Safari discards it under storage pressure and
///    after a PWA sits unopened for long enough. Nothing here can prevent that,
///    which is why `AppPlatform.hasDurableStorage` is false on web and the
///    backup screen leads with the export rather than mentioning it in passing.
library;

// `databaseFactory` — the global setter this whole file exists to assign — is
// NOT exported by sqflite_ffi_web.dart. That package exports only the factories
// themselves (databaseFactoryFfiWeb and friends); the setter lives in
// sqflite_common and reaches us through package:sqflite/sqflite.dart, which is
// already a direct dependency and what all twelve other call sites in lib/ use.
// Importing sqflite here is inert on web: it is plain Dart, and the plugin-backed
// factory inside it is only touched if something reads
// `databaseFactorySqflitePlugin`, which nothing does.
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../core/utils/logger.dart';

const _tag = 'web-db';

/// Point `sqflite` at the WASM/IndexedDB factory, and prove it works.
///
/// Deliberately does **not** swallow its failure. Everywhere else in this app a
/// storage failure degrades to something usable, but there is no degraded mode
/// for "no database at all" — every screen reads from it. A thrown error here
/// surfaces on the loading page in `index.html`, which names the missing setup
/// step; failing quietly would present an empty app that looks like data loss.
Future<void> configureDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;

  // Assigning the factory cannot fail — it is a setter. The thing that can fail
  // is the first attempt to *use* it, because that is when `sqlite3.wasm` and
  // `sqflite_sw.js` are fetched. Left alone, that failure would surface one
  // frame later inside `DatabaseService.instance.database` as an opaque error
  // about opening mizan.db, and the actual cause — a build step that was never
  // run — would be nowhere in the message.
  //
  // So open an in-memory database and close it. It exercises exactly the two
  // fetches in question and touches no real data, and it costs close to nothing:
  // the wasm it warms is the same one the real database would load milliseconds
  // afterwards.
  try {
    final probe = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await probe.close();
  } catch (e) {
    AppLogger.error(
      'WASM SQLite could not start. web/sqlite3.wasm and web/sqflite_sw.js are '
      'fetched at runtime and are not produced by `flutter build web` — run '
      '`dart run sqflite_common_ffi_web:setup` and rebuild.',
      tag: _tag,
      error: e,
    );
    rethrow;
  }

  AppLogger.info(
    'sqflite → WASM SQLite in a web worker, persisted to IndexedDB',
    tag: _tag,
  );
}
