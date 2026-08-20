/// Home Providers — state detection for the 4 Home screen states
///
/// States (detected automatically, no user input needed):
/// 1. Friday      — If today is Friday, regardless of time
/// 2. Returning   — Last opened 3+ days ago
/// 3. Muhasabah   — After Isha time (approx 9 PM local)
/// 4. Morning Wird — Fajr to Dhuhr (approx 5 AM – 12 PM local)
/// 5. Default     — Everything else (afternoon/early evening)
///
/// Times are approximate — proper prayer time API integration in Phase 5.
/// For now: Fajr ~5AM, Dhuhr ~12PM, Asr ~3PM, Maghrib ~6PM, Isha ~9PM
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/vocab_word.dart';
import '../../growth/data/vocab_repository.dart';

// ── Home State Enum ───────────────────────────────────────────
enum HomeState {
  friday,      // Jumu'ah — special question replaces everything
  returning,   // 3+ days away — welcome back, no guilt
  muhasabah,   // Evening — private 3-question reckoning
  wird,        // Morning — daily dhikr + vocab review
  defaultState // Afternoon/default
}

// ── Home State Provider ───────────────────────────────────────
final homeStateProvider = FutureProvider<HomeState>((ref) async {
  final now = DateTime.now();

  // 1. Friday always wins — Jumu'ah is sacred
  if (now.weekday == DateTime.friday) {
    return HomeState.friday;
  }

  // 2. Check last opened — returning state if 3+ days
  final prefs = await SharedPreferences.getInstance();
  final lastOpenedStr = prefs.getString('last_opened_at');
  if (lastOpenedStr != null) {
    final lastOpened = DateTime.tryParse(lastOpenedStr);
    if (lastOpened != null) {
      final daysSince = now.difference(lastOpened).inDays;
      if (daysSince >= 3) {
        // Record this open before returning
        await prefs.setString('last_opened_at', now.toIso8601String());
        return HomeState.returning;
      }
    }
  }

  // Record this open
  await prefs.setString('last_opened_at', now.toIso8601String());

  // 3. Time-based states (approximate prayer times)
  final hour = now.hour;

  // Isha time ~ 9 PM to midnight
  if (hour >= 21 || hour < 2) {
    return HomeState.muhasabah;
  }

  // Morning Wird: Fajr ~ 5 AM to Dhuhr ~ 12 PM
  if (hour >= 5 && hour < 12) {
    return HomeState.wird;
  }

  return HomeState.defaultState;
});

// ── Last Ayah Provider — for Returning state ──────────────────
final lastAyahProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final surah = prefs.getInt('last_surah');
  final ayah = prefs.getInt('last_ayah');
  final surahName = prefs.getString('last_surah_name') ?? '';
  final translation = prefs.getString('last_ayah_translation') ?? '';
  final arabic = prefs.getString('last_ayah_arabic') ?? '';

  if (surah == null || ayah == null) return null;

  return {
    'surah': surah,
    'ayah': ayah,
    'surahName': surahName,
    'translation': translation,
    'arabic': arabic,
  };
});

// ── Vocab Review Provider — words due today for Wird ─────────
final vocabDueProvider = FutureProvider<List<VocabWord>>((ref) async {
  final repo = VocabRepository();
  return repo.getWordsForReview(limit: 3);
});

// ── Muhasabah Done Today Provider ────────────────────────────
final muhasabahDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final lastMuhasabah = prefs.getString('last_muhasabah_date');
  if (lastMuhasabah == null) return false;
  final today = DateTime.now();
  final todayStr = '${today.year}-${today.month}-${today.day}';
  return lastMuhasabah == todayStr;
});

// ── Friday Question Provider ──────────────────────────────────
// One honest question per Friday — rotates weekly
final fridayQuestionProvider = Provider<Map<String, String>>((ref) {
  final questions = [
    {
      'question': 'What is one thing you said this week that you wish you had not?',
      'context': 'The Prophet ﷺ said: "Whoever believes in Allah and the Last Day, let him say something good or remain silent." — Sahih Bukhari',
    },
    {
      'question': 'Did you fulfill a right that someone had over you this week?',
      'context': '"Give the relative his right, and the needy, and the traveler." — Al-Isra 17:26',
    },
    {
      'question': 'What is one act of worship you did this week purely for Allah?',
      'context': '"Verily, the most honored of you in the sight of Allah is the most righteous." — Al-Hujurat 49:13',
    },
    {
      'question': 'Who did you help this week without expecting anything in return?',
      'context': '"And they give food, in spite of their love for it, to the poor, the orphan, and the captive." — Al-Insan 76:8',
    },
    {
      'question': 'What is one thing dunya pulled you toward this week that you wish it hadn\'t?',
      'context': '"Know that the life of this world is but amusement and diversion..." — Al-Hadid 57:20',
    },
    {
      'question': 'How many times did you remember Allah today — truly, not just with your tongue?',
      'context': '"Verily, in the remembrance of Allah do hearts find rest." — Ar-Ra\'d 13:28',
    },
    {
      'question': 'Is there someone you have not forgiven? What is holding you back?',
      'context': '"Let them pardon and overlook. Would you not like that Allah should forgive you?" — An-Nur 24:22',
    },
  ];

  // Rotate weekly — same question all day Friday, changes next Friday
  final weekOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays ~/ 7;
  return questions[weekOfYear % questions.length];
});
