import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// Writing and restoring copies of the listening log and the settings.
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _write() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await backup.write();
    if (mounted) _report(l10n.settingsBackupWritten(file.path));
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    final copies = await backup.list();
    if (!mounted) return;
    if (copies.isEmpty) {
      _report(l10n.settingsBackupNone);
      return;
    }

    final chosen = await showModalBottomSheet<File>(
      context: context,
      // Above the shell, or it opens under the player bar.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final copy in copies)
              ListTile(
                leading: const Icon(Icons.restore_page_outlined),
                title: Text(copy.uri.pathSegments.last),
                onTap: () => Navigator.of(context).pop(copy),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    await backup.restore(chosen);
    if (mounted) _report(l10n.settingsBackupRestored);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsBackup)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          SwitchListTile(
            title: Text(l10n.settingsBackupAuto),
            subtitle: Text(l10n.settingsBackupAutoBody),
            value: backup.automatic,
            onChanged: (value) async {
              await backup.setAutomatic(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: Text(l10n.settingsBackupNow),
            onTap: _write,
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: Text(l10n.settingsBackupRestore),
            onTap: _restore,
          ),
        ],
      ),
    );
  }
}
