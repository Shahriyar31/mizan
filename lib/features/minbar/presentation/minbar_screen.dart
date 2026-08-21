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
                    'الْمِنْبَر',
                    style: AppTypography.arabicDisplay(
                        color: AppColors.gold, size: 20),
                  ),
                  Text(
                    'Al-Minbar',
                    style:
                        AppTypography.displayLarge(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share what you learn — inspire the Ummah',
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
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppColors.gold,
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
                        'A feed of Quranic reflections, hadith, and knowledge — curated content to keep you connected.',
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
