import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../browse/album_screen.dart';
import '../browse/artist_screen.dart';
import '../library/playlist_screen.dart';

/// A titled row of covers, scrolling sideways.
///
/// The same shape carries the home feed, an artist's discography and anything
/// else YouTube hands back as a carousel, so it lives here rather than in the
/// first screen that needed it.
class ShelfRow extends StatelessWidget {
  const ShelfRow({super.key, required this.shelf});

  final Shelf shelf;

  static const _cardWidth = 156.0;

  Future<void> _play(BuildContext context, int index) async {
    try {
      await playerService.setQueue(shelf.songs, startIndex: index);
    } catch (_) {
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
    // A row is one or the other: tracks when the feed knows the listener,
    // covers when it does not.
    final songs = shelf.songs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(shelf.title),
        SizedBox(
          // Room for the cover plus two lines of title beneath it.
          height: _cardWidth + 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.isNotEmpty ? songs.length : shelf.playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => songs.isNotEmpty
                ? CoverCard(
                    title: songs[index].title,
                    thumbnailUrl: songs[index].thumbnailUrl,
                    width: _cardWidth,
                    onTap: () => _play(context, index),
                  )
                : CoverCard(
                    title: shelf.playlists[index].title,
                    thumbnailUrl: shelf.playlists[index].thumbnailUrl,
                    width: _cardWidth,
                    onTap: () => openCollection(context, shelf.playlists[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Opens whatever a card points at.
///
/// YouTube encodes the kind of page in the id itself, which is the only clue a
/// card carries: albums start with `MPRE`, artist channels with `UC`. Anything
/// else is a playlist, including every mix.
void openCollection(BuildContext context, Playlist collection) {
  final id = collection.browseId;
  final screen = switch (id) {
    _ when id.startsWith('MPRE') => AlbumScreen(browseId: id, title: collection.title),
    _ when id.startsWith('UC') => ArtistScreen(browseId: id, name: collection.title),
    _ => PlaylistScreen(playlist: collection),
  };
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// One cover with its title, whether it opens a collection or starts a track.
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.title,
    required this.thumbnailUrl,
    required this.width,
    required this.onTap,
  });

  final String title;
  final String? thumbnailUrl;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(url: thumbnailUrl, size: width),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
