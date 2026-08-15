import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../main.dart';

/// Renders tracks and starts playback on tap.
///
/// Shared by search, liked songs, history and playlist contents: all four are
/// the same interaction, and tapping any row seeds the queue with the rest of
/// the list so what is on screen becomes what plays next.
class SongListView extends StatelessWidget {
  const SongListView({super.key, required this.songs, this.padding});

  final List<Song> songs;
  final EdgeInsets? padding;

  Future<void> _play(BuildContext context, int index) async {
    try {
      await playerService.setQueue(songs, startIndex: index);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reproducir: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? const EdgeInsets.only(bottom: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) => _SongRow(
        song: songs[index],
        onTap: () => _play(context, index),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
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
