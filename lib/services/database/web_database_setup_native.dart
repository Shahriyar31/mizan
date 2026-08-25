/// The native branch of [configureDatabaseFactory] — deliberately empty.
///
/// On Android and iOS the `sqflite` plugin registers its own factory during
/// `WidgetsFlutterBinding.ensureInitialized()`, so overriding it here would
/// replace a working platform implementation with a worse one.
///
/// Selected by `web_database_setup.dart`'s conditional import whenever
/// `dart.library.js_interop` is unavailable, which is every non-web target. It
/// imports nothing, so it cannot break a mobile build.
library;

/// No-op. See the library comment.
Future<void> configureDatabaseFactory() async {}
