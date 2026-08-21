#!/usr/bin/env python3
"""
Surgical line-by-line fixes for the remaining 32 issues.
Targets exact broken patterns found in the output.
"""
import re, os

BASE = os.path.expanduser('~/develop/ummahapp/lib/features/discover')

def fix_file(path, fixes):
    """Apply a list of (old_str, new_str) replacements to a file."""
    with open(path) as f:
        text = f.read()
    for old, new in fixes:
        if old in text:
            text = text.replace(old, new)
        else:
            print(f'  WARN: pattern not found in {os.path.basename(path)}: {repr(old[:60])}')
    with open(path, 'w') as f:
        f.write(text)

# ─────────────────────────────────────────────────────────────────────────────
# prophet_detail_screen.dart fixes
# ─────────────────────────────────────────────────────────────────────────────
prophet_fixes = [
    # Bug 1: ternary color grabbed as bool — label tab text
    (
        'style: AppTypography.labelSmall(color: isSelected),\n                      fontWeight:\n                          isSelected ? FontWeight.w700 : FontWeight.w500,\n                    ),',
        'style: AppTypography.labelSmall(\n                      color: isSelected\n                          ? AppColors.night\n                          : isAvailable\n                              ? AppColors.ink\n                              : AppColors.muted.withValues(alpha: 0.5),\n                    ),'
    ),
    # Bug 2: withValues(alpha) — missing value — source attribution
    (
        'style: AppTypography.labelSmall(color: AppColors.muted.withValues(alpha),\n              fontStyle: FontStyle.italic,\n            ),',
        'style: AppTypography.labelSmall(color: AppColors.muted.withValues(alpha: 0.6)),'
    ),
    # Bug 3: withValues(alpha) — locked layer "one layer per day" text  
    (
        'style: AppTypography.labelSmall(color: AppColors.muted.withValues(alpha),\n                fontStyle: FontStyle.italic,\n              ),',
        'style: AppTypography.labelSmall(color: AppColors.muted.withValues(alpha: 0.5)),'
    ),
    # Also fix bodyMedium with height param that slipped through
    (
        'style: AppTypography.bodyMedium(color: AppColors.ink,\n              height: 1.8,\n            ),',
        'style: AppTypography.bodyMedium(color: AppColors.ink),'
    ),
    # bodyMedium fontStyle italic
    (
        'style: AppTypography.bodyMedium(color: AppColors.muted,\n            fontStyle: FontStyle.italic,\n          ),',
        'style: AppTypography.quoteItalic(color: AppColors.muted),'
    ),
    # headingLarge with fontSize
    (
        'style: AppTypography.displayMedium(color: AppColors.ink,\n            fontSize: 28,\n          ),',
        'style: AppTypography.displayMedium(color: AppColors.ink),'
    ),
    # bodyMedium fontWeight fontSize in gold button
    (
        'style: AppTypography.bodyMedium(color: Colors.black,\n              fontWeight: FontWeight.w700,\n              fontSize: 16,\n            ),',
        'style: AppTypography.labelLarge(color: Colors.black),'
    ),
    # labelSmall letterSpacing 2
    (
        'style: AppTypography.labelSmall(color: AppColors.gold,\n            letterSpacing: 2,\n          ),',
        'style: AppTypography.labelSmall(color: AppColors.gold),'
    ),
    # bodySmall height 1.5
    (
        'style: AppTypography.bodySmall(color: AppColors.muted,\n                height: 1.5,\n              ),',
        'style: AppTypography.bodySmall(color: AppColors.muted),'
    ),
    # bodySmall height 1.6
    (
        'style: AppTypography.bodySmall(color: AppColors.muted,\n                  height: 1.6,\n                ),',
        'style: AppTypography.bodySmall(color: AppColors.muted),'
    ),
    # bodySmall fontWeight w600
    (
        'style: AppTypography.bodySmall(color: AppColors.ink,\n                  fontWeight: FontWeight.w600,\n                ),',
        'style: AppTypography.labelMedium(color: AppColors.ink),'
    ),
    # labelSmall fontWeight w600
    (
        'style: AppTypography.labelSmall(color: AppColors.gold,\n              fontWeight: FontWeight.w600,\n            ),',
        'style: AppTypography.labelSmall(color: AppColors.gold),'
    ),
    # bodySmall height 1.5 (tomorrow teaser)
    (
        'style: AppTypography.bodySmall(color: AppColors.muted,\n                height: 1.5,\n              ),',
        'style: AppTypography.bodySmall(color: AppColors.muted),'
    ),
    # bodyMedium fontWeight color black (advance button)  
    (
        'style: AppTypography.bodyMedium(color: Colors.black,\n              fontWeight: FontWeight.w700,\n            ),',
        'style: AppTypography.labelLarge(color: Colors.black),'
    ),
]

