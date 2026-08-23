/// SETTINGS — the eighth screen.
///
/// Rebuilt from `Mizan Light.pdf` / `Mizan Dark.pdf` page 9 (screen 08 of 08).
/// Reached from any tab, not from the tab bar, which is why it has no tab of its
/// own and why the shell lights nothing while you are here.
///
/// ── Subtitles describe the destination, not a value ───────────────────
/// The mockup's rows carry live readings: "Daily reminder at 6:30 AM",
/// "Mishary al-Afasy · 1.0×", "Sahih International · English", "3 surahs
/// downloaded · 84 MB", "Version 1.0.0". Every one of those is a specific claim
/// about the user's current state, and none of it is exposed by a provider this
/// screen can read today. Printing them would mean five numbers that look
/// authoritative and are decoration.
///
/// So each subtitle says what lives behind the row instead. The exception is
/// **App icon**, which reads the real [logoVariantProvider] — that one is a live
/// value, so it is shown as one.
///
/// Wiring any of the others up is a small job per row: expose the stored value
/// as a provider from its own settings screen, then swap the static string.
///
/// ── Rows are grouped inside one card, not stacked as cards ────────────
/// The mockup draws a single card per section with hairlines between rows.
/// [MizanRow] is a standalone card with its own border, so stacking four of them
/// would give four cards. [_SettingsGroup] therefore owns the surface and each
/// [_SettingsRow] is a flat pressable inside it — depth belongs to the group, and
/// the 1px press nudge still fires per row.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/mizan_brand.dart';
import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../../../shared/widgets/mizan/mizan_pressable.dart';
import '../domain/settings_providers.dart';
import '../domain/translation_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final logoVariant = ref.watch(logoVariantProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MizanGeometry.gutter,
            10,
            MizanGeometry.gutter,
            MizanGeometry.scrollBottomPadding,
          ),
          children: [
            const _HeaderRow(),
            const SizedBox(height: 16),
            _AccountPanel(auth: auth),
            const SizedBox(height: 26),

            const MizanSectionLabel('Preferences'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Daily reminder, quiet hours, reminder time',
                  onTap: () => context.push('/settings/notifications'),
                ),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme, Arabic font, translation, text size',
                  onTap: () => context.push('/settings/personalisation'),
                ),
                // A live value, like App icon: the translator's name is the
                // whole point of the row, so it is read from the provider
                // rather than described.
                _SettingsRow(
                  icon: Icons.translate_rounded,
                  title: 'Translation',
                  subtitle: ref.watch(selectedTranslationProvider).label,
                  onTap: () => context.push('/settings/translation'),
                ),
                _SettingsRow(
                  icon: Icons.headphones_outlined,
                  title: 'Audio',
                  subtitle: 'Reciter, moshaf, playback speed',
                  onTap: () => context.push('/settings/audio'),
                ),
              ],
            ),
            const SizedBox(height: 26),

            const MizanSectionLabel('Data'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.cloud_download_outlined,
                  title: 'Offline & storage',
                  subtitle: 'Downloads, cached audio, storage used',
                  onTap: () => context.push('/settings/system'),
                ),
              ],
            ),
            const SizedBox(height: 26),

            const MizanSectionLabel('App'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: 'Change the language across the app',
                  onTap: () => context.push('/settings/language'),
                ),
                _SettingsRow(
                  icon: Icons.apps_rounded,
                  title: 'App icon',
                  // A real reading. Null means the user has never chosen, in
                  // which case the mark follows the active theme.
                  subtitle: logoVariant == null
                      ? 'Follows your theme'
                      : '${logoVariant.label} · ${logoVariant.description}',
                  onTap: () =>
                      context.push('/settings/personalisation/app-icon'),
                ),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Mizan',
                  subtitle: 'Sources, scholars, terms and privacy',
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

// ══════════════════════════════════════════════════════════════════════
//  HEADER + THEME PILL
// ══════════════════════════════════════════════════════════════════════

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    final mode = ref.watch(themeModeProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text('Settings', style: MizanType.screenTitle(color: p.ink)),
        ),
        const SizedBox(width: 12),
        // The pill states the mode you are in and switches to the next one, so
        // the whole light/dark/system cycle is reachable without opening
        // Appearance. Rule #3 in one tap.
        MizanButton(
          label: mode.pillLabel,
          icon: mode.pillIcon,
          kind: MizanButtonKind.secondary,
          onPressed: () =>
              ref.read(themeModeProvider.notifier).set(mode.nextInCycle),
        ),
      ],
    );
  }
}

