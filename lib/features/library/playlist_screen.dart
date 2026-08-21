import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/collection_header.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';
import '../shared/song_pages.dart';
import '../shared/suggestions.dart';

/// The tracks inside a saved playlist or album.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  /// A method rather than a closure built in `build`, so a rebuild does not
  /// read as a different list and start the whole playlist over.
  Stream<List<Song>> _pages() =>
      innertube.playlistSongPages(widget.playlist.browseId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.title)),
      body: SongPages(
        pages: _pages,
        build: (view) {
          final songs = view.songs;

          // Nothing yet and nothing to say about it: the first page is still on
          // its way, and a playlist opens onto its shape rather than a spinner.
          if (songs.isEmpty && !view.done) return const SongListSkeleton();

          if (songs.isEmpty && view.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${view.error}', textAlign: TextAlign.center),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // The card that opened this already knew the name and the cover,
              // so the header is complete before the tracks arrive and does not
              // have to be fetched a second time.
              SliverToBoxAdapter(
                child: CollectionHeader(
                  title: widget.playlist.title,
                  subtitle: widget.playlist.subtitle,
                  thumbnailUrl: widget.playlist.thumbnailUrl,
                  songs: songs,
                  collection: widget.playlist,
                ),
              ),
              if (songs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.libraryPlaylistEmpty)),
                  ),
                )
              else ...[
                SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) =>
                      SongRow(songs: songs, index: index),
                ),
                // Only once the list really is the whole list. Suggestions
                // under a hundred rows of a list that is still growing would
                // read as its end, and it is not.
                if (view.done)
                  SliverToBoxAdapter(child: Suggestions(seed: songs.first)),
              ],
              if (!view.done) const SliverToBoxAdapter(child: MoreComing()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
