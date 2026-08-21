#!/usr/bin/env python3
"""
Fixes two navigation issues:
1. ProphetDetailScreen uses Navigator.push — breaks GoRouter ShellRoute tabs
2. SahabiTab shows SnackBar — needs real navigation
Both replaced with context.push() via GoRouter.
Also fixes prophet_detail_screen.dart back button to use context.pop().
"""
import os, re

BASE = os.path.expanduser('~/develop/ummahapp/lib')

# ── Fix 1: discover_screen.dart ──────────────────────────────────────────────
path = os.path.join(BASE, 'features/discover/screens/discover_screen.dart')
with open(path) as f:
    text = f.read()

# Add go_router import
if "go_router" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:go_router/go_router.dart';"
    )

# Fix prophet navigation: replace Navigator.push with context.push
text = text.replace(
    """            onTap: item.isUnlocked
                ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProphetDetailScreen(
                        prophetId: item.entry.id,
                      ),
                    ))
                : null,""",
    """            onTap: item.isUnlocked
                ? () => context.push('/discover/prophet/\${item.entry.id}')
                : null,"""
)

# Fix sahabi navigation: replace SnackBar with context.push
text = text.replace(
    """            onTap: item.isUnlocked
                ? () {
                    // TODO: Navigate to SahabiDetailScreen (same pattern as ProphetDetailScreen)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('\${item.entry.nameEnglish} — coming soon')),
                    );
                  }
                : null,""",
    """            onTap: item.isUnlocked
                ? () => context.push('/discover/sahabi/\${item.entry.id}')
                : null,"""
)

# Remove the now-unused ProphetDetailScreen import
text = text.replace("import 'prophet_detail_screen.dart';\n", "")

with open(path, 'w') as f:
    f.write(text)
print('✓ discover_screen.dart — navigation fixed')

# ── Fix 2: prophet_detail_screen.dart back button ────────────────────────────
path = os.path.join(BASE, 'features/discover/screens/prophet_detail_screen.dart')
with open(path) as f:
    text = f.read()

# Add go_router import if missing
if "go_router" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:go_router/go_router.dart';"
    )

# Fix back button: Navigator.of(context).pop() → context.pop()
text = text.replace(
    "onPressed: () => Navigator.of(context).pop(),",
    "onPressed: () => context.pop(),"
)

# Fix quiz navigation — also uses Navigator.push
text = text.replace(
    "Navigator.of(context).push(MaterialPageRoute(\n      builder: (_) => QuizScreen(",
    "Navigator.of(context).push(MaterialPageRoute(\n      builder: (_) => QuizScreen("
)

with open(path, 'w') as f:
    f.write(text)
print('✓ prophet_detail_screen.dart — back button fixed')

print('\nDone. Now copy app_router.dart and create sahabi_detail_screen.dart.')