# ─────────────────────────────────────────────────────────────────────────────
# entry_card.dart fixes
# ─────────────────────────────────────────────────────────────────────────────
entry_fixes = [
    # Bug: arabicDisplay(color: isUnlocked, size: 20) — prophet card
    (
        'style: AppTypography.arabicDisplay(color: isUnlocked, size: 20),',
        'style: AppTypography.arabicDisplay(color: isUnlocked ? AppColors.gold : AppColors.muted, size: 20),'
    ),
    # Bug: displaySmall(color: isUnlocked) — prophet card English name
    (
        'style: AppTypography.displaySmall(color: isUnlocked),',
        'style: AppTypography.displaySmall(color: isUnlocked ? AppColors.ink : AppColors.muted),'
    ),
    # Bug: labelSmall(color: gold.withValues(alpha), letterSpacing)
    (
        'style: AppTypography.labelSmall(color: AppColors.gold.withValues(alpha),\n                    letterSpacing: 0.8,\n                  ),',
        'style: AppTypography.labelSmall(color: AppColors.gold.withValues(alpha: 0.7)),'
    ),
    # Bug: arabicDisplay(color: isUnlocked, size: 18) — sahabi card
    (
        'style: AppTypography.arabicDisplay(color: isUnlocked, size: 18),',
        'style: AppTypography.arabicDisplay(color: isUnlocked ? AppColors.gold : AppColors.muted, size: 18),'
    ),
    # Bug: displaySmall(color: isUnlocked) — sahabi kunyah
    (
        '                            style: AppTypography.displaySmall(color: isUnlocked),',
        '                            style: AppTypography.displaySmall(color: isUnlocked ? AppColors.ink : AppColors.muted),'
    ),
    # Bug: bodySmall height 1.5
    (
        'style: AppTypography.bodySmall(color: AppColors.muted,\n                      height: 1.5,\n                    ),',
        'style: AppTypography.bodySmall(color: AppColors.muted),'
    ),
    # Bug: arabicDisplay(color: isUnlocked, size: 24) — divine name card
    (
        'style: AppTypography.arabicDisplay(color: isUnlocked, size: 24),',
        'style: AppTypography.arabicDisplay(color: isUnlocked ? AppColors.gold : AppColors.muted, size: 24),'
    ),
    # Bug: bodySmall fontStyle italic letterSpacing — translit
    (
        'style: AppTypography.bodySmall(color: AppColors.muted.withValues(alpha),\n                        letterSpacing: 0.5,\n                        fontStyle: FontStyle.italic,\n                      ),',
        'style: AppTypography.quoteItalic(color: AppColors.muted),'
    ),
    # Bug: bodyMedium(color: isUnlocked, fontSize: 14) — meaningBrief
    (
        'style: AppTypography.bodyMedium(color: isUnlocked,\n                        fontSize: 14,\n                      ),',
        'style: AppTypography.bodyMedium(color: isUnlocked ? AppColors.ink : AppColors.muted),'
    ),
    # Bug: labelSmall fontWeight w800 fontSize 13 — sequence badge
    (
        'style: AppTypography.labelSmall(color: isCompleted,\n                fontWeight: FontWeight.w800,\n                fontSize: 13,\n              ),',
        'style: AppTypography.labelSmall(color: isCompleted ? AppColors.night : isUnlocked ? AppColors.gold : AppColors.muted),'
    ),
    # Bug: labelSmall(color: isUnlocked, fontWeight w700) — divine name number badge
    (
        'style: AppTypography.labelSmall(color: isUnlocked,\n                      fontWeight: FontWeight.w700,\n                    ),',
        'style: AppTypography.labelSmall(color: isUnlocked ? AppColors.gold : AppColors.muted),'
    ),
    # Bug: locked hint fontStyle italic withValues(alpha)
    (
        'style: AppTypography.labelSmall(color: AppColors.muted.withValues(alpha),\n        fontStyle: FontStyle.italic,\n      ),',
        'style: AppTypography.labelSmall(color: AppColors.muted.withValues(alpha: 0.5)),'
    ),
]

