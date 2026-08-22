/// Personalisation — theme, Arabic font, translation/transliteration
/// toggles, text sizes. Wired to `reading_preferences_provider.dart`,
/// which the Quran reader (ayah_detail_screen.dart) reads directly.
///
/// "Volume buttons" (page-turn via hardware volume keys) isn't offered —
/// no such handling exists anywhere in the app and no plugin is wired up
/// for it; adding one is out of scope here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/settings_providers.dart';
import '../domain/reading_preferences_provider.dart';
import 'widgets/settings_row.dart';
import '../../../shared/widgets/tactile.dart';

class PersonalisationScreen extends ConsumerWidget {
  const PersonalisationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final prefs = ref.watch(readingPreferencesProvider);
    final controller = ref.read(readingPreferencesProvider.notifier);

    return SettingsSubScaffold(
      title: 'Personalisation',
      children: [
        const SettingsSectionLabel('Theme'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final entry in const [
                (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ThemeTile(
                      icon: entry.$3,
                      label: entry.$2,
                      selected: mode == entry.$1,
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).set(entry.$1),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SettingsSectionLabel('Arabic Font'),
        SettingsGroup(
          children: [
            for (final font in ArabicFont.values)
              SettingsRow(
                icon: Icons.text_fields_rounded,
                title: font.label,
                subtitle: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('بِسْمِ اللَّه',
                        style: font.style(size: 20, color: AppColors.gold)),
                    const SizedBox(width: 10),
                    if (prefs.arabicFont == font)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.gold)
                    else
                      const SizedBox(width: 18),
                  ],
                ),
                onTap: () => controller.setFont(font),
              ),
          ],
        ),

        const SettingsSectionLabel('Quran Display'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.translate_rounded,
              title: 'Translation',
              subtitle: 'Show the English translation under each ayah',
              trailing: Switch(
                value: prefs.showTranslation,
                activeThumbColor: AppColors.gold,
                onChanged: controller.setShowTranslation,
              ),
            ),
            SettingsRow(
              icon: Icons.abc_rounded,
              title: 'Transliteration',
              subtitle: 'Show Latin-script pronunciation, where available',
              trailing: Switch(
                value: prefs.showTransliteration,
                activeThumbColor: AppColors.gold,
                onChanged: controller.setShowTransliteration,
              ),
            ),
          ],
        ),

        const SettingsSectionLabel('Text Size'),
        SettingsGroup(
          children: [
            _SizeSlider(
              icon: Icons.format_size_rounded,
              label: 'Arabic text',
              value: prefs.arabicTextSize,
              min: 20,
              max: 40,
              onChanged: controller.setArabicTextSize,
            ),
            _SizeSlider(
              icon: Icons.short_text_rounded,
              label: 'Translation text',
              value: prefs.translationTextSize,
              min: 12,
              max: 22,
              onChanged: controller.setTranslationTextSize,
            ),
          ],
        ),

        const SettingsSectionLabel('Preview'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Preview(prefs: prefs),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      onTap: onTap,
      baseColor: AppColors.surface,
      borderRadius: 16,
      strength: 0.8,
      // Only the selected tile is raised.
      raised: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.6)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22, color: selected ? AppColors.gold : AppColors.muted),
            const SizedBox(height: 8),
            Text(label,
                style: AppTypography.labelMedium(
                    color: selected ? AppColors.gold : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SizeSlider extends StatelessWidget {
  const _SizeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTypography.labelLarge(color: AppColors.textPrimary)),
              ),
              Text(value.round().toString(),
                  style: AppTypography.labelMedium(color: AppColors.gold)),
            ],
          ),
          Row(
            children: [
              Text('A', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.gold,
                    thumbColor: AppColors.gold,
                    inactiveTrackColor: AppColors.border,
                    overlayColor: AppColors.gold.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ),
              Text('A', style: TextStyle(fontSize: 22, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.prefs});
  final ReadingPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: prefs.arabicFont
                .style(size: prefs.arabicTextSize, color: AppColors.textPrimary)
                .copyWith(height: 1.9),
          ),
          if (prefs.showTransliteration) ...[
            const SizedBox(height: 10),
            Text(
              'Bismillah ir-Rahman ir-Raheem',
              textAlign: TextAlign.center,
              style: AppTypography.quoteItalic(color: AppColors.gold)
                  .copyWith(fontSize: prefs.translationTextSize),
            ),
          ],
          if (prefs.showTranslation) ...[
            const SizedBox(height: 10),
            Text(
              'In the name of Allah, the Most Gracious, the Most Merciful.',
              textAlign: TextAlign.center,
              style: AppTypography.quoteItalic(color: AppColors.textSecondary)
                  .copyWith(fontSize: prefs.translationTextSize),
            ),
          ],
        ],
      ),
    );
  }
}
