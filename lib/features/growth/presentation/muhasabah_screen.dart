/// Muhasabah Screen — 3-question private nightly self-reckoning
///
/// Private forever — never synced to any server.
/// Stored only in SQLite on device.
/// Accessible from Home (Muhasabah state) and Growth tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/database/database_service.dart';

class MuhasabahScreen extends ConsumerStatefulWidget {
  const MuhasabahScreen({super.key});

  @override
  ConsumerState<MuhasabahScreen> createState() => _MuhasabahScreenState();
}

class _MuhasabahScreenState extends ConsumerState<MuhasabahScreen> {
  final _q1Controller = TextEditingController();
  final _q2Controller = TextEditingController();
  final _q3Controller = TextEditingController();
  bool _saving = false;
  bool _saved = false;

  static const _questions = [
    'What did I do today for the sake of Allah?',
    'What did my nafs pull me toward that I should not have followed?',
    'What is my intention for tomorrow?',
  ];

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
      final db = await DatabaseService.instance.database;
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

      await db.insert(
        'reflections',
        {
          'surah_number': 0, // 0 = muhasabah entry, not ayah reflection
          'ayah_number': 0,
          'reflection': '${_q1Controller.text.trim()}|||${_q2Controller.text.trim()}|||${_q3Controller.text.trim()}',
          'saved_at': today.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Mark muhasabah done for today
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_muhasabah_date', todayStr);

      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (e) {
      setState(() => _saving = false);
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
