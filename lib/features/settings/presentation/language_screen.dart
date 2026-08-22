/// Language — real Flutter localization foundation (lib/l10n/, gen-l10n),
/// wired into MaterialApp in app.dart. Only English has translated strings
/// today (lib/l10n/app_en.arb); other languages are listed but disabled
/// rather than pretending they work. Quran/Arabic content is separate
/// from UI localization and is never touched by this.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/settings_row.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSubScaffold(
      title: l10n.languageTitle,
      children: [
        SettingsSectionLabel(l10n.languageCurrent),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.language_rounded,
              title: 'English',
              subtitle: l10n.languageEnglishOnly,
              trailing:
                  Icon(Icons.check_circle_rounded, size: 18, color: AppColors.gold),
            ),
          ],
        ),
        const SettingsSectionLabel('Not yet available'),
        SettingsGroup(
          children: [
            for (final lang in const ['বাংলা (Bengali)', 'हिन्दी (Hindi)', 'Deutsch (German)', 'Français (French)'])
              SettingsRow(
                icon: Icons.language_rounded,
                title: lang,
                subtitle: l10n.languageNotTranslated,
                enabled: false,
              ),
          ],
        ),
      ],
    );
  }
}
