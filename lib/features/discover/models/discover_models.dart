// ─────────────────────────────────────────────────────────────────────────────
// discover_models.dart
// Data models for the Discover tab: Prophets, Sahabah, 99 Names
// ─────────────────────────────────────────────────────────────────────────────

// ── Entry types ───────────────────────────────────────────────────────────────

enum DiscoverSection { prophets, sahabah, names, seerah }

/// Persisted as a string in `discover_progress.entry_type`. Every value must
/// have a case in DiscoverDatabase._typeStr and a branch in _progressFromRow,
/// otherwise progress for that section silently lands under the wrong type.
enum EntryType { prophet, sahabi, divineName, seerah }

// ── Layer model (same 5-layer pattern as Quran tab) ──────────────────────────

class DiscoverLayer {
  final int layerNumber; // 1–5
  final String title; // "Who", "The Call", etc.
  final String subtitle; // One-line teaser shown locked
  final String content; // Full rich content (supports newlines)
  final String source; // e.g. "Ibn Kathir, Stories of the Prophets"
  final String? quranRef; // e.g. "Quran 2:30"
  final String? hadithRef; // e.g. "Sahih Bukhari"

  const DiscoverLayer({
    required this.layerNumber,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.source,
    this.quranRef,
    this.hadithRef,
  });

  factory DiscoverLayer.fromJson(Map<String, dynamic> j) => DiscoverLayer(
        layerNumber: j['layer_number'] as int,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        content: j['content'] as String,
        source: j['source'] as String,
        quranRef: j['quran_ref'] as String?,
        hadithRef: j['hadith_ref'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'layer_number': layerNumber,
        'title': title,
        'subtitle': subtitle,
        'content': content,
        'source': source,
        if (quranRef != null) 'quran_ref': quranRef,
        if (hadithRef != null) 'hadith_ref': hadithRef,
      };
}

// ── Quiz question models ──────────────────────────────────────────────────────

enum QuizQuestionType { factual, reflective }

class QuizOption {
  final String id; // "a", "b", "c", "d"
  final String text;

