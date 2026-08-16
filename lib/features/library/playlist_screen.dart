import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../main.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.title)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Song>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final songs = snapshot.data ?? const [];
                if (songs.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context)!.libraryPlaylistEmpty),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (var i = 0; i < songs.length; i++)
                      SongRow(songs: songs, index: i),
                    // What else goes with this, once the list itself has been
                    // read: a playlist that ends in a wall is a dead end.
                    Suggestions(seed: songs.first),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
