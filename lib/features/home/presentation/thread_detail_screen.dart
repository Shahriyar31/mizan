/// Thread Detail — a single connected-sequence screen (not a quiz, no
/// points/XP/badges). Stages use only the verified Encounter data already
/// defined in features/home/data/todays_encounter.dart.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/todays_encounter.dart';

class ThreadDetailScreen extends StatelessWidget {
  const ThreadDetailScreen({super.key, required this.encounter});
  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('The Thread',
                      style: AppTypography.displaySmall(color: AppColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
                children: [
                  _Stage(
                    number: '01',
                    title: encounter.subject.toUpperCase(),
                    body: encounter.hook,
                    isLast: false,
                  ),
                  _Stage(
                    number: '02',
                    title: 'THE MOMENT',
                    body: encounter.context,
                    isLast: false,
                  ),
                  _Stage(
                    number: '03',
                    title: 'THE SOURCE',
                    body: encounter.reference,
                    isLast: false,
                  ),
                  _Stage(
                    number: '04',
                    title: 'SIT WITH THIS',
                    body: encounter.question,
                    isLast: true,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(encounter.routePath);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Read the full story →',
                            style: AppTypography.labelMedium(color: AppColors.gold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.number,
    required this.title,
    required this.body,
    required this.isLast,
  });

  final String number;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number,
                style: AppTypography.labelSmall(color: AppColors.gold)
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.labelSmall(color: AppColors.gold)
                          .copyWith(letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(body,
                      style: AppTypography.bodyLarge(color: AppColors.textPrimary)
                          .copyWith(height: 1.6)),
                ],
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 14, bottom: 14),
            child: Container(width: 1, height: 28, color: AppColors.border),
          ),
      ],
    );
  }
}
