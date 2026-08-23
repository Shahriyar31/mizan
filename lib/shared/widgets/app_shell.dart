/// AppShell — the persistent bottom tab bar that wraps every tab screen.
///
/// ── Why ShellRoute + AppShell ─────────────────────────────────────────
/// Without this, switching tabs would rebuild each screen from scratch and throw
/// away its scroll position. GoRouter's ShellRoute keeps each tab's widget tree
/// alive and swaps only [child], so the shell itself never rebuilds on a tab
/// change — only the tab bar's highlighted index does.
///
/// ── What the design actually asks for ─────────────────────────────────
/// Read off the bottom strip of both mockup sets (Mizan Light/Dark, all eight
/// pages — the bar is identical on every one):
///
///   • Five tabs, sentence case: Home · Quran · Discover · Halaqa · Minbar.
///     Not the uppercase 7px labels this file used to draw.
///   • No pill, no capsule, no tinted background behind the active tab. The
///     ONLY active marker is a small gold diamond under the label.
///   • Active icon and label take the theme's ink (navy on cream, cream on
///     navy); the other four take the single muted grey.
///   • The bar sits on `card` — a shade brighter than the page on light, a shade
///     lighter than the page on dark — with a hairline along its top edge.
///
/// ── Growth and Settings are deliberately not tabs ─────────────────────
/// The design has eight screens but five tabs. Growth is reached from Today's
/// Mizan on Home (and from the streak pill), and Settings from the avatar in any
/// header — the mockups label them "reached from Today's Mizan" and "reached from
/// any tab" respectively.
///
/// That is why [_currentIndex] returns **-1** rather than falling back to 0. The
/// old fallback meant standing on `/growth` lit up the Home tab, which quietly
/// told the user they were somewhere they weren't. With -1 no tab is lit, which
/// is the truth: you are on a screen that lives outside the tab set.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mizan_tokens.dart';
import '../../core/theme/mizan_typography.dart';
import 'mizan/mizan_components.dart';
import 'mizan/mizan_pressable.dart';
import 'responsive.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// The current tab's screen, supplied by GoRouter's ShellRoute.
  final Widget child;

  /// Tab order, and the route prefix each tab owns.
  ///
  /// Prefix matching is intentional: the Reader lives under `/quran/...`, so
  /// reading an ayah correctly keeps the Quran tab lit instead of dropping the
  /// highlight. Anything not prefixed by one of these five — `/growth`,
  /// `/settings` and their sub-routes — lights nothing.
  static const List<String> _routes = [
    '/home',
    '/quran',
    '/discover',
    '/halaqa',
    '/minbar',
  ];

  /// The active tab, or -1 when the current route is not one of the five.
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return _routes.indexWhere(location.startsWith);
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final index = _currentIndex(context);

    return Scaffold(
      backgroundColor: p.page,

      // Unconstrained on phones; capped to a comfortable reading width and
      // centred on tablets so content never stretches edge to edge.
      body: ResponsiveCenter(child: child),

      bottomNavigationBar: _MizanTabBar(
        currentIndex: index,
        onTap: (i) {
          if (i != index) context.go(_routes[i]);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  THE BAR
// ══════════════════════════════════════════════════════════════════════

class _MizanTabBar extends StatelessWidget {
  const _MizanTabBar({required this.currentIndex, required this.onTap});

  /// -1 means no tab is active — see [AppShell._currentIndex].
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.menu_book_outlined, label: 'Quran'),
    (icon: Icons.explore_outlined, label: 'Discover'),
    (icon: Icons.people_outline_rounded, label: 'Halaqa'),
    (icon: Icons.campaign_outlined, label: 'Minbar'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(
          top: BorderSide(color: p.hairline, width: MizanGeometry.hairlineWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MizanGeometry.tabBarHeight,
          child: ResponsiveCenter(
            // Narrower than page content: five icons don't need the full
            // tablet width, and spreading them leaves absurd gaps.
            maxWidth: 480,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      isActive: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  /// [MizanDiamond] lays out at `size * 1.42`. The inactive tab reserves the
  /// same box so labels sit on one line across the bar instead of jumping up
  /// when a tab loses its marker.
  static const double _markerSize = 5;
  static const double _markerBox = _markerSize * 1.42;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final color = isActive ? p.ink : p.muted;

    return MizanPressable(
      onTap: onTap,
      // The bar is one continuous surface; a raised tab would break it. The 1px
      // press nudge still fires, which is all the feedback a tab needs.
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.rowRadius),
      semanticLabel: label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MizanType.navLabel(color: color).copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _markerBox,
            child: isActive
                ? MizanDiamond(size: _markerSize, color: p.accent)
                : null,
          ),
        ],
      ),
    );
  }
}
