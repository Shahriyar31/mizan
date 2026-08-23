/// The daily ayah rotation.
///
/// ── Why this file exists ──────────────────────────────────────────────
/// This list used to be a `static const _ayahs` — a `List<Map<String, Object>>`
/// — buried inside a private widget in `home_screen.dart`. Two problems with
/// that: the content was untyped (every read was a cast and a guess at the key
/// names), and it was invisible from outside the widget, so rebuilding the Home
/// screen would have quietly deleted it.
///
/// ── Citation Lock ─────────────────────────────────────────────────────
/// Every entry carries its surah name and its ayah number, and those are the
/// citation. `surahNumber`/`ayahNumber` are the same reference in numeric form,
/// present only so "Read in context" can open the right place in the reader —
/// they are not a second claim.
///
/// The `context` line is a one-sentence framing, not tafseer, and it is
/// deliberately non-interpretive. Where an entry does lean on a source, the
/// source is named inside the line itself (see Al-Baqarah 2:201). Nothing may be
/// added to this list without a verified reference.
library;

import '../domain/streak_math.dart' show dayOfYear;

class DailyAyah {
  const DailyAyah({
    required this.arabic,
    required this.translation,
    required this.surahName,
    required this.surahNumber,
    required this.ayahNumber,
    required this.context,
  });

  final String arabic;
  final String translation;

  /// The surah's name as it should be displayed, e.g. `Qaf`.
  final String surahName;

  final int surahNumber;
  final int ayahNumber;

  /// A single framing sentence. Never tafseer.
  final String context;

  /// The display citation, e.g. `Qaf 50:37`.
  String get reference => '$surahName $surahNumber:$ayahNumber';
}

const List<DailyAyah> kDailyAyahs = [
  DailyAyah(
    arabic: 'أَفَلَا يَتَدَبَّرُونَ الْقُرْآنَ',
    translation: 'Will they not then ponder over the Quran?',
    surahName: 'Muhammad',
    surahNumber: 47,
    ayahNumber: 24,
    context: 'The ayah from which this app takes its name.',
  ),
  DailyAyah(
    arabic: 'وَبِالْأَسْحَارِ هُمْ يَسْتَغْفِرُونَ',
    translation:
        'And in the hours before dawn, they would seek forgiveness.',
    surahName: 'Adh-Dhariyat',
    surahNumber: 51,
    ayahNumber: 18,
    context:
        'Of those whom Allah praises — they sought forgiveness at Fajr.',
  ),
  DailyAyah(
    arabic: 'إِنَّ فِي ذَٰلِكَ لَذِكْرَىٰ لِمَن كَانَ لَهُ قَلْبٌ',
    translation: 'Indeed in that is a reminder for whoever has a heart.',
    surahName: 'Qaf',
    surahNumber: 50,
    ayahNumber: 37,
    context: 'The heart that receives. The Quran speaks to those who listen.',
  ),
  DailyAyah(
    arabic: 'وَاذْكُر رَّبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً',
    translation: 'Remember your Lord within yourself in humility and fear.',
    surahName: "Al-A'raf",
    surahNumber: 7,
    ayahNumber: 205,
    context: 'Remembrance that is real — felt inside, not only spoken.',
  ),
  DailyAyah(
    arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ',
    translation: 'Remember Me, and I will remember you.',
    surahName: 'Al-Baqarah',
    surahNumber: 2,
    ayahNumber: 152,
    context: 'The greatest exchange — your remembrance for His.',
  ),
  DailyAyah(
    arabic: 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    translation: 'Indeed, Allah is with the patient.',
    surahName: 'Al-Baqarah',
    surahNumber: 2,
    ayahNumber: 153,
    context: 'Not a promise of ease. A promise of company.',
  ),
  DailyAyah(
    arabic:
        'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
    translation:
        'Our Lord, give us good in this world and good in the Hereafter.',
    surahName: 'Al-Baqarah',
    surahNumber: 2,
    ayahNumber: 201,
    context: "The du'a the Prophet ﷺ made most often — Sahih Bukhari.",
  ),
];

/// The ayah for a given day.
///
/// Rotates on day-of-year so it is stable for the whole day and identical on
/// every device — no persistence needed, and no randomness that could show two
/// different ayat on two screens of the same app.
DailyAyah ayahForToday({DateTime? now}) {
  final d = now ?? DateTime.now();
  return kDailyAyahs[dayOfYear(d) % kDailyAyahs.length];
}
