#!/usr/bin/env python3
"""
Final fix: rewrite all AppTypography calls to use your app's method-based API.
Your AppTypography methods already accept color as a parameter — no .copyWith() needed.

Pattern being fixed:
  AppTypography.bodyMedium(color: x, height: 1.8)  ← extra params not in signature
  → AppTypography.bodyMedium(color: x)              ← only pass what the method accepts

Each method signature from your app_typography.dart:
  arabicDisplay({Color color, double size})
  arabicBody({Color color, double size})
  arabicSmall({Color color, double size})
  arabicHero({Color color, double size})
  displayLarge({Color color})
  displayMedium({Color color})
  displaySmall({Color color})
  labelLarge({Color color})
  labelMedium({Color color})
  labelSmall({Color color})
  bodyLarge({Color color})
  bodyMedium({Color color})
  bodySmall({Color color})
  quoteItalic({Color color})

Extra params like fontSize, fontWeight, height, fontStyle, letterSpacing
passed via .copyWith() or as extra args are INVALID — strip them.
"""

import re, os

BASE = os.path.expanduser('~/develop/ummahapp/lib/features/discover')

FILES = [
    os.path.join(BASE, 'screens/discover_screen.dart'),
    os.path.join(BASE, 'screens/prophet_detail_screen.dart'),
    os.path.join(BASE, 'screens/quiz_screen.dart'),
    os.path.join(BASE, 'widgets/entry_card.dart'),
]

# Methods that accept (color, size) — arabic ones
ARABIC_METHODS = {'arabicDisplay', 'arabicBody', 'arabicSmall', 'arabicHero'}
# Methods that accept only (color)
COLOR_ONLY_METHODS = {
    'displayLarge', 'displayMedium', 'displaySmall',
    'labelLarge', 'labelMedium', 'labelSmall',
    'bodyLarge', 'bodyMedium', 'bodySmall',
    'quoteItalic',
}
ALL_METHODS = ARABIC_METHODS | COLOR_ONLY_METHODS

def extract_color_arg(args_str):
    """Extract just the color: X part from a args string."""
    # Look for color: SomeColor.something or color: Colors.something
    m = re.search(r'color:\s*([\w.()]+(?:\.withValues\(alpha:\s*[\d.]+\))?)', args_str)
    if m:
        return f'color: {m.group(1)}'
    return None

def fix_typography_calls(text):
    """
    Fix all AppTypography.method(...) calls to only pass valid params.
    Handles both:
      AppTypography.method(color: x, fontSize: y, ...)  → AppTypography.method(color: x)
      AppTypography.method()  → AppTypography.method()   [unchanged]
    Also handles _AppTypography prefix (quiz_screen uses this).
    """
    prefixes = ['AppTypography', '_AppTypography']
    
    for method in ALL_METHODS:
        for prefix in prefixes:
            # Match: AppTypography.method( ... ) — single line or multiline
            # We need to handle nested parens? No — these are simple calls.
            # Use a pattern that captures everything between the outermost parens.
            pattern = rf'{re.escape(prefix)}\.{re.escape(method)}\s*\(([^)]*)\)'
            
            def replacer(m, method=method, prefix=prefix):
                inner = m.group(1).strip()
                if not inner:
                    # No args — call with no args
                    return f'{prefix}.{method}()'
                
                color_arg = extract_color_arg(inner)
                
                if method in ARABIC_METHODS:
                    # Check for size arg too
                    size_m = re.search(r'(?:fontSize|size):\s*([\d.]+)', inner)
                    if color_arg and size_m:
                        return f'{prefix}.{method}({color_arg}, size: {size_m.group(1)})'
                    elif color_arg:
                        return f'{prefix}.{method}({color_arg})'
                    elif size_m:
                        return f'{prefix}.{method}(size: {size_m.group(1)})'
                    else:
                        return f'{prefix}.{method}()'
                else:
                    # color only
                    if color_arg:
                        return f'{prefix}.{method}({color_arg})'
                    else:
                        return f'{prefix}.{method}()'
            
            text = re.sub(pattern, replacer, text)
    
    return text

def fix_remaining_copywith(text):
    """
    After the above, there may still be cases like:
      AppTypography.bodySmall\n    .copyWith(color: x)
    These are split across lines — handle them.
    """
    # Join any AppTypography.method\n  .copyWith pattern
    # These happen when the original had: AppTypography.bodySmall\n.copyWith(...)
    for prefix in ['AppTypography', '_AppTypography']:
        for method in ALL_METHODS:
            # multiline: AppTypography.method\n   .copyWith(args)
            pattern = rf'{re.escape(prefix)}\.{re.escape(method)}\s*\n\s*\.copyWith\(([^)]*)\)'
            
            def replacer2(m, method=method, prefix=prefix):
                inner = m.group(1).strip()
                color_arg = extract_color_arg(inner)
                if color_arg:
                    return f'{prefix}.{method}({color_arg})'
                return f'{prefix}.{method}()'
            
            text = re.sub(pattern, replacer2, text)
    
    return text

def fix_stub_classes(text):
    """Remove stub class blocks from files that still have them."""
    # Remove _AppColors stub
    text = re.sub(r'\n// Stubs.*?(?=\nclass [A-Z]|\Z)', '', text, flags=re.DOTALL)
    text = re.sub(r'\nclass _AppColors \{.*?\n\}', '', text, flags=re.DOTALL)
    text = re.sub(r'\nclass _AppTypography \{.*?\n\}', '', text, flags=re.DOTALL)
    # Remove AppColors/AppTypography stubs (non-underscore versions)
    text = re.sub(r'\n// Stub colour.*?(?=\nclass [A-Z][^A-Z]|\Z)', '', text, flags=re.DOTALL)
    text = re.sub(r'\nclass AppColors \{[^}]*\}', '', text, flags=re.DOTALL)
    text = re.sub(r'\nclass AppTypography \{[^}]*\}', '', text, flags=re.DOTALL)
    return text

def fix_imports(text, filename):
    """Ensure correct imports are present, remove bad ones."""
    # Remove any 'show AppColors, AppTypography' imports
    text = re.sub(r"import '[^']*discover_screen\.dart' show AppColors, AppTypography;\n", '', text)
    
    real_imports = (
        "import 'package:taddabur/core/theme/app_colors.dart';\n"
        "import 'package:taddabur/core/theme/app_typography.dart';\n"
    )
    
    # Add after flutter/material import if not already present
    if 'package:taddabur/core/theme/app_colors.dart' not in text:
        text = text.replace(
            "import 'package:flutter/material.dart';\n",
            "import 'package:flutter/material.dart';\n" + real_imports
        )
    
    return text

def fix_unused_imports(text):
    """Remove unused import of discover_models in discover_screen."""
    text = re.sub(r"import '../models/discover_models\.dart';\n", '', text)
    return text

for path in FILES:
    if not os.path.exists(path):
        print(f'SKIP (not found): {path}')
        continue
    
    fname = os.path.basename(path)
    
    with open(path) as f:
        text = f.read()
    
    text = fix_stub_classes(text)
    text = fix_imports(text, fname)
    text = fix_typography_calls(text)
    text = fix_remaining_copywith(text)
    
    if fname == 'discover_screen.dart':
        text = fix_unused_imports(text)
    
    with open(path, 'w') as f:
        f.write(text)
    
    print(f'✓ {fname}')

print('\nDone. Run:')
print('  cd ~/develop/ummahapp && flutter analyze lib/features/discover/')
