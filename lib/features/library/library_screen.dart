import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../shared/skeleton.dart';
import '../shared/shelf_row.dart';
import '../shared/sorted_songs.dart';
import 'auto_playlists.dart';
import 'local_playlist_screen.dart';
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
      length: 8,
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
              Tab(text: l10n.librarySongs),
              Tab(text: l10n.libraryPlaylists),
              Tab(text: l10n.libraryAlbums),
              Tab(text: l10n.libraryArtists),
              Tab(text: l10n.libraryDevice),
              Tab(text: l10n.libraryHistory),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _Downloads(),
                if (session.isSignedIn)
                  _GrowingShelf(
                    pages: innertube.likedSongPages,
                    empty: l10n.libraryEmptyLikes,
                  )
                else
                  _SignedOut(onSignIn: _signIn),
                if (session.isSignedIn)
                  _GrowingShelf(
                    pages: innertube.librarySongPages,
                    empty: l10n.libraryEmptySongs,
                  )
                else
                  _SignedOut(onSignIn: _signIn),
                _Playlists(onSignIn: _signIn),
                if (session.isSignedIn)
                  _Shelf<Playlist>(
                    load: innertube.savedAlbums,
                    empty: l10n.libraryEmptyAlbums,
                    build: (albums) => _CollectionList(collections: albums),
                  )
                else
                  _SignedOut(onSignIn: _signIn),
                _Artists(onSignIn: _signIn),
                const _DeviceSongs(),
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

/// Playlists: the ones made here first, then the account's.
///
/// Two sources in one tab rather than two tabs, because a listener looking for
/// a playlist does not care which side of the network it lives on.
class _Playlists extends StatelessWidget {
  const _Playlists({required this.onSignIn});

  final VoidCallback onSignIn;

  Future<void> _create(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      // Above the shell, or it opens under the player bar.
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlistLocalNew),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.playlistNameHint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await localPlaylists.create(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: localPlaylists,
      builder: (context, _) => ListView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(l10n.playlistLocalNew),
            onTap: () => _create(context),
          ),
          for (final playlist in localPlaylists.all)
            ListTile(
              leading: Artwork(
                url: playlist.thumbnailUrl,
                size: 44,
                radius: 8,
              ),
              title: Text(playlist.name),
              subtitle: Text(l10n.sortCount(playlist.songs.length)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LocalPlaylistScreen(id: playlist.id),
                ),
              ),
            ),
          // Kept here rather than fetched: these are the collections the
          // listener marked, and the whole point of the mark is that the shelf
          // is there without an account and without a network.
          ListenableBuilder(
            listenable: savedCollections,
            builder: (context, _) {
              // Artists are kept in the same shelf and shown in their own tab:
              // a subscription is not a playlist, and reading it as one here
              // would open a list that does not exist.
              final saved = [
                for (final collection in savedCollections.all)
                  if (!isArtistId(collection.browseId)) collection,
              ];
              if (saved.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(l10n.librarySaved),
                  for (final collection in saved)
                    ListTile(
                      leading: Artwork(
                        url: collection.thumbnailUrl,
                        size: 44,
                        radius: 8,
                      ),
                      title: Text(
                        collection.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: collection.subtitle.isEmpty
                          ? null
                          : Text(
                              collection.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => openCollection(context, collection),
                    ),
                ],
              );
            },
          ),
          if (session.isSignedIn) ...[
            _SectionLabel(l10n.playlistInAccount),
            _AccountPlaylists(),
          ],
        ],
      ),
    );
  }
}

/// Artists: the ones followed from here first, then whoever the account
/// follows.
///
/// Two sources in one tab for the same reason the playlists tab has two — a
/// listener does not think of them as different shelves — and while signed out
/// the local marks are the whole tab rather than an invitation to sign in.
class _Artists extends StatelessWidget {
  const _Artists({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: savedCollections,
      builder: (context, _) {
        final followed = [
          for (final collection in savedCollections.all)
            if (isArtistId(collection.browseId)) collection,
        ];

        if (!session.isSignedIn) {
          if (followed.isEmpty) return _SignedOut(onSignIn: onSignIn);
          return _CollectionList(collections: followed, round: true);
        }

        return _Shelf<Playlist>(
          load: innertube.savedArtists,
          empty: l10n.libraryEmptyArtists,
          // The account's list already holds anything subscribed to from here
          // once YouTube has caught up; until then the local mark is what the
          // listener saw happen, so it leads.
          build: (artists) => _CollectionList(
            collections: [
              ...followed,
              ...artists.where((artist) => !followed.contains(artist)),
            ],
            round: true,
          ),
        );
      },
    );
  }
}

/// The account's own playlists, loaded once the tab is open.
class _AccountPlaylists extends StatefulWidget {
  @override
  State<_AccountPlaylists> createState() => _AccountPlaylistsState();
}

