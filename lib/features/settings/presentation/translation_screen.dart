/// Translation — which translator's words appear under the Arabic.
///
/// A short list on purpose. Every entry is a named human translator whose
/// published work can be quoted and checked; there is no "auto" option and there
/// never will be, because a machine rendering of the Qur'an is not a translation
/// anybody can be held to. Adding one is a two-line change in
/// [kQuranTranslations] — and a device check, since a retired Quran.com id comes
/// back as ayat with no translation rather than as an error.
///
/// Picking here re-fetches the surahs you have open. [ayatProvider] watches the
/// selection, and the repository caches per surah *and* translation, so the
/// switch costs one fetch per surah and switching back costs nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../domain/translation_provider.dart';
import 'widgets/settings_row.dart';

class TranslationScreen extends ConsumerWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final chosen = ref.watch(selectedTranslationProvider);
    final controller = ref.read(selectedTranslationProvider.notifier);

    // Grouped by language so the list reads as "English, then Bengali, then
    // Hindi" rather than as four unrelated names.
    final languages = <String>[];
    for (final t in kQuranTranslations) {
      if (!languages.contains(t.language)) languages.add(t.language);
    }

    return SettingsSubScaffold(
      title: 'Translation',
      children: [
        for (final language in languages) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MizanGeometry.gutter,
              22,
              MizanGeometry.gutter,
              10,
            ),
            child: MizanSectionLabel(language),
          ),
          for (final t in kQuranTranslations.where((t) => t.language == language))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MizanGeometry.gutter,
                0,
                MizanGeometry.gutter,
                MizanGeometry.gap,
              ),
              child: MizanRow(
                title: t.translator,
                subtitle: t.note,
                leading: Icon(
                  Icons.translate_rounded,
                  size: 20,
                  color: p.accentText,
                ),
                showChevron: false,
                trailing: _Check(on: t.id == chosen.id),
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.select(t);
                },
              ),
            ),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(
            MizanGeometry.gutter,
            12,
            MizanGeometry.gutter,
            MizanGeometry.gap,
          ),
          child: MizanSurface(
            tone: MizanTone.sunk,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 19,
                    color: p.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The Arabic never changes — only the translation line does. '
                    'A translation is one scholar\'s reading of the meaning, '
                    'which is why the translator is named on every ayah you '
                    'share.',
                    style: MizanType.body(color: p.muted).copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The gold tick on the selected row. A diamond, not a checkbox: this is a
/// one-of-many choice and the Mizan mark is already the app's "this one" glyph.
class _Check extends StatelessWidget {
  const _Check({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    if (!on) {
      // Holds the width so rows do not shift sideways as the pick moves.
      return const SizedBox(width: 22, height: 22);
    }
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Icon(Icons.check_rounded, size: 20, color: p.accentText),
      ),
    );
  }
}
