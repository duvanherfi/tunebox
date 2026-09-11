import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/search.dart';
import '../../data/models/song.dart';
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
/// A card from a shelf carries only its id, and YouTube encodes the kind of
/// page in the id itself: albums start with `MPRE`, artist channels with `UC`,
/// and anything else is a playlist, including every mix. A search row knows
/// better than the id does — a profile's id starts with `UC` exactly like an
/// artist's — so it says so with [kind].
///
/// A profile opens on the artist page on purpose: a channel answers with the
/// same shape an artist does, shelves of what they published, and the page
/// already draws that.
void openCollection(
  BuildContext context,
  Playlist collection, {
  CollectionKind? kind,
}) {
  final id = collection.browseId;
  final screen = switch (kind) {
    CollectionKind.album => AlbumScreen(browseId: id, title: collection.title),
    CollectionKind.artist ||
    CollectionKind.profile =>
      ArtistScreen(browseId: id, name: collection.title),
    CollectionKind.playlist ||
    CollectionKind.podcast =>
      PlaylistScreen(playlist: collection),
    null => switch (id) {
      _ when id.startsWith('MPRE') =>
        AlbumScreen(browseId: id, title: collection.title),
      _ when isArtistId(id) => ArtistScreen(browseId: id, name: collection.title),
      _ => PlaylistScreen(playlist: collection),
    },
  };
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// The tracks of a collection named by a row rather than opened as a page.
///
/// A search row carries a title, a cover and an id and nothing else, so the
/// menu it opens has nothing to play until the page behind it is asked for.
/// That is one request, made when the menu opens rather than when the row is
/// drawn: a screen of results would otherwise fetch thirty pages nobody asked
/// to see. Which request it is follows [openCollection] exactly, so the menu
/// and the page always agree about what a row is.
Future<List<Song>> collectionSongs(
  Playlist collection,
  CollectionKind? kind,
) async {
  final id = collection.browseId;
  final page = switch (kind) {
    CollectionKind.album => await innertube.albumPage(id),
    CollectionKind.artist ||
    CollectionKind.profile =>
      await innertube.artistPage(id),
    CollectionKind.playlist ||
    CollectionKind.podcast =>
      await innertube.playlistPage(id),
    null => id.startsWith('MPRE')
        ? await innertube.albumPage(id)
        : isArtistId(id)
            ? await innertube.artistPage(id)
            : await innertube.playlistPage(id),
  };
  return page.songs;
}

/// Whether a browse id names a person rather than a list. The saved shelf holds
/// both, and they belong on different pages and in different tabs.
bool isArtistId(String browseId) => browseId.startsWith('UC');

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
