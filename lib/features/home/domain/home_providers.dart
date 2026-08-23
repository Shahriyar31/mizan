/// Home Providers — the small reads Home and Growth share.
///
/// ── What used to be here, and why it is gone ──────────────────────────
/// This file used to own `HomeState` and `homeStateProvider`: a five-way switch
/// (Friday / Returning / Muhasabah / Wird / Default) that swapped the entire Home
/// screen depending on the hour and the weekday. The redesigned Home is one
/// composed screen — header, Today's Mizan, Today's Thread, two-up, ayah — so
/// nothing selects a state any more, and the enum had no readers left.
///
/// Deleting it also removed a real bug rather than just dead lines. That provider
/// wrote `last_opened_at` in two places, and `StreakStore` (in
/// `streak_provider.dart`) writes the same key from `main()`. Whichever ran
/// second won, so the streak could silently freeze. `StreakStore` is now the
/// single owner of `last_opened_at` and `streak_count` — do not write either key
/// from anywhere else.
///
/// The Friday question below is kept deliberately: its seven entries are verified
/// Quran and hadith citations, and they will be needed again when Jumu'ah gets a
/// home in the new design. Do not delete them to tidy up.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/vocab_word.dart';
import '../../growth/data/vocab_repository.dart';

// ── Last Ayah Provider — where the reader left off ─────────────
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
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
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
