library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class HalaqaScreen extends StatelessWidget {
  const HalaqaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Center(
        child: Text(
          'Halaqa — Phase 5',
          style: AppTypography.displayMedium(),
        ),
      ),
    );
  }
}
