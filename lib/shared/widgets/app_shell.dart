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
/// ── The icons are artwork, not glyphs ─────────────────────────────────
/// Each tab draws one of the ten bundled PNGs through [MizanIcon]. They were
/// `Icons.home_outlined` and friends until the artwork arrived; the asset README
/// forbids both tinting them and substituting a Material icon for them, so the
/// active state is carried entirely by the three cues in the table below.
///
/// The one mistake worth naming, because it is the natural way to write this and
/// it is wrong: the inactive fade goes on the **image**, not on the tab's Column.
/// Fading the column takes the label with it, and a 10px label at 52% is around
/// 2:1 against the card — unreadable in daylight and a WCAG failure regardless.
/// [MizanIcon.opacity] exists so the fade lands in the right place.
///
///   Icon        active 1.0            inactive 0.52
///   Label       w700, `p.ink`         w400, `p.muted`
///   Under it    5px gold diamond      an empty 5px box, so nothing shifts
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

import '../../core/branding/mizan_icons.dart';
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

  static const _tabs = <({MizanIcons icon, String label})>[
    (icon: MizanIcons.home, label: 'Home'),
    (icon: MizanIcons.quran, label: 'Quran'),
    (icon: MizanIcons.discover, label: 'Discover'),
    (icon: MizanIcons.halaqa, label: 'Halaqa'),
    (icon: MizanIcons.minbar, label: 'Minbar'),
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

  final MizanIcons icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  /// [MizanDiamond] lays out at `size * 1.42`. The inactive tab reserves the
  /// same box so labels sit on one line across the bar instead of jumping up
  /// when a tab loses its marker.
  static const double _markerSize = 5;
  static const double _markerBox = _markerSize * 1.42;

  /// Icon edge, from the asset README. Larger than the 22px Material icon it
  /// replaced because this artwork carries interior detail — a mihrab arch with
  /// something inside it — where a glyph carried one silhouette.
  static const double _iconSize = 27;

  /// What the inactive icon fades to. The label does **not** fade with it; see
  /// the note at the top of this file.
  static const double _inactiveOpacity = 0.52;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

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
          MizanIcon(
            icon,
            size: _iconSize,
            opacity: isActive ? 1.0 : _inactiveOpacity,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // navLabel is 11px/w600 — the right role, but the tab bar is
            // specified at 10px and swings the weight the full w400–w700 range,
            // because with no pill and no tint the weight is a third of the
            // active signal rather than a flourish on it.
            style: MizanType.navLabel(color: isActive ? p.ink : p.muted)
                .copyWith(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 5),
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
