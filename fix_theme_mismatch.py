#!/usr/bin/env python3
"""
Fixes all AppColors and AppTypography mismatches in the discover feature.
Your app's actual names differ from the stub names used in the discover files.
This script remaps all of them.

Run from anywhere:  python3 fix_theme_mismatch.py
"""

import os
import re

BASE = os.path.expanduser('~/develop/ummahapp/lib/features/discover')

FILES = [
    os.path.join(BASE, 'screens/discover_screen.dart'),
    os.path.join(BASE, 'screens/prophet_detail_screen.dart'),
    os.path.join(BASE, 'screens/quiz_screen.dart'),
    os.path.join(BASE, 'widgets/entry_card.dart'),
]

# ── Colour remap ──────────────────────────────────────────────────────────────
# stub name used in discover files → your actual AppColors name
COLOR_MAP = {
    'AppColors.background':     'AppColors.night',
    'AppColors.goldAccent':     'AppColors.gold',
    'AppColors.textPrimary':    'AppColors.ink',
    'AppColors.textSecondary':  'AppColors.muted',
    'AppColors.surfaceElevated':'AppColors.slate',
    'AppColors.layerLocked':    'AppColors.parchment3',
    'AppColors.layerUnlocked':  'AppColors.jade',
    # error already exists — no remap needed
}

# ── Typography remap ──────────────────────────────────────────────────────────
# The discover files call AppTypography.headingLarge.copyWith(color: x)
# but your AppTypography methods are functions: AppTypography.displayMedium(color: x)
# So we need to convert   AppTypography.XXX.copyWith(color: Y, ...)
#                      →  AppTypography.YYY(color: Y)
# and also plain         AppTypography.XXX  (used as TextStyle directly)
#                      →  AppTypography.YYY()

# Map from stub property name → your actual method name
TYPO_MAP = {
    'headingLarge':  'displayMedium',
    'headingMedium': 'displaySmall',
    'bodyLarge':     'bodyLarge',
    'bodyMedium':    'bodyMedium',
    'bodySmall':     'bodySmall',
    'labelLarge':    'labelLarge',
    'labelMedium':   'labelMedium',
    'labelSmall':    'labelSmall',
    'arabicDisplay': 'arabicDisplay',
    'arabicBody':    'arabicBody',
    'arabicSmall':   'arabicSmall',
    'arabicHero':    'arabicHero',
}

def fix_typography(text):
    """
    Convert AppTypography.XXX.copyWith(color: Y, fontWeight: Z)
         → AppTypography.YYY(color: Y, fontWeight: Z)
    and AppTypography.XXX (bare, no call)
         → AppTypography.YYY()
    """
    for stub, real in TYPO_MAP.items():
        # Pattern 1: AppTypography.headingLarge.copyWith(...)
        # Capture everything inside copyWith( ... ) — may span multiple params
        pattern = rf'AppTypography\.{re.escape(stub)}\.copyWith\(([^)]*)\)'
        def replace_copywith(m, real=real):
            inner = m.group(1).strip()
            return f'AppTypography.{real}({inner})'
        text = re.sub(pattern, replace_copywith, text)

        # Pattern 2: AppTypography.headingLarge, (trailing comma or end)
        # bare usage without .copyWith — add ()
        text = re.sub(
            rf'AppTypography\.{re.escape(stub)}\b(?!\s*[\.(])',
            f'AppTypography.{real}()',
            text
        )

    return text

def fix_colors(text):
    # Do longest match first to avoid partial replacements
    for stub, real in sorted(COLOR_MAP.items(), key=lambda x: -len(x[0])):
        text = text.replace(stub, real)
    return text

total_files = 0
for path in FILES:
    if not os.path.exists(path):
        print(f'  SKIP (not found): {path}')
        continue

    with open(path) as f:
        original = f.read()

    fixed = fix_colors(original)
    fixed = fix_typography(fixed)

    with open(path, 'w') as f:
        f.write(fixed)

    total_files += 1
    print(f'✓ Fixed: {os.path.basename(path)}')

print(f'\nDone — {total_files} files updated.')
print('Now run:')
print('  cd ~/develop/ummahapp && flutter analyze lib/features/discover/')
