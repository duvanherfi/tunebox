import 'package:flutter/material.dart';

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
      padding: padding,
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: song.thumbnailUrl == null
                ? const SizedBox(width: 48, height: 48)
                : Image.network(
                    song.thumbnailUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 48, height: 48),
                  ),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              Text(song.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _play(context, index),
        );
      },
    );
  }
}
