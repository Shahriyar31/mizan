/// More — FAQ, How Taddabur Works, Terms, Privacy, About, Licenses.
/// FAQ/How-it-works describe the app's actual real behavior — nothing
/// fabricated. Terms/Privacy have no real legal text in the project;
/// their screens say so plainly rather than inventing legal claims.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/settings_row.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'More',
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.help_outline_rounded,
              title: 'FAQ',
              onTap: () => context.push('/settings/more/faq'),
            ),
            SettingsRow(
              icon: Icons.explore_outlined,
              title: 'How Taddabur Works',
              onTap: () => context.push('/settings/more/how-it-works'),
            ),
            SettingsRow(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: () => context.push('/settings/more/terms'),
            ),
            SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => context.push('/settings/more/privacy'),
            ),
            SettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'About Taddabur',
              onTap: () => context.push('/settings/more/about'),
            ),
            SettingsRow(
              icon: Icons.code_rounded,
              title: 'Open-source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Taddabur',
                applicationVersion: '0.1.0',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared simple content page for the More sub-screens.
class MoreContentScreen extends StatelessWidget {
  const MoreContentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;

  /// Each entry: (heading, body).
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: title,
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.$1,
                    style: AppTypography.labelLarge(color: AppColors.gold)),
                const SizedBox(height: 6),
                Text(section.$2,
                    style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
