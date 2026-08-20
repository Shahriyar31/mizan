/// Arabic text utilities
/// Helpers for RTL, diacritics, and Arabic string handling
library;

class ArabicUtils {
  ArabicUtils._();

  /// Checks if a string contains Arabic characters
  static bool containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// Returns TextDirection based on content
  static bool isRtl(String text) => containsArabic(text);

  /// Removes tashkeel (diacritics) for search purposes
  static String removeDiacritics(String text) {
    return text.replaceAll(
      RegExp(r'[\u064B-\u065F\u0670]'),
      '',
    );
  }
}
