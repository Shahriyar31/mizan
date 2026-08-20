/// Curated Arabic word roots for common Quranic words
///
/// Why local data instead of API:
/// Quran.com API does not provide root letters.
/// Root dictionaries (like Lane's Lexicon) are complex datasets.
/// For Phase 3 we curate the most common Quranic words manually.
/// Phase 4 will integrate a full morphology API (Quranic Arabic Corpus).
///
/// Structure: arabic_word_without_diacritics → WordData
library;

class WordData {
  const WordData({
    required this.root,
    required this.meaning,
    required this.insight,
  });

  final String root; // Three root letters e.g. "س-م-و"
  final String meaning; // Core meaning of the root
  final String insight; // Scholarly insight about this word
}

class WordRootsData {
  WordRootsData._();

  /// Returns word data for a given Arabic word if it exists in our dataset
  static WordData? lookup(String arabicWord) {
    final clean = _removeDiacritics(arabicWord);
    return _roots[clean];
  }

  static String _removeDiacritics(String text) {
    return text
        // Remove all Arabic diacritical marks (harakat) — standard range
        .replaceAll(RegExp(r'[\u064B-\u0653]'), '')
        // Remove tatweel (kashida extension)
        .replaceAll('\u0640', '')
        // Remove superscript alef (appears inside words like ٱلْعَٰلَمِينَ)
        .replaceAll('\u0670', '')
        // Normalize alef wasla (U+0671 → plain alef U+0627)
        .replaceAll('\u0671', '\u0627')
        // Normalize alef with hamza above (U+0623 → plain alef)
        .replaceAll('\u0623', '\u0627')
        // Normalize alef with hamza below (U+0625 → plain alef)
        .replaceAll('\u0625', '\u0627')
        // Normalize alef with madda (U+0622 → plain alef)
        .replaceAll('\u0622', '\u0627')
        // Remove other Quranic annotation marks
        .replaceAll(RegExp(r'[\u06D6-\u06ED]'), '')
        .trim();
  }

