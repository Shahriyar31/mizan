/// Layer Content — curated data for the 5-layer tafseer system
///
/// Structure: surahNumber → ayahNumber → LayerData
/// Each LayerData contains content for all 5 layers.
///
/// Phase 3: Al-Fatihah fully curated (7 ayat × 5 layers = 35 entries)
/// Phase 4: RAG pipeline generates content dynamically for all 6236 ayat
///
/// Why local data first:
/// Curating Al-Fatihah manually lets us validate the UX and content
/// quality before building the AI pipeline. We know exactly what
/// good layer content looks like before asking AI to generate it.
library;

class LayerData {
  const LayerData({
    required this.words,
    required this.context,
    required this.scholars,
    required this.isnad,
    required this.tomorrowTeasers,
  });

  // Layer 1 — Words: grammatical and linguistic breakdown
  // This is a summary shown in the Words layer tab header
  // The actual word-by-word comes from the existing word tap system
  final String words;

  // Layer 2 — Context: historical scene of revelation
  final String context;

  // Layer 3 — Scholars: one key insight, one scholar, cited properly
  final ScholarInsight scholars;

  // Layer 4 — Isnad: chain of narration for any hadith in this ayah
  // If no hadith is directly referenced, we use a relevant narration
  final IsnadData isnad;

  // Tomorrow teasers — shown at bottom of each layer
  // Index 0 = shown at end of Words layer (teases Context)
  // Index 1 = shown at end of Context layer (teases Scholars)
  // Index 2 = shown at end of Scholars layer (teases Isnad)
  // Index 3 = shown at end of Isnad layer (teases Reflection)
  final List<String> tomorrowTeasers;
}

class ScholarInsight {
  const ScholarInsight({
    required this.scholarName,
    required this.scholarEra,
    required this.work,
    required this.insight,
    required this.arabicQuote,
  });

  final String scholarName;  // Ibn Kathir
  final String scholarEra;   // 1301–1373 CE
  final String work;         // Tafseer Ibn Kathir
  final String insight;      // The insight in English
  final String arabicQuote;  // Original Arabic if available
}

class IsnadData {
  const IsnadData({
    required this.hadithText,
    required this.narrator,
    required this.collection,
    required this.reference,
    required this.grade,
    required this.chain,
  });

  final String hadithText;   // The hadith in English
  final String narrator;     // The companion who narrated it
  final String collection;   // Sahih Muslim
  final String reference;    // Muslim 395
  final String grade;        // Sahih
  final List<ChainLink> chain; // The narrators in order
}

class ChainLink {
  const ChainLink({
    required this.name,
    required this.arabicName,
    required this.died,
    required this.role,
    required this.bio,
  });

  final String name;        // Umar ibn al-Khattab
  final String arabicName;  // عمر بن الخطاب
  final String died;        // 644 CE / 23 AH
  final String role;        // Companion (Sahabi)
  final String bio;         // Short biography
}

/// Central registry of all curated layer content
class LayerContentData {
  LayerContentData._();

  /// Returns layer data for a specific ayah
  /// Returns null if content is not yet curated for this ayah
  static LayerData? getContent(int surahNumber, int ayahNumber) {
    return _content['$surahNumber:$ayahNumber'];
  }

