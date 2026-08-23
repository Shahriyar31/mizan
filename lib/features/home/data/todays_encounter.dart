/// Today's Encounter — a small curated set of real, already-verified
/// Discover entries, picked deterministically by day-of-year.
///
/// Every hook/explanation string below is copied verbatim from the app's
/// own Discover content (assets/data/discover/**), not invented. Each
/// entry's [routePath] opens that entry's real detail screen, where the
/// full sourced content already lives.
library;

import '../domain/streak_math.dart' show dayOfYear;

class Encounter {
  const Encounter({
    required this.hook,
    required this.question,
    required this.subject,
    required this.context,
    required this.reference,
    required this.routePath,
  });

  /// The curiosity hook, e.g. "313 men. 2 horses. 70 camels."
  final String hook;

  /// e.g. "Who were they?"
  final String question;

  /// The subject's display name, e.g. "The Battle of Badr".
  final String subject;

  /// The real teaser copied from the Discover entry.
  final String context;

  /// Short, honest attribution — the entry's own era/category label, not a
  /// fabricated citation.
  final String reference;

  final String routePath;
}

const List<Encounter> kEncounters = [
  Encounter(
    hook: 'A shepherd boy, guarding another man\'s sheep.',
    question: 'Why did the Prophet ﷺ tell the whole ummah to learn from him?',
    subject: 'Abdullah ibn Mas\'ud',
    context:
        "A shepherd boy guarding another man's sheep. The Prophet ﷺ told the ummah to take the Qur'an from him.",
    reference: "The Reciter of the Prophet's ﷺ Household",
    routePath: '/discover/sahabi/abdullah_ibn_masud',
  ),
  Encounter(
    hook: 'The first free man to accept Islam.',
    question: 'What did the Prophet ﷺ call him?',
    subject: 'Abu Bakr',
    context:
        "The first free man to accept Islam. The companion in the cave. The one the Prophet called 'freed from the Fire.'",
    reference: 'First Caliph — Al-Siddiq',
    routePath: '/discover/sahabi/abu_bakr',
  ),
  Encounter(
    hook: 'He was told to keep his Islam secret and go home.',
    question: 'What did he do instead?',
    subject: 'Abu Dharr',
    context:
        'He was told to keep his Islam secret and go home. He walked into the mosque of Quraysh and announced it.',
    reference: 'The Man Who Would Not Keep It Quiet',
    routePath: '/discover/sahabi/abu_dharr',
  ),
  Encounter(
    hook: 'Before he spoke, Allah taught him the names of all things.',
    question: 'What was his first word?',
    subject: 'Adam (عليه السلام)',
    context:
        'Before he was a prophet, he was clay. Before he spoke, Allah taught him the names of all things. His first act of consciousness was a sneeze — and his first word was praise.',
    reference: 'The First Human',
    routePath: '/discover/prophet/adam',
  ),
  Encounter(
    hook: 'The strongest civilisation of their age.',
    question: 'What did a single wind leave standing?',
    subject: 'Hud (عليه السلام) and the People of \'Ad',
    context:
        'They were the strongest civilisation of their age, and they built monuments on every hill. A wind came for eight days and left nothing standing but the message they had refused.',
    reference: "The Prophet of 'Ad",
    routePath: '/discover/prophet/hud',
  ),
  Encounter(
    hook: '313 men. 2 horses. 70 camels.',
    question: 'Against an army of 1,000 — what happened?',
    subject: 'The Battle of Badr',
    context:
        "313 men. 2 horses. 70 camels. Against an army of 1,000. And Allah called it 'The Day of Criterion.'",
    reference: 'The Day of Criterion',
    routePath: '/discover/seerah/battle_badr',
  ),
  Encounter(
    hook: 'A document hung on the wall of the Ka\'bah.',
    question: 'What did it seal two clans into for three years?',
    subject: 'The Boycott',
    context:
        "A document hung on the wall of the Ka'bah sealed two clans into a valley. Three years. Leaves and skins.",
    reference: 'Three Years in the Valley',
    routePath: '/discover/seerah/boycott',
  ),
  Encounter(
    hook: 'الأَعْلَى — "The Most High."',
    question: 'What does it mean to sit with this name?',
    subject: 'Al-A\'la',
    context:
        'One of the 99 Names — Al-A\'la, "The Most High." Explored across its layers: meaning, reflection, and how it shapes how you see everything beneath Him.',
    reference: '99 Names of Allah',
    routePath: '/discover/name/al_aala',
  ),
];

/// Deterministic by day-of-year — same encounter all day, changes daily.
Encounter encounterForToday({DateTime? now}) {
  final date = now ?? DateTime.now();
  return kEncounters[dayOfYear(date) % kEncounters.length];
}

/// 1-based position of today's encounter in [kEncounters] — used only for
/// the small stage number on the Home card ("01", "02", …).
int encounterIndexForToday({DateTime? now}) {
  final date = now ?? DateTime.now();
  return (dayOfYear(date) % kEncounters.length) + 1;
}

/// The seven morning adhkar — the same verified list the full Dhikr screen
/// uses (features/home/presentation/home_screen.dart's `_DhikrList`).
/// Kept here as the single source so Home's "Daily Dua" pick and the full
/// Dhikr list never drift apart.
const List<Map<String, String>> kMorningAdhkar = [
  {
    'arabic': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
    'translit': 'Asbahna wa asbahal mulku lillah',
    'meaning': 'We enter the morning, and all dominion belongs to Allah.',
    'source': 'Abu Dawud',
  },
  {
    'arabic': 'اللَّهُمَّ بِكَ أَصْبَحْنَا',
    'translit': 'Allahumma bika asbahna',
    'meaning': 'O Allah, by Your grace we have entered the morning.',
    'source': 'Abu Dawud',
  },
  {
    'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'translit': 'Subhan Allah wa bihamdihi',
    'meaning': 'Glory be to Allah and all praise is His.',
    'source': 'Sahih Muslim — 100 times in the morning',
  },
  {
    'arabic': 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    'translit': 'La ilaha illallah wahdahu la sharika lah',
    'meaning': 'There is no god but Allah, alone with no partner.',
    'source': 'Sahih Bukhari — 10 times in the morning',
  },
  {
    'arabic': 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
    'translit': 'A\'udhu billahi minash-shaytanir-rajim',
    'meaning': 'I seek refuge in Allah from the accursed Satan.',
    'source': 'Morning Athkar',
  },
  {
    'arabic': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ',
    'translit': 'Bismillahil-ladhi la yadurru ma\'as mihi shay\'',
    'meaning': 'In the name of Allah with whose name nothing can cause harm.',
    'source': 'Abu Dawud, Tirmidhi — 3 times in morning',
  },
  {
    'arabic': 'رَضِيتُ بِاللَّهِ رَبًّا وَبِالْإِسْلَامِ دِينًا',
    'translit': 'Raditu billahi rabban wa bil-islami dinan',
    'meaning': 'I am pleased with Allah as my Lord and Islam as my religion.',
    'source': 'Abu Dawud — 3 times in morning',
  },
];

/// Deterministic by day-of-year — same dua all day, changes daily.
Map<String, String> duaForToday({DateTime? now}) {
  final date = now ?? DateTime.now();
  return kMorningAdhkar[dayOfYear(date) % kMorningAdhkar.length];
}