class _AccountPlaylistsState extends State<_AccountPlaylists> {
  late final Future<List<Playlist>> _future = innertube.savedPlaylists();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Playlist>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final playlists = snapshot.data ?? const <Playlist>[];
        return Column(
          children: [
            for (final playlist in playlists)
              ListTile(
                leading: Artwork(
                  url: playlist.thumbnailUrl,
                  size: 44,
                  radius: 8,
                ),
                title: Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: playlist.subtitle.isEmpty
                    ? null
                    : Text(
                        playlist.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistScreen(playlist: playlist),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// What is on the device, listed whether or not there is a network.
class _Downloads extends StatelessWidget {
  const _Downloads();

  /// The name of a track being fetched. It has left the queue and has not
  /// joined the library yet, so it is looked for in both.
  static String _titleFor(String videoId, List<Song> pending, List<Song> done) {
    for (final song in [...pending, ...done]) {
      if (song.videoId == videoId) return song.title;
    }
    return videoId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final songs = downloads.songs;
        final pending = downloads.queued;
        final active = downloads.inProgress;

        if (songs.isEmpty && pending.isEmpty && active.isEmpty) {
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
        // What is arriving goes above what has arrived: the rows that change
        // are the ones being watched.
        return Column(
          children: [
            for (final entry in active.entries)
              _Downloading(
                title: _titleFor(entry.key, pending, songs),
                progress: entry.value,
              ),
            for (final song in pending)
              ListTile(
                dense: true,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(l10n.downloadQueued),
                trailing: IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => downloads.cancel(song.videoId),
                ),
              ),
            if (songs.isNotEmpty) Expanded(child: SortedSongs(songs: songs)),
          ],
        );
      },
    );
  }
}

/// A track being fetched right now, with how far it has got.
class _Downloading extends StatelessWidget {
  const _Downloading({required this.title, required this.progress});

  final String title;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.downloading_rounded),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            // Indeterminate until the first bytes report a size: a bar sitting
            // at zero looks stuck, and it is not.
            value: progress == 0 ? null : progress,
            minHeight: 4,
          ),
        ),
      ),
      trailing: Text('${(progress * 100).round()}%'),
    );
  }
}

/// A plain list of albums or artists, each opening its own page.
class _CollectionList extends StatelessWidget {
  const _CollectionList({required this.collections, this.round = false});

  final List<Playlist> collections;

  /// Artists are people; a circle says so.
  final bool round;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        return ListTile(
          leading: Artwork(
            url: collection.thumbnailUrl,
            size: 48,
            radius: round ? 24 : 8,
          ),
          title: Text(
            collection.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: collection.subtitle.isEmpty
              ? null
              : Text(
                  collection.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => openCollection(context, collection),
        );
      },
    );
  }
}

/// The music already on the phone, once permission is given to look.
class _DeviceSongs extends StatelessWidget {
  const _DeviceSongs();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: deviceSongs,
      builder: (context, _) {
        if (deviceSongs.scanning) {
          return const Center(child: CircularProgressIndicator());
        }
        if (deviceSongs.songs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.libraryDeviceEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () async {
                      final allowed = await deviceSongs.scan();
                      if (!allowed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.libraryDeviceDenied)),
                        );
                      }
                    },
                    child: Text(l10n.libraryDeviceScan),
                  ),
                ],
              ),
            ),
          );
        }
        return SortedSongs(songs: deviceSongs.songs);
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
/// A song list that paints its first page and keeps growing behind it.
///
/// The account's own lists run to hundreds of tracks and arrive a hundred at a
/// time, so waiting for the last page would leave the tab blank for a dozen
/// requests. What arrives is shown, and the rest lands underneath it — which
/// also keeps the sorting honest, since [SortedSongs] reorders whatever it is
/// given and half a list sorted reads as a whole one.
class _GrowingShelf extends StatefulWidget {
  const _GrowingShelf({required this.pages, required this.empty});

  final Stream<List<Song>> Function() pages;
  final String empty;

  @override
  State<_GrowingShelf> createState() => _GrowingShelfState();
}

class _GrowingShelfState extends State<_GrowingShelf>
    with AutomaticKeepAliveClientMixin {
  final _songs = <Song>[];
  StreamSubscription<List<Song>>? _reading;
  Object? _error;
  var _done = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _read();
  }

  void _read() {
    _reading?.cancel();
    setState(() {
      _songs.clear();
      _error = null;
      _done = false;
    });
    _reading = widget.pages().listen(
      (page) => setState(() => _songs.addAll(page)),
      // A page that never came is not a reason to empty the screen: what did
      // arrive is still the account's, and the retry is the same pull down.
      onError: (Object error) => setState(() {
        _error = error;
        _done = true;
      }),
      onDone: () => setState(() => _done = true),
    );
  }

  @override
  void dispose() {
    _reading?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_songs.isEmpty) {
      if (_error != null) return _Retry(message: '$_error', onRetry: _read);
      if (!_done) return const SongListSkeleton();
      return Center(child: Text(widget.empty));
    }
    return RefreshIndicator(
      onRefresh: () async => _read(),
      child: SortedSongs(songs: _songs),
    );
  }
}

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