# ─────────────────────────────────────────────────────────────────────────────
# quiz_screen.dart fixes
# ─────────────────────────────────────────────────────────────────────────────
quiz_fixes = [
    # Bug: bodySmall fontStyle italic withValues(alpha)
    (
        'style: AppTypography.bodySmall(color: AppColors.muted.withValues(alpha),\n              fontStyle: FontStyle.italic,\n            ),',
        'style: AppTypography.quoteItalic(color: AppColors.muted),'
    ),
    # Bug: headingMedium height fontSize
    (
        'style: AppTypography.displaySmall(color: AppColors.ink,\n            height: 1.5,\n            fontSize: 18,\n          ),',
        'style: AppTypography.displaySmall(color: AppColors.ink),'
    ),
    # Bug: bodyMedium height 1.4
    (
        'style: AppTypography.bodyMedium(color: textColor,\n                        height: 1.4,\n                      ),',
        'style: AppTypography.bodyMedium(color: textColor),'
    ),
    # Bug: bodyMedium fontWeight fontSize advance button
    (
        'style: AppTypography.bodyMedium(color: Colors.black,\n              fontWeight: FontWeight.w700,\n              fontSize: 16,\n            ),',
        'style: AppTypography.labelLarge(color: Colors.black),'
    ),
    # Bug: headingLarge result screen
    (
        'style: AppTypography.displayMedium(color: AppColors.ink,\n                ),',
        'style: AppTypography.displayMedium(color: AppColors.ink),'
    ),
    # Bug: bodyMedium height 1.7 result screen  
    (
        'style: AppTypography.bodyMedium(color: AppColors.muted,\n                  height: 1.7,\n                ),',
        'style: AppTypography.bodyMedium(color: AppColors.muted),'
    ),
    # Bug: bodyMedium fontWeight result button
    (
        'style: AppTypography.bodyMedium(color: passed ? Colors.black : AppColors.ink,\n                      fontWeight: FontWeight.w700,\n                    ),',
        'style: AppTypography.labelLarge(color: passed ? Colors.black : AppColors.ink),'
    ),
    # Bug: headingMedium quiz header fontSize 16
    (
        'style: AppTypography.displaySmall(color: AppColors.ink,\n                fontSize: 16,\n              ),',
        'style: AppTypography.displaySmall(color: AppColors.ink),'
    ),
    # Bug: bodySmall height 1.7 scholar card
    (
        'style: AppTypography.bodySmall(color: AppColors.ink,\n              height: 1.7,\n            ),',
        'style: AppTypography.bodySmall(color: AppColors.ink),'
    ),
    # Bug: quiz_screen argument_type_not_assignable line 415
    (
        'style: AppTypography.bodyMedium(color: passed,\n              fontWeight: FontWeight.w700,\n              fontSize: 16,\n            ),',
        'style: AppTypography.labelLarge(color: passed ? Colors.black : AppColors.ink),'
    ),
]

fix_file(os.path.join(BASE, 'screens/prophet_detail_screen.dart'), prophet_fixes)
print('✓ prophet_detail_screen.dart')

fix_file(os.path.join(BASE, 'widgets/entry_card.dart'), entry_fixes)
print('✓ entry_card.dart')

fix_file(os.path.join(BASE, 'screens/quiz_screen.dart'), quiz_fixes)
print('✓ quiz_screen.dart')

print('\nDone. Run:')
print('  cd ~/develop/ummahapp && flutter analyze lib/features/discover/')
