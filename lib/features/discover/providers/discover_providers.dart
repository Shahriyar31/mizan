// ─────────────────────────────────────────────────────────────────────────────
// discover_providers.dart
// Riverpod providers for Discover tab.
// Handles content loading, unlock logic, sequential progression.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discover_models.dart';
import '../data/discover_database.dart';
import '../data/discover_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1.  Content providers (load from assets JSON)
// ─────────────────────────────────────────────────────────────────────────────

final prophetsProvider = FutureProvider<List<ProphetEntry>>((ref) async {
  return DiscoverRepository.getProphets();
});

final sahabahProvider = FutureProvider<List<SahabiEntry>>((ref) async {
  return DiscoverRepository.getSahabah();
});

final namesProvider = FutureProvider<List<DivineName>>((ref) async {
  return DiscoverRepository.getNames();
});

// ─────────────────────────────────────────────────────────────────────────────
// 2.  Progress state — per section
// ─────────────────────────────────────────────────────────────────────────────

// Maps entryId -> DiscoverProgress
class DiscoverProgressNotifier
    extends StateNotifier<AsyncValue<Map<String, DiscoverProgress>>> {
  final EntryType entryType;

  DiscoverProgressNotifier(this.entryType)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await DiscoverDatabase.getAllProgress(entryType);
      state = AsyncValue.data({for (final r in rows) r.entryId: r});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  DiscoverProgress? progressFor(String entryId) =>
      state.valueOrNull?[entryId];

  /// Returns whether entry at sequenceNumber is accessible.
  /// Entry 1 is always unlocked. Entry N requires entry N-1 completed.
  bool isEntryUnlocked(String entryId, int sequenceNumber,
      List<String> orderedIds) {
    if (sequenceNumber == 1) return true;
    // Find this entry's position in the ordered list, then get the one before it
    final myIndex = orderedIds.indexOf(entryId);
    if (myIndex <= 0) return true; // first in list or not found
    final predecessorId = orderedIds[myIndex - 1];
    final pred = state.valueOrNull?[predecessorId];
    return pred?.entryCompleted ?? false;
  }

  bool isEntryUnlockedAlways(String entryId) => true;

  /// The reader opened this story. Creates the progress row with its first layer
  /// open — and only its first — then returns it so the caller knows where to
  /// resume.
  Future<DiscoverProgress> start(String entryId) async {
    final row = await DiscoverDatabase.ensureProgress(entryId, entryType);
    _put(row);
    return row;
  }

  /// The reader finished layer [layerIndex] (0-based) of a story with
  /// [layerCount] layers, so the next layer opens.
  ///
  /// This is the completion gate: the key to layer N+1 is finishing layer N, not
  /// waiting a day for it. Safe to call more than once — the write takes the
  /// larger of the two counts, so nothing closes behind a reader who goes back.
  Future<DiscoverProgress> recordLayerRead(
    String entryId, {
    required int layerIndex,
    required int layerCount,
  }) async {
    // `clamp` throws when its lower bound exceeds its upper one, so a
    // `layerCount` of 0 would turn turning a page into an exception. Callers
    // guard against it today; this does not rely on their continuing to.
    final open = layerCount < 1 ? 1 : (layerIndex + 2).clamp(1, layerCount);
    final row = await DiscoverDatabase.openLayersUpTo(entryId, entryType, open);
    _put(row);
    return row;
  }

  void _put(DiscoverProgress row) {
    if (!mounted) return;
    final current = Map<String, DiscoverProgress>.from(state.valueOrNull ?? {});
    current[row.entryId] = row;
    state = AsyncValue.data(current);
  }

  /// Save quiz result, update progress map.
  Future<void> submitQuiz(QuizResult result) async {
    await DiscoverDatabase.saveQuizResult(result);
    // Reload this entry's progress from DB
    final updated =
        await DiscoverDatabase.getProgress(result.entryId, entryType);
    if (updated != null) {
      final current =
          Map<String, DiscoverProgress>.from(state.valueOrNull ?? {});
      current[result.entryId] = updated;
      state = AsyncValue.data(current);
    }
  }

  Future<void> refresh() => _load();
}

// One provider per section so they reload independently
final prophetProgressProvider = StateNotifierProvider<DiscoverProgressNotifier,
    AsyncValue<Map<String, DiscoverProgress>>>(
  (ref) => DiscoverProgressNotifier(EntryType.prophet),
);

