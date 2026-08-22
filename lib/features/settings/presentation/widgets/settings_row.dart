/// SettingsRow — one compact, tappable row: icon · title + subtitle · chevron.
///
/// Shared by the Settings main list and every sub-screen so the whole
/// section reads as one consistent list, not a page of one-off widgets.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared scaffold for every Settings sub-screen: back arrow, title, same
/// scroll body — so each one reads as part of the same list, not a one-off
/// screen with its own chrome.
class SettingsSubScaffold extends StatelessWidget {
  const SettingsSubScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Text(title,
                      style: AppTypography.displaySmall(
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Custom trailing widget (a Switch, a value label…). Defaults to a
  /// chevron when [onTap] is set, or nothing when it isn't.
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dim = enabled ? 1.0 : 0.4;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.gold.withValues(alpha: dim)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.labelLarge(
                          color: AppColors.textPrimary.withValues(alpha: dim))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(
                            color: AppColors.muted.withValues(alpha: dim))),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.muted.withValues(alpha: dim)),
          ],
        ),
      ),
    );
  }
}

/// Thin divider matching the row's left inset, used between [SettingsRow]s.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 58),
        child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
      );
}

/// Section label above a group of rows (e.g. "ACCOUNT").
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(text.toUpperCase(),
            style: AppTypography.labelSmall(color: AppColors.gold)),
      );
}

/// A full-bleed rounded group container (card-free page, grouped list look).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SettingsDivider(),
              children[i],
            ],
          ],
        ),
      );
}

/// Simple "not available yet" body for a sub-screen with no real backing
/// state to connect to (rather than faking controls that don't do anything).
class SettingsComingSoon extends StatelessWidget {
  const SettingsComingSoon({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 32, color: AppColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(color: AppColors.muted)),
          ],
        ),
      );
}
