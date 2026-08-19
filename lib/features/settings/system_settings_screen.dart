import 'package:flutter/material.dart';

import '../../data/home_widget_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'section_label.dart';
import 'update_sheet.dart';

/// What the app asks of the platform around it.
///
/// Only Android has anything here, so the index hides the whole entry
/// elsewhere rather than opening an empty screen.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSystem)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: Text(l10n.settingsWidget),
            subtitle: Text(l10n.settingsWidgetBody),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final asked = await requestWidgetOnHomeScreen();
              if (!asked) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.settingsWidgetManual)),
                );
              }
            },
          ),
          SettingsLabel(l10n.settingsUpdates),
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: Text(l10n.settingsUpdateNow),
                  // The version installed right now, because "look for
                  // updates" is a question about a number nobody remembers.
                  subtitle: Text(
                    l10n.settingsUpdatesInstalled(
                      updates.installed?.toString() ?? '',
                    ),
                  ),
                  // Asked for by hand, so it answers even when the answer is
                  // that there is nothing.
                  onTap: () => showUpdateSheet(context, checkOnOpen: true),
                ),
                SwitchListTile(
                  title: Text(l10n.settingsUpdateCheck),
                  subtitle: Text(l10n.settingsUpdateCheckBody),
                  value: settings.updateCheck,
                  onChanged: settings.setUpdateCheck,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
