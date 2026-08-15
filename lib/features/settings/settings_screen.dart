import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../player/playback_sheet.dart';
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
            if (settings.equalizerEnabled) const EqualizerBands(),
            _Label(l10n.settingsStorage),
            const _StorageSummary(),
            SwitchListTile(
              title: Text(l10n.settingsCache),
              subtitle: Text(l10n.settingsCacheBody),
              value: settings.cacheEnabled,
              onChanged: settings.setCacheEnabled,
            ),
            if (settings.cacheEnabled) const _CacheLimit(),
            const _ClearCache(),
            _Label(l10n.settingsBackup),
            const _Backups(),
            _Label(l10n.settingsSleep),
            const SleepTimerControls(),
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

/// What the app is taking up, as two bars rather than two numbers.
///
/// Storage settings are where people go when a phone is full, and the question
/// they arrive with is "what is big" — a bar answers that before the number is
/// read, and shows the cache against its own ceiling rather than against the
/// device.
class _StorageSummary extends StatefulWidget {
  const _StorageSummary();

  @override
  State<_StorageSummary> createState() => _StorageSummaryState();
}

class _StorageSummaryState extends State<_StorageSummary> {
  late Future<({int downloads, int cache})> _sizes = _measure();

  Future<({int downloads, int cache})> _measure() async => (
        downloads: await downloads.sizeInBytes(),
        cache: await audioCache.sizeInBytes(),
      );

  void _remeasure() => setState(() => _sizes = _measure());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final limit = settings.cacheLimitMb * 1024 * 1024;

    return FutureBuilder<({int downloads, int cache})>(
      future: _sizes,
      builder: (context, snapshot) {
        final sizes = snapshot.data ?? (downloads: 0, cache: 0);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StorageBar(
                label: l10n.libraryDownloads,
                used: sizes.downloads,
                // Downloads have no ceiling of their own, so they are drawn
                // against the cache's — enough to compare the two.
                of: limit,
                value: megabytes(sizes.downloads),
              ),
              const SizedBox(height: 14),
              _StorageBar(
                label: l10n.settingsStorageCache,
                used: sizes.cache,
                of: limit,
                value: '${megabytes(sizes.cache)} / ${settings.cacheLimitMb} MB',
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _remeasure,
                  child: Text(l10n.settingsStorageRefresh),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({
    required this.label,
    required this.used,
    required this.of,
    required this.value,
  });

  final String label;
  final int used;
  final int of;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: of == 0 ? 0 : (used / of).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
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

class _Backups extends StatefulWidget {
  const _Backups();

  @override
  State<_Backups> createState() => _BackupsState();
}

class _BackupsState extends State<_Backups> {
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

    return Column(
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
