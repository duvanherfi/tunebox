import 'package:flutter/material.dart';

import '../../data/models/song.dart';
import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/collection_header.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';
import '../shared/suggestions.dart';

/// The tracks inside a saved playlist or album.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = innertube.playlistSongs(widget.playlist.browseId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.title)),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SongListSkeleton();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final songs = snapshot.data ?? const <Song>[];
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
                // What else goes with this, once the list itself has been
                // read: a playlist that ends in a wall is a dead end.
                SliverToBoxAdapter(child: Suggestions(seed: songs.first)),
              ],
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
