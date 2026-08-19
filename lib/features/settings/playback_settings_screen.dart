import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/player_service.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'section_label.dart';

/// How the music sounds: what happens when a track ends, how fast it runs, and
/// the bands underneath it.
///
/// The sleep timer used to live here. It is an instruction about what is
/// playing right now, not a preference that survives the app, so it stays in
/// the player's own sheet where the music is.
class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSound)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SettingsLabel(l10n.settingsPlayback),
            SwitchListTile(
              title: Text(l10n.settingsAutoplay),
              subtitle: Text(l10n.settingsAutoplayBody),
              value: settings.autoplay,
              onChanged: settings.setAutoplay,
            ),
            SwitchListTile(
              title: Text(l10n.settingsSkipSilence),
              subtitle: Text(l10n.settingsSkipSilenceBody),
              value: settings.skipSilence,
              onChanged: settings.setSkipSilence,
            ),
            SwitchListTile(
              title: Text(l10n.settingsNormalize),
              subtitle: Text(l10n.settingsNormalizeBody),
              value: settings.normalizeVolume,
              onChanged: settings.setNormalizeVolume,
            ),
            const _SpeedSlider(),
            ListTile(
              title: Text(l10n.settingsFade),
              subtitle: Text(l10n.settingsFadeBody),
            ),
            Slider(
              value: settings.fadeSeconds.toDouble(),
              max: 12,
              divisions: 12,
              label: l10n.settingsFadeValue(settings.fadeSeconds),
              onChanged: (value) => settings.setFadeSeconds(value.round()),
            ),
            SwitchListTile(
              title: Text(l10n.settingsKeepAwake),
              subtitle: Text(l10n.settingsKeepAwakeBody),
              value: settings.keepAwake,
              onChanged: settings.setKeepAwake,
            ),
            // The equalizer belongs to Android's audio session; nothing behind
            // it exists elsewhere, and a switch that cannot change anything is
            // worse than no switch.
            if (PlayerService.supportsEqualizer) ...[
              SettingsLabel(l10n.settingsEqualizer),
              SwitchListTile(
                title: Text(l10n.settingsEqualizerOn),
                value: settings.equalizerEnabled,
                onChanged: settings.setEqualizerEnabled,
              ),
              if (settings.equalizerEnabled) const EqualizerBands(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.settingsSpeed(settings.speed.toStringAsFixed(2))),
      subtitle: Slider(
        value: settings.speed,
        min: 0.5,
        max: 2,
        // Steps rather than a continuous slide: nobody wants 1.03×, and the
        // labelled stops are what people actually reach for.
        divisions: 6,
        label: '${settings.speed.toStringAsFixed(2)}×',
        onChanged: settings.setSpeed,
      ),
    );
  }
}

/// The device's own equalizer bands.
///
/// How many there are and where they sit is decided by the hardware, so the
/// sliders are built from what it reports rather than from a fixed list.
class EqualizerBands extends StatelessWidget {
  const EqualizerBands({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<AndroidEqualizerParameters>(
      future: playerService.equalizer?.parameters,
      builder: (context, snapshot) {
        final parameters = snapshot.data;
        if (parameters == null) {
          // Android only hands over the bands once an audio session exists, so
          // with nothing playing there is nothing to draw — and a spinner alone
          // would look like a hang rather than a wait for the music.
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.settingsEqualizerIdle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final band in parameters.bands)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        _hertz(band.centerFrequency),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<double>(
                        stream: band.gainStream,
                        builder: (context, gain) => Slider(
                          value: gain.data ?? band.gain,
                          min: parameters.minDecibels,
                          max: parameters.maxDecibels,
                          onChanged: (value) async {
                            await band.setGain(value);
                            await settings.setBandGains(
                              parameters.bands.map((b) => b.gain).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _hertz(double frequency) => frequency >= 1000
      ? '${(frequency / 1000).toStringAsFixed(frequency % 1000 == 0 ? 0 : 1)} kHz'
      : '${frequency.round()} Hz';
}
