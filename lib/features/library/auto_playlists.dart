import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/sorted_songs.dart';

/// Lists nobody had to make.
///
/// Everything here is already known — what was played most, what is on the
/// device, what is still in the cache — and the only thing missing was a door
/// to it. They are computed on open rather than stored, so they are never out
/// of date and there is nothing to keep in step.
class AutoPlaylists extends StatelessWidget {
  const AutoPlaylists({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _Tile(
              icon: Icons.local_fire_department_rounded,
              label: l10n.autoTop,
              onTap: () => _open(context, l10n.autoTop, _top()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              icon: Icons.download_done_rounded,
              label: l10n.autoDownloads,
              onTap: () => _open(context, l10n.autoDownloads, downloads.songs),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              icon: Icons.offline_bolt_rounded,
              label: l10n.autoCached,
              onTap: () => _open(context, l10n.autoCached, _cached()),
            ),
          ),
        ],
      ),
    );
  }

  /// The hundred played most, ever — not over a window, since this is a
  /// listener's own chart rather than a snapshot of a month.
  static List<Song> _top() => playHistory
      .topSongs(DateTime.fromMillisecondsSinceEpoch(0), take: 100)
      .map((entry) => entry.song)
      .toList();

  /// What will play without the network: the cache holds files by video id and
  /// nothing else, so the names come from the log of what put them there.
  static List<Song> _cached() {
    final seen = <String>{};
    return [
      for (final song in playHistory.songs)
        if (audioCache.fileFor(song.videoId).existsSync() &&
            seen.add(song.videoId))
          song,
    ];
  }

  static void _open(BuildContext context, String title, List<Song> songs) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: songs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      AppLocalizations.of(context)!.libraryEmptyHistory,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SortedSongs(songs: songs),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