  static const Map<String, WordData> _roots = {
    // ── Al-Fatihah ─────────────────────────────────────────────
    'بسم': WordData(
      root: 'س-م-و',
      meaning: 'name, to name, to mark',
      insight: 'The "ba" (بـ) prefix means "by means of" or "with". '
          'Starting with bismillah means: everything I do, I do by '
          'the name and authority of Allah — not by my own power.',
    ),
    'الله': WordData(
      root: 'أ-ل-ه',
      meaning: 'The God, the One worthy of worship',
      insight: 'The only Arabic word with no plural, no feminine, '
          'and no diminutive. It cannot be reduced or multiplied. '
          'Ibn al-Qayyim: "It is the greatest Name of Allah."',
    ),
    'لله': WordData(
      root: 'أ-ل-ه',
      meaning: 'belonging to Allah, for Allah',
      insight: 'The lam (لـ) of ownership. All praise belongs '
          'exclusively to Allah — not partially, not shared. '
          'This is why the surah begins with "al" (the definite '
          'article) — ALL praise, comprehensively.',
    ),
    'الرحمن': WordData(
      root: 'ر-ح-م',
      meaning: 'The Most Gracious, intensely merciful',
      insight: 'Al-Rahmān refers to mercy that encompasses all of '
          'creation — believer and disbeliever alike. It is the mercy '
          'of provision, of rain, of life itself. Vast and immediate.',
    ),
    'الرحيم': WordData(
      root: 'ر-ح-م',
      meaning: 'The Most Merciful, repeatedly merciful',
      insight: 'Al-Rahīm is mercy specifically for believers, '
          'especially on the Day of Judgement. The same root as '
          'Rahmān but a different grammatical form — ongoing, '
          'specifically directed mercy.',
    ),
    'الحمد': WordData(
      root: 'ح-م-د',
      meaning: 'praise that is deserved, earned praise',
      insight: 'Al-hamdu is not just any praise — it is praise given '
          'because the one being praised truly deserves it. Shukr '
          '(شكر) is gratitude for a favor received. Hamd is praise '
          'for who Allah IS, independent of what He gave you.',
    ),
    'رب': WordData(
      root: 'ر-ب-ب',
      meaning: 'Lord, Owner, Sustainer, the One who raises',
      insight: 'Rabb comes from the root meaning to nurture and '
          'raise to completion. It is used for a master who raises '
          'a child, an owner who tends a garden. Allah is the Rabb '
          'who brings everything from nothing to completeness.',
    ),
    // Key variant — Uthmani script for العالمين
    // After full normalization: ال + عالمين (the superscript alef inside
    // makes عٰلمين → عالمين once U+0670 is stripped)
    'العالمين': WordData(
      root: 'ع-ل-م',
      meaning: 'all the worlds, all of creation',
      insight: 'From the same root as \'ilm (knowledge). The worlds '
          'are called \'ālamīn because they are the "signs" (ayāt) '
          'by which Allah is known. Every created thing is evidence '
          'of its Creator.',
    ),
    // Additional variant without alef in عالمين (in case superscript alef was the alef itself)
    'العلمين': WordData(
      root: 'ع-ل-م',
      meaning: 'all the worlds, all of creation',
      insight: 'From the same root as \'ilm (knowledge). The worlds '
          'are called \'ālamīn because they are the "signs" (ayāt) '
          'by which Allah is known. Every created thing is evidence '
          'of its Creator.',
    ),
    'مالك': WordData(
      root: 'م-ل-ك',
      meaning: 'Owner, the one with complete possession',
      insight: 'Mālik (مالك) is the owner who possesses absolutely. '
          'Different from Malik (ملك, King) — though both are '
          'Names of Allah. An owner can do with his property '
          'whatever he wills. The Day of Judgement belongs to '
          'Allah entirely.',
    ),
    'ملك': WordData(
      root: 'م-ل-ك',
      meaning: 'King, the one who commands',
      insight: 'Malik is the sovereign King — the one whose command '
          'is absolute. The Quran uses both Mālik (owner) and Malik '
          '(king) as Names of Allah, covering the full scope of '
          'divine authority.',
    ),
    'يوم': WordData(
      root: 'ي-و-م',
      meaning: 'day, a period of time',
      insight: 'Yawm al-Dīn — the Day of the Deen. Not "judgment" '
          'in the punitive sense but the Day when everything is '
          'weighed and given its due. The day truth becomes '
          'undeniable.',
    ),
    'الدين': WordData(
      root: 'د-ي-ن',
      meaning: 'the way of life, recompense, what is owed',
      insight: 'Al-Dīn carries three meanings simultaneously: '
          '(1) the way of life, (2) recompense and reward, '
          '(3) submission and obedience. The Day of Dīn is the '
          'day of ultimate accountability.',
    ),
    'اياك': WordData(
      root: '',
      meaning: 'You (alone), specifically You',
      insight: 'The word order "iyyāka" (You alone) placed BEFORE '
          'the verb is grammatically emphatic in Arabic — it restricts '
          'worship exclusively to Allah. It cannot be "You and also '
          'someone else." This is the declaration of tawhid inside '
          'the prayer itself.',
    ),
    'نعبد': WordData(
      root: 'ع-ب-د',
      meaning: 'we worship, we serve',
      insight: '\'Abd means slave or servant — complete submission. '
          'The shift from third person (Rabb of the worlds) to '
          'second person (You alone we worship) is deliberate. '
          'Scholars call this iltifāt — a turning toward Allah '
          'directly, mid-sentence.',
    ),
    'نستعين': WordData(
      root: 'ع-و-ن',
      meaning: 'we seek help, we ask for assistance',
      insight: 'The "sta" (استـ) prefix indicates seeking. '
          'We actively seek aid. Worship first, then help — '
          'the order matters. You cannot sincerely ask for '
          'Allah\'s help while worshipping something else.',
    ),
    'اهدنا': WordData(
      root: 'ه-د-ي',
      meaning: 'guide us, show us the way',
      insight: 'Hidāyah has two levels: (1) being shown the path, '
          '(2) being given the ability to walk it. We ask for '
          'both every time we recite this. A Muslim who already '
          'knows Islam still asks for guidance — because staying '
          'on the path requires as much help as finding it.',
    ),
    'الصراط': WordData(
      root: 'ص-ر-ط',
      meaning: 'the road, the straight highway',
      insight: 'Al-Sirāt was the word Romans used for their '
          'engineered roads — straight, wide, clear. Not a path '
          'through wilderness but a built road. Allah\'s way is '
          'not vague — it is clear and documented.',
    ),
    'المستقيم': WordData(
      root: 'ق-و-م',
      meaning: 'the straight, the upright, the established',
      insight: 'Mustaqīm comes from qāma — to stand upright. '
          'The straight path is not just geometrically straight — '
          'it is upright, it stands firm. It does not bend '
          'with circumstance.',
    ),
    'صراط': WordData(
      root: 'ص-ر-ط',
      meaning: 'road, path, way',
      insight: 'Sirāt appears twice in Al-Fatihah — the straight '
          'path of those Allah blessed, contrasted with those '
          'who went astray. The repetition is not redundant; '
          'it clarifies by describing both who is on it and '
          'who diverged from it.',
    ),
    'الذين': WordData(
      root: 'ذ-و-',
      meaning: 'those who, the ones who',
      insight: 'Al-ladhīna — a relative pronoun pointing to a group. '
          'The people of the straight path are defined by being '
          'blessed (an\'amta) — not by their own effort alone '
          'but by Allah\'s grace upon them.',
    ),
    'انعمت': WordData(
      root: 'ن-ع-م',
      meaning: 'You blessed, You bestowed grace',
      insight: 'Na\'ima means to be in a state of ease and blessing. '
          'The ni\'mah (blessing) here is the blessing of being '
          'guided — the greatest of all blessings. The Prophets, '
          'the truthful, the martyrs, and the righteous.',
    ),
    'عليهم': WordData(
      root: '',
      meaning: 'upon them',
      insight: 'The preposition \'alā (upon) with a pronoun. '
          'Guidance descends upon people — it is a gift from '
          'above, not something earned from below.',
    ),
    'المغضوب': WordData(
      root: 'غ-ض-ب',
      meaning: 'those who earned anger',
      insight: 'Al-maghdūb means those upon whom anger has descended. '
          'Classical tafseer identifies these as people who knew '
          'the truth but rejected it knowingly — the sin of '
          'arrogance over the sin of ignorance.',
    ),
    'الضالين': WordData(
      root: 'ض-ل-ل',
      meaning: 'those who went astray, the lost ones',
      insight: 'Al-Dāllīn means those who lost the way through '
          'ignorance or sincere misdirection — not through '
          'deliberate rejection. Classical tafseer contrasts '
          'them with al-maghdūb: one knew and refused, '
          'the other sought and missed.',
    ),

    // ── Al-Ikhlas ───────────────────────────────────────────────
    'قل': WordData(
      root: 'ق-و-ل',
      meaning: 'say, declare, speak',
      insight: 'Every time the Quran says "Qul" (Say), Allah is '
          'instructing the Prophet ﷺ — and by extension every Muslim '
          'who recites — to make a declaration. This is active '
          'testimony, not passive belief.',
    ),
    'هو': WordData(
      root: '',
      meaning: 'He, the pronoun of the transcendent',
      insight: 'Huwa (He) is used for something beyond immediate '
          'perception. Allah is described with the third-person '
          'pronoun because He transcends what human senses can '
          'directly perceive. Yet He is nearer to us than our '
          'own jugular vein.',
    ),
    'احد': WordData(
      root: 'و-ح-د',
      meaning: 'One, uniquely singular, indivisible',
      insight: 'Ahad is stronger than Wāhid (one). Wāhid means '
          'one in number — there could theoretically be a second. '
          'Ahad means uniquely singular — no second is even '
          'conceivable. Allah\'s oneness is not numerical.',
    ),
    'الصمد': WordData(
      root: 'ص-م-د',
      meaning: 'the Self-Sufficient, the one all depend on',
      insight: 'Al-Samad is the master whom everyone turns to '
          'in need, who himself needs nothing. Ibn Abbas: '
          '"The one whose leadership is complete, whose '
          'forbearance is complete, whose knowledge is complete." '
          'Every creature is hollow — Al-Samad is completely solid.',
    ),
    'يلد': WordData(
      root: 'و-ل-د',
      meaning: 'to give birth, to father, to be born from',
      insight: 'Lam yalid — He did not beget. This refutes the '
          'Christian concept of divine sonship and the Arab '
          'concept of the angels as daughters of Allah. '
          'Begetting requires physicality, limitation, need — '
          'none of which apply to Allah.',
    ),
    'يولد': WordData(
      root: 'و-ل-د',
      meaning: 'to be born, to be begotten',
      insight: 'Lam yūlad — He was not born from anything. '
          'He has no origin, no beginning, no parent. '
          'He is Al-Awwal (the First) with nothing before Him.',
    ),
    'كفوا': WordData(
      root: 'ك-ف-أ',
      meaning: 'equal, equivalent, a match',
      insight: 'Kufuwan means an equal or equivalent. The surah '
          'closes by stating: nothing is equal to Allah — '
          'not in His essence, not in His attributes, '
          'not in His actions. Incomparability is the '
          'final word.',
    ),

    // ── Al-Falaq ────────────────────────────────────────────────
    'اعوذ': WordData(
      root: 'ع-و-ذ',
      meaning: 'I seek refuge, I take shelter',
      insight: '\'A\'ūdhu comes from the root meaning to cling to '
          'something for protection — like a child clinging to '
          'a parent. It is active, urgent seeking of shelter. '
          'The Prophet ﷺ said these two surahs are the most '
          'powerful protection ever revealed.',
    ),
    'برب': WordData(
      root: 'ر-ب-ب',
      meaning: 'by the Lord of, in the Lord of',
      insight: 'The ba prefix (بـ) means "by means of" or "with". '
          'Seeking refuge bi-rabb means taking shelter through '
          'the Lordship of Allah — His ownership and authority '
          'over everything that might harm.',
    ),
    'الفلق': WordData(
      root: 'ف-ل-ق',
      meaning: 'the daybreak, the splitting open',
      insight: 'Al-Falaq is the moment of dawn — when darkness '
          'is split open by light. Seeking refuge in the Lord '
          'of the dawn means seeking refuge in the One who '
          'brings light out of absolute darkness. He controls '
          'the boundary between night and day.',
    ),
    'شر': WordData(
      root: 'ش-ر-ر',
      meaning: 'evil, harm, that which is bad',
      insight: 'Sharr is comprehensive evil — harm in all its '
          'forms. The surah asks refuge from the evil of '
          'four specific things: all created things, '
          'the night when it darkens, those who blow on knots, '
          'and the envier.',
    ),
    'ما': WordData(
      root: '',
      meaning: 'what, that which',
      insight: 'Mā is a relative particle meaning "that which" '
          'or "whatever." Mā khalaqa means "whatever He created" '
          '— this is comprehensive. Seeking refuge from the evil '
          'of ALL creation, not just specific things.',
    ),
    'خلق': WordData(
      root: 'خ-ل-ق',
      meaning: 'to create, creation',
      insight: 'Khalaqa means to create from nothing — only Allah '
          'does this. Everything in creation has the potential '
          'for harm because creation is under divine will. '
          'We seek refuge in the Creator from the creation.',
    ),
    'غاسق': WordData(
      root: 'غ-س-ق',
      meaning: 'darkness, that which pours darkness',
      insight: 'Ghāsiq means intensely dark — the darkness that '
          'pours over everything at night. The night is when '
          'predators emerge, when people cannot see, when '
          'evil operates more easily. The word waqab means '
          'it entered and settled in.',
    ),
    'النفاثات': WordData(
      root: 'ن-ف-ث',
      meaning: 'those who blow, those who exhale into',
      insight: 'Al-Naffāthāt are those who blow into knots — '
          'a reference to sihr (magic) practiced in Arabia. '
          'The blowing transfers something from the mouth '
          'into the knot. This is the category of all '
          'forms of harmful spiritual manipulation.',
    ),
    'العقد': WordData(
      root: 'ع-ق-د',
      meaning: 'knots, contracts, ties',
      insight: '\'Uqad are knots — both literally (used in sihr) '
          'and metaphorically (all things that bind and trap). '
          'The surah asks protection from all forms of '
          'manipulation that create invisible bonds.',
    ),
    'حاسد': WordData(
      root: 'ح-س-د',
      meaning: 'envier, one who feels hasad',
      insight: 'Hasad is wanting someone\'s blessing to be '
          'removed from them. It is more destructive than '
          'ghibtah (longing for the same blessing for yourself). '
          'The Prophet ﷺ confirmed the evil eye is real. '
          'This surah is the prescription.',
    ),

    // ── An-Nas ──────────────────────────────────────────────────
    'الناس': WordData(
      root: 'ن-و-س',
      meaning: 'the people, humanity, human beings',
      insight: 'Al-Nās comes from the root meaning to be visible, '
          'to be social. Human beings are defined by their '
          'visibility to each other — their social nature. '
          'The surah asks protection from evil that targets '
          'precisely this social vulnerability.',
    ),
    'الملك': WordData(
      root: 'م-ل-ك',
      meaning: 'the King, the sovereign',
      insight: 'Three attributes of Allah open An-Nās: '
          'Rabb (Lord — who raised us), Malik (King — who rules us), '
          'Ilāh (God — who is worshipped by us). Complete relationship '
          'between Creator and creation in three words.',
    ),
    'الاله': WordData(
      root: 'أ-ل-ه',
      meaning: 'the God, the One worshipped',
      insight: 'Ilāh is the One to whom worship is directed. '
          'Allah is simultaneously our Rabb (who owns us), '
          'our Malik (who rules us), and our Ilāh '
          '(who alone deserves our worship).',
    ),
    'الوسواس': WordData(
      root: 'و-س-و-س',
      meaning: 'the whisperer, the one who whispers repeatedly',
      insight: 'Waswās is the sound of leaves rustling — subtle, '
          'barely audible, persistent. Shaytan\'s method is not '
          'a shout but a whisper. He repeats the same doubt '
          'quietly until it feels like your own thought.',
    ),
    'الخناس': WordData(
      root: 'خ-ن-س',
      meaning: 'the one who withdraws and returns',
      insight: 'Al-Khannās withdraws when Allah is remembered '
          'and returns when attention lapses. Ibn Abbas: '
          '"He sits on the heart of the son of Adam. When '
          'he remembers Allah, Shaytan withdraws. When he '
          'forgets, Shaytan whispers again."',
    ),
    'الجنة': WordData(
      root: 'ج-ن-ن',
      meaning: 'the jinn, that which is hidden',
      insight: 'Jinn and jannah (paradise) share the root '
          'j-n-n meaning hidden/concealed. Jinn are hidden '
          'beings. The whispering evil comes from both hidden '
          'beings (jinn) and visible beings (humans).',
    ),

    // ── Al-Asr ──────────────────────────────────────────────────
    'العصر': WordData(
      root: 'ع-ص-ر',
      meaning: 'time, the afternoon, the pressing/squeezing',
      insight: 'Al-\'Asr means to press or squeeze — like pressing '
          'grapes. Time presses life out of us. The surah is an '
          'oath by time itself — the very thing that is '
          'destroying us is the witness against us.',
    ),
    'الانسان': WordData(
      root: 'ن-س-ي',
      meaning: 'the human being, the one who forgets',
      insight: 'Al-Insān comes from the root nasiya — to forget. '
          'The human being is defined by forgetfulness. '
          'This is why dhikr (remembrance) is so central — '
          'it counters the defining flaw of our nature.',
    ),
    'لفي': WordData(
      root: '',
      meaning: 'truly in, surely within',
      insight: 'The lam (لـ) before fī is the lam of emphasis — '
          'truly, surely, without doubt. Combined with the '
          'oath by time, this is the strongest possible '
          'assertion: humanity is DEFINITIVELY in loss.',
    ),
    'خسر': WordData(
      root: 'خ-س-ر',
      meaning: 'loss, destruction, to be in deficit',
      insight: 'Khusr is not just loss but being in a state of '
          'continuous loss — like a business bleeding money. '
          'The default state of a human life, according to '
          'this surah, is loss. The exception requires four '
          'things: faith, good deeds, truth, and patience.',
    ),
    'امنوا': WordData(
      root: 'أ-م-ن',
      meaning: 'they believed, those who have faith',
      insight: 'Āmanū is the first exception to universal loss. '
          'Imān (faith) is not just intellectual assent — '
          'it is security and trust. From the same root as '
          'amān (safety) and amīn (trustworthy). '
          'The believer is the one who entrusts themselves '
          'entirely to Allah.',
    ),
    'الصالحات': WordData(
      root: 'ص-ل-ح',
      meaning: 'righteous deeds, things that reform',
      insight: 'Ṣāliḥ means something that is correct, sound, '
          'and beneficial — that which reforms and fixes. '
          'Good deeds are called ṣāliḥāt because they correct '
          'the corruption of the nafs and benefit the community.',
    ),
    'الحق': WordData(
      root: 'ح-ق-ق',
      meaning: 'truth, what is real and established',
      insight: 'Al-Haqq is truth that is established — not just '
          'correct belief but lived reality. Recommending al-haqq '
          'means telling people what is true even when it is '
          'difficult, unpopular, or personally costly.',
    ),
    'الصبر': WordData(
      root: 'ص-ب-ر',
      meaning: 'patience, to bind and restrain',
      insight: 'Sabr literally means to bind or restrain. '
          'It is not passive endurance but active restraint — '
          'holding yourself back from panic, from complaint, '
          'from giving up. The patient one chains his soul '
          'to what Allah wills.',
    ),
    'الصابرين': WordData(
      root: 'ص-ب-ر',
      meaning: 'those who are patient, those who restrain themselves',
      insight: 'Ṣābirīn is the plural of those who practice sabr. '
          'Al-Asr names them because patience is the hardest '
          'of the four qualities — faith is easy to claim, '
          'deeds can be performed in moments, truth can be '
          'spoken once. Patience must be maintained every day.',
    ),
  };
}
