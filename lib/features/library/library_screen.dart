import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../shared/skeleton.dart';
import '../shared/sorted_songs.dart';
import 'auto_playlists.dart';
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

  /// What was played here, then what the account remembers.
  ///
  /// Two sources because they answer different questions. The device knows what
  /// this app just played, instantly and exactly; the account knows everything
  /// heard anywhere else, but writes on its own schedule. Showing the local
  /// plays first means a track appears in History the moment it starts, and the
  /// rest of a listening life is still there underneath.
  Future<List<Song>> _history() async {
    final local = playHistory.songs;
    final seen = local.map((song) => song.videoId).toSet();
    if (!session.isSignedIn) return local;
    try {
      final remote = await innertube.history();
      return [...local, ...remote.where((song) => !seen.contains(song.videoId))];
    } catch (_) {
      return local; // A history that only reaches back to this device still is one.
    }
  }

  Future<void> _signIn() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Only the two account-backed tabs need a session. Downloads and history
    // are this device's, and hiding them behind a sign-in wall would be a lie
    // about where they come from.
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Above the tabs, because these are not one of them: they cut across
          // everything the library holds.
          const AutoPlaylists(),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.libraryDownloads),
              Tab(text: l10n.libraryLikes),
              Tab(text: l10n.libraryPlaylists),
              Tab(text: l10n.libraryHistory),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _Downloads(),
                if (session.isSignedIn)
                  _Shelf<Song>(
                    load: innertube.likedSongs,
                    empty: l10n.libraryEmptyLikes,
                    build: (songs) => SortedSongs(songs: songs),
                  )
                else
                  _SignedOut(onSignIn: _signIn),
                if (session.isSignedIn)
                  _Shelf<Playlist>(
                    load: innertube.savedPlaylists,
                    empty: l10n.libraryEmptyPlaylists,
                    build: (playlists) => _PlaylistGrid(playlists: playlists),
                  )
                else
                  _SignedOut(onSignIn: _signIn),
                _Shelf<Song>(
                  load: _history,
                  empty: l10n.libraryEmptyHistory,
                  build: (songs) => SortedSongs(songs: songs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What is on the device, listed whether or not there is a network.
class _Downloads extends StatelessWidget {
  const _Downloads();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final songs = downloads.songs;
        if (songs.isEmpty && downloads.inProgress.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.libraryEmptyDownloads,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return SortedSongs(songs: songs);
      },
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.librarySignedOutTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.librarySignedOutBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onSignIn, child: Text(l10n.signIn)),
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
          return const SongListSkeleton();
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.74,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistScreen(playlist: playlist),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Artwork(
                    url: playlist.thumbnailUrl,
                    size: constraints.maxWidth,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
