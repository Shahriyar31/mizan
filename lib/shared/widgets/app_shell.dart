/// AppShell — The persistent bottom navigation bar
///
/// Why ShellRoute + AppShell pattern:
/// Without this, every tab push would reset scroll position and state.
/// ShellRoute keeps each tab's widget tree alive when switching tabs.
/// This is how Instagram, Twitter, every real app works.
///
/// The AppShell wraps all tab screens and shows the bottom nav.
/// It never rebuilds when switching tabs — only the child changes.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
  });

  // child is the current tab's screen — provided by GoRouter's ShellRoute
  final Widget child;

  // Maps route paths to tab indices
  // When GoRouter changes the route, we use this to highlight correct tab
  static const List<String> _routes = [
    '/home',
    '/quran',
    '/discover',
    '/halaqa',
    '/growth',
    '/minbar',
  ];

  // Gets the current tab index from the current route
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _routes.indexWhere(
      (route) => location.startsWith(route),
    );
    return index < 0 ? 0 : index;
  }

  // Navigates to the tapped tab
  void _onTabTapped(BuildContext context, int index) {
    if (index != _currentIndex(context)) {
      context.go(_routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // child is the current tab screen
      body: child,

      // Bottom navigation bar
      bottomNavigationBar: _TadabburBottomNav(
        currentIndex: _currentIndex(context),
        onTap: (index) => _onTabTapped(context, index),
      ),
    );
  }
}

class _TadabburBottomNav extends StatelessWidget {
  const _TadabburBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBg,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'HOME',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                // Using book icon for Quran
                icon: Icons.menu_book_rounded,
                label: 'QURAN',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.explore_rounded,
                label: 'DISCOVER',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.people_rounded,
                label: 'HALAQA',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.auto_graph_rounded,
                label: 'GROWTH',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
              ),
              _NavItem(
                icon: Icons.campaign_rounded,
                label: 'MINBAR',
                isActive: currentIndex == 5,
                onTap: () => onTap(5),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.gold : AppColors.navInactive;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.gold.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                    letterSpacing: 0.4,
                    fontFamily: 'Inter',
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
