import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'appearance_screen.dart';
import 'backup_settings_screen.dart';
import 'playback_settings_screen.dart';
import 'storage_settings_screen.dart';
import 'system_settings_screen.dart';

/// One door per domain.
///
/// This screen used to be the domains themselves, stacked: playback, the
/// equalizer, storage, the home screen widget and backups under a title that
/// only named the first of them. Anything past the fade slider was found by
/// scrolling into it rather than by looking for it. Each row now says what is
/// behind it, and the subtitle says it again in the words people arrive with.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    void open(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _Entry(
            icon: Icons.tune_rounded,
            title: l10n.settingsSound,
            body: l10n.settingsSoundBody,
            onTap: () => open(const PlaybackSettingsScreen()),
          ),
          _Entry(
            icon: Icons.sd_storage_outlined,
            title: l10n.settingsStorage,
            body: l10n.settingsStorageBody,
            onTap: () => open(const StorageSettingsScreen()),
          ),
          _Entry(
            icon: Icons.cloud_upload_outlined,
            title: l10n.settingsBackup,
            body: l10n.settingsBackupBody,
            onTap: () => open(const BackupSettingsScreen()),
          ),
          _Entry(
            icon: Icons.palette_outlined,
            title: l10n.accountAppearance,
            body: l10n.settingsAppearanceBody,
            onTap: () => open(const AppearanceScreen()),
          ),
          // The widget is the only thing behind this door, and it is Android's
          // alone; elsewhere the row would open on nothing.
          if (Platform.isAndroid)
            _Entry(
              icon: Icons.phone_android_rounded,
              title: l10n.settingsSystem,
              body: l10n.settingsSystemBody,
              onTap: () => open(const SystemSettingsScreen()),
            ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
