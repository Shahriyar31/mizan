/// RecitationCache — ayah recitations kept as files on the device.
///
/// This is the fix for the distorted playback, and it is worth being precise
/// about why, because swapping audio providers would not have fixed it.
///
/// Every ayah used to be a cold `setUrl` immediately followed by `play()`. The
/// player therefore started decoding while the first bytes were still arriving,
/// with no buffer ahead of the playhead — so any hiccup on the connection became
/// an audible artefact rather than a pause. It happened most on the 192 kbps
/// reciters, because they need half again as much throughput as the 128 kbps
/// ones, which is exactly the pattern of "some reciters sound worse". And it
/// happened on *every* ayah boundary and *every* repeat, because nothing was
/// kept: listening to one ayah five times for memorisation meant downloading it
/// five times.
///
/// Once an ayah is a local file none of that applies: playback is a disk read,
/// repeats are instant, and the next ayah is already on disk before the current
/// one finishes. The same files make recitation work with no connection at all.
///
/// ── Layout ────────────────────────────────────────────────────────────
///     <appCache>/recitation/<reciterId>/<surah:3><ayah:3>.mp3
///
/// The reciter id comes first so switching reciter cannot collide, and clearing
/// one reciter is a directory delete. The cache directory is used rather than
/// application support on purpose: this is re-downloadable content, so the OS
/// should be free to evict it under storage pressure and it must not be included
/// in an iCloud backup.
///
/// ── Never store a broken file ─────────────────────────────────────────
/// Downloads land on a `.dl` temporary file and are renamed into place only
/// after a 200 with a plausible body length. A truncated write that is renamed
/// anyway is the one failure mode a media cache must not have, because it turns
/// a transient network fault into permanent silence for that ayah.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/logger.dart';

class RecitationCache {
  RecitationCache._();

  static final RecitationCache instance = RecitationCache._();

  static const String _tag = 'RecitationCache';
  static const String _folder = 'recitation';

  /// Below this, the body is not a recitation — it is an error page, an empty
  /// 200, or a truncated response. The shortest ayah in the Qur'an is a couple
  /// of words, which is still several times this at any bitrate.
  static const int _minimumBytes = 2048;

  static const Duration _downloadTimeout = Duration(seconds: 20);

  Directory? _root;

  /// Absolute paths known to exist, so the hot path does not stat the file
  /// system on every ayah tap.
  final Set<String> _present = {};

  /// In-flight downloads keyed by absolute path. A prefetch of the next ayah and
  /// a tap on that same ayah must not download it twice.
  final Map<String, Future<File?>> _inflight = {};

  // ── Paths ───────────────────────────────────────────────────────────

  static String fileName(int surahNumber, int ayahNumber) =>
      '${surahNumber.toString().padLeft(3, '0')}'
      '${ayahNumber.toString().padLeft(3, '0')}.mp3';

  Future<Directory> _rootDirectory() async {
    final held = _root;
    if (held != null) return held;
    final base = await getApplicationCacheDirectory();
    final root = Directory(p.join(base.path, _folder));
    _root = root;
    return root;
  }

  /// Where this ayah lives, whether or not it has been downloaded yet.
  ///
  /// Also used as the cache file handed to just_audio's caching source, so a
  /// streamed first listen and a prefetch write to the same place.
  Future<File> fileFor(String reciterId, int surahNumber, int ayahNumber) async {
    final root = await _rootDirectory();
    final dir = Directory(p.join(root.path, _safe(reciterId)));
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (_) {
        // Creation can fail on a full disk; the caller degrades to streaming.
      }
    }
    return File(p.join(dir.path, fileName(surahNumber, ayahNumber)));
  }

  /// The stored file, or null if this ayah has not been downloaded.
  Future<File?> cached(String reciterId, int surahNumber, int ayahNumber) async {
    final file = await fileFor(reciterId, surahNumber, ayahNumber);
    if (_present.contains(file.path)) return file;
    try {
      if (await file.exists() && await file.length() >= _minimumBytes) {
        _present.add(file.path);
        return file;
      }
    } catch (_) {
      // Unreadable — treat as absent.
    }
    return null;
  }

  // ── Download ────────────────────────────────────────────────────────

  /// Ensures this ayah is on disk and returns the file, or null if it could not
  /// be fetched. Never throws: a failed cache write is a slower app, not an
  /// error the listener should see.
  Future<File?> ensure(
    String reciterId,
    int surahNumber,
    int ayahNumber,
    String url,
  ) async {
    final existing = await cached(reciterId, surahNumber, ayahNumber);
    if (existing != null) return existing;

    final file = await fileFor(reciterId, surahNumber, ayahNumber);
    final running = _inflight[file.path];
    if (running != null) return running;

    final future = _download(file, url).whenComplete(() {
      _inflight.remove(file.path);
    });
    _inflight[file.path] = future;
    return future;
  }

  /// Warms the cache without waiting for it. Called for the *next* ayah while
  /// the current one plays, which is what removes the gap at the boundary.
  void prefetch(
    String reciterId,
    int surahNumber,
    int ayahNumber,
    String url,
  ) {
    // Errors are already swallowed inside ensure(); the ignored future is
    // deliberate — nothing on screen waits for a prefetch.
    ensure(reciterId, surahNumber, ayahNumber, url);
  }

  Future<File?> _download(File file, String url) async {
    final temp = File('${file.path}.dl');
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(_downloadTimeout);
      if (response.statusCode != 200) {
        AppLogger.info(
          'recitation ${response.statusCode} for ${p.basename(file.path)}',
          tag: _tag,
        );
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.length < _minimumBytes) {
        AppLogger.info(
          'recitation body too small (${bytes.length}B) for '
          '${p.basename(file.path)}',
          tag: _tag,
        );
        return null;
      }
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      _present.add(file.path);
      return file;
    } catch (e) {
      // No connection, timeout, full disk. Streaming still works.
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      return null;
    }
  }

  // ── Housekeeping, surfaced in Settings → Audio ───────────────────────

  Future<int> count() async {
    final files = await _files();
    return files.length;
  }

  Future<int> bytes() async {
    var total = 0;
    for (final file in await _files()) {
      try {
        total += await file.length();
      } catch (_) {
        // Vanished mid-walk.
      }
    }
    return total;
  }

  Future<void> clear() async {
    _present.clear();
    try {
      final root = await _rootDirectory();
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {
      // Nothing to do — a cache that will not delete is not a failure state.
    }
  }

  Future<List<File>> _files() async {
    try {
      final root = await _rootDirectory();
      if (!await root.exists()) return const [];
      return root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Reciter ids come from a remote catalogue, so they are not trusted as path
  /// segments. Anything outside this set becomes an underscore.
  static String _safe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
}
