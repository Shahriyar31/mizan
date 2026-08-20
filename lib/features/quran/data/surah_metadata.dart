/// Surah Metadata — revelation location and period for all 114 surahs
///
/// Sources: Classical Islamic scholarship consensus
/// Location: Makkah or Madinah (a small number have both — listed as primary)
/// Period: Approximate year of revelation (BH = Before Hijra, AH = After Hijra)
/// Order: Chronological revelation order (separate from Quran order)
///
/// This data is settled Islamic knowledge — not AI-generated.
library;

class SurahMeta {
  final int surahNumber;
  final String location;     // 'Makkah' or 'Madinah'
  final String period;       // e.g. '~610 CE', 'Early Makkah', '2 AH'
  final String theme;        // One-line description of surah's central theme
  final int revelationOrder; // Chronological order of revelation

  const SurahMeta({
    required this.surahNumber,
    required this.location,
    required this.period,
    required this.theme,
    required this.revelationOrder,
  });
}

class SurahMetadata {
  SurahMetadata._();

  static SurahMeta? get(int surahNumber) {
    return _data[surahNumber];
  }

  static const Map<int, SurahMeta> _data = {
    1:   SurahMeta(surahNumber: 1,   location: 'Makkah',  period: '~610 CE',    theme: 'The opening prayer — the essence of the Quran',                  revelationOrder: 5),
    2:   SurahMeta(surahNumber: 2,   location: 'Madinah', period: '1–2 AH',     theme: 'Constitution for the new Muslim community',                      revelationOrder: 87),
    3:   SurahMeta(surahNumber: 3,   location: 'Madinah', period: '3 AH',       theme: 'Lessons from the Battle of Uhud and People of the Book',          revelationOrder: 89),
    4:   SurahMeta(surahNumber: 4,   location: 'Madinah', period: '3–4 AH',     theme: 'Rights of women, orphans, and the vulnerable',                   revelationOrder: 92),
    5:   SurahMeta(surahNumber: 5,   location: 'Madinah', period: '10 AH',      theme: 'Completion of the religion — covenants and lawful food',          revelationOrder: 112),
    6:   SurahMeta(surahNumber: 6,   location: 'Makkah',  period: '~615 CE',    theme: 'Tawhid against Makkan polytheism',                               revelationOrder: 55),
    7:   SurahMeta(surahNumber: 7,   location: 'Makkah',  period: '~615 CE',    theme: 'Stories of past nations and their rejection of prophets',         revelationOrder: 39),
    8:   SurahMeta(surahNumber: 8,   location: 'Madinah', period: '2 AH',       theme: 'Battle of Badr — divine support and war ethics',                 revelationOrder: 88),
    9:   SurahMeta(surahNumber: 9,   location: 'Madinah', period: '9 AH',       theme: 'Disavowal of treaties with polytheists',                         revelationOrder: 113),
    10:  SurahMeta(surahNumber: 10,  location: 'Makkah',  period: '~615 CE',    theme: 'Divine wisdom in the Quran and stories of Yunus',                revelationOrder: 51),
    11:  SurahMeta(surahNumber: 11,  location: 'Makkah',  period: '~615 CE',    theme: 'Patience through the stories of Nuh, Hud, and Salih',            revelationOrder: 52),
    12:  SurahMeta(surahNumber: 12,  location: 'Makkah',  period: '~615 CE',    theme: 'The story of Yusuf — patience, purity, and divine plan',         revelationOrder: 53),
    13:  SurahMeta(surahNumber: 13,  location: 'Madinah', period: '~622 CE',    theme: 'Signs of Allah in creation and hearts at peace with dhikr',      revelationOrder: 96),
    14:  SurahMeta(surahNumber: 14,  location: 'Makkah',  period: '~615 CE',    theme: 'Ibrahim\'s prayer for Makkah and gratitude to Allah',            revelationOrder: 72),
    15:  SurahMeta(surahNumber: 15,  location: 'Makkah',  period: '~615 CE',    theme: 'The seven oft-repeated verses and warnings to mockers',           revelationOrder: 54),
    16:  SurahMeta(surahNumber: 16,  location: 'Makkah',  period: '~615 CE',    theme: 'Signs of Allah\'s blessings — bees, honey, and gratitude',       revelationOrder: 70),
    17:  SurahMeta(surahNumber: 17,  location: 'Makkah',  period: '~621 CE',    theme: 'Isra — the night journey and ethics of the believer',            revelationOrder: 50),
    18:  SurahMeta(surahNumber: 18,  location: 'Makkah',  period: '~615 CE',    theme: 'Trials of faith — the Cave, Khidr, and Dhul-Qarnayn',            revelationOrder: 69),
    19:  SurahMeta(surahNumber: 19,  location: 'Makkah',  period: '~614 CE',    theme: 'Mercy — stories of Maryam, Zakariyya, and Isa',                  revelationOrder: 44),
    20:  SurahMeta(surahNumber: 20,  location: 'Makkah',  period: '~614 CE',    theme: 'The story of Musa and his mission to Pharaoh',                   revelationOrder: 45),
    21:  SurahMeta(surahNumber: 21,  location: 'Makkah',  period: '~615 CE',    theme: 'The prophets — all called to the same truth',                    revelationOrder: 73),
    22:  SurahMeta(surahNumber: 22,  location: 'Madinah', period: '2 AH',       theme: 'Hajj — pilgrimage and the permission to fight',                  revelationOrder: 103),
    23:  SurahMeta(surahNumber: 23,  location: 'Makkah',  period: '~615 CE',    theme: 'Qualities of the successful believer',                           revelationOrder: 74),
    24:  SurahMeta(surahNumber: 24,  location: 'Madinah', period: '5–6 AH',     theme: 'Modesty, slander, and the light of Allah',                       revelationOrder: 102),
    25:  SurahMeta(surahNumber: 25,  location: 'Makkah',  period: '~615 CE',    theme: 'The criterion — distinguishing truth from falsehood',             revelationOrder: 42),
    26:  SurahMeta(surahNumber: 26,  location: 'Makkah',  period: '~615 CE',    theme: 'Stories of nine prophets and the rejection they faced',           revelationOrder: 47),
    27:  SurahMeta(surahNumber: 27,  location: 'Makkah',  period: '~615 CE',    theme: 'Sulayman and the Queen of Saba — wisdom and submission',         revelationOrder: 48),
    28:  SurahMeta(surahNumber: 28,  location: 'Makkah',  period: '~615 CE',    theme: 'The full story of Musa from birth to prophethood',               revelationOrder: 49),
    29:  SurahMeta(surahNumber: 29,  location: 'Makkah',  period: '~615 CE',    theme: 'Trial is the proof of faith — the spider\'s web',                revelationOrder: 85),
    30:  SurahMeta(surahNumber: 30,  location: 'Makkah',  period: '~614 CE',    theme: 'Rome will defeat Persia — Allah\'s promise always comes true',    revelationOrder: 84),
    31:  SurahMeta(surahNumber: 31,  location: 'Makkah',  period: '~615 CE',    theme: 'Luqman\'s wisdom — gratitude, humility, and family',             revelationOrder: 57),
    32:  SurahMeta(surahNumber: 32,  location: 'Makkah',  period: '~615 CE',    theme: 'Creation, certainty in the Quran, and the Last Day',             revelationOrder: 75),
    33:  SurahMeta(surahNumber: 33,  location: 'Madinah', period: '5 AH',       theme: 'Battle of Ahzab — manners in the Prophet\'s household',          revelationOrder: 90),
    34:  SurahMeta(surahNumber: 34,  location: 'Makkah',  period: '~615 CE',    theme: 'Gratitude and the story of Dawud, Sulayman, and Saba',           revelationOrder: 58),
    35:  SurahMeta(surahNumber: 35,  location: 'Makkah',  period: '~615 CE',    theme: 'The Creator — angels, signs in nature, and divine will',         revelationOrder: 43),
    36:  SurahMeta(surahNumber: 36,  location: 'Makkah',  period: '~615 CE',    theme: 'The heart of the Quran — resurrection and divine power',         revelationOrder: 41),
    37:  SurahMeta(surahNumber: 37,  location: 'Makkah',  period: '~615 CE',    theme: 'Angels in ranks and stories of Ibrahim and Yunus',               revelationOrder: 56),
    38:  SurahMeta(surahNumber: 38,  location: 'Makkah',  period: '~615 CE',    theme: 'Dawud, Sulayman, and Ayyub — patience and divine gifts',         revelationOrder: 38),
    39:  SurahMeta(surahNumber: 39,  location: 'Makkah',  period: '~615 CE',    theme: 'Sincere worship — following the best of what was revealed',      revelationOrder: 59),
    40:  SurahMeta(surahNumber: 40,  location: 'Makkah',  period: '~615 CE',    theme: 'The Forgiver — the believer in Pharaoh\'s court',                revelationOrder: 60),
    41:  SurahMeta(surahNumber: 41,  location: 'Makkah',  period: '~615 CE',    theme: 'The Quran as guidance — signs in the universe and in the self',  revelationOrder: 61),
    42:  SurahMeta(surahNumber: 42,  location: 'Makkah',  period: '~615 CE',    theme: 'Consultation — the Quran revealed by divine will',               revelationOrder: 62),
    43:  SurahMeta(surahNumber: 43,  location: 'Makkah',  period: '~615 CE',    theme: 'Ornaments of gold — Ibrahim vs idols, Isa vs excess',            revelationOrder: 63),
    44:  SurahMeta(surahNumber: 44,  location: 'Makkah',  period: '~615 CE',    theme: 'The blessed night — smoke as a sign of the Day of Judgment',     revelationOrder: 64),
    45:  SurahMeta(surahNumber: 45,  location: 'Makkah',  period: '~615 CE',    theme: 'The kneeling — signs of Allah rejected by arrogance',            revelationOrder: 65),
    46:  SurahMeta(surahNumber: 46,  location: 'Makkah',  period: '~615 CE',    theme: 'The wind-curved dunes — Hud\'s people and the Jinn who listened', revelationOrder: 66),
    47:  SurahMeta(surahNumber: 47,  location: 'Madinah', period: '1 AH',       theme: 'Muhammad — war, peace, and the test of true faith',              revelationOrder: 95),
    48:  SurahMeta(surahNumber: 48,  location: 'Madinah', period: '6 AH',       theme: 'Clear victory — Treaty of Hudaybiyyah',                          revelationOrder: 111),
    49:  SurahMeta(surahNumber: 49,  location: 'Madinah', period: '9 AH',       theme: 'Inner rooms — manners with the Prophet and Muslim brotherhood',   revelationOrder: 106),
    50:  SurahMeta(surahNumber: 50,  location: 'Makkah',  period: '~615 CE',    theme: 'Resurrection is certain — closer than your jugular vein',        revelationOrder: 34),
    51:  SurahMeta(surahNumber: 51,  location: 'Makkah',  period: '~615 CE',    theme: 'The winds — divine promises are always fulfilled',               revelationOrder: 67),
    52:  SurahMeta(surahNumber: 52,  location: 'Makkah',  period: '~615 CE',    theme: 'The mountain — torment is coming and cannot be averted',         revelationOrder: 76),
    53:  SurahMeta(surahNumber: 53,  location: 'Makkah',  period: '~614 CE',    theme: 'The star — Miraj and what the Prophet ﷺ truly saw',             revelationOrder: 23),
    54:  SurahMeta(surahNumber: 54,  location: 'Makkah',  period: '~614 CE',    theme: 'The moon split — will you not remember?',                        revelationOrder: 37),
    55:  SurahMeta(surahNumber: 55,  location: 'Madinah', period: '~622 CE',    theme: 'The Most Merciful — which of Allah\'s favors will you deny?',    revelationOrder: 97),
    56:  SurahMeta(surahNumber: 56,  location: 'Makkah',  period: '~615 CE',    theme: 'The inevitable — three groups on the Day of Judgment',           revelationOrder: 46),
    57:  SurahMeta(surahNumber: 57,  location: 'Madinah', period: '8 AH',       theme: 'Iron — spend in the way of Allah before the Day comes',          revelationOrder: 94),
    58:  SurahMeta(surahNumber: 58,  location: 'Madinah', period: '~7 AH',      theme: 'The woman who disputes — zihar and standing for justice',        revelationOrder: 105),
    59:  SurahMeta(surahNumber: 59,  location: 'Madinah', period: '4 AH',       theme: 'The gathering — Banu Nadir and the names of Allah',              revelationOrder: 101),
    60:  SurahMeta(surahNumber: 60,  location: 'Madinah', period: '8 AH',       theme: 'The examined woman — loyalty to Allah over disbelievers',        revelationOrder: 91),
    61:  SurahMeta(surahNumber: 61,  location: 'Madinah', period: '3 AH',       theme: 'The ranks — say what you do and do what you say',                revelationOrder: 98),
    62:  SurahMeta(surahNumber: 62,  location: 'Madinah', period: '~2 AH',      theme: 'Friday — leave trade for the prayer and remember Allah much',    revelationOrder: 110),
    63:  SurahMeta(surahNumber: 63,  location: 'Madinah', period: '4 AH',       theme: 'The hypocrites — their words and their hollow hearts',           revelationOrder: 104),
    64:  SurahMeta(surahNumber: 64,  location: 'Madinah', period: '~1 AH',      theme: 'Mutual loss — the test of wealth and children',                  revelationOrder: 108),
    65:  SurahMeta(surahNumber: 65,  location: 'Madinah', period: '~7 AH',      theme: 'Divorce — rights, waiting periods, and trusting Allah',          revelationOrder: 99),
    66:  SurahMeta(surahNumber: 66,  location: 'Madinah', period: '7 AH',       theme: 'Prohibition — the Prophet\'s household and protecting the family', revelationOrder: 107),
    67:  SurahMeta(surahNumber: 67,  location: 'Makkah',  period: '~615 CE',    theme: 'Sovereignty — death is a test, and the earth holds His provision', revelationOrder: 77),
    68:  SurahMeta(surahNumber: 68,  location: 'Makkah',  period: '~610 CE',    theme: 'The pen — the Prophet ﷺ is not mad; he has the finest character', revelationOrder: 2),
    69:  SurahMeta(surahNumber: 69,  location: 'Makkah',  period: '~615 CE',    theme: 'The reality — what will make you realize what the Hour is?',     revelationOrder: 78),
    70:  SurahMeta(surahNumber: 70,  location: 'Makkah',  period: '~615 CE',    theme: 'The ascending stairways — patience until the Day arrives',        revelationOrder: 79),
    71:  SurahMeta(surahNumber: 71,  location: 'Makkah',  period: '~615 CE',    theme: 'Nuh — 950 years of calling his people',                          revelationOrder: 71),
    72:  SurahMeta(surahNumber: 72,  location: 'Makkah',  period: '~615 CE',    theme: 'The Jinn — they heard the Quran and believed immediately',       revelationOrder: 40),
    73:  SurahMeta(surahNumber: 73,  location: 'Makkah',  period: '~610 CE',    theme: 'The wrapped one — rise in the night and pray with devotion',     revelationOrder: 3),
    74:  SurahMeta(surahNumber: 74,  location: 'Makkah',  period: '~610 CE',    theme: 'The cloaked one — arise and warn',                               revelationOrder: 4),
    75:  SurahMeta(surahNumber: 75,  location: 'Makkah',  period: '~613 CE',    theme: 'The rising — man will testify against himself on that Day',      revelationOrder: 31),
    76:  SurahMeta(surahNumber: 76,  location: 'Madinah', period: '~1 AH',      theme: 'Man — created from a drop, guided or ungrateful',                revelationOrder: 98),
    77:  SurahMeta(surahNumber: 77,  location: 'Makkah',  period: '~615 CE',    theme: 'Those sent forth — woe that Day to those who denied',            revelationOrder: 33),
    78:  SurahMeta(surahNumber: 78,  location: 'Makkah',  period: '~615 CE',    theme: 'The announcement — what are they asking one another about?',     revelationOrder: 80),
    79:  SurahMeta(surahNumber: 79,  location: 'Makkah',  period: '~615 CE',    theme: 'Those who pull out — the angels and the lessons of Musa',        revelationOrder: 81),
    80:  SurahMeta(surahNumber: 80,  location: 'Makkah',  period: '~613 CE',    theme: 'He frowned — a blind man comes and the Prophet turns away',      revelationOrder: 24),
    81:  SurahMeta(surahNumber: 81,  location: 'Makkah',  period: '~613 CE',    theme: 'The folding — when the sun is folded and deeds are revealed',    revelationOrder: 7),
    82:  SurahMeta(surahNumber: 82,  location: 'Makkah',  period: '~613 CE',    theme: 'The splitting — when the sky splits and the records are opened', revelationOrder: 82),
    83:  SurahMeta(surahNumber: 83,  location: 'Makkah',  period: '~615 CE',    theme: 'Those who give less — woe to the cheaters in measure',           revelationOrder: 86),
    84:  SurahMeta(surahNumber: 84,  location: 'Makkah',  period: '~613 CE',    theme: 'The splitting open — the sky will split and obey its Lord',      revelationOrder: 83),
    85:  SurahMeta(surahNumber: 85,  location: 'Makkah',  period: '~614 CE',    theme: 'The great constellations — the people of the trench',            revelationOrder: 27),
    86:  SurahMeta(surahNumber: 86,  location: 'Makkah',  period: '~613 CE',    theme: 'The night visitor — man is created from fluid and will be returned', revelationOrder: 36),
    87:  SurahMeta(surahNumber: 87,  location: 'Makkah',  period: '~613 CE',    theme: 'The Most High — glorify your Lord and purify yourself',          revelationOrder: 8),
    88:  SurahMeta(surahNumber: 88,  location: 'Makkah',  period: '~613 CE',    theme: 'The overwhelming — faces on that Day humiliated or joyful',      revelationOrder: 68),
    89:  SurahMeta(surahNumber: 89,  location: 'Makkah',  period: '~613 CE',    theme: 'The dawn — the soul at peace returns to its Lord',               revelationOrder: 10),
    90:  SurahMeta(surahNumber: 90,  location: 'Makkah',  period: '~613 CE',    theme: 'The city — man is created for struggle',                         revelationOrder: 35),
    91:  SurahMeta(surahNumber: 91,  location: 'Makkah',  period: '~613 CE',    theme: 'The sun — successful is he who purifies his soul',               revelationOrder: 26),
    92:  SurahMeta(surahNumber: 92,  location: 'Makkah',  period: '~613 CE',    theme: 'The night — the generous will find ease, the miser hardship',    revelationOrder: 9),
    93:  SurahMeta(surahNumber: 93,  location: 'Makkah',  period: '~613 CE',    theme: 'The morning light — your Lord has not forsaken you',             revelationOrder: 11),
    94:  SurahMeta(surahNumber: 94,  location: 'Makkah',  period: '~613 CE',    theme: 'The opening up — with every hardship comes ease',                revelationOrder: 12),
    95:  SurahMeta(surahNumber: 95,  location: 'Makkah',  period: '~613 CE',    theme: 'The fig — man created in the best form, then reduced',           revelationOrder: 28),
    96:  SurahMeta(surahNumber: 96,  location: 'Makkah',  period: '610 CE',     theme: 'The clot — the first revelation: Read in the name of your Lord', revelationOrder: 1),
    97:  SurahMeta(surahNumber: 97,  location: 'Makkah',  period: '~613 CE',    theme: 'Power — Laylat al-Qadr, better than a thousand months',          revelationOrder: 25),
    98:  SurahMeta(surahNumber: 98,  location: 'Madinah', period: '~1 AH',      theme: 'Clear evidence — the People of the Book and the upright religion', revelationOrder: 100),
    99:  SurahMeta(surahNumber: 99,  location: 'Madinah', period: '~1 AH',      theme: 'The earthquake — the earth bears witness to every deed',         revelationOrder: 93),
    100: SurahMeta(surahNumber: 100, location: 'Makkah',  period: '~613 CE',    theme: 'The running horses — man is ungrateful to his Lord',             revelationOrder: 14),
    101: SurahMeta(surahNumber: 101, location: 'Makkah',  period: '~613 CE',    theme: 'The striking — deeds on scales, heavy or light',                 revelationOrder: 30),
    102: SurahMeta(surahNumber: 102, location: 'Makkah',  period: '~613 CE',    theme: 'Competition for increase — distraction until the grave',         revelationOrder: 16),
    103: SurahMeta(surahNumber: 103, location: 'Makkah',  period: '~613 CE',    theme: 'Time — all of mankind is in loss, except four qualities',        revelationOrder: 13),
    104: SurahMeta(surahNumber: 104, location: 'Makkah',  period: '~613 CE',    theme: 'The slanderer — wealth hoarded will not help on that Day',       revelationOrder: 32),
    105: SurahMeta(surahNumber: 105, location: 'Makkah',  period: '~613 CE',    theme: 'The elephant — Allah destroyed the army of Abraha',              revelationOrder: 19),
    106: SurahMeta(surahNumber: 106, location: 'Makkah',  period: '~613 CE',    theme: 'Quraysh — their security in trade came from Allah',              revelationOrder: 29),
    107: SurahMeta(surahNumber: 107, location: 'Makkah',  period: '~613 CE',    theme: 'Small kindnesses — one who denies judgment neglects the weak',   revelationOrder: 17),
    108: SurahMeta(surahNumber: 108, location: 'Makkah',  period: '~613 CE',    theme: 'Abundance — We gave you Al-Kawthar, so pray and sacrifice',      revelationOrder: 15),
    109: SurahMeta(surahNumber: 109, location: 'Makkah',  period: '~613 CE',    theme: 'The disbelievers — to you your religion, to me mine',            revelationOrder: 18),
    110: SurahMeta(surahNumber: 110, location: 'Madinah', period: '10 AH',      theme: 'Divine help — when victory comes, glorify and seek forgiveness', revelationOrder: 114),
    111: SurahMeta(surahNumber: 111, location: 'Makkah',  period: '~610 CE',    theme: 'The palm fibre — Abu Lahab and his wife will perish',            revelationOrder: 6),
    112: SurahMeta(surahNumber: 112, location: 'Makkah',  period: '~613 CE',    theme: 'Sincerity — Allah is One, eternal, beyond all comparison',       revelationOrder: 22),
    113: SurahMeta(surahNumber: 113, location: 'Makkah',  period: '~613 CE',    theme: 'The daybreak — seek refuge from the evils of creation',          revelationOrder: 20),
    114: SurahMeta(surahNumber: 114, location: 'Makkah',  period: '~613 CE',    theme: 'Mankind — seek refuge from the whispering devil',               revelationOrder: 21),
  };
}
