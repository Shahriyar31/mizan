/// Notifications — real local scheduled reminders (flutter_local_notifications),
/// no server/push. Preferences persist via notificationPreferencesProvider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/notification_preferences_provider.dart';
import 'widgets/settings_row.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);

    return SettingsSubScaffold(
      title: 'Notifications',
      children: [
        const SettingsSectionLabel('General'),
        SettingsGroup(children: [
          SettingsRow(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Turn all reminders on or off',
            trailing: Switch(
              value: prefs.masterEnabled,
              activeThumbColor: AppColors.gold,
              onChanged: controller.setMaster,
            ),
          ),
        ]),
        if (prefs.masterEnabled) ...[
          const SettingsSectionLabel('Daily content'),
          SettingsGroup(children: [
            SettingsRow(
              icon: Icons.menu_book_rounded,
              title: 'Ayah to Sit With',
              trailing: Switch(
                value: prefs.dailyAyah,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => controller.setCategory(dailyAyah: v),
              ),
            ),
            SettingsRow(
              icon: Icons.favorite_border_rounded,
              title: 'Daily Dua',
              trailing: Switch(
                value: prefs.dailyDua,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => controller.setCategory(dailyDua: v),
              ),
            ),
            SettingsRow(
              icon: Icons.auto_awesome_rounded,
              title: "Today's Encounter",
              trailing: Switch(
                value: prefs.todaysEncounter,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => controller.setCategory(todaysEncounter: v),
              ),
            ),
            SettingsRow(
              icon: Icons.school_rounded,
              title: 'Learning reminder',
              subtitle: 'Nudge to continue where you left off',
              trailing: Switch(
                value: prefs.learningReminder,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => controller.setCategory(learningReminder: v),
              ),
            ),
          ]),
          const SettingsSectionLabel('Time'),
          SettingsGroup(children: [
            SettingsRow(
              icon: Icons.schedule_rounded,
              title: 'Notification time',
              subtitle: prefs.time.format(context),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: prefs.time,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context)
                          .colorScheme
                          .copyWith(primary: AppColors.gold),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) await controller.setTime(picked);
              },
            ),
          ]),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Reminders are scheduled on this device only — no account or '
            'internet connection required.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
