/// ID + code generators.
///
/// We hand-roll a UUID v4 instead of pulling in the `uuid` package: it keeps
/// dependencies (and offline `flutter pub get`s) minimal, and it's a useful
/// thing to understand. A v4 UUID is just 122 random bits with a few version
/// bits pinned, formatted as 8-4-4-4-12 hex.
///
/// [inviteCode] produces the short, human-friendly code people type to join a
/// Halaqa (ambiguous characters like O/0/I/1 are removed on purpose).
library;

import 'dart:math';

class IdGenerator {
  IdGenerator._();

  static final Random _rng = Random.secure();

  /// RFC-4122 version-4 UUID, e.g. "3f2504e0-4f89-41d3-9a0c-0305e82c3301".
  static String uuid() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }

  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// A short invite code like "K7P2QM" (default length 6). No O/0/I/1.
  static String inviteCode({int length = 6}) {
    return List.generate(
      length,
      (_) => _codeAlphabet[_rng.nextInt(_codeAlphabet.length)],
    ).join();
  }
}
