/// Structured logging utility
/// Use this everywhere instead of print()
/// In production builds, logs are suppressed automatically
library;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);

  static void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);

  static void warning(String message, {String? tag}) =>
      _log(LogLevel.warning, message, tag: tag);

  static void error(String message, {Object? error, String? tag}) {
    _log(LogLevel.error, message, tag: tag);
    if (error != null) _log(LogLevel.error, error.toString(), tag: tag);
  }

  static void _log(LogLevel level, String message, {String? tag}) {
    if (!kDebugMode) return; // Silent in production

    final prefix = switch (level) {
      LogLevel.debug   => '🔍 DEBUG',
      LogLevel.info    => '✅ INFO ',
      LogLevel.warning => '⚠️  WARN ',
      LogLevel.error   => '❌ ERROR',
    };

    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$prefix $tagStr $message');
  }
}
