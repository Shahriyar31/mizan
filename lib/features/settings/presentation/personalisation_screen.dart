/// Appearance — theme, Arabic font, translation/transliteration
/// toggles, text sizes. Wired to `reading_preferences_provider.dart`,
/// which the Quran reader (ayah_detail_screen.dart) reads directly.
///
/// The class and the route are still called "personalisation" — that name is
/// baked into the route path and a dozen doc comments, and a URL nobody sees is
/// not worth a churn commit. The *title* says Appearance because that is what
/// the Settings row you tapped to get here says, and a door and the room behind
/// it must carry the same name.
///
/// "Volume buttons" (page-turn via hardware volume keys) isn't offered —
/// no such handling exists anywhere in the app and no plugin is wired up
/// for it; adding one is out of scope here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/mizan_brand.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../domain/settings_providers.dart';
import '../domain/reading_preferences_provider.dart';
import 'widgets/settings_row.dart';
import '../../../shared/widgets/mizan/mizan_logo.dart';
import '../../../shared/widgets/mizan/mizan_pressable.dart';

class PersonalisationScreen extends ConsumerWidget {
  const PersonalisationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final logoVariant = ref.watch(logoVariantProvider);
    final prefs = ref.watch(readingPreferencesProvider);
    final controller = ref.read(readingPreferencesProvider.notifier);

    return SettingsSubScaffold(
      title: 'Appearance',
      children: [
        const SettingsSectionLabel('Theme'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ThemeSegmented(
            mode: mode,
            onSelect: (value) =>
                ref.read(themeModeProvider.notifier).set(value),
          ),
        ),

        const SettingsSectionLabel('App Icon'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.auto_awesome_mosaic_rounded,
              title: 'App icon',
              subtitle: logoVariant == null
                  ? 'Matching your theme'
                  : '${logoVariant.label} — '
                      '${logoVariant.description.toLowerCase()}',
              // A custom trailing suppresses SettingsRow's automatic chevron,
              // so it is re-added here after the preview.
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MizanMark(width: 30),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.muted),
                ],
              ),
              onTap: () =>
                  context.push('/settings/personalisation/app-icon'),
            ),
          ],
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

// ══════════════════════════════════════════════════════════════════════
//  THEME — a segmented track, not three boxes
// ══════════════════════════════════════════════════════════════════════

/// Three big bordered boxes were the wrong *shape* for this control, which is
/// why they needed a tint, a thicker border and a raised shadow before the
/// chosen one read as chosen. Three equal boxes say "three separate buttons,
/// press any of them". Theme mode is one choice out of three that exclude each
/// other, and a segmented track says exactly that with no decoration at all:
/// one sunk groove, one raised thumb, and the thumb is wherever you last tapped.
///
/// The thumb is the only part carrying depth. Mizan reserves shadow for things
/// you press, and here the raised segment *is* a press made permanent;
/// unselected segments paint nothing, so the row stays quiet.
class _ThemeSegmented extends StatelessWidget {
  const _ThemeSegmented({required this.mode, required this.onSelect});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onSelect;

  static const _entries = <(ThemeMode, String, IconData)>[
    (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
    (ThemeMode.light, 'Light', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: p.sunk,
            borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
            border: Border.all(
              color: p.hairline,
              width: MizanGeometry.hairlineWidth,
            ),
          ),
          child: Row(
            children: [
              for (final entry in _entries)
                Expanded(
                  child: _ThemeSegment(
                    icon: entry.$3,
                    label: entry.$2,
                    selected: mode == entry.$1,
                    onTap: () => onSelect(entry.$1),
                  ),
                ),
            ],
          ),
        ),

        // Shown for System only. "System" is the one option whose result the
        // control cannot show you, so it says which way the device currently
        // falls instead of leaving you to guess.
        if (mode == ThemeMode.system) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              'Following your device — currently '
              '${MediaQuery.platformBrightnessOf(context) == Brightness.light ? 'light' : 'dark'}.',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
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
    final p = MizanPalette.of(context);
    // Rule #1: the gold family may not be text on cream, so the selected label
    // takes `accentText` — bronze on light, true gold on dark — never `accent`.
    final color = selected ? p.accentText : p.muted;

    return MizanPressable(
      onTap: onTap,
      // The pressable paints nothing itself; the thumb is the AnimatedContainer
      // below so selection eases across instead of snapping. The 1px press
      // nudge still comes from here.
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
      semanticLabel: selected ? '$label theme, selected' : '$label theme',
      child: AnimatedContainer(
        duration: MizanMotion.theme,
        curve: Curves.easeOut,
        // 13 + 18px icon + 13 clears the 44px tap target without the track
        // needing a fixed height.
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? p.card : Colors.transparent,
          borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
          boxShadow: selected ? p.restShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MizanType.button(color: color).copyWith(fontSize: 14),
              ),
            ),
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