  const QuizOption({required this.id, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> j) =>
      QuizOption(id: j['id'] as String, text: j['text'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

class QuizQuestion {
  final int number; // 1–10
  final QuizQuestionType type;
  final String prompt;
  final List<QuizOption> options;
  final String? correctOptionId; // null for reflective
  final String citation; // Quranic ayah or hadith ref
  final String scholarReflection; // shown after answering
  // For reflective questions: slider value 0–100 (e.g. "How much does this
  // quality define you?") — stored but not graded.
  final String? sliderLabel;

  const QuizQuestion({
    required this.number,
    required this.type,
    required this.prompt,
    required this.options,
    this.correctOptionId,
    required this.citation,
    required this.scholarReflection,
    this.sliderLabel,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        number: j['number'] as int,
        type: j['type'] == 'factual'
            ? QuizQuestionType.factual
            : QuizQuestionType.reflective,
        prompt: j['prompt'] as String,
        options: (j['options'] as List)
            .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        correctOptionId: j['correct_option_id'] as String?,
        citation: j['citation'] as String,
        scholarReflection: j['scholar_reflection'] as String,
        sliderLabel: j['slider_label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'type': type == QuizQuestionType.factual ? 'factual' : 'reflective',
        'prompt': prompt,
        'options': options.map((o) => o.toJson()).toList(),
        if (correctOptionId != null) 'correct_option_id': correctOptionId,
        'citation': citation,
        'scholar_reflection': scholarReflection,
        if (sliderLabel != null) 'slider_label': sliderLabel,
      };
}

// ── Prophet model ─────────────────────────────────────────────────────────────

class ProphetEntry {
  final String id; // "adam", "ibrahim", etc.
  final int sequenceNumber; // 1 = Adam, 2 = Idris, ...
  final String nameArabic; // آدم
  final String nameEnglish; // Adam
  final String nameTranslit; // Ādam
  final String quranicMention; // "Named 25 times in the Quran"
  final String era; // "The First Human" — card badge, unique per prophet
  final String teaser; // One sentence hook shown before unlock
  final List<DiscoverLayer> layers; // Always 5
  final List<QuizQuestion> quiz; // Always 10 (5 factual + 5 reflective)

  /// Browse-section heading, e.g. "The House of Ibrahim". Shared by several
  /// entries, unlike [era] which is unique per entry. Optional so older
  /// content still loads; the UI falls back to [era].
  final String? group;

  const ProphetEntry({
    required this.id,
    required this.sequenceNumber,
    required this.nameArabic,
    required this.nameEnglish,
    required this.nameTranslit,
    required this.quranicMention,
    required this.era,
    required this.teaser,
    required this.layers,
    required this.quiz,
    this.group,
  });

  factory ProphetEntry.fromJson(Map<String, dynamic> j) => ProphetEntry(
        id: j['id'] as String,
        sequenceNumber: j['sequence_number'] as int,
        nameArabic: j['name_arabic'] as String,
        nameEnglish: j['name_english'] as String,
        nameTranslit: j['name_translit'] as String,
        quranicMention: j['quranic_mention'] as String,
        era: j['era'] as String,
        teaser: j['teaser'] as String,
        group: j['group'] as String?,
        layers: (j['layers'] as List)
            .map((l) => DiscoverLayer.fromJson(l as Map<String, dynamic>))
            .toList(),
        quiz: (j['quiz'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

// ── Sahabi model ──────────────────────────────────────────────────────────────

class SahabiEntry {
  final String id; // "abu_bakr", etc.
  final int sequenceNumber;
  final String nameArabic;
  final String nameEnglish;
  final String kunyah; // Abu Bakr, Umm Salamah, etc.
  final String tribe; // Quraysh, Ansar, etc.
  final String era; // "Early Makkan Period"
  final String teaser;
  final List<DiscoverLayer> layers;
  final List<QuizQuestion> quiz;

  const SahabiEntry({
    required this.id,
    required this.sequenceNumber,
    required this.nameArabic,
    required this.nameEnglish,
    required this.kunyah,
    required this.tribe,
    required this.era,
    required this.teaser,
    required this.layers,
    required this.quiz,
  });

  factory SahabiEntry.fromJson(Map<String, dynamic> j) => SahabiEntry(
        id: j['id'] as String,
        sequenceNumber: j['sequence_number'] as int,
        nameArabic: j['name_arabic'] as String,
        nameEnglish: j['name_english'] as String,
        kunyah: j['kunyah'] as String,
        tribe: j['tribe'] as String,
        era: j['era'] as String,
        teaser: j['teaser'] as String,
        layers: (j['layers'] as List)
            .map((l) => DiscoverLayer.fromJson(l as Map<String, dynamic>))
            .toList(),
        quiz: (j['quiz'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

// ── 99 Names model ────────────────────────────────────────────────────────────

class DivineName {
  final String id; // "ar_rahman"
  final int number; // 1–99
  final String arabic; // الرَّحْمَٰنُ
  final String translit; // Ar-Rahmān
  final String meaningBrief; // "The Extremely Merciful"
  final List<DiscoverLayer> layers; // 5 layers
  final List<QuizQuestion> quiz;

  const DivineName({
    required this.id,
    required this.number,
    required this.arabic,
    required this.translit,
    required this.meaningBrief,
    required this.layers,
    required this.quiz,
  });

  factory DivineName.fromJson(Map<String, dynamic> j) => DivineName(
        id: j['id'] as String,
        number: j['number'] as int,
        arabic: j['arabic'] as String,
        translit: j['translit'] as String,
        meaningBrief: j['meaning_brief'] as String,
        layers: (j['layers'] as List)
            .map((l) => DiscoverLayer.fromJson(l as Map<String, dynamic>))
            .toList(),
        quiz: (j['quiz'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

// ── Progress model (mirrors SQLite row) ──────────────────────────────────────

class DiscoverProgress {
  final String entryId; // matches ProphetEntry.id / etc.
  final EntryType entryType;
  final int layersUnlocked; // 0–5, increments one per day
  final DateTime? lastLayerUnlockedAt;
  final bool quizPassed;
  final DateTime? quizPassedAt;
  final bool entryCompleted; // all 5 layers done AND quiz passed

  const DiscoverProgress({
    required this.entryId,
    required this.entryType,
    required this.layersUnlocked,
    this.lastLayerUnlockedAt,
    required this.quizPassed,
    this.quizPassedAt,
    required this.entryCompleted,
  });

  DiscoverProgress copyWith({
    int? layersUnlocked,
    DateTime? lastLayerUnlockedAt,
    bool? quizPassed,
    DateTime? quizPassedAt,
    bool? entryCompleted,
  }) =>
      DiscoverProgress(
        entryId: entryId,
        entryType: entryType,
        layersUnlocked: layersUnlocked ?? this.layersUnlocked,
        lastLayerUnlockedAt: lastLayerUnlockedAt ?? this.lastLayerUnlockedAt,
        quizPassed: quizPassed ?? this.quizPassed,
        quizPassedAt: quizPassedAt ?? this.quizPassedAt,
        entryCompleted: entryCompleted ?? this.entryCompleted,
      );

  // Can unlock the next layer today?
  // Dev mode: always true — re-enable day gate before launch
  bool get canUnlockNextLayer => layersUnlocked < 5;

  bool get isFullyReadable => layersUnlocked >= 5;
  bool get quizAvailable => isFullyReadable; // Dev: show quiz when layers unlocked
}

// ── Quiz result model ─────────────────────────────────────────────────────────


// ── Seerah Entry model ────────────────────────────────────────────────────────

class SeerahEntry {
  final String id;
  final int sequenceNumber;
  final String title;
  final String titleArabic;
  final String year;
  final String era;
  final String teaser;
  final List<DiscoverLayer> layers;
  final List<QuizQuestion> quiz;

  /// Browse-section heading, e.g. "The Makkan Years". See [ProphetEntry.group].
  final String? group;

  const SeerahEntry({
    required this.id,
    required this.sequenceNumber,
    required this.title,
    required this.titleArabic,
    required this.year,
    required this.era,
    required this.teaser,
    required this.layers,
    required this.quiz,
    this.group,
  });

  factory SeerahEntry.fromJson(Map<String, dynamic> j) => SeerahEntry(
        id: j['id'] as String,
        sequenceNumber: j['sequence_number'] as int,
        title: j['title'] as String,
        titleArabic: j['title_arabic'] as String,
        year: j['year'] as String,
        era: j['era'] as String,
        teaser: j['teaser'] as String,
        group: j['group'] as String?,
        layers: (j['layers'] as List)
            .map((l) => DiscoverLayer.fromJson(l as Map<String, dynamic>))
            .toList(),
        quiz: (j['quiz'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class SeerahListItem {
  final SeerahEntry entry;
  final DiscoverProgress? progress;

  const SeerahListItem({required this.entry, required this.progress});
}

class QuizResult {
  final String entryId;
  final EntryType entryType;
  final DateTime completedAt;
  final int factualScore; // 0–5
  final Map<int, String> selectedOptions; // questionNumber -> optionId
  final Map<int, double> sliderValues; // questionNumber -> 0.0–1.0
  final bool passed; // factualScore >= 3

  const QuizResult({
    required this.entryId,
    required this.entryType,
    required this.completedAt,
    required this.factualScore,
    required this.selectedOptions,
    required this.sliderValues,
    required this.passed,
  });
}
