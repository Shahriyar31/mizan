/// Reusable citation display block
/// Used in Scholar AI responses, tafseer layers, Minbar cards
/// Every citation in the app looks identical — builds trust
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class CitationBlock extends StatelessWidget {
  const CitationBlock({
    super.key,
    required this.source,
    required this.detail,
    this.isVerified = true,
  });

  final String source;   // e.g. "Sahih Muslim 2999"
  final String detail;   // e.g. "Narrated by Suhaib (RA) · Grade: Sahih"
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: const BorderSide(color: AppColors.gold, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📚 $source', style: AppTypography.caption()),
          const SizedBox(height: 3),
          Text(detail, style: AppTypography.bodySmall()),
          if (isVerified) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.verified, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Verified source',
                  style: AppTypography.caption(color: AppColors.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
