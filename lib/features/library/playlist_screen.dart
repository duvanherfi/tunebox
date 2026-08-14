import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../main.dart';
import '../player/mini_player.dart';
import '../shared/song_list_view.dart';

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
                  return const Center(child: Text('Esta playlist está vacía'));
                }
                return SongListView(songs: songs);
              },
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
