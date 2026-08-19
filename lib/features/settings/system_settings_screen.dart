import 'package:flutter/material.dart';

import '../../data/home_widget_bridge.dart';
import '../../l10n/app_localizations.dart';

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
        ],
      ),
    );
  }
}