final sahabiProgressProvider = StateNotifierProvider<DiscoverProgressNotifier,
    AsyncValue<Map<String, DiscoverProgress>>>(
  (ref) => DiscoverProgressNotifier(EntryType.sahabi),
);

final nameProgressProvider = StateNotifierProvider<DiscoverProgressNotifier,
    AsyncValue<Map<String, DiscoverProgress>>>(
  (ref) => DiscoverProgressNotifier(EntryType.divineName),
);

/// The progress notifier for a given section.
///
/// There is one provider per section so they reload independently, which leaves
/// anything that only knows an [EntryType] — the shared layer reader, Home's
/// thread rail — switching on it inline. This is that switch, written once.
StateNotifierProvider<DiscoverProgressNotifier,
        AsyncValue<Map<String, DiscoverProgress>>>
    discoverProgressProviderFor(EntryType type) => switch (type) {
          EntryType.prophet => prophetProgressProvider,
          EntryType.sahabi => sahabiProgressProvider,
          EntryType.divineName => nameProgressProvider,
          EntryType.seerah => seerahProgressProvider,
        };

// ─────────────────────────────────────────────────────────────────────────────
// 3.  Derived: list of (entry, progress, isUnlocked) for UI
// ─────────────────────────────────────────────────────────────────────────────

class ProphetListItem {
  final ProphetEntry entry;
  final DiscoverProgress? progress;
  final bool isUnlocked;

  const ProphetListItem({
    required this.entry,
    required this.progress,
    required this.isUnlocked,
  });
}

final prophetListProvider = Provider<AsyncValue<List<ProphetListItem>>>((ref) {
  final prophetsAsync = ref.watch(prophetsProvider);
  final progressAsync = ref.watch(prophetProgressProvider);

  return prophetsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (prophets) {
      return progressAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (progressMap) {
          final orderedIds = prophets.map((p) => p.id).toList();
          return AsyncValue.data(prophets.map((prophet) {
            final progress = progressMap[prophet.id];
            final notifier =
                ref.read(prophetProgressProvider.notifier);
            final unlocked = notifier.isEntryUnlocked(
              prophet.id,
              prophet.sequenceNumber,
              orderedIds,
            );
            return ProphetListItem(
              entry: prophet,
              progress: progress,
              isUnlocked: unlocked,
            );
          }).toList());
        },
      );
    },
  );
});

class SahabiListItem {
  final SahabiEntry entry;
  final DiscoverProgress? progress;
  final bool isUnlocked;

  const SahabiListItem({
    required this.entry,
    required this.progress,
    required this.isUnlocked,
  });
}

final sahabiListProvider = Provider<AsyncValue<List<SahabiListItem>>>((ref) {
  final sahabahAsync = ref.watch(sahabahProvider);
  final progressAsync = ref.watch(sahabiProgressProvider);

  return sahabahAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (sahabah) {
      return progressAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (progressMap) {
          final orderedIds = sahabah.map((s) => s.id).toList();
          return AsyncValue.data(sahabah.map((sahabi) {
            final progress = progressMap[sahabi.id];
            final notifier = ref.read(sahabiProgressProvider.notifier);
            final unlocked = notifier.isEntryUnlocked(
              sahabi.id,
              sahabi.sequenceNumber,
              orderedIds,
            );
            return SahabiListItem(
              entry: sahabi,
              progress: progress,
              isUnlocked: unlocked,
            );
          }).toList());
        },
      );
    },
  );
});

class NameListItem {
  final DivineName entry;
  final DiscoverProgress? progress;
  final bool isUnlocked;

  const NameListItem({
    required this.entry,
    required this.progress,
    required this.isUnlocked,
  });
}

