library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A compact, horizontally scrollable set of learning layers.
///
/// Five descriptive labels cannot stay legible as equal-width items on a
/// phone, so each remains a full tap target while the row scrolls naturally.
///
/// Layers past [unlockedCount] are drawn shut and refuse the tap. That is the
/// visible half of Discover's completion gate — the reader can see how much story
/// is ahead of them without being able to skip to the end of it.
class PillLayerNavigation extends StatelessWidget {
   PillLayerNavigation({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.unlockedCount,
    Color? accent,
  })  : _accent = accent;

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// How many layers may be opened, counting from the first. Null means all of
  /// them, which is what an ungated caller gets.
  final int? unlockedCount;

  final Color? _accent;

  Color get accent => _accent ?? AppColors.gold;

  @override
  Widget build(BuildContext context) {
    final open = unlockedCount ?? labels.length;

    return Container(
      decoration:  BoxDecoration(
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
              final locked = index >= open;
              return Semantics(
                button: true,
                selected: selected,
                enabled: !locked,
                label: locked
                    ? '${labels[index]}, locked. Finish the layer you are on to open it.'
                    : labels[index],
                child: Material(
                  color: Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    // Null, not a no-op: an unresponsive pill that still ripples
                    // reads as a broken button rather than a shut one.
                    onTap: locked
                        ? null
                        : () {
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
                      child: Row(
                        children: [
                          if (locked) ...[
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            labels[index],
                            style: AppTypography.labelMedium(
                              color: locked
                                  ? AppColors.muted
                                  : selected
                                      ? AppColors.goldSoft
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
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
