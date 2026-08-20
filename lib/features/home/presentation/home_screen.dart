library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'تَدَبُّر',
              style: AppTypography.arabicHero(),
            ),
            const SizedBox(height: 12),
            Text(
              'Home — Phase 3',
              style: AppTypography.labelMedium(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
