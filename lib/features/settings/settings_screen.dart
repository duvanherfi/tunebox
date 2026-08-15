import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// Everything about how the music sounds and how long it keeps sounding.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Label(l10n.settingsPlayback),
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
            _Label(l10n.settingsEqualizer),
            SwitchListTile(
              title: Text(l10n.settingsEqualizerOn),
              value: settings.equalizerEnabled,
              onChanged: settings.setEqualizerEnabled,
            ),
            if (settings.equalizerEnabled) const _EqualizerBands(),
            _Label(l10n.settingsStorage),
            SwitchListTile(
              title: Text(l10n.settingsCache),
              subtitle: Text(l10n.settingsCacheBody),
              value: settings.cacheEnabled,
              onChanged: settings.setCacheEnabled,
            ),
            if (settings.cacheEnabled) const _CacheLimit(),
            const _ClearCache(),
            _Label(l10n.settingsSleep),
            const _SleepTimer(),
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
class _EqualizerBands extends StatelessWidget {
  const _EqualizerBands();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<AndroidEqualizerParameters>(
      future: playerService.equalizer.parameters,
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

class _CacheLimit extends StatelessWidget {
  const _CacheLimit();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.settingsCacheLimit(settings.cacheLimitMb)),
      subtitle: Slider(
        value: settings.cacheLimitMb.toDouble(),
        min: 128,
        max: 4096,
        divisions: 31,
        label: '${settings.cacheLimitMb} MB',
        onChanged: (value) => settings.setCacheLimitMb(value.round()),
      ),
    );
  }
}

/// Shows what the cache currently costs, because "clear the cache" without a
/// number is a question nobody can answer.
class _ClearCache extends StatefulWidget {
  const _ClearCache();

  @override
  State<_ClearCache> createState() => _ClearCacheState();
}

class _ClearCacheState extends State<_ClearCache> {
  late Future<int> _size = audioCache.sizeInBytes();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<int>(
      future: _size,
      builder: (context, snapshot) {
        final bytes = snapshot.data ?? 0;
        return ListTile(
          leading: const Icon(Icons.delete_outline_rounded),
          title: Text(l10n.settingsCacheClear(_megabytes(bytes))),
          enabled: bytes > 0,
          onTap: () async {
            await audioCache.clear();
            if (mounted) setState(() => _size = audioCache.sizeInBytes());
          },
        );
      },
    );
  }

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _SleepTimer extends StatelessWidget {
  const _SleepTimer();

  static const _choices = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: playerService.sleepAt,
      builder: (context, endsAt, _) {
        final remaining = endsAt?.difference(DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final choice in _choices)
                    ChoiceChip(
                      label: Text(l10n.settingsSleepMinutes(choice.inMinutes)),
                      selected: false,
                      onSelected: (_) => playerService.sleepAfter(choice),
                    ),
                ],
              ),
            ),
            if (remaining != null && !remaining.isNegative)
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text(
                  l10n.settingsSleepPending(remaining.inMinutes + 1),
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                trailing: TextButton(
                  onPressed: () => playerService.sleepAfter(null),
                  child: Text(l10n.cancel),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