  static const Map<String, LayerData> _content = {

    // ── Al-Fatihah 1:1 — Bismillah ─────────────────────────────
    '1:1': LayerData(
      words: 'Four words. بِسْمِ (by the name) + ٱللَّهِ (Allah) + '
          'ٱلرَّحْمَٰنِ (the Most Gracious) + ٱلرَّحِيمِ (the Most Merciful). '
          'The ba prefix (بـ) is the ba of seeking help — not just '
          '"in the name" but "seeking assistance through the name."',

      context: 'The Basmala was revealed to the Prophet ﷺ before '
          'nearly every surah — it is the opening of the Quran itself. '
          'The Prophet ﷺ was instructed to begin recitation with it. '
          'Before Islam, Arabs began their writings with "Bismika Allahumma" '
          '(In Your name, O Allah). The Quran refined this into the '
          'complete theological statement: Allah\'s name, then His mercy, '
          'twice — because mercy defines His relationship with creation '
          'more than any other attribute.',

      scholars: ScholarInsight(
        scholarName: 'Ibn al-Qayyim al-Jawziyyah',
        scholarEra: '1292–1350 CE',
        work: 'Madarij al-Salikin',
        insight: 'Ibn al-Qayyim wrote that beginning with Bismillah '
            'means the servant acknowledges that his action has no '
            'power of its own — it only succeeds because it is attached '
            'to the name of Allah. The ba is the ba of istianah '
            '(seeking aid). Every action begun with Bismillah is '
            'surrendered to Allah before it begins.',
        arabicQuote: 'الباء باء الاستعانة والتبرك والمصاحبة',
      ),

      isnad: IsnadData(
        hadithText: 'Every matter of importance that does not begin '
            'with the praise of Allah is cut off from blessing.',
        narrator: 'Abu Hurairah (RA)',
        collection: 'Sunan Ibn Majah',
        reference: 'Ibn Majah 1894',
        grade: 'Hasan',
        chain: [
          ChainLink(
            name: 'Abu Hurairah',
            arabicName: 'أبو هريرة',
            died: '678 CE / 58 AH',
            role: 'Companion (Sahabi)',
            bio: 'Abd al-Rahman ibn Sakhr al-Dawsi. The companion '
                'who narrated the most hadith — over 5,000 narrations. '
                'Embraced Islam in 7 AH and remained close to the '
                'Prophet ﷺ until his death. Known for his extraordinary '
                'memory, which the Prophet ﷺ made du\'a for.',
          ),
          ChainLink(
            name: 'Muhammad ibn Amr',
            arabicName: 'محمد بن عمرو',
            died: '749 CE / 144 AH',
            role: 'Tabi\' (Successor)',
            bio: 'Muhammad ibn Amr ibn Alqama al-Laythi. A Medinan '
                'scholar known for his narrations from Abu Salamah '
                'from Abu Hurairah. Imam Ahmad ibn Hanbal said of '
                'him: "He is fine."',
          ),
        ],
      ),

      tomorrowTeasers: [
        'Tomorrow: Why did Allah choose to reveal Al-Fatihah in Mecca '
            '— and what was the first thing the Prophet ﷺ did after '
            'it was revealed?',
        'Tomorrow: What Ibn Kathir said about the ba in Bismillah '
            'that changed how scholars understood the opening of every surah.',
        'Tomorrow: The hadith about Bismillah that was narrated by '
            'over 200 companions — and the single word in it that '
            'scholars debated for centuries.',
        'Tomorrow: Reflect — what do you actually begin with '
            'Bismillah in your life? And what would change if you did?',
      ],
    ),

    // ── Al-Fatihah 1:2 — Alhamdulillah ────────────────────────
    '1:2': LayerData(
      words: 'ٱلْحَمْدُ (the praise) + لِلَّهِ (belongs to Allah) + '
          'رَبِّ (Lord of) + ٱلْعَٰلَمِينَ (all the worlds). '
          'The definite article "al" before hamd means ALL praise — '
          'not some, not most, but every category of praise that '
          'exists belongs to Allah.',

      context: 'Al-Fatihah was revealed twice — once in Mecca early '
          'in the Prophet\'s ﷺ mission, and once in Madinah. It is '
          'the only surah to have this distinction. The scholars say '
          'this is because of its supreme importance — it anchors '
          'every prayer. The phrase Alhamdulillah was one of the '
          'first phrases the Prophet ﷺ taught the companions. '
          'When asked what begins a believer\'s day, he ﷺ said: '
          '"Alhamdulillah in every state."',

      scholars: ScholarInsight(
        scholarName: 'Ibn Kathir',
        scholarEra: '1301–1373 CE',
        work: 'Tafseer al-Quran al-Azeem',
        insight: 'Ibn Kathir writes that Alhamdulillah encompasses '
            'all praise for all of Allah\'s perfections — His '
            'attributes, His actions, His creation, His mercy, '
            'His justice. He notes that the scholars of Arabic '
            'said hamd is better than shukr (gratitude) because '
            'hamd is given freely for who Allah IS, while shukr '
            'is given in return for a favor received.',
        arabicQuote: 'الحمد هو الثناء على المحمود بصفاته من غير سبق إحسان',
      ),

      isnad: IsnadData(
        hadithText: 'Alhamdulillah fills the scales.',
        narrator: 'Abu Malik al-Ash\'ari (RA)',
        collection: 'Sahih Muslim',
        reference: 'Muslim 223',
        grade: 'Sahih',
        chain: [
          ChainLink(
            name: 'Abu Malik al-Ash\'ari',
            arabicName: 'أبو مالك الأشعري',
            died: 'Unknown / early AH',
            role: 'Companion (Sahabi)',
            bio: 'A companion of the Prophet ﷺ from the Ash\'ari tribe '
                'of Yemen. His given name is debated — some say Ka\'b '
                'ibn Asim, others Harith. He narrated several important '
                'hadith about purity and prayer.',
          ),
          ChainLink(
            name: 'Abu Sallam al-Habashi',
            arabicName: 'أبو سلام الحبشي',
            died: '~730 CE / 112 AH',
            role: 'Tabi\' (Successor)',
            bio: 'Mamtur al-Habashi, a freed slave from Ethiopia. '
                'A reliable narrator from Syria, known for his '
                'knowledge of the companions\' sayings. Ibn Hibban '
                'included him among the trustworthy narrators.',
          ),
        ],
      ),

      tomorrowTeasers: [
        'Tomorrow: The historical moment in Makkah when Alhamdulillah '
            'was first spoken publicly — and how the Quraysh responded.',
        'Tomorrow: Ibn Kathir\'s distinction between hamd and shukr '
            'that every Muslim should know before they say Alhamdulillah.',
        'Tomorrow: The hadith where the Prophet ﷺ said Alhamdulillah '
            '"fills the scales" — and what the scholars said this means '
            'for the Day of Judgement.',
        'Tomorrow: When did you last say Alhamdulillah and mean it '
            'fully — not as a habit, but as a genuine acknowledgement '
            'that all praise belongs to Allah?',
      ],
    ),

    // ── Al-Fatihah 1:3 ─────────────────────────────────────────
    '1:3': LayerData(
      words: 'ٱلرَّحْمَٰنِ (the Most Gracious) + ٱلرَّحِيمِ (the Most Merciful). '
          'Same two names as in Bismillah — but placed here after '
          'establishing that all praise belongs to Allah. The repetition '
          'is intentional: mercy is the lens through which Allah\'s '
          'lordship should be understood.',

      context: 'Both names come from the root r-h-m (mercy). '
          'The scholars made a distinction: Al-Rahman is the vast mercy '
          'that covers all of creation without exception — believer '
          'and disbeliever, human and animal, in this world. '
          'Al-Raheem is the specific mercy that Allah reserves for '
          'believers on the Day of Judgement. In the hadith, the '
          'Prophet ﷺ said Allah has 100 mercies — He sent one to '
          'the world, and that one mercy is what all creation shows '
          'to each other. The other 99 are held for the Day of Judgement.',

      scholars: ScholarInsight(
        scholarName: 'Al-Tabari',
        scholarEra: '839–923 CE',
        work: 'Jami\' al-Bayan fi Ta\'wil al-Quran',
        insight: 'Al-Tabari — the earliest major classical tafseer '
            'scholar — writes that Al-Rahman is specific to Allah and '
            'cannot be used for anyone else, while Al-Raheem can be '
            'used for humans (the Prophet ﷺ is called raheem in 9:128). '
            'Allah chose Al-Rahman as a name that belongs to Him alone '
            'because the scale of His mercy has no human equivalent.',
        arabicQuote: 'الرحمن: ذو الرحمة الشاملة لجميع الخلق في الدنيا',
      ),

      isnad: IsnadData(
        hadithText: 'Allah has one hundred mercies, of which He sent '
            'down one between humans, jinn, animals, and insects, '
            'by which they show compassion and mercy to one another. '
            'He has kept ninety-nine mercies for the Day of Resurrection.',
        narrator: 'Abu Hurairah (RA)',
        collection: 'Sahih Muslim',
        reference: 'Muslim 2752',
        grade: 'Sahih',
        chain: [
          ChainLink(
            name: 'Abu Hurairah',
            arabicName: 'أبو هريرة',
            died: '678 CE / 58 AH',
            role: 'Companion (Sahabi)',
            bio: 'The most prolific narrator of hadith. See his '
                'biography in Bismillah (1:1) Isnad layer.',
          ),
          ChainLink(
            name: 'Hammam ibn Munabbih',
            arabicName: 'همام بن منبه',
            died: '719 CE / 101 AH',
            role: 'Tabi\' (Successor)',
            bio: 'A Yemeni scholar and one of the earliest collectors '
                'of hadith. His Sahifah — a written collection of '
                'hadith from Abu Hurairah — is considered one of the '
                'oldest surviving hadith documents.',
          ),
        ],
      ),

      tomorrowTeasers: [
        'Tomorrow: Why the same two names appear twice in Al-Fatihah '
            '— and what the scholars said about the theology behind this repetition.',
        'Tomorrow: Al-Tabari\'s ruling on who is allowed to be called '
            'Al-Rahman — and why this distinction matters for tawhid.',
        'Tomorrow: The hadith about Allah\'s 100 mercies — and the '
            'single narration that made this the most cited hadith '
            'on divine mercy in Islamic history.',
        'Tomorrow: If Allah has held back 99 of His mercies for '
            'the Day of Judgement — what does that tell you about '
            'how to approach that Day?',
      ],
    ),

    // ── Remaining ayat — abbreviated for launch, expand in Phase 4 ──
    '1:4': LayerData(
      words: 'مَٰلِكِ (Owner/Master of) + يَوْمِ (the Day of) + '
          'ٱلدِّينِ (the Deen/Recompense). The word Malik means '
          'the one who owns absolutely — on that Day, nothing belongs '
          'to anyone except by Allah\'s permission.',
      context: 'Yawm al-Din — the Day when every action is weighed '
          'and every soul receives exactly what it earned. The Quran '
          'returns to this Day repeatedly because human beings tend '
          'to live as if there is no accounting. This ayah is placed '
          'immediately after the mercy of Allah — the sequence is '
          'intentional: mercy first, then accountability.',
      scholars: ScholarInsight(
        scholarName: 'Ibn Kathir',
        scholarEra: '1301–1373 CE',
        work: 'Tafseer al-Quran al-Azeem',
        insight: 'Ibn Kathir notes that some reciters read Malik '
            '(King) and others read Maalik (Owner) — both are '
            'authentic readings (qira\'at). He says both are Names '
            'of Allah and both are true: He is the King who commands '
            'and the Owner who possesses absolutely.',
        arabicQuote: 'مالك يوم الدين أي المتصرف فيه بلا منازع',
      ),
      isnad: IsnadData(
        hadithText: 'The people will stand before the Lord of the '
            'worlds until one of them is submerged in his sweat '
            'up to half of his ears.',
        narrator: 'Ibn Umar (RA)',
        collection: 'Sahih al-Bukhari',
        reference: 'Bukhari 4938',
        grade: 'Sahih',
        chain: [
          ChainLink(
            name: 'Abdullah ibn Umar',
            arabicName: 'عبدالله بن عمر',
            died: '693 CE / 73 AH',
            role: 'Companion (Sahabi)',
            bio: 'Son of the second Caliph Umar ibn al-Khattab. '
                'One of the most prolific narrators of hadith — '
                'over 2,600 narrations. Known for his extreme '
                'precision in following the Sunnah in every detail.',
          ),
        ],
      ),
      tomorrowTeasers: [
        'Tomorrow: The historical debate between two authentic Quranic '
            'readings of this ayah — and why both are accepted.',
        'Tomorrow: Ibn Kathir on the difference between Malik (King) '
            'and Maalik (Owner) as Names of Allah.',
        'Tomorrow: The hadith describing the scene of Yawm al-Din — '
            'narrated by a companion who witnessed the Prophet ﷺ weep '
            'while reciting this ayah.',
        'Tomorrow: Knowing that Allah is the Owner of the Day of '
            'Judgement — what in your life would you do differently '
            'if you thought about this every single day?',
      ],
    ),

    '1:5': LayerData(
      words: 'إِيَّاكَ (You alone) + نَعْبُدُ (we worship) + '
          'وَإِيَّاكَ (and You alone) + نَسْتَعِينُ (we ask for help). '
          'The word order in Arabic is significant: iyyaka (You) '
          'before na\'budu (we worship) means the object comes before '
          'the verb — this is emphasis. It is not "we worship You" '
          'but "You — only You — do we worship."',
      context: 'This is the center of Al-Fatihah and the center of '
          'the prayer itself. The surah shifts here from third person '
          '(praising Allah who is described) to second person '
          '(speaking directly to Allah). Scholars call this iltifat — '
          'a turning. The worshipper has been describing Allah, '
          'then suddenly turns and speaks to Him directly. '
          'This is the moment salah becomes conversation.',
      scholars: ScholarInsight(
        scholarName: 'Ibn al-Qayyim al-Jawziyyah',
        scholarEra: '1292–1350 CE',
        work: 'Al-Fawa\'id',
        insight: 'Ibn al-Qayyim wrote that this ayah contains the '
            'secret of the entire religion. Iyyaka na\'budu '
            '(worship alone) removes shirk. Iyyaka nasta\'een '
            '(help from You alone) removes reliance on oneself. '
            'When a Muslim truly internalizes this ayah, he is '
            'freed from two prisons: the prison of worshipping '
            'other than Allah, and the prison of trusting in himself.',
        arabicQuote:
            'إياك نعبد تتضمن التبري من الشرك وإياك نستعين تتضمن التبري من الحول والقوة',
      ),
      isnad: IsnadData(
        hadithText: 'Allah the Mighty says: I have divided the prayer '
            'between Myself and My servant into two halves, and My '
            'servant shall have what he asks for. When the servant '
            'says Iyyaka na\'budu wa iyyaka nasta\'een, Allah says: '
            'This is between Me and My servant, and My servant shall '
            'have what he asked for.',
        narrator: 'Abu Hurairah (RA)',
        collection: 'Sahih Muslim',
        reference: 'Muslim 395',
        grade: 'Sahih',
        chain: [
          ChainLink(
            name: 'Abu Hurairah',
            arabicName: 'أبو هريرة',
            died: '678 CE / 58 AH',
            role: 'Companion (Sahabi)',
            bio: 'The most prolific narrator of hadith. '
                'See his full biography in 1:1 Isnad layer.',
          ),
          ChainLink(
            name: 'Sa\'id ibn al-Musayyib',
            arabicName: 'سعيد بن المسيب',
            died: '715 CE / 94 AH',
            role: 'Tabi\' (Successor)',
            bio: 'The greatest scholar of the Successors generation '
                'in Madinah. His father was a companion. He narrated '
                'from Umar, Uthman, Ali, and Abu Hurairah. Imam '
                'al-Shafi\'i said his mursal narrations are the most '
                'reliable of all the Successors.',
          ),
        ],
      ),
      tomorrowTeasers: [
        'Tomorrow: The grammatical device the Quran uses in this ayah '
            'that has no equivalent in English — and why it changes '
            'the meaning entirely.',
        'Tomorrow: Ibn al-Qayyim on why this single ayah contains '
            'the secret of the entire religion.',
        'Tomorrow: The hadith qudsi where Allah Himself speaks about '
            'what happens when a worshipper recites iyyaka na\'budu — '
            'in real time, during prayer.',
        'Tomorrow: When you say iyyaka na\'budu in salah — are you '
            'speaking the words, or are you actually speaking to Allah? '
            'What would change if it was truly the second?',
      ],
    ),

    '1:6': LayerData(
      words: 'ٱهْدِنَا (guide us) + ٱلصِّرَٰطَ (the path/road) + '
          'ٱلْمُسْتَقِيمَ (the straight/upright). The verb ihdinā '
          'is a du\'a verb — a request, not a statement. Every single '
          'rakah of prayer, the Muslim asks Allah for guidance. '
          'Not past tense ("You guided us") but present imperative '
          '("Guide us — right now, in this moment").',
      context: 'A Muslim who prays five times a day says this du\'a '
          'a minimum of 17 times. Scholars noted the wisdom: guidance '
          'is not a one-time event but a continuous need. '
          'The Prophet ﷺ would say after every salah: '
          '"O Allah, guide me and make my affairs easy." '
          'This ayah is the most-repeated du\'a in human history — '
          'said by over a billion people every single day.',
      scholars: ScholarInsight(
        scholarName: 'Ibn Kathir',
        scholarEra: '1301–1373 CE',
        work: 'Tafseer al-Quran al-Azeem',
        insight: 'Ibn Kathir explains that hidayah (guidance) has '
            'two levels. The first is irshad — being shown the right '
            'path. The second is tawfiq — being given the ability '
            'to walk it. Both are from Allah. This ayah asks for '
            'both simultaneously. A person can know the right path '
            'and still not have the strength to walk it. We need '
            'Allah for both the map and the feet.',
        arabicQuote: 'الهداية نوعان: هداية الإرشاد والبيان، وهداية التوفيق والإلهام',
      ),
      isnad: IsnadData(
        hadithText: 'Say: O Allah, guide me and make my affair easy.',
        narrator: 'Ali ibn Abi Talib (RA)',
        collection: 'Sahih Muslim',
        reference: 'Muslim 771',
        grade: 'Sahih',
        chain: [
          ChainLink(
            name: 'Ali ibn Abi Talib',
            arabicName: 'علي بن أبي طالب',
            died: '661 CE / 40 AH',
            role: 'Companion (Sahabi)',
            bio: 'The cousin and son-in-law of the Prophet ﷺ. '
                'The fourth Caliph of Islam. Among the first to '
                'embrace Islam. Known for his extraordinary knowledge — '
                'the Prophet ﷺ said: "I am the city of knowledge '
                'and Ali is its gate."',
          ),
        ],
      ),
      tomorrowTeasers: [
        'Tomorrow: Why a Muslim who already follows Islam still needs '
            'to ask for guidance 17 times every day — the answer '
            'from the scholars will change how you hear this du\'a.',
        'Tomorrow: Ibn Kathir\'s two levels of guidance — and which '
            'one most Muslims think they\'re asking for, versus '
            'which one they actually need.',
        'Tomorrow: The hadith the Prophet ﷺ taught Ali specifically '
            'about guidance — and the night it was first spoken.',
        'Tomorrow: You say ihdinas-sirat — guide us to the path — '
            'but what would walking that path look like for you '
            'specifically, in your actual life, tomorrow?',
      ],
    ),

    '1:7': LayerData(
      words: 'صِرَٰطَ (path of) + ٱلَّذِينَ (those who) + '
          'أَنْعَمْتَ (You blessed) + عَلَيْهِمْ (upon them) + '
          'غَيْرِ (not) + ٱلْمَغْضُوبِ (those who earned anger) + '
          'عَلَيْهِمْ (upon them) + وَلَا (nor) + ٱلضَّآلِّينَ '
          '(those who went astray). The surah ends by defining '
          'the straight path through contrast — not just what it is, '
          'but what it is not.',
      context: 'The Prophet ﷺ explained in a hadith who al-maghdub '
          '(those who earned anger) and al-dhallin (those who went '
          'astray) refer to. The Quran does not leave this undefined. '
          'The key distinction is between knowing the truth and '
          'rejecting it (earning anger) versus seeking the truth '
          'and missing it (going astray). One is the sin of arrogance, '
          'the other is the condition of those who sincerely erred.',
      scholars: ScholarInsight(
        scholarName: 'Ibn al-Qayyim al-Jawziyyah',
        scholarEra: '1292–1350 CE',
        work: 'Madarij al-Salikin',
        insight: 'Ibn al-Qayyim writes that the distinction between '
            'al-maghdub and al-dallin is one of the most important '
            'in the Quran. He who has knowledge without action earns '
            'anger. He who has action without knowledge goes astray. '
            'The straight path is knowledge with action. Al-Fatihah '
            'thus defines the complete framework of the spiritual life '
            'in its final ayah.',
        arabicQuote: 'من علم ولم يعمل كان من المغضوب عليهم، ومن عمل بلا علم كان من الضالين',
      ),
      isnad: IsnadData(
        hadithText: 'Al-Maghdub alayhim are the Jews and Al-Dallin '
            'are the Christians.',
        narrator: 'Adi ibn Hatim (RA)',
        collection: 'Jami\' al-Tirmidhi',
        reference: 'Tirmidhi 2954',
        grade: 'Sahih',
        chain: [
          ChainLink(
            name: 'Adi ibn Hatim al-Ta\'i',
            arabicName: 'عدي بن حاتم الطائي',
            died: '687 CE / 68 AH',
            role: 'Companion (Sahabi)',
            bio: 'Son of the famous pre-Islamic poet and generous man '
                'Hatim al-Ta\'i. Adi was a Christian who embraced Islam '
                'in 9 AH after a long conversation with the Prophet ﷺ. '
                'His conversion is itself a tafseer of this ayah — '
                'he came as al-dallin and found the straight path.',
          ),
          ChainLink(
            name: 'Simak ibn Harb',
            arabicName: 'سماك بن حرب',
            died: '745 CE / 123 AH',
            role: 'Tabi\' (Successor)',
            bio: 'A Kufan scholar who narrated from many companions. '
                'Al-Tirmidhi and others narrate through him. '
                'Ibn Ma\'in and Ahmad ibn Hanbal considered him '
                'reliable.',
          ),
        ],
      ),
      tomorrowTeasers: [
        'Tomorrow: The Prophet\'s ﷺ own explanation of who al-maghdub '
            'and al-dallin refer to — and why scholars say this does '
            'not limit the meaning to specific groups.',
        'Tomorrow: Ibn al-Qayyim\'s framework of knowledge vs action '
            '— and which side of this distinction most practicing '
            'Muslims fall on without realizing it.',
        'Tomorrow: The companion who narrated this hadith was himself '
            'a former Christian — his story is the living tafseer '
            'of the final ayah of Al-Fatihah.',
        'Tomorrow: Al-Fatihah ends with this ayah — you\'ve completed '
            'the full 5-layer journey through the Opening. Write your '
            'personal reflection: what does Al-Fatihah mean to you now '
            'that it did not mean before?',
      ],
    ),
  };
}
