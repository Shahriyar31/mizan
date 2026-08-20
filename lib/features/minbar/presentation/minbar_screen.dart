library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class MinbarScreen extends StatelessWidget {
  const MinbarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Center(
        child: Text(
          'Al-Minbar — Phase 5',
          style: AppTypography.displayMedium(
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
