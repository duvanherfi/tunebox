import 'package:flutter/material.dart';

import '../../core/audio/player_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// What the app is taking up and how much of it it is allowed to take.
class StorageSettingsScreen extends StatelessWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsStorage)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            const _StorageSummary(),
            // Offered only where it can do something: caching while streaming
            // is the one thing Apple's player refuses to open, so elsewhere the
            // switch would be a promise the audio path cannot keep. What is
            // already on disk still has its size and its clear button below.
            if (PlayerService.supportsStreamCaching) ...[
              SwitchListTile(
                title: Text(l10n.settingsCache),
                subtitle: Text(l10n.settingsCacheBody),
                value: settings.cacheEnabled,
                onChanged: settings.setCacheEnabled,
              ),
              if (settings.cacheEnabled) const _CacheLimit(),
            ],
            const _ClearCache(),
          ],
        ),
      ),
    );
  }
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
