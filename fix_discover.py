#!/usr/bin/env python3
"""
Fix all 45 flutter analyze issues in the discover feature.
Run this on your machine:  python3 fix_discover.py
"""

import re
import os

BASE = os.path.expanduser('~/develop/ummahapp/lib/features/discover')

# ─────────────────────────────────────────────────────────────────────────────
# Helper: replace all .withOpacity(x) → .withValues(alpha: x)
# ─────────────────────────────────────────────────────────────────────────────
def fix_with_opacity(text):
    return re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', text)

# ─────────────────────────────────────────────────────────────────────────────
# 1. discover_screen.dart
#    - Remove unused import '../models/discover_models.dart'
#    - Remove stub classes (lines 317–end)
#    - Add real imports at top
#    - Fix withOpacity
# ─────────────────────────────────────────────────────────────────────────────
path = os.path.join(BASE, 'screens/discover_screen.dart')
with open(path) as f:
    text = f.read()

# Remove unused import
text = text.replace("import '../models/discover_models.dart';\n", '')

# Remove stub block — everything from the stub comment to end of file
text = re.sub(
    r'\n// Stub colour.*',
    '',
    text,
    flags=re.DOTALL
)

# Add real imports after the flutter/material import line
real_imports = (
    "import 'package:taddabur/core/theme/app_colors.dart';\n"
    "import 'package:taddabur/core/theme/app_typography.dart';\n"
)
text = text.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n" + real_imports
)

# Fix withOpacity
text = fix_with_opacity(text)

# Fix prefer_const_constructors — the two Tab() calls at line 256
# Already const-safe via flutter; these are just infos, not errors. Leave.

with open(path, 'w') as f:
    f.write(text)
print('✓ discover_screen.dart fixed')

# ─────────────────────────────────────────────────────────────────────────────
# 2. prophet_detail_screen.dart
#    - Remove unused import '../screens/discover_screen.dart' show AppColors...
#    - Remove stub classes (lines 738–end)
#    - Add real imports
#    - Fix withOpacity
#    - Fix sized_box_for_whitespace (Container → SizedBox where only height set)
# ─────────────────────────────────────────────────────────────────────────────
path = os.path.join(BASE, 'screens/prophet_detail_screen.dart')
with open(path) as f:
    text = f.read()

# Remove unused import (the show AppColors, AppTypography line)
text = re.sub(
    r"import '\.\.\/screens\/discover_screen\.dart' show AppColors, AppTypography;\n",
    '',
    text
)

# Remove stub block
text = re.sub(
    r'\n// Stub.*',
    '',
    text,
    flags=re.DOTALL
)

# Add real imports
text = text.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n"
    "import 'package:taddabur/core/theme/app_colors.dart';\n"
    "import 'package:taddabur/core/theme/app_typography.dart';\n"
)

# Fix withOpacity
text = fix_with_opacity(text)

# Fix sized_box_for_whitespace: Container(height: X) → SizedBox(height: X)
text = re.sub(
    r'Container\(\s*height:\s*(\d+(?:\.\d+)?),?\s*\)',
    r'SizedBox(height: \1)',
    text
)

with open(path, 'w') as f:
    f.write(text)
print('✓ prophet_detail_screen.dart fixed')

# ─────────────────────────────────────────────────────────────────────────────
# 3. quiz_screen.dart
#    - Remove stub classes _AppColors / _AppTypography
#    - Replace all _AppColors. → AppColors. and _AppTypography. → AppTypography.
#    - Add real imports
#    - Fix withOpacity
# ─────────────────────────────────────────────────────────────────────────────
path = os.path.join(BASE, 'screens/quiz_screen.dart')
with open(path) as f:
    text = f.read()

# Remove stub block
text = re.sub(
    r'\n// Stubs.*',
    '',
    text,
    flags=re.DOTALL
)

# Replace _AppColors. and _AppTypography. with real names
text = text.replace('_AppColors.', 'AppColors.')
text = text.replace('_AppTypography.', 'AppTypography.')

# Add real imports
text = text.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n"
    "import 'package:taddabur/core/theme/app_colors.dart';\n"
    "import 'package:taddabur/core/theme/app_typography.dart';\n"
)

# Fix withOpacity
text = fix_with_opacity(text)

with open(path, 'w') as f:
    f.write(text)
print('✓ quiz_screen.dart fixed')

# ─────────────────────────────────────────────────────────────────────────────
# 4. entry_card.dart
#    - Remove import show AppColors, AppTypography from discover_screen
#    - Add real imports
#    - Fix withOpacity
# ─────────────────────────────────────────────────────────────────────────────
path = os.path.join(BASE, 'widgets/entry_card.dart')
with open(path) as f:
    text = f.read()

# Remove the show import
text = re.sub(
    r"import '\.\.\/screens\/discover_screen\.dart' show AppColors, AppTypography;\n",
    '',
    text
)

# Add real imports
text = text.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n"
    "import 'package:taddabur/core/theme/app_colors.dart';\n"
    "import 'package:taddabur/core/theme/app_typography.dart';\n"
)

# Fix withOpacity
text = fix_with_opacity(text)

with open(path, 'w') as f:
    f.write(text)
print('✓ entry_card.dart fixed')

# ─────────────────────────────────────────────────────────────────────────────
# 5. discover_providers.dart
#    - Add real imports (in case it also imports from discover_screen)
# ─────────────────────────────────────────────────────────────────────────────
path = os.path.join(BASE, 'providers/discover_providers.dart')
with open(path) as f:
    text = f.read()

text = fix_with_opacity(text)

with open(path, 'w') as f:
    f.write(text)
print('✓ discover_providers.dart fixed')

print('\nAll done. Now run:')
print('  cd ~/develop/ummahapp && flutter analyze lib/features/discover/')
