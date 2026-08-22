/// Settings — grouped into ACCOUNT / PREFERENCES / APP, each its own
/// visually distinct card group.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/settings_providers.dart';
import 'widgets/settings_row.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Text('Settings',
                  style: AppTypography.displayLarge(color: AppColors.textPrimary)),
            ),

            // ── Account ──────────────────────────────────────────
            const SettingsSectionLabel('Account'),
            _AccountGroup(auth: auth),

            const SizedBox(height: 24),

            // ── Preferences ──────────────────────────────────────
            const SettingsSectionLabel('Preferences'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Daily notifications, reminders, notification time',
                  onTap: () => context.push('/settings/notifications'),
                ),
                SettingsRow(
                  icon: Icons.tune_rounded,
                  title: 'Personalisation',
                  subtitle: 'Theme, Arabic font, translation, transliteration, text size',
                  onTap: () => context.push('/settings/personalisation'),
                ),
                SettingsRow(
                  icon: Icons.headphones_rounded,
                  title: 'Audio',
                  subtitle: 'Reciter, moshaf, playback speed',
                  onTap: () => context.push('/settings/audio'),
                ),
                SettingsRow(
                  icon: Icons.settings_outlined,
                  title: 'System',
                  subtitle: 'Downloads, storage, updates',
                  onTap: () => context.push('/settings/system'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── App ──────────────────────────────────────────────
            const SettingsSectionLabel('App'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: 'Change the language across the app',
                  onTap: () => context.push('/settings/language'),
                ),
                SettingsRow(
                  icon: Icons.more_horiz_rounded,
                  title: 'More',
                  subtitle: 'FAQ, tutorial, terms, privacy, about',
                  onTap: () => context.push('/settings/more'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountGroup extends ConsumerWidget {
  const _AccountGroup({required this.auth});
  final AuthState auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (auth.loading) {
      return const SettingsGroup(children: [
        SettingsRow(icon: Icons.person_outline_rounded, title: 'Loading…'),
      ]);
    }

    if (!auth.signedIn) {
      return SettingsGroup(children: [
        SettingsRow(
          icon: Icons.person_outline_rounded,
          title: 'Sign in',
          subtitle:
              'Create an account or sign in to sync your Halaqa and Al-Minbar activity',
          onTap: () => context.go(auth.hasAccount ? '/auth?login=1' : '/auth'),
        ),
      ]);
    }

    final account = auth.account!;
    return SettingsGroup(children: [
      SettingsRow(
        icon: Icons.person_rounded,
        title: account.name,
        subtitle: account.email,
      ),
      SettingsRow(
        icon: Icons.cloud_done_rounded,
        title: 'Signed in',
        subtitle: 'Your Halaqa and Al-Minbar activity is synced',
      ),
      SettingsRow(
        icon: Icons.logout_rounded,
        title: 'Sign out',
        onTap: () => ref.read(authControllerProvider.notifier).logOut(),
      ),
      SettingsRow(
        icon: Icons.delete_outline_rounded,
        title: 'Delete account',
        subtitle: 'Signs you out and forgets this device',
        onTap: () => _confirmDelete(context, ref),
      ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete account?',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        content: Text(
          'This signs you out and removes this device\'s saved sign-in. '
          'Your account itself is not permanently deleted from the server '
          'from here — contact support for full account deletion.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete',
                style: AppTypography.buttonSecondary(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    }
  }
}