final nameListProvider = Provider<AsyncValue<List<NameListItem>>>((ref) {
  final namesAsync = ref.watch(namesProvider);
  final progressAsync = ref.watch(nameProgressProvider);

  return namesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (names) {
      return progressAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (progressMap) {
          return AsyncValue.data(names.map((name) {
            final progress = progressMap[name.id];
            const unlocked = true; // Names are all unlocked — not sequential
            return NameListItem(
              entry: name,
              progress: progress,
              isUnlocked: unlocked,
            );
          }).toList());
        },
      );
    },
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 4.  Quiz state — drives quiz screen
// ─────────────────────────────────────────────────────────────────────────────

class QuizState {
  final List<QuizQuestion> questions;
  final int currentIndex; // 0–9
  final Map<int, String> selectedOptions; // questionNum -> optionId
  final Map<int, double> sliderValues; // questionNum -> 0.0–1.0
  final bool showingResult; // true after factual answer submitted
  final bool isComplete; // all 10 answered
  final int? factualScore; // set when complete

  const QuizState({
    required this.questions,
    this.currentIndex = 0,
    this.selectedOptions = const {},
    this.sliderValues = const {},
    this.showingResult = false,
    this.isComplete = false,
    this.factualScore,
  });

  QuizQuestion get currentQuestion => questions[currentIndex];

  bool get isLastQuestion => currentIndex == questions.length - 1;

  QuizState copyWith({
    int? currentIndex,
    Map<int, String>? selectedOptions,
    Map<int, double>? sliderValues,
    bool? showingResult,
    bool? isComplete,
    int? factualScore,
  }) =>
      QuizState(
        questions: questions,
        currentIndex: currentIndex ?? this.currentIndex,
        selectedOptions: selectedOptions ?? this.selectedOptions,
        sliderValues: sliderValues ?? this.sliderValues,
        showingResult: showingResult ?? this.showingResult,
        isComplete: isComplete ?? this.isComplete,
        factualScore: factualScore ?? this.factualScore,
      );
}

class QuizNotifier extends StateNotifier<QuizState> {
  final String entryId;
  final EntryType entryType;
  final Ref _ref;

  QuizNotifier(this.entryId, this.entryType, List<QuizQuestion> questions,
      this._ref)
      : super(QuizState(questions: questions));

  void selectOption(String optionId) {
    if (state.showingResult) return;
    final qNum = state.currentQuestion.number;
    state = state.copyWith(
      selectedOptions: {...state.selectedOptions, qNum: optionId},
      showingResult: state.currentQuestion.type == QuizQuestionType.factual,
    );
  }

  void setSlider(double value) {
    final qNum = state.currentQuestion.number;
    state = state.copyWith(
      sliderValues: {...state.sliderValues, qNum: value},
    );
  }

  void advance() {
    if (state.isLastQuestion) {
      _finalize();
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      showingResult: false,
    );
  }

  void _finalize() {
    // Tally factual score
    int score = 0;
    for (final q in state.questions) {
      if (q.type == QuizQuestionType.factual) {
        final selected = state.selectedOptions[q.number];
        if (selected == q.correctOptionId) score++;
      }
    }

    final passed = score >= 3; // Pass threshold: 3/5 factual correct

    final result = QuizResult(
      entryId: entryId,
      entryType: entryType,
      completedAt: DateTime.now(),
      factualScore: score,
      selectedOptions: state.selectedOptions,
      sliderValues: state.sliderValues,
      passed: passed,
    );

    // Save to DB via progress notifier
    final notifier = _progressNotifier();
    notifier.submitQuiz(result);

    state = state.copyWith(
      isComplete: true,
      factualScore: score,
    );
  }

  DiscoverProgressNotifier _progressNotifier() {
    switch (entryType) {
      case EntryType.prophet:
        return _ref.read(prophetProgressProvider.notifier);
      case EntryType.sahabi:
        return _ref.read(sahabiProgressProvider.notifier);
      case EntryType.divineName:
        return _ref.read(nameProgressProvider.notifier);
      case EntryType.seerah:
        return _ref.read(seerahProgressProvider.notifier);
    }
  }
}

// Family provider — one quiz instance per entry
final quizProvider = StateNotifierProvider.family<QuizNotifier, QuizState,
    ({String entryId, EntryType entryType, List<QuizQuestion> questions})>(
  (ref, args) => QuizNotifier(
    args.entryId,
    args.entryType,
    args.questions,
    ref,
  ),
);

// ── Seerah Providers ──────────────────────────────────────────────────────────

final seerahProvider = FutureProvider<List<SeerahEntry>>((ref) async {
  return DiscoverRepository.getSeerah();
});

final seerahProgressProvider =
    StateNotifierProvider<DiscoverProgressNotifier,
        AsyncValue<Map<String, DiscoverProgress>>>(
  (ref) => DiscoverProgressNotifier(EntryType.seerah),
);

final seerahListProvider = Provider<AsyncValue<List<SeerahListItem>>>((ref) {
  final seerahAsync = ref.watch(seerahProvider);
  final progressAsync = ref.watch(seerahProgressProvider);

  return seerahAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (entries) {
      return progressAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
        data: (progressMap) {
          return AsyncValue.data(entries.map((entry) {
            final progress = progressMap[entry.id];
            return SeerahListItem(entry: entry, progress: progress);
          }).toList());
        },
      );
    },
  );
});

