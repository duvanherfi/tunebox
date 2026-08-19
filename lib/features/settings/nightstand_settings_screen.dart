import 'package:flutter/material.dart';

import '../../data/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'section_label.dart';

/// Everything about the nightstand screen, since none of it belongs anywhere
/// else: what it draws, how bright it is, and whether it ever comes up on its
/// own.
class NightstandSettingsScreen extends StatelessWidget {
  const NightstandSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNightstand)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SettingsLabel(l10n.nightstandShows),
            SwitchListTile(
              title: Text(l10n.nightstandClock),
              value: settings.nightstandClock,
              onChanged: settings.setNightstandClock,
            ),
            SwitchListTile(
              title: Text(l10n.nightstandArt),
              value: settings.nightstandArt,
              onChanged: settings.setNightstandArt,
            ),
            SwitchListTile(
              title: Text(l10n.nightstandTrack),
              value: settings.nightstandTitle,
              onChanged: settings.setNightstandTitle,
            ),
            SwitchListTile(
              title: Text(l10n.nightstandProgress),
              value: settings.nightstandProgress,
              onChanged: settings.setNightstandProgress,
            ),
            SettingsLabel(l10n.nightstandControlsLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<NightstandControls>(
                segments: [
                  ButtonSegment(
                    value: NightstandControls.always,
                    label: Text(l10n.nightstandControlsAlways),
                  ),
                  ButtonSegment(
                    value: NightstandControls.onTouch,
                    label: Text(l10n.nightstandControlsOnTouch),
                  ),
                  ButtonSegment(
                    value: NightstandControls.never,
                    label: Text(l10n.nightstandControlsNever),
                  ),
                ],
                selected: {settings.nightstandControls},
                onSelectionChanged: (chosen) =>
                    settings.setNightstandControls(chosen.first),
              ),
            ),
            _Note(l10n.nightstandControlsBody),
            SettingsLabel(l10n.nightstandScreenLabel),
            ListTile(
              title: Text(l10n.nightstandDim(settings.nightstandDim)),
              subtitle: Slider(
                value: settings.nightstandDim.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                onChanged: (value) => settings.setNightstandDim(value.round()),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.nightstandBurnIn),
              subtitle: Text(l10n.nightstandBurnInBody),
              value: settings.nightstandBurnIn,
              onChanged: settings.setNightstandBurnIn,
            ),
            SettingsLabel(l10n.nightstandEnters),
            ListTile(
              title: Text(l10n.nightstandIdle),
              subtitle: Text(l10n.nightstandIdleBody),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final seconds in const [0, 30, 60, 120, 300])
                    ChoiceChip(
                      label: Text(_idleLabel(l10n, seconds)),
                      selected: settings.nightstandIdleSeconds == seconds,
                      onSelected: (_) =>
                          settings.setNightstandIdleSeconds(seconds),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text(l10n.nightstandOnCharge),
              subtitle: Text(l10n.nightstandOnChargeBody),
              value: settings.nightstandOnCharge,
              onChanged: settings.setNightstandOnCharge,
            ),
          ],
        ),
      ),
    );
  }

  String _idleLabel(AppLocalizations l10n, int seconds) => switch (seconds) {
        0 => l10n.nightstandIdleNever,
        < 60 => l10n.nightstandIdleSeconds(seconds),
        _ => l10n.nightstandIdleMinutes(seconds ~/ 60),
      };
}

/// The sentence under a control that a subtitle cannot carry, because the
/// control it explains is not a ListTile.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
