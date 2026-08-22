/// Audio — MP3Quran reciter/moshaf selection, connected to the Quran
/// reader's shared player (features/quran/domain/audio_providers.dart).
/// Playback speed is wired (just_audio supports it). Downloads/background
/// playback aren't implemented — not faked here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../quran/domain/audio_providers.dart';
import 'widgets/settings_row.dart';

class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitersAsync = ref.watch(recitersProvider);
    final pair = ref.watch(selectedMoshafProvider);

    return SettingsSubScaffold(
      title: 'Audio',
      children: [
        const SettingsSectionLabel('Reciter'),
        recitersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SettingsGroup(children: [
            SettingsRow(
              icon: Icons.error_outline_rounded,
              title: 'Could not load reciters',
              subtitle: 'Check your connection and try again',
              onTap: () async {
                await clearRecitersCache();
                ref.invalidate(recitersProvider);
              },
            ),
          ]),
          data: (reciters) => SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.mic_rounded,
                title: pair?.$1.name ?? 'Choose a reciter',
                subtitle: pair != null
                    ? pair.$2.name
                    : '${reciters.length} reciters available',
                onTap: () => _pickReciter(context, ref, reciters),
              ),
            ],
          ),
        ),
        if (pair != null) ...[
          const SettingsSectionLabel('Playback Speed'),
          const _SpeedRow(),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Downloads and background lock-screen controls aren\'t '
            'implemented yet — audio streams while the app is open.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  void _pickReciter(BuildContext context, WidgetRef ref, List reciters) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReciterPicker(reciters: reciters.cast()),
    );
  }
}

class _ReciterPicker extends ConsumerWidget {
  const _ReciterPicker({required this.reciters});
  final List reciters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choose a reciter',
                  style: AppTypography.displaySmall(color: AppColors.textPrimary)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: reciters.length,
                itemBuilder: (context, i) {
                  final reciter = reciters[i];
                  return ExpansionTile(
                    iconColor: AppColors.gold,
                    collapsedIconColor: AppColors.muted,
                    title: Text(reciter.name,
                        style: AppTypography.labelLarge(color: AppColors.textPrimary)),
                    children: [
                      for (final moshaf in reciter.moshaf)
                        Consumer(
                          builder: (context, ref, _) {
                            final selected =
                                ref.watch(selectedReciterProvider);
                            final isSelected = selected?.reciterId ==
                                    reciter.id &&
                                selected?.moshafId == moshaf.id;
                            return SettingsRow(
                              icon: Icons.graphic_eq_rounded,
                              title: moshaf.name,
                              subtitle: '${moshaf.surahList.length} surahs',
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded,
                                      size: 18, color: AppColors.gold)
                                  : null,
                              onTap: () {
                                ref
                                    .read(selectedReciterProvider.notifier)
                                    .select(reciter.id, moshaf.id);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedRow extends ConsumerWidget {
  const _SpeedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(quranAudioProvider.notifier);
    return SettingsGroup(children: [
      StreamBuilder<double>(
        stream: controller.player.speedStream,
        initialData: controller.player.speed,
        builder: (context, snapshot) {
          final speed = snapshot.data ?? 1.0;
          return SettingsRow(
            icon: Icons.speed_rounded,
            title: 'Speed',
            subtitle: '${speed.toStringAsFixed(2)}x',
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: speed,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                activeColor: AppColors.gold,
                inactiveColor: AppColors.border,
                onChanged: (v) => controller.setSpeed(v),
              ),
            ),
          );
        },
      ),
    ]);
  }
}
