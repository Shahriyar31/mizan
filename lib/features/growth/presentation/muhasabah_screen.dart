/// Muhasabah Screen — 3-question private nightly self-reckoning
///
/// Private forever — never synced to any server.
/// Stored only in SQLite on device, one row per night, through
/// [MuhasabahRepository]. It used to write a single sentinel row into the
/// `reflections` table, which meant each night replaced the night before; see
/// that file for the full account.
/// Accessible from Home (Muhasabah state) and Growth tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/domain/todays_mizan.dart';
import '../data/muhasabah_repository.dart';

class MuhasabahScreen extends ConsumerStatefulWidget {
  const MuhasabahScreen({super.key});

  @override
  ConsumerState<MuhasabahScreen> createState() => _MuhasabahScreenState();
}

class _MuhasabahScreenState extends ConsumerState<MuhasabahScreen> {
  final _q1Controller = TextEditingController();
  final _q2Controller = TextEditingController();
  final _q3Controller = TextEditingController();
  final _repo = MuhasabahRepository();
  bool _saving = false;
  bool _saved = false;

  static const _questions = [
    'What did I do today for the sake of Allah?',
    'What did my nafs pull me toward that I should not have followed?',
    'What is my intention for tomorrow?',
  ];

  @override
  void initState() {
    super.initState();
    _prefillTonight();
  }

  /// If the reader already wrote tonight, show them their own words.
  ///
  /// Saving replaces the row for this date, so an empty form would be an
  /// invitation to overwrite what they wrote an hour ago without ever seeing
  /// it. Loading it first turns the second visit into editing.
  ///
  /// Failure is silent on purpose: an empty form is a usable screen, and an
  /// error banner on a page whose entire promise is privacy and quiet would
  /// cost more than the prefill is worth.
  Future<void> _prefillTonight() async {
    try {
      final existing = await _repo.entryFor(DateTime.now());
      if (existing == null || !mounted) return;
      _q1Controller.text = existing.forAllah;
      _q2Controller.text = existing.nafsPull;
      _q3Controller.text = existing.tomorrow;
    } catch (_) {
      // Leave the form empty.
    }
  }

  @override
  void dispose() {
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final today = DateTime.now();

      await _repo.save(
        forAllah: _q1Controller.text,
        nafsPull: _q2Controller.text,
        tomorrow: _q3Controller.text,
        when: today,
      );

      // Mark muhasabah done for today. Same date function as the row key, so
      // the flag Home reads and the row it refers to can never disagree.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_muhasabah_date', MuhasabahRepository.dateKey(today));

      // Sitting with the three questions is the clearest "reflected" the app
      // has. `TodaysMizanController` already unions `last_muhasabah_date` in on
      // restore, but that only helps on the *next* launch — marking here lights
      // the Home strip and counts the streak day now, while the user is still
      // in the app to see it.
      await ref.read(todaysMizanProvider.notifier).mark(MizanFacet.reflected);

      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (e) {
      // A failed save must say so. The success state clears the fields behind a
      // "May Allah accept it" screen, so failing quietly would let someone walk
      // away believing tonight was written down when it wasn't.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            'Could not save tonight\'s muhasabah. Your words are still here — try again.',
            style: AppTypography.bodySmall(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child:  Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الْمُحَاسَبَةُ',
                          style: AppTypography.arabicBody()
                              .copyWith(fontSize: 20, color: AppColors.gold)),
                      Text('Private — never seen by anyone',
                          style: AppTypography.caption(color: AppColors.muted)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              if (_saved) ...[
                _SavedState(),
              ] else ...[
                // Question 1
                _QuestionField(
                  number: '١',
                  question: _questions[0],
                  controller: _q1Controller,
                  hint: 'A prayer, a kind word, an act of patience...',
                ),
                const SizedBox(height: 20),

                // Question 2
                _QuestionField(
                  number: '٢',
                  question: _questions[1],
                  controller: _q2Controller,
                  hint: 'Be honest — this is between you and Allah...',
                ),
                const SizedBox(height: 20),

                // Question 3
                _QuestionField(
                  number: '٣',
                  question: _questions[2],
                  controller: _q3Controller,
                  hint: 'One intention, stated clearly...',
                ),

                const SizedBox(height: 32),

                // Save button
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.jade,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Center(
                      child: _saving
                          ?  CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2)
                          : Text('Save Muhasabah',
                              style: AppTypography.labelLarge(
                                  color: AppColors.white)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Private note
                Center(
                  child: Text(
                    '🔒  Saved on your device only. Never uploaded.',
                    style: AppTypography.caption(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    required this.number,
    required this.question,
    required this.controller,
    required this.hint,
  });

  final String number;
  final String question;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number,
                style: AppTypography.arabicBody()
                    .copyWith(fontSize: 22, color: AppColors.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(question,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(height: 1.5)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 4,
          style: AppTypography.bodyMedium(color: AppColors.textPrimary)
              .copyWith(height: 1.6),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodySmall(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.jade, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

class _SavedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              const Text('🤲', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 20),
              Text('May Allah accept it.',
                  style: AppTypography.displaySmall(color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Your muhasabah has been saved privately.\nOnly you will ever see it.',
                style: AppTypography.bodyMedium(color: AppColors.muted)
                    .copyWith(height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Return home',
                      style: AppTypography.labelLarge(color: AppColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
