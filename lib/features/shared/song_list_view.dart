import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'playing_bars.dart';
import 'song_menu.dart';

/// Renders tracks and starts playback on tap.
///
/// Shared by search, liked songs, history and playlist contents: all four are
/// the same interaction, and tapping any row seeds the queue with the rest of
/// the list so what is on screen becomes what plays next.
class SongListView extends StatelessWidget {
  const SongListView({super.key, required this.songs, this.padding});

  final List<Song> songs;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding:
          padding ??
          EdgeInsets.only(bottom: 8 + MediaQuery.paddingOf(context).bottom),
      itemCount: songs.length,
      itemBuilder: (context, index) => SongRow(songs: songs, index: index),
    );
  }
}

/// One track in a list, together with the list it belongs to.
///
/// It takes the whole list rather than a single song because tapping a row has
/// always meant "play from here": the queue that follows is the rest of what
/// was on screen.
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.songs,
    required this.index,
    this.numbered = false,
  });

  final List<Song> songs;
  final int index;

  /// Shows the track's position instead of its cover. On an album every row
  /// would otherwise repeat the same sleeve — or, since YouTube omits it there,
  /// the same grey placeholder.
  final bool numbered;

  Future<void> _play(BuildContext context) async {
    // A tap that starts a track resolves over the network before anything
    // moves on screen; the tick is the acknowledgement in the meantime.
    unawaited(HapticFeedback.selectionClick());
    try {
      await playerService.setQueue(songs, startIndex: index);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.playbackFailed('')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = songs[index];

    return StreamBuilder<MediaItem?>(
      stream: playerService.mediaItem,
      builder: (context, snapshot) {
        final current = snapshot.data?.id == song.videoId;
        return _row(context, theme, song, current);
      },
    );
  }

  Widget _row(
    BuildContext context,
    ThemeData theme,
    Song song,
    bool current,
  ) {
    return InkWell(
      onTap: () => _play(context),
      // Both ways in, because both are habits: the long press comes from the
      // phone, the button from every music app that has ever had a row of
      // three dots at the end of a track.
      onLongPress: () => showSongMenu(context, song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (current)
              // The mark goes where the artwork was: same footprint, so rows
              // do not shift as the queue moves through them.
              SizedBox(
                width: 44,
                child: Center(
                  child: StreamBuilder<PlaybackState>(
                    stream: playerService.playbackState,
                    builder: (context, state) => PlayingBars(
                      playing: state.data?.playing ?? false,
                      size: 18,
                    ),
                  ),
                ),
              )
            else if (numbered)
              SizedBox(
                width: 44,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              )
            else
              Artwork(url: song.thumbnailUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: current ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Duration sits apart from the metadata line so the eye can scan a
            // column of times without reading every subtitle.
            if (song.duration != null) ...[
              const SizedBox(width: 12),
              Text(
                _format(song.duration!),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            IconButton(
              tooltip: AppLocalizations.of(context)!.tipMore,
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showSongMenu(context, song),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
