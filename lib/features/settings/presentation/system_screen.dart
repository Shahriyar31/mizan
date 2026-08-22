/// System — real app version (package_info_plus), real temp-cache size
/// (path_provider) with a safe clear (temp dir only — never touches the
/// SQLite database, SharedPreferences, or the Supabase session). No
/// download feature exists yet, so no "download over Wi-Fi" toggle is
/// shown — nothing to gate. No update-check server exists — reported
/// honestly rather than faked.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/settings_row.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  PackageInfo? _info;
  int? _cacheBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    final size = await _dirSize(await getTemporaryDirectory());
    if (mounted) setState(() {
      _info = info;
      _cacheBytes = size;
    });
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } finally {
      final size = await _dirSize(await getTemporaryDirectory());
      if (mounted) {
        setState(() {
          _cacheBytes = size;
          _clearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'System',
      children: [
        const SettingsSectionLabel('Storage'),
        SettingsGroup(children: [
          SettingsRow(
            icon: Icons.storage_rounded,
            title: 'Cache',
            subtitle: _cacheBytes == null
                ? 'Calculating…'
                : _formatBytes(_cacheBytes!),
          ),
          SettingsRow(
            icon: Icons.cleaning_services_rounded,
            title: _clearing ? 'Clearing…' : 'Clear cache',
            subtitle: 'Temporary files only — your progress and account are safe',
            enabled: !_clearing,
            onTap: _clearCache,
          ),
        ]),
        const SettingsSectionLabel('Updates'),
        SettingsGroup(children: [
          SettingsRow(
            icon: Icons.system_update_rounded,
            title: 'Check for updates',
            subtitle: 'Not available — install updates from where you got the app',
          ),
        ]),
        const SettingsSectionLabel('About'),
        SettingsGroup(children: [
          SettingsRow(
            icon: Icons.info_outline_rounded,
            title: 'App version',
            subtitle: _info == null
                ? '…'
                : '${_info!.version} (${_info!.buildNumber})',
          ),
        ]),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Downloads aren\'t implemented yet, so there\'s no Wi-Fi-only '
            'setting to show.',
            style: AppTypography.bodySmall(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
