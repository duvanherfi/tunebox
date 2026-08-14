import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../shared/song_list_view.dart';
import 'playlist_screen.dart';

/// The signed-in surfaces: liked songs, saved playlists and listening history.
///
/// Every tab is the same browse endpoint with a different id, so they share one
/// loader and differ only in how the result is rendered.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _signIn() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!session.isSignedIn) return _SignedOut(onSignIn: _signIn);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Me gusta'),
              Tab(text: 'Playlists'),
              Tab(text: 'Historial'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Shelf<Song>(
                  load: innertube.likedSongs,
                  empty: 'No has marcado ninguna canción',
                  build: (songs) => SongListView(songs: songs),
                ),
                _Shelf<Playlist>(
                  load: innertube.savedPlaylists,
                  empty: 'No tienes playlists guardadas',
                  build: (playlists) => _PlaylistGrid(playlists: playlists),
                ),
                _Shelf<Song>(
                  load: innertube.history,
                  empty: 'Todavía no has escuchado nada',
                  build: (songs) => SongListView(songs: songs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'Inicia sesión para ver tu biblioteca',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tus me gusta, playlists e historial de YouTube Music.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onSignIn,
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads one browse shelf and renders it, with retry on failure.
class _Shelf<T> extends StatefulWidget {
  const _Shelf({
    super.key,
    required this.load,
    required this.build,
    required this.empty,
  });

  final Future<List<T>> Function() load;
  final Widget Function(List<T>) build;
  final String empty;

  @override
  State<_Shelf<T>> createState() => _ShelfState<T>();
}

class _ShelfState<T> extends State<_Shelf<T>>
    with AutomaticKeepAliveClientMixin {
  late Future<List<T>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Retry(
            message: '${snapshot.error}',
            onRetry: () => setState(() => _future = widget.load()),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return Center(child: Text(widget.empty));
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = widget.load());
            await _future;
          },
          child: widget.build(items),
        );
      },
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistScreen(playlist: playlist),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: playlist.thumbnailUrl == null
                      ? const ColoredBox(
                          color: Colors.white10,
                          child: Center(child: Icon(Icons.queue_music)),
                        )
                      : Image.network(
                          playlist.thumbnailUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.white10,
                            child: Center(child: Icon(Icons.queue_music)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                playlist.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }
}
