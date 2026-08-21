library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A compact, horizontally scrollable set of learning layers.
///
/// Five descriptive labels cannot stay legible as equal-width items on a
/// phone, so each remains a full tap target while the row scrolls naturally.
class PillLayerNavigation extends StatelessWidget {
  const PillLayerNavigation({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.accent = AppColors.gold,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = index == selectedIndex;
              return Semantics(
                button: true,
                selected: selected,
                label: labels[index],
                child: Material(
                  color: Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      if (!selected) HapticFeedback.selectionClick();
                      onSelected(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: selected
                              ? accent.withValues(alpha: 0.75)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        labels[index],
                        style: AppTypography.labelMedium(
                          color: selected
                              ? AppColors.goldSoft
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
