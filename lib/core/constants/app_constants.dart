/// App-wide business logic constants
library;

class AppConstants {
  AppConstants._();

  // ── Tafseer layer system ──────────────────────────────────────
  static const int totalLayers = 5;
  // Layers unlock Mon=1, Tue=2, Wed=3, Thu=4, Fri=5
  // Saturday and Sunday: all completed layers remain accessible

  // ── Halaqa ────────────────────────────────────────────────────
  static const int maxHalaqaMembers = 8;
  static const int minHalaqaMembers = 2;
  static const int personalNoteMaxLength = 100;
  static const int daysBeforeNudge = 3;

  // ── Vocabulary Bank ───────────────────────────────────────────
  static const int dailyVocabReviewCount = 3;
  // Spaced repetition intervals (days)
  static const List<int> srsIntervals = [1, 3, 7, 14, 30, 90];

  // ── Muhasabah ─────────────────────────────────────────────────
  static const int muhasabahQuestions = 3;

  // ── Returning user ────────────────────────────────────────────
  static const int returningUserDays = 3;
  // If user hasn't opened app in this many days, show returning state

  // ── Wird ──────────────────────────────────────────────────────
  static const int wirdCycleDays = 7;

  // ── Minbar ────────────────────────────────────────────────────
  static const int minbarPageSize = 20;

  // ── Scholar AI ────────────────────────────────────────────────
  static const int aiMaxTokens = 1000;
  static const int aiContextChunks = 5;
}
