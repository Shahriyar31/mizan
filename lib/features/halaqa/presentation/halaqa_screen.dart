library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class HalaqaScreen extends StatelessWidget {
  const HalaqaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حَلَقَة',
                    style: AppTypography.arabicDisplay(
                        color: AppColors.jade, size: 20),
                  ),
                  Text(
                    'Halaqa',
                    style:
                        AppTypography.displayLarge(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Learn together — share knowledge with your circle',
                    style: AppTypography.bodySmall(color: AppColors.muted),
                  ),
                ],
              ),
            ),

            // Coming soon content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.jade.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.jade.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.people_rounded,
                        color: AppColors.jade,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Coming Soon',
                      style: AppTypography.displaySmall(
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        'Study circles with your friends — read together, quiz each other, grow in knowledge.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