extension on ThemeMode {
  String get pillLabel => switch (this) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  IconData get pillIcon => switch (this) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.brightness_auto_outlined,
      };

  /// Light → Dark → System → Light. System sits last because it is the least
  /// obvious of the three and shouldn't be something you land on by accident.
  ThemeMode get nextInCycle => switch (this) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };
}

// ══════════════════════════════════════════════════════════════════════
//  ACCOUNT
// ══════════════════════════════════════════════════════════════════════

/// The navy panel at the top. Same slot in all three auth states, because a
/// panel that appears and disappears makes the screen jump on every launch while
/// the session resolves.
class _AccountPanel extends ConsumerWidget {
  const _AccountPanel({required this.auth});

  final AuthState auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MizanPalette.of(context);
    const tone = MizanTone.inverse;

    final (String title, String subtitle, VoidCallback? onTap) = switch (auth) {
      AuthState(loading: true) => ('Checking your account', '—', null),
      AuthState(signedIn: false) => (
          'Sign in',
          'Sync your Halaqa and Al-Minbar across devices',
          () => context.go(auth.hasAccount ? '/auth?login=1' : '/auth'),
        ),
      _ => (
          auth.account!.name,
          'Synced · ${auth.account!.email}',
          () => _showAccountSheet(context, ref, auth),
        ),
    };

    return MizanSurface(
      tone: tone,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accent.withValues(alpha: 0.14),
              border: Border.all(
                color: p.accent.withValues(alpha: 0.38),
                width: MizanGeometry.hairlineWidth,
              ),
            ),
            child: auth.signedIn
                ? Text(
                    auth.account!.initial,
                    style: MizanType.cardHeadline(color: tone.accentTextOn(p)),
                  )
                : Icon(Icons.person_outline_rounded,
                    size: 24, color: tone.accentTextOn(p)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MizanType.bodyStrong(color: tone.onColor(p))
                      .copyWith(fontSize: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MizanType.body(color: tone.mutedOn(p)),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 24, color: tone.accentTextOn(p)),
          ],
        ],
      ),
    );
  }
}

/// Sign out and account deletion live behind the panel's chevron rather than as
/// two more rows in the list — they are the only destructive things on the screen
/// and shouldn't sit one mis-tap away from "Language".
void _showAccountSheet(BuildContext context, WidgetRef ref, AuthState auth) {
  final p = MizanPalette.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(MizanGeometry.gutter),
      child: MizanSurface(
        tone: MizanTone.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MizanSectionLabel('Account'),
            const SizedBox(height: 8),
            Text(
              auth.account?.name ?? 'Your account',
              style: MizanType.cardHeadline(color: p.ink),
            ),
            const SizedBox(height: 4),
            Text(
              auth.account?.email ?? '',
              style: MizanType.body(color: p.muted),
            ),
            const SizedBox(height: 18),
            MizanButton(
              label: 'Sign out',
              kind: MizanButtonKind.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                ref.read(authControllerProvider.notifier).logOut();
              },
            ),
            const SizedBox(height: 10),
            MizanButton(
              label: 'Delete account',
              kind: MizanButtonKind.quiet,
              expand: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final p = MizanPalette.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: MizanGeometry.cardBorderRadius,
        side: BorderSide(color: p.hairline, width: MizanGeometry.hairlineWidth),
      ),
      title: Text('Delete account?',
          style: MizanType.cardHeadline(color: p.ink)),
      // Unchanged wording: it is careful about what this actually does, and
      // overstating it would be worse than a plain dialog.
      content: Text(
        'This signs you out and removes this device\'s saved sign-in. '
        'Your account itself is not permanently deleted from the server '
        'from here — contact support for full account deletion.',
        style: MizanType.body(color: p.muted),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        MizanButton(
          label: 'Cancel',
          kind: MizanButtonKind.quiet,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        MizanButton(
          label: 'Delete',
          kind: MizanButtonKind.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(authControllerProvider.notifier).deleteAccount();
  }
}

// ══════════════════════════════════════════════════════════════════════
//  GROUPED ROWS
// ══════════════════════════════════════════════════════════════════════

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      tone: MizanTone.card,
      // The rows own their padding so a press highlight reaches the card edge.
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) MizanRule(color: p.hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanPressable(
      onTap: onTap,
      // Flat: the group card already carries the depth, and a raised row inside
      // a card reads as a mistake.
      fill: Colors.transparent,
      shadowsEnabled: false,
      borderRadius: MizanGeometry.rowBorderRadius,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          // Bronze on cream, gold on navy — the gold family as a glyph, never as
          // gold text on cream.
          Icon(icon, size: 23, color: p.accentText),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MizanType.bodyStrong(color: p.ink)
                      .copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: MizanType.body(color: p.muted).copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
        ],
      ),
    );
  }
}
