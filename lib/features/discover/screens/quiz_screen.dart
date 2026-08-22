// ─────────────────────────────────────────────────────────────────────────────
// quiz_screen.dart
// 10-question quiz: 5 factual MCQ (graded) + 5 reflective (slider + 4 options)
// Factual: shows correct/wrong + citation after answering.
// Reflective: no wrong answer — scholar reflection shown after engagement.
// Pass threshold: 3/5 factual correct.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:taddabur/core/theme/app_colors.dart';
import 'package:taddabur/core/theme/app_typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discover_models.dart';
import '../providers/discover_providers.dart';

class QuizScreen extends ConsumerWidget {
  final String entryId;
  final EntryType entryType;
  final String entryName;
  final List<QuizQuestion> questions;

  const QuizScreen({
    super.key,
    required this.entryId,
    required this.entryType,
    required this.entryName,
    required this.questions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizProvider((
      entryId: entryId,
      entryType: entryType,
      questions: questions,
    )));
    final notifier = ref.read(quizProvider((
      entryId: entryId,
      entryType: entryType,
      questions: questions,
    )).notifier);

    if (quizState.isComplete) {
      return _QuizResultScreen(
        entryName: entryName,
        factualScore: quizState.factualScore!,
        passed: (quizState.factualScore ?? 0) >= 3,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            _QuizHeader(
              entryName: entryName,
              currentIndex: quizState.currentIndex,
              total: quizState.questions.length,
              onClose: () => Navigator.of(context).pop(),
            ),
            _QuizProgressBar(
              current: quizState.currentIndex,
              total: quizState.questions.length,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: _QuestionView(
                  question: quizState.currentQuestion,
                  selectedOptionId:
                      quizState.selectedOptions[quizState.currentQuestion.number],
                  sliderValue:
                      quizState.sliderValues[quizState.currentQuestion.number] ??
                          0.5,
                  showingResult: quizState.showingResult,
                  onSelectOption: notifier.selectOption,
                  onSliderChange: notifier.setSlider,
                  onAdvance: notifier.advance,
                  isLastQuestion: quizState.isLastQuestion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question view — switches between factual and reflective
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionView extends StatelessWidget {
  final QuizQuestion question;
  final String? selectedOptionId;
  final double sliderValue;
  final bool showingResult;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<double> onSliderChange;
  final VoidCallback onAdvance;
  final bool isLastQuestion;

  const _QuestionView({
    required this.question,
    required this.selectedOptionId,
    required this.sliderValue,
    required this.showingResult,
    required this.onSelectOption,
    required this.onSliderChange,
    required this.onAdvance,
    required this.isLastQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: question.type == QuizQuestionType.factual
                ? AppColors.gold.withValues(alpha: 0.15)
                : AppColors.slate,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            question.type == QuizQuestionType.factual
                ? 'Factual — Q${question.number}/5'
                : 'Reflection — Q${question.number - 5}/5',
            style: AppTypography.labelSmall(color: AppColors.gold),
          ),
        ),
        const SizedBox(height: 20),

        // Prompt
        Text(
          question.prompt,
          style: AppTypography.displaySmall(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 24),

        // Options
        ...question.options.map((option) {
          final isSelected = selectedOptionId == option.id;
          final isCorrect = question.correctOptionId == option.id;
          final showCorrect = showingResult && isCorrect;
          final showWrong = showingResult && isSelected && !isCorrect;

          Color borderColor = AppColors.gold.withValues(alpha: 0.2);
          Color bgColor = AppColors.slate;
          Color textColor = AppColors.textPrimary;

          if (showCorrect) {
            borderColor = Colors.green.shade400;
            bgColor = Colors.green.shade900.withValues(alpha: 0.3);
            textColor = Colors.green.shade300;
          } else if (showWrong) {
            borderColor = Colors.red.shade400;
            bgColor = Colors.red.shade900.withValues(alpha: 0.3);
            textColor = Colors.red.shade300;
          } else if (isSelected) {
            borderColor = AppColors.gold;
            bgColor = AppColors.gold.withValues(alpha: 0.1);
          }

          return GestureDetector(
            onTap: showingResult
                ? null
                : () {
                    if (question.type == QuizQuestionType.factual) {
                      HapticFeedback.mediumImpact();
                    } else {
                      HapticFeedback.selectionClick();
                    }
                    onSelectOption(option.id);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  // Option letter
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        option.id.toUpperCase(),
                        style: AppTypography.labelSmall(color: textColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      style: AppTypography.bodyMedium(color: textColor),
                    ),
                  ),
                  if (showCorrect)
                    _PopIn(
                      child: Icon(Icons.check_rounded,
                          color: Colors.green.shade400, size: 18),
                    )
                  else if (showWrong)
                    _PopIn(
                      child: Icon(Icons.close_rounded,
                          color: Colors.red.shade400, size: 18),
                    ),
                ],
              ),
            ),
          );
        }),

        // Reflective: slider
        if (question.type == QuizQuestionType.reflective &&
            question.sliderLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            question.sliderLabel!,
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: AppColors.gold.withValues(alpha: 0.2),
              thumbColor: AppColors.gold,
              overlayColor: AppColors.gold.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: sliderValue,
              onChanged: onSliderChange,
            ),
          ),
        ],

        // After answer: citation + scholar reflection
        if (showingResult || (question.type == QuizQuestionType.reflective && selectedOptionId != null)) ...[
          const SizedBox(height: 20),
          _ScholarReflectionCard(
            citation: question.citation,
            reflection: question.scholarReflection,
            isFactual: question.type == QuizQuestionType.factual,
          ),
          const SizedBox(height: 20),
          _AdvanceButton(
            label: isLastQuestion ? 'See Results' : 'Continue →',
            onTap: onAdvance,
          ),
        ],

        // Reflective: allow advancing without "showingResult" once option picked
        if (question.type == QuizQuestionType.reflective &&
            selectedOptionId == null) ...[
          const SizedBox(height: 8),
          Text(
            'Choose the option closest to your heart.',
            style: AppTypography.quoteItalic(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scholar reflection card
// ─────────────────────────────────────────────────────────────────────────────

class _ScholarReflectionCard extends StatelessWidget {
  final String citation;
  final String reflection;
  final bool isFactual;

  const _ScholarReflectionCard({
    required this.citation,
    required this.reflection,
    required this.isFactual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Citation
          Row(
            children: [
              Icon(
                isFactual ? Icons.menu_book_rounded : Icons.format_quote_rounded,
                size: 14,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Text(
                citation,
                style: AppTypography.labelSmall(color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reflection
          Text(
            reflection,
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result screen
// ─────────────────────────────────────────────────────────────────────────────

class _QuizResultScreen extends StatefulWidget {
  final String entryName;
  final int factualScore;
  final bool passed;
  final VoidCallback onClose;

  const _QuizResultScreen({
    required this.entryName,
    required this.factualScore,
    required this.passed,
    required this.onClose,
  });

  @override
  State<_QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<_QuizResultScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    if (widget.passed) {
      Future.delayed(
          const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryName = widget.entryName;
    final factualScore = widget.factualScore;
    final passed = widget.passed;
    final onClose = widget.onClose;
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon
              _PopIn(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: passed
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : AppColors.slate,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: passed
                          ? AppColors.gold
                          : AppColors.muted.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      passed ? '✓' : '$factualScore/5',
                      style: TextStyle(
                        fontSize: passed ? 40 : 28,
                        color: passed
                            ? AppColors.gold
                            : AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                passed ? 'Jazakallah Khayran' : 'Keep Reflecting',
                style: AppTypography.displayMedium(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                passed
                    ? 'You scored $factualScore/5 on the factual questions.\n'
                        'The story of $entryName has been completed.\n'
                        'The next prophet is now unlocked.'
                    : 'You scored $factualScore/5 on the factual questions.\n'
                        'You need 3 or more to unlock the next story.\n'
                        'Review the layers and try again.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                  decoration: BoxDecoration(
                    color: passed
                        ? AppColors.gold
                        : AppColors.slate,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    passed ? 'Continue' : 'Review Layers',
                    style: AppTypography.bodyMedium(color: passed ? Colors.black : AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small "pops in" animation for the correct/wrong feedback icon — a bare
// AnimatedContainer doesn't replay when the icon first appears, so this
// runs a short elastic scale-in from the icon's first frame.
// ─────────────────────────────────────────────────────────────────────────────

class _PopIn extends StatelessWidget {
  final Widget child;
  const _PopIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _QuizHeader extends StatelessWidget {
  final String entryName;
  final int currentIndex;
  final int total;
  final VoidCallback onClose;

  const _QuizHeader({
    required this.entryName,
    required this.currentIndex,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child:  Icon(Icons.close_rounded,
                color: AppColors.muted, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$entryName — Quiz',
              style: AppTypography.displaySmall(color: AppColors.textPrimary),
            ),
          ),
          Text(
            '${currentIndex + 1} / $total',
            style: AppTypography.labelSmall(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _QuizProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _QuizProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (current + 1) / total,
          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          valueColor:
               AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      ),
    );
  }
}

class _AdvanceButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdvanceButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodyMedium(color: Colors.black),
          ),
        ),
      ),
    );
  }
}
