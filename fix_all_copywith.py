#!/usr/bin/env python3
"""
Final comprehensive fix: convert ALL .copyWith() calls on AppTypography methods
to direct method calls with only the color parameter.
Works on files as they exist on your machine right now.
"""
import re, os

BASE = os.path.expanduser('~/develop/ummahapp/lib/features/discover')

FILES = [
    os.path.join(BASE, 'screens/prophet_detail_screen.dart'),
    os.path.join(BASE, 'widgets/entry_card.dart'),
    os.path.join(BASE, 'screens/quiz_screen.dart'),
    os.path.join(BASE, 'screens/discover_screen.dart'),
]

# Your AppTypography method signatures:
# arabicDisplay/arabicBody/arabicSmall/arabicHero → accept (color, size)
# all others → accept (color) only
ARABIC_METHODS = {'arabicDisplay', 'arabicBody', 'arabicSmall', 'arabicHero'}
ALL_METHODS = ARABIC_METHODS | {
    'displayLarge', 'displayMedium', 'displaySmall',
    'labelLarge', 'labelMedium', 'labelSmall',
    'bodyLarge', 'bodyMedium', 'bodySmall', 'quoteItalic',
}

def get_color_from_args(args):
    """Extract color value from copyWith args, handling ternary expressions."""
    args = args.strip()
    if not args:
        return None
    # Match color: <expression> where expression can be a ternary
    # Ternary: condition ? trueVal : falseVal
    # Simple: AppColors.something or AppColors.something.withValues(...)
    m = re.search(r'color:\s*(.+?)(?:,\s*(?:fontSize|fontWeight|height|fontStyle|letterSpacing|size)\s*:|$)', args, re.DOTALL)
    if m:
        color = m.group(1).strip().rstrip(',').strip()
        return color
    return None

def fix_typography_multiline(text, prefix):
    """
    Fix patterns like:
    AppTypography.bodyMedium.copyWith(
      color: AppColors.ink,
      height: 1.8,
    )
    → AppTypography.bodyMedium(color: AppColors.ink)
    
    Also handles single-line .copyWith(color: x)
    """
    for method in ALL_METHODS:
        # Pattern: AppTypography.method.copyWith( ... )
        # The content between parens may span multiple lines
        pattern = rf'{re.escape(prefix)}\.{re.escape(method)}\.copyWith\s*\((.*?)\)'
        
        def replacer(m, method=method, prefix=prefix):
            inner = m.group(1)
            color = get_color_from_args(inner)
            
            if method in ARABIC_METHODS:
                # Also check for size
                size_m = re.search(r'(?:fontSize|size):\s*([\d.]+)', inner)
                if color and size_m:
                    return f'{prefix}.{method}(color: {color}, size: {size_m.group(1)})'
                elif color:
                    return f'{prefix}.{method}(color: {color})'
                else:
                    return f'{prefix}.{method}()'
            else:
                if color:
                    return f'{prefix}.{method}(color: {color})'
                else:
                    return f'{prefix}.{method}()'
        
        text = re.sub(pattern, replacer, text, flags=re.DOTALL)
    
    return text

def fix_bare_copywith(text, prefix):
    """
    Fix patterns like:
    AppTypography.bodySmall
        .copyWith(color: AppColors.gold)
    where the method call and .copyWith are on separate lines.
    """
    for method in ALL_METHODS:
        pattern = rf'{re.escape(prefix)}\.{re.escape(method)}\s*\n\s*\.copyWith\s*\((.*?)\)'
        
        def replacer(m, method=method, prefix=prefix):
            inner = m.group(1)
            color = get_color_from_args(inner)
            if color:
                return f'{prefix}.{method}(color: {color})'
            return f'{prefix}.{method}()'
        
        text = re.sub(pattern, replacer, text, flags=re.DOTALL)
    
    return text

def fix_invalid_extra_params(text, prefix):
    """
    Fix calls like AppTypography.bodyMedium(color: x, height: 1.8, fontWeight: ...)
    Strip all params except color (and size for arabic methods).
    """
    for method in ALL_METHODS:
        pattern = rf'{re.escape(prefix)}\.{re.escape(method)}\s*\((.*?)\)'
        
        def replacer(m, method=method, prefix=prefix):
            inner = m.group(1)
            # Check if there are invalid params
            has_invalid = any(p in inner for p in ['fontSize:', 'fontWeight:', 'height:', 'fontStyle:', 'letterSpacing:'])
            if not has_invalid:
                return m.group(0)  # no change needed
            
            color = get_color_from_args(inner)
            if method in ARABIC_METHODS:
                size_m = re.search(r'(?:fontSize|size):\s*([\d.]+)', inner)
                if color and size_m:
                    return f'{prefix}.{method}(color: {color}, size: {size_m.group(1)})'
                elif color:
                    return f'{prefix}.{method}(color: {color})'
                else:
                    return f'{prefix}.{method}()'
            else:
                if color:
                    return f'{prefix}.{method}(color: {color})'
                else:
                    return f'{prefix}.{method}()'
        
        text = re.sub(pattern, replacer, text, flags=re.DOTALL)
    
    return text

for path in FILES:
    if not os.path.exists(path):
        print(f'SKIP: {path}')
        continue
    
    with open(path) as f:
        text = f.read()
    
    original = text
    
    # Fix both AppTypography and _AppTypography prefixes
    for prefix in ['AppTypography', '_AppTypography']:
        text = fix_typography_multiline(text, prefix)
        text = fix_bare_copywith(text, prefix)
        text = fix_invalid_extra_params(text, prefix)
    
    if text != original:
        with open(path, 'w') as f:
            f.write(text)
        print(f'✓ Fixed: {os.path.basename(path)}')
    else:
        print(f'  No changes needed: {os.path.basename(path)}')

print('\nDone. Run:')
print('  cd ~/develop/ummahapp && flutter analyze lib/features/discover/ && flutter run -d emulator-5554')
